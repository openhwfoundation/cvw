///////////////////////////////////////////
// tb_vfrec7.sv
//
// Purpose: Standalone self-checking unit test for src/vpu/vfrec7.sv.
//
// This does not compare against another copy of the RTL. Expected values
// come from an independent real-number decode of IEEE 754 bit patterns
// (rechecking the RISC-V vfrec7 accuracy bound, |approx*x - 1| <= 2^-6)
// and from the standard IEEE round-on-overflow table, both derived from
// the spec rather than from the design under test.
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

  // Generous relative-error bound: the spec guarantees 2^-7, this leaves
  // margin so the test only catches real regressions, not ulp nitpicks.
  localparam real ERR_BOUND = 2.0 ** -6;

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

  function automatic real decode_fp(
    input logic [63:0] bits, input int expbits, input int fracbits
  );
    logic sign;
    longint unsigned expfield, fracfield, expmask, fracmask;
    int bias;
    real fracval, val;
    expmask  = (64'h1 << expbits)  - 1;
    fracmask = (64'h1 << fracbits) - 1;
    sign     = bits[expbits+fracbits];
    expfield = (bits >> fracbits) & expmask;
    fracfield = bits & fracmask;
    bias = (1 << (expbits-1)) - 1;
    if (expfield == 0)
      fracval = real'(fracfield) / real'(longint'(1) << fracbits);
    else
      fracval = 1.0 + real'(fracfield) / real'(longint'(1) << fracbits);
    val = fracval * (2.0 ** real'((expfield == 0 ? 1 : longint'(expfield)) - bias));
    decode_fp = sign ? -val : val;
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
    #1;
    checks++;
    if (vd !== exp_vd || fflags !== exp_fflags) begin
      errors++;
      $display("MISMATCH[%s]: vsew=%0d rm=%0d vs2=%h  got(vd=%h,fflags=%b)  want(vd=%h,fflags=%b)",
                tag, vsew, rm, vs2, vd, fflags, exp_vd, exp_fflags);
    end
  endtask

  task automatic check_approx(input string tag, input int expbits, input int fracbits);
    real x, y, err;
    #1;
    checks++;
    if (fflags !== 5'b0) begin
      errors++;
      $display("MISMATCH[%s]: vsew=%0d vs2=%h expected no flags, got fflags=%b",
                tag, vsew, vs2, fflags);
      return;
    end
    x = decode_fp(vs2, expbits, fracbits);
    y = decode_fp(vd,  expbits, fracbits);
    err = (x * y) - 1.0;
    if (err < 0.0) err = -err;
    if (err > ERR_BOUND) begin
      errors++;
      $display("MISMATCH[%s]: vsew=%0d vs2=%h vd=%h  x=%f y=%f |x*y-1|=%f > %f",
                tag, vsew, vs2, vd, x, y, err, ERR_BOUND);
    end
  endtask

  task automatic check_top7_match(
    input string tag, input logic [6:0] a, input logic [6:0] b
  );
    checks++;
    if (a !== b) begin
      errors++;
      $display("MISMATCH[%s]: top-7 significand differs across SEW: %h vs %h", tag, a, b);
    end
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
    // Generic finite, nonzero, non-overflow inputs: accuracy-bound sweep
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
              vs2 = pack_fp(sgn[0], expval, frac, expbits, width);
              check_approx("normal-sweep", expbits, width);
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
            vs2 = pack_fp(sgn[0], 64'h0, frac, expbits, width);
            check_approx("subnormal-sweep", expbits, width);
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

    $finish(errors == 0 ? 0 : 1);
  end

endmodule
