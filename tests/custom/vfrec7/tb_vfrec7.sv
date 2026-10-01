///////////////////////////////////////////
// tb_vfrec7.sv
//
// Purpose: Standalone self-checking unit test for src/vpu/vfrec7.sv.
//
// This does not reuse any of the DUT's RTL.
// Expected values are computed bit-exact by an independent reference model
// (function expected_vfrec7 below) that reimplements the ISA-level
// algorithm directly from IEEE 754 bit fields: normalize, look up the
// 7-bit reciprocal approximation, recompute the output exponent, and
// reassemble, including the reciprocal-result-is-subnormal case. The 7-bit
// approximation is computed from its definition (function rec7_ref), not
// copied from the RVV table, so a wrong table entry in the RTL is caught.
// Directed special cases (NaN/Inf/zero/overflow) use the standard IEEE
// tables the same way.
////////////////////////////////////////////////////////////////////////////////////////////////

`include "config.vh"

import cvw::*;

module tb_vfrec7;

  `include "parameter-defs.vh"

  localparam logic [2:0] VSEW_16 = 3'b001;
  localparam logic [2:0] VSEW_32 = 3'b010;
  localparam logic [2:0] VSEW_64 = 3'b011;

  localparam logic [2:0] RNE = 3'b000;
  localparam logic [2:0] RTZ = 3'b001;
  localparam logic [2:0] RDN = 3'b010;
  localparam logic [2:0] RUP = 3'b011;
  localparam logic [2:0] RMM = 3'b100;

  localparam int NV = 4;
  localparam int DZ = 3;
  localparam int OF = 2;

  logic [63:0] vs2;
  logic [2:0]  vsew;
  logic [2:0]  rm;
  logic [63:0] vd;
  logic [4:0]  fflags;

  // ----------------------------------------------------------------------
  // vfrec7 sits downstream of the FPU's unpackinput unit and does not
  // instantiate it itself, so the testbench wires the two together here,
  // the same way the VPU pipeline will.
  //
  // unpackinput expects a scalar-style FLEN-wide operand that is properly
  // NaN-boxed above its native width. Vector elements carry no such
  // boxing, so the selected SEW-wide element is boxed here first.
  // ----------------------------------------------------------------------
  logic [P.FMTBITS-1:0] fmt;
  logic [P.FLEN-1:0]    boxedVs2;

  always_comb
    case (vsew)
      VSEW_16: begin fmt = P.H_FMT; boxedVs2 = {{(P.FLEN-16){1'b1}}, vs2[15:0]}; end
      VSEW_32: begin fmt = P.S_FMT; boxedVs2 = {{(P.FLEN-32){1'b1}}, vs2[31:0]}; end
      VSEW_64: begin fmt = P.D_FMT; boxedVs2 = vs2;                             end
      default: begin fmt = P.H_FMT; boxedVs2 = '0;                              end
    endcase

  logic            sign, nan, snan, zero, inf, subnorm;
  logic [P.NE-1:0] exp;
  logic [P.NF:0]   man;

  unpackinput #(P) unpackVs2 (
    .A         (boxedVs2),
    .Fmt       (fmt),
    .En        (1'b1),
    .FPUActive (1'b1),
    .Sgn       (sign),
    .Exp       (exp),
    .Man       (man),
    .NaN       (nan),
    .SNaN      (snan),
    .Zero      (zero),
    .Inf       (inf),
    .ExpMax    (),
    .Subnorm   (subnorm),
    .PostBox   ()
  );

  vfrec7 #(P) dut (
    .Xs        (sign),
    .Xe        (exp),
    .Xm        (man),
    .XNaN      (nan),
    .XSNaN     (snan),
    .XZero     (zero),
    .XInf      (inf),
    .XSubnorm  (subnorm),
    .Vsew      (vsew),
    .Frm       (rm),
    .Vfrec7Res (vd),
    .Vfrec7Flg (fflags)
  );

  int checks = 0;
  int errors = 0;
  int logfd;   // results/vfrec7.log: one line per check, pass or fail

  // ----------------------------------------------------------------------
  // Bit-pattern <-> real helpers, independent of the DUT
  // ----------------------------------------------------------------------

  function automatic logic [63:0] pack_fp(
    input logic sign, input longint unsigned expval, input longint unsigned fracval,
    input int expbits, input int fracbits
  );
    longint unsigned expmask, fracmask;
    expmask  = (64'h1 << expbits)  - 1;
    fracmask = (64'h1 << fracbits) - 1;
    pack_fp = (longint'(sign) << (expbits + fracbits)) |
              ((expval & expmask) << fracbits) |
              (fracval & fracmask);
  endfunction

  // ----------------------------------------------------------------------
  // Golden reference model for finite, nonzero, non-overflow inputs.
  // Reimplements the ISA-level vfrec7 algorithm directly from the IEEE 754
  // bit fields (normalize -> 7-bit LUT -> recompute exponent -> reassemble,
  // including the case where the reciprocal result is itself subnormal),
  // independent of the DUT's RTL.
  // ----------------------------------------------------------------------

  // Reference 7-bit reciprocal: the reciprocal of the midpoint of input
  // interval idx, [1 + idx/128, 1 + (idx+1)/128), scaled into [1,2) and its
  // 7 fraction bits rounded to nearest. This reproduces the RVV vfrec7
  // table without copying its values; no entry is within 0.02 ulp of a tie,
  // so real arithmetic is exact enough.
  function automatic logic [6:0] rec7_ref(input longint unsigned idx);
    real m;
    m = 1.0 + real'(2*idx + 1) / 256.0;
    return 7'($rtoi((2.0/m - 1.0) * 128.0 + 0.5));
  endfunction

  function automatic int clz(input longint unsigned val, input int width);
    clz = width;
    for (int i = width-1; i >= 0; i--)
      if (val[i]) begin
        clz = width-1-i;
        break;
      end
  endfunction

  function automatic void expected_vfrec7(
    input  logic            sign,
    input  longint unsigned expfield,
    input  longint unsigned fracfield,   // must be nonzero when expfield == 0
    input  int               expbits,
    input  int               fracbits,
    output logic [63:0]      exp_vd,
    output logic [4:0]       exp_fflags
  );
    longint unsigned bias, idx, shifted, r7, frac_out, pre_shift;
    longint signed   e, eOutBiased;
    int              z;

    bias       = (64'h1 << (expbits-1)) - 1;
    exp_fflags = 5'b0;

    if (expfield != 0) begin // normal input: already in [1,2)
      e   = longint'(expfield) - longint'(bias);
      idx = fracfield >> (fracbits-7);
    end else begin // subnormal input: shift the implicit leading 1 into place
      z       = clz(fracfield, fracbits);
      e       = -longint'(bias) - longint'(z);
      shifted = (fracfield << (z+1)) & ((64'h1 << fracbits) - 1);
      idx     = shifted >> (fracbits-7);
    end

    r7         = rec7_ref(idx);
    eOutBiased = longint'(bias) - 1 - e; // this format's biased output exponent

    if (eOutBiased == 0 || eOutBiased == -1) begin // reciprocal result is itself subnormal
      pre_shift = (64'h1 << fracbits) | (r7 << (fracbits-7));
      frac_out  = (pre_shift >> (eOutBiased == 0 ? 1 : 2)) & ((64'h1 << fracbits) - 1);
      exp_vd    = pack_fp(sign, 64'h0, frac_out, expbits, fracbits);
    end else begin // normal result
      frac_out = r7 << (fracbits-7);
      exp_vd   = pack_fp(sign, eOutBiased, frac_out, expbits, fracbits); // eOutBiased >= 1 here
    end
  endfunction

  function automatic int expbits_of(input logic [2:0] sew);
    expbits_of = (sew == VSEW_16) ? 5 : (sew == VSEW_32) ? 8 : 11;
  endfunction

  function automatic int fracbits_of(input logic [2:0] sew);
    fracbits_of = (sew == VSEW_16) ? 10 : (sew == VSEW_32) ? 23 : 52;
  endfunction

  // ----------------------------------------------------------------------
  // Checks
  // ----------------------------------------------------------------------

  task automatic check_exact(
    input string tag, input logic [63:0] exp_vd, input logic [4:0] exp_fflags
  );
    logic pass;
    #1;
    checks++;
    pass = (vd === exp_vd) && (fflags === exp_fflags);
    if (!pass) begin
      errors++;
      $display("MISMATCH[%s]: vsew=%0d rm=%0d vs2=%h  got(vd=%h,fflags=%b)  want(vd=%h,fflags=%b)",
                tag, vsew, rm, vs2, vd, fflags, exp_vd, exp_fflags);
    end
    $fdisplay(logfd, "%s [%s] vsew=%0d rm=%0d vs2=%h -> vd=%h fflags=%b (want vd=%h fflags=%b)",
              pass ? "PASS" : "FAIL", tag, vsew, rm, vs2, vd, fflags, exp_vd, exp_fflags);
  endtask

  task automatic check_top7_match(
    input string tag, input logic [6:0] a, input logic [6:0] b
  );
    logic pass;
    checks++;
    pass = (a === b);
    if (!pass) begin
      errors++;
      $display("MISMATCH[%s]: top-7 significand differs across SEW: %h vs %h", tag, a, b);
    end
    $fdisplay(logfd, "%s [%s] a=%h b=%h", pass ? "PASS" : "FAIL", tag, a, b);
  endtask

  // ----------------------------------------------------------------------
  // Independent overflow round-mode table (standard IEEE overflow rule)
  // ----------------------------------------------------------------------

  function automatic logic expected_overflow_to_inf(input logic sign, input logic [2:0] rmv);
    case (rmv)
      RTZ: expected_overflow_to_inf = 1'b0;
      RUP: expected_overflow_to_inf = sign ? 1'b0 : 1'b1;
      RDN: expected_overflow_to_inf = sign ? 1'b1 : 1'b0;
      default: expected_overflow_to_inf = 1'b1; // RNE, RMM, and reserved encodings
    endcase
  endfunction

  int unsigned fw[3];
  int unsigned eb[3];
  logic [2:0]  sews[3];
  logic [63:0] sign_mask, pos_inf, max_finite, canonical_nan;

  initial begin
    logfd = $fopen("results/vfrec7.log", "w");

    fw[0] = 10; eb[0] = 5;  sews[0] = VSEW_16;
    fw[1] = 23; eb[1] = 8;  sews[1] = VSEW_32;
    fw[2] = 52; eb[2] = 11; sews[2] = VSEW_64;

    // ======================================================================
    // Directed special cases
    // ======================================================================
    for (int fmt = 0; fmt < 3; fmt++) begin
      int unsigned width, expbits;
      longint unsigned allones;
      width = fw[fmt]; expbits = eb[fmt];
      vsew = sews[fmt];
      rm   = RNE;
      allones = (64'h1 << expbits) - 1;

      sign_mask     = pack_fp(1'b1, 64'h0, 64'h0, expbits, width);
      pos_inf       = pack_fp(1'b0, allones, 64'h0, expbits, width);
      max_finite    = pack_fp(1'b0, allones - 1, (64'h1 << width) - 1, expbits, width);
      canonical_nan = pack_fp(1'b0, allones, (64'h1 << (width-1)), expbits, width);

      for (int sgn = 0; sgn < 2; sgn++) begin
        vs2 = pack_fp(sgn[0], 64'h0, 64'h0, expbits, width);
        check_exact("zero->inf", pos_inf | (sgn ? sign_mask : 64'h0), 5'b1 << DZ);

        vs2 = pack_fp(sgn[0], allones, 64'h0, expbits, width);
        check_exact("inf->zero", sgn ? sign_mask : 64'h0, 5'b0);

        vs2 = pack_fp(sgn[0], allones, (64'h1 << (width-1)), expbits, width);
        check_exact("qnan", canonical_nan, 5'b0);

        vs2 = pack_fp(sgn[0], allones, 64'h1, expbits, width);
        check_exact("snan", canonical_nan, 5'b1 << NV);
      end

      // ====================================================================
      // Very-small subnormal: reciprocal exponent overflows, saturating to
      // +/-max-finite or +/-infinity per rounding mode.
      // ====================================================================
      for (int ki = 0; ki < 3; ki++) begin
        int unsigned k;
        longint unsigned frac;
        k = (ki == 0) ? 2 : (ki == 1) ? (width/2) : (width-1);
        frac = 64'h1 << (width-1-k);
        for (int sgn = 0; sgn < 2; sgn++) begin
          for (int rmv = 0; rmv < 8; rmv++) begin
            logic to_inf;
            vs2 = pack_fp(sgn[0], 64'h0, frac, expbits, width);
            rm  = rmv[2:0];
            to_inf = expected_overflow_to_inf(sgn[0], rmv[2:0]);
            check_exact("overflow",
                        (to_inf ? pos_inf : max_finite) | (sgn ? sign_mask : 64'h0),
                        (5'b1 << OF) | 5'b1);
          end
        end
      end
    end

    // ======================================================================
    // Generic finite, nonzero, non-overflow inputs: exact-match sweep
    // ======================================================================
    for (int fmt = 0; fmt < 3; fmt++) begin
      int unsigned width, expbits;
      width = fw[fmt]; expbits = eb[fmt];
      vsew = sews[fmt];
      rm   = RNE;

      // Normal-exponent sweep: min normal, mid, max normal.
      for (int ei = 0; ei < 3; ei++) begin
        longint unsigned expval;
        expval = (ei == 0) ? 1 : (ei == 1) ? (1 << (expbits-1)) : ((1 << expbits) - 2);
        for (int idx = 0; idx < 128; idx++) begin
          for (int lowfill = 0; lowfill < 2; lowfill++) begin
            longint unsigned lowwidth, lowbits, frac;
            lowwidth = width - 7;
            lowbits  = lowfill ? ((64'h1 << lowwidth) - 1) : 64'h0;
            frac     = (longint'(idx) << lowwidth) | lowbits;
            for (int sgn = 0; sgn < 2; sgn++) begin
              logic [63:0] exp_vd;
              logic [4:0]  exp_fflags;
              expected_vfrec7(sgn[0], expval, frac, expbits, width, exp_vd, exp_fflags);
              vs2 = pack_fp(sgn[0], expval, frac, expbits, width);
              check_exact("normal-sweep", exp_vd, exp_fflags);
            end
          end
        end
      end

      // Subnormal-input sweep (zero_count 0 and 1, still in-range).
      for (int k = 0; k < 2; k++) begin
        for (int idx = 0; idx < 128; idx += 5) begin
          longint unsigned frac;
          frac = (64'h1 << (width-1-k)) | (longint'(idx) >> (k+1));
          for (int sgn = 0; sgn < 2; sgn++) begin
            logic [63:0] exp_vd;
            logic [4:0]  exp_fflags;
            expected_vfrec7(sgn[0], 64'h0, frac, expbits, width, exp_vd, exp_fflags);
            vs2 = pack_fp(sgn[0], 64'h0, frac, expbits, width);
            check_exact("subnormal-sweep", exp_vd, exp_fflags);
          end
        end
      end
    end

    // ======================================================================
    // Cross-SEW consistency: with the input exponent fixed at each format's
    // own bias, norm_out_exp is always in the normal range for every SEW,
    // so the assembled result's top-7 significand bits (driven straight by
    // the shared LUT) must match across SEW for a given lut_idx.
    // ======================================================================
    for (int idx = 0; idx < 128; idx++) begin
      for (int sgn = 0; sgn < 2; sgn++) begin
        logic [6:0] top7 [3];
        for (int fmt = 0; fmt < 3; fmt++) begin
          int unsigned width, expbits;
          longint unsigned bias;
          width = fw[fmt]; expbits = eb[fmt];
          bias  = (1 << (expbits-1)) - 1;
          vsew  = sews[fmt];
          rm    = RNE;
          vs2   = pack_fp(sgn[0], bias, longint'(idx) << (width-7), expbits, width);
          #1;
          checks++;
          if (fflags !== 5'b0) begin
            errors++;
            $display("MISMATCH[cross-sew]: unexpected fflags=%b vsew=%0d idx=%0d", fflags, vsew, idx);
          end
          top7[fmt] = vd[width-1 -: 7];
        end
        check_top7_match("cross-sew16v32", top7[0], top7[1]);
        check_top7_match("cross-sew32v64", top7[1], top7[2]);
      end
    end

    if (errors == 0)
      $display("ALL PASS: %0d checks, 0 mismatches", checks);
    else
      $display("FAILURES: %0d/%0d checks mismatched", errors, checks);

    if (errors == 0)
      $fdisplay(logfd, "ALL PASS: %0d checks, 0 mismatches", checks);
    else
      $fdisplay(logfd, "FAILURES: %0d/%0d checks mismatched", errors, checks);
    $fclose(logfd);

    $finish(errors == 0 ? 0 : 1);
  end

endmodule
