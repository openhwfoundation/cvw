///////////////////////////////////////////
//
// Written: me@KatherineParry.com, james.stine@okstate.edu
//
// Purpose: Testbench for UCB Testfloat on Wally
//
// A component of the Wally configurable RISC-V project.
//
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

`include "config.vh"
`include "tests_fp.vh"

import cvw::*;

module testbench_fp;
  // The test and the precisions to run come from the plusargs +TEST= and +TEST_SIZE=, so one compiled
  // design runs every test of a configuration.  The parameters are the defaults when a plusarg is absent.
  parameter string TEST="none"; // choices are cvtint, cvtfp, cmp, add, sub, mul, div, sqrt, fma, round, class, sgnj, minmax, all
  parameter string TEST_SIZE="all"; // all, QP, DP, SP, or HP
  string TestName, TestSize;
  string VectorPath;                           // directory (and file-name prefix) of the test vectors

  `include "parameter-defs.vh"

  // FIXME: needs cleaning of unused variables (jes)
  string       Tests[];                        // list of tests to be run
  logic [3:0]  OpCtrl[];                       // list of op controls: {Zfa, OpCtrl}
  logic [3:0]  Unit[];                         // list of units being tested
  logic        WriteInt[];                     // Is being written to integer resgiter
  logic [2:0]  Frm[4:0] = {3'b100, 3'b010, 3'b011, 3'b001, 3'b000}; // rounding modes: rne-000, rz-001, ru-011, rd-010, rnm-100
  logic [1:0]  Fmt[];                          // list of formats for the other units

  logic        clk=0;
  logic [31:0] TestNum=0;                      // index for the test
  logic [31:0] errors=0;                       // how many errors
  logic [31:0] VectorNum=0;                    // index for test vector
  // A vector holds up to four Q_LEN-bit fields (X, Y, Z, Ans) above an 8-bit field (two hex digits) of flags
  logic [P.Q_LEN*4+7:0]  TestVector;          // current test vector, streamed from the .tv file
  int          fd;                             // test vector file

  logic [1:0] FmtVal;                          // value of the current Fmt
  logic [3:0] UnitVal, OpCtrlVal;              // value of the current Unit/OpCtrl ({Zfa, OpCtrl})
  logic [2:0] FrmVal;                          // value of the current rounding mode
  logic       WriteIntVal;                     // value of the current WriteInt
  logic [P.Q_LEN-1:0]  X, Y, Z;                // inputs read from TestFloat
  logic [P.FLEN-1:0]   XPostBox;               // inputs read from TestFloat
  logic [P.XLEN-1:0]   SrcA;                   // integer input
  logic [P.Q_LEN-1:0]  Ans;                    // correct answer from TestFloat
  logic [P.Q_LEN-1:0]  Res;                    // result from other units
  logic [4:0] AnsFlg;                          // correct flags read from testfloat
  logic [4:0] ResFlg, Flg;                     // Result flags
  logic [P.FMTBITS-1:0] ModFmt;                // format - 10 = half, 00 = single, 01 = double, 11 = quad
  logic [P.FLEN-1:0]    FpRes, FpCmpRes;       // Results from each unit
  logic [P.XLEN-1:0]    IntRes, CmpRes;        // Results from each unit
  logic [P.FLEN-1:0]    FRoundRes, SgnRes;     // fround and sign injection results
  logic [P.XLEN-1:0]    ClassRes;              // fclass result
  logic                 FRoundNV, FRoundNX;    // fround flags
  logic [P.Q_LEN-1:0]   FpResExtended;         // FpRes extended to same length as Ans/Res
  logic [4:0] CmpFlg;                          // compare flags
  logic            AnsNaN, ResNaN, NaNGood;
  logic            Xs, Ys, Zs;                 // sign of the inputs
  logic [P.NE-1:0] Xe, Ye, Ze;                 // exponent of the inputs
  logic [P.NF:0]   Xm, Ym, Zm;                 // mantissas of the inputs
  logic            XNaN, YNaN, ZNaN;           // is the input NaN
  logic            XSNaN, YSNaN, ZSNaN;        // is the input a signaling NaN
  logic            XSubnorm, ZSubnorm;         // is the input denormalized
  logic            XInf, YInf, ZInf;           // is the input infinity
  logic            XZero, YZero, ZZero;        // is the input zero
  logic            XExpMax, YExpMax, ZExpMax;  // is the input's exponent all ones
  logic [P.CVTLEN-1:0] CvtLzcInE;              // input to the Leading Zero Counter (priority encoder)
  logic                IntZero;
  logic                CvtResSgnE;
  logic [P.NE:0] CvtCalcExpE;                  // the calculated exponent
  logic [P.LOGCVTLEN-1:0] CvtShiftAmtE;        // how much to shift by
  logic [P.DIVb:0] Quot;
  logic CvtResSubnormUfE;
  logic DivStart = 1'b0;
  logic FDivBusyE;
  logic reset = 1'b1;
  logic [$clog2(P.NF+2)-1:0] XZeroCnt, YZeroCnt;

  // in-between FMA signals
  logic Mult;
  logic Ss;
  logic [P.NE+1:0] Pe;
  logic [P.NE+1:0] Se;
  logic ASticky;
  logic KillProd;
  logic [$clog2(P.FMALEN+1)-1:0] SCnt;
  logic [P.FMALEN-1:0] Sm;
  logic InvA;
  logic NegSum;
  logic As;
  logic Ps;
  logic DivSticky;
  logic DivNegSticky;
  logic [P.NE+1:0] DivCalcExp;
  logic            divsqrtop;

  // Missing logic vectors fdivsqrt
  logic [2:0] Funct3E;
  logic [2:0] Funct3M;
  logic       FlushE;
  logic       IFDivStartE;
  logic       FDivDoneE;
  logic [P.NE+1:0]   UeM;
  logic [P.DIVb:0]   UmM;
  logic [P.XLEN-1:0] FIntDivResultM;
  logic ResMatch;                   // Check if result match
  logic FlagMatch;                  // Check if IEEE flags match
  logic IntResult;                  // result is an integer (compare or conversion to integer)

  logic [P.NE-2:0]      BiasE;      // Bias of exponent
  logic [P.LOGFLEN-1:0] NfE;        // Number of fractional bits


  // select tests relevant to the specified configuration
  //    cvtint - test integer conversion unit (fcvtint)
  //    cvtfp  - test floating-point conversion unit (fcvtfp)
  //    cmp    - test comparison unit's LT, LE, EQ operations (fcmp)
  //    add    - test addition
  //    sub    - test subtraction
  //    mul    - test multiplication
  //    fma    - test fused multiply-add
  //    div    - test division
  //    sqrt   - test square root
  //    round  - test Zfa fround and froundnx (fround)
  //    class  - test fclass (fclassify)
  //    sgnj   - test fsgnj, fsgnjn and fsgnjx (fsgninj)
  //    minmax - test fmin and fmax (fcmp)
  //    all    - test all of the above
  // cmp also tests the Zfa quiet compares fleq and fltq when Zfa is supported.  TestFloat has no vectors
  // for class, sgnj and minmax, so they run only on vector sets that have them, such as cover-float's.

  // add the five files (one per rounding mode) of one operation to the test lists
  task automatic AddOp(input string Stem, input logic [3:0] Op, input logic [3:0] U, input logic [1:0] F);
    static string Modes[5] = '{"rne", "rz", "ru", "rd", "rnm"}; // in the order of Frm
    for (int i = 0; i < 5; i++) begin
      string Name;
      Name = {Stem, "_", Modes[i], ".tv"}; // a separate string: Verilator would append {Stem, ...} as four entries
      Tests = {Tests, Name};
      Unit = {Unit, U};
      Fmt = {Fmt, F};
    end
    OpCtrl = {OpCtrl, Op};
    WriteInt = {WriteInt, 1'b0};
  endtask

  // whether the vector set has a file, for operations TestFloat has no vectors for
  function automatic logic HaveVectors(string Stem);
    int f;
    f = $fopen({VectorPath, Stem, "_rne.tv"}, "r");
    if (f != 0) $fclose(f);
    return f != 0;
  endfunction
  initial begin : driver
    if (!$value$plusargs("TEST=%s", TestName)) TestName = TEST;
    if (!$value$plusargs("TEST_SIZE=%s", TestSize)) TestSize = TEST_SIZE;
    // +VECTORS=<dir>/<prefix> reads the vectors from other files named like TestFloat's, such as the
    // cover-float vectors that make coverfloat converts into tests/fp/coverfloat/vectors
    if (!$value$plusargs("VECTORS=%s", VectorPath)) VectorPath = `PATH;

    if (P.Q_SUPPORTED & (TestSize == "QP" | TestSize == "all")) begin // if Quad precision is supported
      if (TestName == "cvtint" | TestName == "all") begin  // if testing integer conversion
        // add the 128-bit cvtint tests to the to-be-tested list
        Tests = {Tests, f128rv32cvtint};
        // add the op-codes for these tests to the op-code list
        OpCtrl = {OpCtrl, `FROM_UI_OPCTRL, `FROM_I_OPCTRL, `TO_UI_OPCTRL, `TO_I_OPCTRL};
        WriteInt = {WriteInt, 1'b0, 1'b0, 1'b1, 1'b1};
        // add what unit is used and the fmt to their lists (one for each test)
        for(int i = 0; i<20; i++) begin
          Unit = {Unit, `CVTINTUNIT};
          Fmt = {Fmt, 2'b11};
        end
        if (P.XLEN == 64) begin // if 64-bit integers are supported add their conversions
          Tests = {Tests, f128rv64cvtint};
          // add the op-codes for these tests to the op-code list
          OpCtrl = {OpCtrl, `FROM_UL_OPCTRL, `FROM_L_OPCTRL, `TO_UL_OPCTRL, `TO_L_OPCTRL};
          WriteInt = {WriteInt, 1'b0, 1'b0, 1'b1, 1'b1};
          // add what unit is used and the fmt to their lists (one for each test)
          for(int i = 0; i<20; i++) begin
            Unit = {Unit, `CVTINTUNIT};
            Fmt = {Fmt, 2'b11};
          end
        end
      end
      // if the floating-point conversions are being tested
      if (TestName == "cvtfp" | TestName == "all") begin
        if (P.D_SUPPORTED) begin // if double precision is supported
          // add the 128 <-> 64 bit conversions to the to-be-tested list
          Tests = {Tests, f128f64cvt};
          // add the op-ctrls (i.e. the format of the result)
          OpCtrl = {OpCtrl, 4'b01, 4'b11};
          WriteInt = {WriteInt, 1'b0, 1'b0};
          // add the unit being tested and fmt (input format)
          for(int i = 0; i<5; i++) begin
            Unit = {Unit, `CVTFPUNIT};
            Fmt = {Fmt, 2'b11};
          end
          for(int i = 0; i<5; i++) begin
            Unit = {Unit, `CVTFPUNIT};
            Fmt = {Fmt, 2'b01};
          end
        end
        if (P.F_SUPPORTED) begin // if single precision is supported
          // add the 128 <-> 32 bit conversions to the to-be-tested list
          Tests = {Tests, f128f32cvt};
          // add the op-ctrls (i.e. the format of the result)
          OpCtrl = {OpCtrl, 4'b00, 4'b11};
          WriteInt = {WriteInt, 1'b0, 1'b0};
          // add the unit being tested and fmt (input format)
          for(int i = 0; i<5; i++) begin
            Unit = {Unit, `CVTFPUNIT};
            Fmt = {Fmt, 2'b11};
          end
          for(int i = 0; i<5; i++) begin
            Unit = {Unit, `CVTFPUNIT};
            Fmt = {Fmt, 2'b00};
          end
        end
        if (P.ZFH_SUPPORTED) begin // if half precision is supported
          // add the 128 <-> 16 bit conversions to the to-be-tested list
          Tests = {Tests, f128f16cvt};
          // add the op-ctrls (i.e. the format of the result)
          OpCtrl = {OpCtrl, 4'b10, 4'b11};
          WriteInt = {WriteInt, 1'b0, 1'b0};
          // add the unit being tested and fmt (input format)
          for(int i = 0; i<5; i++) begin
            Unit = {Unit, `CVTFPUNIT};
            Fmt = {Fmt, 2'b11};
          end
          for(int i = 0; i<5; i++) begin
            Unit = {Unit, `CVTFPUNIT};
            Fmt = {Fmt, 2'b10};
          end
        end
      end
      if (TestName == "cmp" | TestName == "all") begin // if comparisons are being tested
        // add the compare tests/op-ctrls/unit/fmt
        Tests = {Tests, f128cmp};
        OpCtrl = {OpCtrl, `EQ_OPCTRL, `LE_OPCTRL, `LT_OPCTRL};
        WriteInt = {WriteInt, 1'b0, 1'b0, 1'b0};
        for(int i = 0; i<15; i++) begin
          Unit = {Unit, `CMPUNIT};
          Fmt = {Fmt, 2'b11};
        end
      end
      if (TestName == "add" | TestName == "all") begin // if addition is being tested
        // add the addition tests/op-ctrls/unit/fmt
        Tests = {Tests, f128add};
        OpCtrl = {OpCtrl, `ADD_OPCTRL};
        WriteInt = {WriteInt, 1'b0};
        for(int i = 0; i<5; i++) begin
          Unit = {Unit, `FMAUNIT};
          Fmt = {Fmt, 2'b11};
        end
      end
      if (TestName == "sub" | TestName == "all") begin // if subtraction is being tested
        // add the subtraction tests/op-ctrls/unit/fmt
        Tests = {Tests, f128sub};
        OpCtrl = {OpCtrl, `SUB_OPCTRL};
        WriteInt = {WriteInt, 1'b0};
        for(int i = 0; i<5; i++) begin
          Unit = {Unit, `FMAUNIT};
          Fmt = {Fmt, 2'b11};
        end
      end
      if (TestName == "mul" | TestName == "all") begin // if multiplication is being tested
        // add the multiply tests/op-ctrls/unit/fmt
        Tests = {Tests, f128mul};
        OpCtrl = {OpCtrl, `MUL_OPCTRL};
        WriteInt = {WriteInt, 1'b0};
        for(int i = 0; i<5; i++) begin
          Unit = {Unit, `FMAUNIT};
          Fmt = {Fmt, 2'b11};
        end
      end
      if (TestName == "div" | TestName == "all") begin // if division is being tested
        // add the divide tests/op-ctrls/unit/fmt
        Tests = {Tests, f128div};
        OpCtrl = {OpCtrl, `DIV_OPCTRL};
        WriteInt = {WriteInt, 1'b0};
        for(int i = 0; i<5; i++) begin
          Unit = {Unit, `DIVUNIT};
          Fmt = {Fmt, 2'b11};
        end
      end
      if (TestName == "sqrt" | TestName == "all") begin // if square-root is being tested
        // add the square-root tests/op-ctrls/unit/fmt
        Tests = {Tests, f128sqrt};
        OpCtrl = {OpCtrl, `SQRT_OPCTRL};
        WriteInt = {WriteInt, 1'b0};
        for(int i = 0; i<5; i++) begin
          Unit = {Unit, `DIVUNIT};
          Fmt = {Fmt, 2'b11};
        end
      end
      if (TestName == "fma" | TestName == "all") begin  // if fused-mutliply-add is being tested
        Tests = {Tests, f128fma};
        OpCtrl = {OpCtrl, `FMA_OPCTRL};
        WriteInt = {WriteInt, 1'b0};
        for(int i = 0; i<5; i++) begin
          Unit = {Unit, `FMAUNIT};
          Fmt = {Fmt, 2'b11};
        end
      end
    end
    if (P.D_SUPPORTED & (TestSize == "DP" | TestSize == "all")) begin // if double precision is supported
      if (TestName == "cvtint" | TestName == "all") begin // if integer conversion is being tested
        Tests = {Tests, f64rv32cvtint};
        // add the op-codes for these tests to the op-code list
        OpCtrl = {OpCtrl, `FROM_UI_OPCTRL, `FROM_I_OPCTRL, `TO_UI_OPCTRL, `TO_I_OPCTRL};
        WriteInt = {WriteInt, 1'b0, 1'b0, 1'b1, 1'b1};
        // add what unit is used and the fmt to their lists (one for each test)
        for(int i = 0; i<20; i++) begin
          Unit = {Unit, `CVTINTUNIT};
          Fmt = {Fmt, 2'b01};
        end
        if (P.XLEN == 64) begin // if 64-bit integers are being supported
          Tests = {Tests, f64rv64cvtint};
          // add the op-codes for these tests to the op-code list
          OpCtrl = {OpCtrl, `FROM_UL_OPCTRL, `FROM_L_OPCTRL, `TO_UL_OPCTRL, `TO_L_OPCTRL};
          WriteInt = {WriteInt, 1'b0, 1'b0, 1'b1, 1'b1};
          // add what unit is used and the fmt to their lists (one for each test)
          for(int i = 0; i<20; i++) begin
            Unit = {Unit, `CVTINTUNIT};
            Fmt = {Fmt, 2'b01};
          end
        end
      end
      if (TestName == "cvtfp" | TestName == "all") begin // if floating point conversions are being tested
        if (P.F_SUPPORTED) begin // if single precision is supported
          // add the 64 <-> 32 bit conversions to the to-be-tested list
          Tests = {Tests, f64f32cvt};
          // add the op-ctrls (i.e. the format of the result)
          OpCtrl = {OpCtrl, 4'b00, 4'b01};
          WriteInt = {WriteInt, 1'b0, 1'b0};
          // add the unit being tested and fmt (input format)
          for(int i = 0; i<5; i++) begin
            Unit = {Unit, `CVTFPUNIT};
            Fmt = {Fmt, 2'b01};
          end
          for(int i = 0; i<5; i++) begin
            Unit = {Unit, `CVTFPUNIT};
            Fmt = {Fmt, 2'b00};
          end
        end
        if (P.ZFH_SUPPORTED) begin // if half precision is supported
          // add the 64 <-> 16 bit conversions to the to-be-tested list
          Tests = {Tests, f64f16cvt};
          // add the op-ctrls (i.e. the format of the result)
          OpCtrl = {OpCtrl, 4'b10, 4'b01};
          WriteInt = {WriteInt, 1'b0, 1'b0};
          // add the unit being tested and fmt (input format)
          for(int i = 0; i<5; i++) begin
            Unit = {Unit, `CVTFPUNIT};
            Fmt = {Fmt, 2'b01};
          end
          for(int i = 0; i<5; i++) begin
            Unit = {Unit, `CVTFPUNIT};
            Fmt = {Fmt, 2'b10};
          end
        end
      end
      if (TestName == "cmp" | TestName == "all") begin // if comparisons are being tested
        // add the correct tests/op-ctrls/unit/fmt to their lists
        Tests = {Tests, f64cmp};
        OpCtrl = {OpCtrl, `EQ_OPCTRL, `LE_OPCTRL, `LT_OPCTRL};
        WriteInt = {WriteInt, 1'b0, 1'b0, 1'b0};
        for(int i = 0; i<15; i++) begin
          Unit = {Unit, `CMPUNIT};
          Fmt = {Fmt, 2'b01};
        end
      end
      if (TestName == "add" | TestName == "all") begin // if addition is being tested
        // add the correct tests/op-ctrls/unit/fmt to their lists
        Tests = {Tests, f64add};
        OpCtrl = {OpCtrl, `ADD_OPCTRL};
        WriteInt = {WriteInt, 1'b0};
        for(int i = 0; i<5; i++) begin
          Unit = {Unit, `FMAUNIT};
          Fmt = {Fmt, 2'b01};
        end
      end
      if (TestName == "sub" | TestName == "all") begin // if subtration is being tested
        // add the correct tests/op-ctrls/unit/fmt to their lists
        Tests = {Tests, f64sub};
        OpCtrl = {OpCtrl, `SUB_OPCTRL};
        WriteInt = {WriteInt, 1'b0};
        for(int i = 0; i<5; i++) begin
          Unit = {Unit, `FMAUNIT};
          Fmt = {Fmt, 2'b01};
        end
      end
      if (TestName == "mul" | TestName == "all") begin // if multiplication is being tested
        // add the correct tests/op-ctrls/unit/fmt to their lists
        Tests = {Tests, f64mul};
        OpCtrl = {OpCtrl, `MUL_OPCTRL};
        WriteInt = {WriteInt, 1'b0};
        for(int i = 0; i<5; i++) begin
          Unit = {Unit, `FMAUNIT};
          Fmt = {Fmt, 2'b01};
        end
      end
      if (TestName == "div" | TestName == "all") begin // if division is being tested
        // add the correct tests/op-ctrls/unit/fmt to their lists
        Tests = {Tests, f64div};
        OpCtrl = {OpCtrl, `DIV_OPCTRL};
        WriteInt = {WriteInt, 1'b0};
        for(int i = 0; i<5; i++) begin
          Unit = {Unit, `DIVUNIT};
          Fmt = {Fmt, 2'b01};
        end
      end
      if (TestName == "sqrt" | TestName == "all") begin // if square-root is being tessted
        // add the correct tests/op-ctrls/unit/fmt to their lists
        Tests = {Tests, f64sqrt};
        OpCtrl = {OpCtrl, `SQRT_OPCTRL};
        WriteInt = {WriteInt, 1'b0};
        for(int i = 0; i<5; i++) begin
          Unit = {Unit, `DIVUNIT};
          Fmt = {Fmt, 2'b01};
        end
      end
      if (TestName == "fma" | TestName == "all") begin // if the fused multiply add is being tested
        Tests = {Tests, f64fma};
        OpCtrl = {OpCtrl, `FMA_OPCTRL};
        WriteInt = {WriteInt, 1'b0};
        for(int i = 0; i<5; i++) begin
          Unit = {Unit, `FMAUNIT};
          Fmt = {Fmt, 2'b01};
        end
      end
    end
    if (P.F_SUPPORTED & (TestSize == "SP" | TestSize == "all")) begin // if single precision being supported
      if (TestName == "cvtint"| TestName == "all") begin // if integer conversion is being tested
        Tests = {Tests, f32rv32cvtint};
        // add the op-codes for these tests to the op-code list
        OpCtrl = {OpCtrl, `FROM_UI_OPCTRL, `FROM_I_OPCTRL, `TO_UI_OPCTRL, `TO_I_OPCTRL};
        WriteInt = {WriteInt, 1'b0, 1'b0, 1'b1, 1'b1};
        // add what unit is used and the fmt to their lists (one for each test)
        for(int i = 0; i<20; i++) begin
          Unit = {Unit, `CVTINTUNIT};
          Fmt = {Fmt, 2'b00};
        end
        if (P.XLEN == 64) begin // if 64-bit integers are supported
          Tests = {Tests, f32rv64cvtint};
          // add the op-codes for these tests to the op-code list
          OpCtrl = {OpCtrl, `FROM_UL_OPCTRL, `FROM_L_OPCTRL, `TO_UL_OPCTRL, `TO_L_OPCTRL};
          WriteInt = {WriteInt, 1'b0, 1'b0, 1'b1, 1'b1};
          // add what unit is used and the fmt to their lists (one for each test)
          for(int i = 0; i<20; i++) begin
            Unit = {Unit, `CVTINTUNIT};
            Fmt = {Fmt, 2'b00};
          end
        end
      end
      if (TestName == "cvtfp" | TestName == "all") begin  // if floating point conversion is being tested
        if (P.ZFH_SUPPORTED) begin
          // add the 32 <-> 16 bit conversions to the to-be-tested list
          Tests = {Tests, f32f16cvt};
          // add the op-ctrls (i.e. the format of the result)
          OpCtrl = {OpCtrl, 4'b10, 4'b00};
          WriteInt = {WriteInt, 1'b0, 1'b0};
          // add the unit being tested and fmt (input format)
          for(int i = 0; i<5; i++) begin
            Unit = {Unit, `CVTFPUNIT};
            Fmt = {Fmt, 2'b00};
          end
          for(int i = 0; i<5; i++) begin
            Unit = {Unit, `CVTFPUNIT};
            Fmt = {Fmt, 2'b10};
          end
        end
      end
      if (TestName == "cmp" | TestName == "all") begin // if comparison is being tested
        // add the correct tests/op-ctrls/unit/fmt to their lists
        Tests = {Tests, f32cmp};
        OpCtrl = {OpCtrl, `EQ_OPCTRL, `LE_OPCTRL, `LT_OPCTRL};
        WriteInt = {WriteInt, 1'b0, 1'b0, 1'b0};
        for(int i = 0; i<15; i++) begin
          Unit = {Unit, `CMPUNIT};
          Fmt = {Fmt, 2'b00};
        end
      end
      if (TestName == "add" | TestName == "all") begin // if addition is being tested
        // add the correct tests/op-ctrls/unit/fmt to their lists
        Tests = {Tests, f32add};
        OpCtrl = {OpCtrl, `ADD_OPCTRL};
        WriteInt = {WriteInt, 1'b0};
        for(int i = 0; i<5; i++) begin
          Unit = {Unit, `FMAUNIT};
          Fmt = {Fmt, 2'b00};
        end
      end
      if (TestName == "sub" | TestName == "all") begin // if subtration is being tested
        // add the correct tests/op-ctrls/unit/fmt to their lists
        Tests = {Tests, f32sub};
        OpCtrl = {OpCtrl, `SUB_OPCTRL};
        WriteInt = {WriteInt, 1'b0};
        for(int i = 0; i<5; i++) begin
          Unit = {Unit, `FMAUNIT};
          Fmt = {Fmt, 2'b00};
        end
      end
      if (TestName == "mul" | TestName == "all") begin // if multiply is being tested
        // add the correct tests/op-ctrls/unit/fmt to their lists
        Tests = {Tests, f32mul};
        OpCtrl = {OpCtrl, `MUL_OPCTRL};
        WriteInt = {WriteInt, 1'b0};
        for(int i = 0; i<5; i++) begin
          Unit = {Unit, `FMAUNIT};
          Fmt = {Fmt, 2'b00};
        end
      end
    if (TestName == "div" | TestName == "all") begin // if division is being tested
      // add the correct tests/op-ctrls/unit/fmt to their lists
      Tests = {Tests, f32div};
      OpCtrl = {OpCtrl, `DIV_OPCTRL};
      WriteInt = {WriteInt, 1'b0};
      for(int i = 0; i<5; i++) begin
        Unit = {Unit, `DIVUNIT};
        Fmt = {Fmt, 2'b00};
      end
    end
      if (TestName == "sqrt" | TestName == "all") begin // if sqrt is being tested
        // add the correct tests/op-ctrls/unit/fmt to their lists
        Tests = {Tests, f32sqrt};
        OpCtrl = {OpCtrl, `SQRT_OPCTRL};
        WriteInt = {WriteInt, 1'b0};
        for(int i = 0; i<5; i++) begin
          Unit = {Unit, `DIVUNIT};
          Fmt = {Fmt, 2'b00};
        end
      end
      if (TestName == "fma" | TestName == "all")  begin // if fma is being tested
          Tests = {Tests, f32fma};
          OpCtrl = {OpCtrl, `FMA_OPCTRL};
          WriteInt = {WriteInt, 1'b0};
          for(int i = 0; i<5; i++) begin
            Unit = {Unit, `FMAUNIT};
            Fmt = {Fmt, 2'b00};
          end
      end
    end
    if (P.ZFH_SUPPORTED & (TestSize == "HP" | TestSize == "all")) begin // if half precision supported
      if (TestName == "cvtint" | TestName == "all") begin // if in conversions are being tested
        Tests = {Tests, f16rv32cvtint};
        // add the op-codes for these tests to the op-code list
        OpCtrl = {OpCtrl, `FROM_UI_OPCTRL, `FROM_I_OPCTRL, `TO_UI_OPCTRL, `TO_I_OPCTRL};
        WriteInt = {WriteInt, 1'b0, 1'b0, 1'b1, 1'b1};
        // add what unit is used and the fmt to their lists (one for each test)
        for(int i = 0; i<20; i++) begin
          Unit = {Unit, `CVTINTUNIT};
          Fmt = {Fmt, 2'b10};
        end
        if (P.XLEN == 64) begin // if 64-bit integers are supported
          Tests = {Tests, f16rv64cvtint};
          // add the op-codes for these tests to the op-code list
          OpCtrl = {OpCtrl, `FROM_UL_OPCTRL, `FROM_L_OPCTRL, `TO_UL_OPCTRL, `TO_L_OPCTRL};
          WriteInt = {WriteInt, 1'b0, 1'b0, 1'b1, 1'b1};
          // add what unit is used and the fmt to their lists (one for each test)
          for(int i = 0; i<20; i++) begin
            Unit = {Unit, `CVTINTUNIT};
            Fmt = {Fmt, 2'b10};
          end
        end
      end
      if (TestName == "cmp" | TestName == "all") begin // if comparisons are being tested
        // add the correct tests/op-ctrls/unit/fmt to their lists
        Tests = {Tests, f16cmp};
        OpCtrl = {OpCtrl, `EQ_OPCTRL, `LE_OPCTRL, `LT_OPCTRL};
        WriteInt = {WriteInt, 1'b0, 1'b0, 1'b0};
        for(int i = 0; i<15; i++) begin
          Unit = {Unit, `CMPUNIT};
          Fmt = {Fmt, 2'b10};
        end
      end
      if (TestName == "add" | TestName == "all") begin //  if addition is being tested
        // add the correct tests/op-ctrls/unit/fmt to their lists
        Tests = {Tests, f16add};
        OpCtrl = {OpCtrl, `ADD_OPCTRL};
        WriteInt = {WriteInt, 1'b0};
        for(int i = 0; i<5; i++) begin
          Unit = {Unit, `FMAUNIT};
          Fmt = {Fmt, 2'b10};
        end
      end
      if (TestName == "sub" | TestName == "all") begin // if subtraction is being tested
        // add the correct tests/op-ctrls/unit/fmt to their lists
        Tests = {Tests, f16sub};
        OpCtrl = {OpCtrl, `SUB_OPCTRL};
        WriteInt = {WriteInt, 1'b0};
        for(int i = 0; i<5; i++) begin
          Unit = {Unit, `FMAUNIT};
          Fmt = {Fmt, 2'b10};
        end
      end
      if (TestName == "mul" | TestName == "all") begin // if multiplication is being tested
        // add the correct tests/op-ctrls/unit/fmt to their lists
        Tests = {Tests, f16mul};
        OpCtrl = {OpCtrl, `MUL_OPCTRL};
        WriteInt = {WriteInt, 1'b0};
        for(int i = 0; i<5; i++) begin
          Unit = {Unit, `FMAUNIT};
          Fmt = {Fmt, 2'b10};
        end
      end
      if (TestName == "div" | TestName == "all") begin // if division is being tested
        // add the correct tests/op-ctrls/unit/fmt to their lists
        Tests = {Tests, f16div};
        OpCtrl = {OpCtrl, `DIV_OPCTRL};
        WriteInt = {WriteInt, 1'b0};
        for(int i = 0; i<5; i++) begin
          Unit = {Unit, `DIVUNIT};
          Fmt = {Fmt, 2'b10};
        end
      end
      if (TestName == "sqrt" | TestName == "all") begin // if sqrt is being tested
        // add the correct tests/op-ctrls/unit/fmt to their lists
        Tests = {Tests, f16sqrt};
        OpCtrl = {OpCtrl, `SQRT_OPCTRL};
        WriteInt = {WriteInt, 1'b0};
        for(int i = 0; i<5; i++) begin
          Unit = {Unit, `DIVUNIT};
          Fmt = {Fmt, 2'b10};
        end
      end
      if (TestName == "fma" | TestName == "all") begin // if fma is being tested
        Tests = {Tests, f16fma};
        OpCtrl = {OpCtrl, `FMA_OPCTRL};
        WriteInt = {WriteInt, 1'b0};
        for(int i = 0; i<5; i++) begin
          Unit = {Unit, `FMAUNIT};
          Fmt = {Fmt, 2'b10};
        end
      end
    end
    // Zfa quiet compares, fround and froundnx, and the units only some vector sets have
    for (int i = 0; i < 4; i++) begin
      logic [1:0] f;
      logic       supported;
      string      n;
      case (i)
        0: begin f = 2'b11; n = "f128"; supported = P.Q_SUPPORTED   & (TestSize == "QP" | TestSize == "all"); end
        1: begin f = 2'b01; n = "f64";  supported = P.D_SUPPORTED   & (TestSize == "DP" | TestSize == "all"); end
        2: begin f = 2'b00; n = "f32";  supported = P.F_SUPPORTED   & (TestSize == "SP" | TestSize == "all"); end
        default: begin f = 2'b10; n = "f16";  supported = P.ZFH_SUPPORTED & (TestSize == "HP" | TestSize == "all"); end
      endcase
      if (supported) begin
        if (P.ZFA_SUPPORTED & (TestName == "cmp" | TestName == "all")) begin
          AddOp({n, "_le_quiet"}, `LEQ_OPCTRL, `CMPUNIT, f);
          AddOp({n, "_lt_quiet"}, `LTQ_OPCTRL, `CMPUNIT, f);
        end
        if (P.ZFA_SUPPORTED & (TestName == "round" | TestName == "all")) begin
          AddOp({n, "_roundToInt"},      `ROUND_OPCTRL,   `ROUNDUNIT, f);
          AddOp({n, "_roundToIntExact"}, `ROUNDNX_OPCTRL, `ROUNDUNIT, f);
        end
        if ((TestName == "class" | TestName == "all") & HaveVectors({n, "_class"}))
          AddOp({n, "_class"}, `CLASS_OPCTRL, `CLASSUNIT, f);
        if ((TestName == "sgnj" | TestName == "all") & HaveVectors({n, "_sgnj"})) begin
          AddOp({n, "_sgnj"},  `SGNJ_OPCTRL,  `SGNJUNIT, f);
          AddOp({n, "_sgnjn"}, `SGNJN_OPCTRL, `SGNJUNIT, f);
          AddOp({n, "_sgnjx"}, `SGNJX_OPCTRL, `SGNJUNIT, f);
        end
        if ((TestName == "minmax" | TestName == "all") & HaveVectors({n, "_min"})) begin
          AddOp({n, "_min"}, `MIN_OPCTRL, `MINMAXUNIT, f);
          AddOp({n, "_max"}, `MAX_OPCTRL, `MINMAXUNIT, f);
        end
      end
    end
    if (Tests.size() == 0) begin
      $fatal(1, "TEST %s not supported in this configuration", TestName);
    end

    // Run each test file.  Each file holds one operation in one rounding mode; files come in groups of
    // five (rne, rz, ru, rd, rnm) that share one OpCtrl.  This process is the only one that changes the
    // inputs, and it changes them only on the falling edge of clk (or between edges for the
    // combinational units), so the result it checks is never racing with the vector that produced it.
    repeat (2) @(negedge clk);
    reset = 1'b0;
    for (TestNum = 0; TestNum < Tests.size(); TestNum++) begin
      UnitVal     = Unit[TestNum];
      FmtVal      = Fmt[TestNum];
      OpCtrlVal   = OpCtrl[TestNum/5];
      WriteIntVal = WriteInt[TestNum/5];
      FrmVal      = Frm[TestNum%5];
      fd = $fopen({VectorPath, Tests[TestNum]}, "r");
      if (fd == 0) begin
        $fatal(1, "Error: cannot open %s%s; run make testfloat (or make coverfloat) in $WALLY", VectorPath, Tests[TestNum]);
      end
      $display("Running %s vectors", Tests[TestNum]);
      for (VectorNum = 0; $fscanf(fd, "%h\n", TestVector) == 1; VectorNum++) begin
        if (UnitVal == `DIVUNIT) begin
          // Start the divider at the next rising edge, wait for it to finish, and check one cycle
          // after FDivDoneE, when its result has reached the Memory-stage outputs (UmM, DivStickyM)
          @(negedge clk) DivStart = 1'b1;
          @(negedge clk) DivStart = 1'b0;
          while (!FDivDoneE) @(negedge clk);
          @(negedge clk);
        end else #1; // the other units are combinational: let the result settle
        checkResult();
      end
      $fclose(fd);
    end
    $display("\nAll Tests completed with %d errors\n", errors);
    $finish;
  end

  // modify the format signal if only 2 precisions supported
  //    - 1 for the larger precision
  //    - 0 for the smaller precision
  always_comb begin
    if (P.FMTBITS == 1) ModFmt = P.FMTBITS'(FmtVal == P.FMT);
    else                ModFmt = P.FMTBITS'(FmtVal);
  end

  // extract the inputs (X, Y, Z, SrcA) and the output (Ans, AnsFlg) from the current test vector
  readvectors #(P) readvectors (.Fmt(FmtVal), .ModFmt, .TestVector,
                                .Ans(Ans), .AnsFlg(AnsFlg), .SrcA,
                                .Xs, .Ys, .Zs, .Unit(UnitVal),
                                .Xe, .Ye, .Ze, .OpCtrl(OpCtrlVal),
                                .Xm, .Ym, .Zm,
                                .XNaN, .YNaN, .ZNaN,
                                .XSNaN, .YSNaN, .ZSNaN,
                                .XSubnorm, .ZSubnorm,
                                .XZero, .YZero, .ZZero,
                                .XInf, .YInf, .ZInf, .XExpMax,
                                .X, .Y, .Z, .XPostBox, .NfE, .BiasE);

  // instantiate devices under test.  Every unit is present so that one compiled design runs every test.
  fma #(P) fma(.Xs(Xs), .Ys(Ys), .Zs(Zs),
    .Xe(Xe), .Ye(Ye), .Ze(Ze),
    .Xm(Xm), .Ym(Ym), .Zm(Zm),
    .XZero, .YZero, .ZZero, .Ss, .Se,
    .OpCtrl(OpCtrlVal[2:0]), .Sm, .InvA, .SCnt, .As, .Ps,
    .ASticky);

  postprocess #(P) postprocess(.Xs(Xs), .Ys(Ys), .PostProcSel(UnitVal[1:0]),
    .OpCtrl(OpCtrlVal[2:0]), .DivUm(Quot), .DivUe(DivCalcExp),
    .Xm(Xm), .Ym(Ym), .Zm(Zm), .CvtCe(CvtCalcExpE), .DivSticky(DivSticky), .FmaSs(Ss),
    .XNaN(XNaN), .YNaN(YNaN), .ZNaN(ZNaN), .CvtResSubnormUf(CvtResSubnormUfE),
    .XZero(XZero), .YZero(YZero), .CvtShiftAmt(CvtShiftAmtE),
    .XInf(XInf), .YInf(YInf), .ZInf(ZInf), .CvtCs(CvtResSgnE), .ToInt(WriteIntVal),
    .XSNaN(XSNaN), .YSNaN(YSNaN), .ZSNaN(ZSNaN), .CvtLzcIn(CvtLzcInE), .IntZero,
    .FmaASticky(ASticky), .FmaSe(Se),
    .FmaSm(Sm), .FmaSCnt(SCnt), .FmaAs(As), .FmaPs(Ps), .Fmt(ModFmt), .Frm(FrmVal),
    .PostProcFlg(Flg), .PostProcRes(FpRes), .FCvtIntRes(IntRes), .Zfa(1'b0));

  fcvt #(P) fcvt (.Xs(Xs), .Xe(Xe), .Xm(Xm), .Int(SrcA), .ToInt(WriteIntVal),
    .XZero(XZero), .OpCtrl(OpCtrlVal[2:0]), .IntZero,
    .Fmt(ModFmt), .Ce(CvtCalcExpE), .ShiftAmt(CvtShiftAmtE),
    .ResSubnormUf(CvtResSubnormUfE), .Cs(CvtResSgnE), .LzcIn(CvtLzcInE));

  // OpCtrl[3] selects the Zfa quiet compares fleq and fltq
  fcmp #(P) fcmp (.Fmt(ModFmt), .OpCtrl(OpCtrlVal[2:0]), .Zfa(OpCtrlVal[3]), .Xs, .Ys, .Xe, .Ye,
    .Xm, .Ym, .XZero, .YZero, .CmpIntRes(CmpRes),
    .XNaN, .YNaN, .XSNaN, .YSNaN, .X(X[P.FLEN-1:0]), .Y(Y[P.FLEN-1:0]), .CmpNV(CmpFlg[4]), .CmpFpRes(FpCmpRes));

  fdivsqrt #(P) fdivsqrt(.clk, .reset, .XsE(Xs), .FmtE(ModFmt), .XmE(Xm), .YmE(Ym),
    .XeE(Xe), .YeE(Ye), .SqrtE(OpCtrlVal[0]), .SqrtM(OpCtrlVal[0]),
    .XInfE(XInf), .YInfE(YInf), .XZeroE(XZero), .YZeroE(YZero),
    .XNaNE(XNaN), .YNaNE(YNaN), .NfE, .BiasE,
    .FDivStartE(DivStart), .IDivStartE(1'b0), .W64E(1'b0),
    .StallM(1'b0), .DivStickyM(DivSticky), .FDivBusyE, .UeM(DivCalcExp),
    .UmM(Quot),
    .FlushE(1'b0), .ForwardedSrcAE('0), .ForwardedSrcBE('0), .Funct3M(Funct3M),
    .Funct3E(Funct3E), .IntDivE(1'b0), .FIntDivResultM(FIntDivResultM),
    .FDivDoneE(FDivDoneE), .IFDivStartE(IFDivStartE));

  assign CmpFlg[3:0] = 0;

  // Zfa fround and froundnx; OpCtrl[0] selects froundnx
  fround #(P) fround(.Xs, .Xe, .Xm, .XNaN, .XSNaN, .Fmt(ModFmt), .Frm(FrmVal), .Nf(NfE),
    .ZfaFRoundNX(OpCtrlVal[0]), .FRound(FRoundRes), .FRoundNV, .FRoundNX);

  fsgninj #(P) fsgninj(.OpCtrl(OpCtrlVal[1:0]), .Xs, .Ys, .X(XPostBox), .Fmt(ModFmt), .SgnRes);

  fclassify #(P) fclassify(.Xs, .XSubnorm, .XZero, .XNaN, .XInf, .XSNaN, .ClassRes);

  // produce clock
  always begin
    clk = 1; #5; clk = 0; #5;
  end

  // Check if the correct answer and result is a NaN
  always_comb begin
    if (UnitVal === `CVTINTUNIT | UnitVal === `CMPUNIT | UnitVal === `CLASSUNIT) begin
      // an integer output can't be a NaN
      AnsNaN = 1'b0;
      ResNaN = 1'b0;
    end else if (UnitVal === `CVTFPUNIT) begin
      case (OpCtrlVal[1:0])
        2'b11: begin // quad
          AnsNaN = &Ans[P.Q_LEN-2:P.NF]&(|Ans[P.Q_NF-1:0]);
          ResNaN = &Res[P.Q_LEN-2:P.NF]&(|Res[P.Q_NF-1:0]);
        end
        2'b01: begin // double
          AnsNaN = &Ans[P.D_LEN-2:P.D_NF]&(|Ans[P.D_NF-1:0]);
          ResNaN = &Res[P.D_LEN-2:P.D_NF]&(|Res[P.D_NF-1:0]);
        end
        2'b00: begin // single
          AnsNaN = &Ans[P.S_LEN-2:P.S_NF]&(|Ans[P.S_NF-1:0]);
          ResNaN = &Res[P.S_LEN-2:P.S_NF]&(|Res[P.S_NF-1:0]);
        end
        2'b10: begin // half
          AnsNaN = &Ans[P.H_LEN-2:P.H_NF]&(|Ans[P.H_NF-1:0]);
          ResNaN = &Res[P.H_LEN-2:P.H_NF]&(|Res[P.H_NF-1:0]);
        end
      endcase
    end else begin
      case (FmtVal)
        2'b11: begin // quad
          AnsNaN = &Ans[P.Q_LEN-2:P.Q_NF]&(|Ans[P.Q_NF-1:0]);
          ResNaN = &Res[P.Q_LEN-2:P.Q_NF]&(|Res[P.Q_NF-1:0]);
        end
        2'b01: begin // double
          AnsNaN = &Ans[P.D_LEN-2:P.D_NF]&(|Ans[P.D_NF-1:0]);
          ResNaN = &Res[P.D_LEN-2:P.D_NF]&(|Res[P.D_NF-1:0]);
        end
        2'b00: begin // single
          AnsNaN = &Ans[P.S_LEN-2:P.S_NF]&(|Ans[P.S_NF-1:0]);
          ResNaN = &Res[P.S_LEN-2:P.S_NF]&(|Res[P.S_NF-1:0]);
        end
        2'b10: begin // half
          AnsNaN = &Ans[P.H_LEN-2:P.H_NF]&(|Ans[P.H_NF-1:0]);
          ResNaN = &Res[P.H_LEN-2:P.H_NF]&(|Res[P.H_NF-1:0]);
        end
      endcase
    end
  end

  always_comb begin
    Res = '0; ResFlg = '0;
    FpResExtended = {{(P.Q_LEN-P.FLEN){1'b1}}, FpRes};
    // select the result to check
    case (UnitVal)
      `FMAUNIT: Res = FpResExtended;
      `DIVUNIT: Res = FpResExtended;
      `CMPUNIT: Res = {{(P.Q_LEN-P.XLEN){1'b0}}, CmpRes};
      `CVTINTUNIT: if (WriteIntVal) Res = {{(P.Q_LEN-P.XLEN){1'b0}}, IntRes}; else Res = FpResExtended;
      `CVTFPUNIT: Res = FpResExtended;
      `ROUNDUNIT: Res = {{(P.Q_LEN-P.FLEN){1'b1}}, FRoundRes};
      `CLASSUNIT: Res = {{(P.Q_LEN-P.XLEN){1'b0}}, ClassRes};
      `SGNJUNIT: Res = {{(P.Q_LEN-P.FLEN){1'b1}}, SgnRes};
      `MINMAXUNIT: Res = {{(P.Q_LEN-P.FLEN){1'b1}}, FpCmpRes};
      default: ;
    endcase

    // select the flag to check
    case (UnitVal)
      `FMAUNIT: ResFlg = Flg;
      `DIVUNIT: ResFlg = Flg;
      `CMPUNIT: ResFlg = CmpFlg;
      `CVTINTUNIT: ResFlg = Flg;
      `CVTFPUNIT: ResFlg = Flg;
      `ROUNDUNIT: ResFlg = {FRoundNV, 3'b0, FRoundNX};
      `MINMAXUNIT: ResFlg = CmpFlg;
      default: ;   // class and sign injection raise no flags
    endcase
  end

  // check if the NaN value is good. IEEE754-2019 sections 6.3 and 6.2.3 specify:
  //    - the sign of the NaN does not matter for the operations being tested
  //    - when 2 or more NaNs are inputted the NaN that is propagated doesn't matter
  always_comb begin
    NaNGood = 1'b0;
    // sign injection and classify must match exactly, NaN payloads and signs included
    if (UnitVal !== `CVTFPUNIT & UnitVal !== `CVTINTUNIT & UnitVal !== `SGNJUNIT & UnitVal !== `CLASSUNIT)
      case (FmtVal)
        2'b11: NaNGood = (((P.IEEE754==0)&AnsNaN&(Res === {1'b0, {P.Q_NE+1{1'b1}}, {P.Q_NF-1{1'b0}}})) |
                          (AnsFlg[4]&(Res[P.Q_LEN-2:0] === {{P.Q_NE+1{1'b1}}, {P.Q_NF-1{1'b0}}})) |
                          (XNaN&(Res[P.Q_LEN-2:0] === {X[P.Q_LEN-2:P.Q_NF],1'b1,X[P.Q_NF-2:0]})) |
                          (YNaN&(Res[P.Q_LEN-2:0] === {Y[P.Q_LEN-2:P.Q_NF],1'b1,Y[P.Q_NF-2:0]})) |
                          (ZNaN&(Res[P.Q_LEN-2:0] === {Z[P.Q_LEN-2:P.Q_NF],1'b1,Z[P.Q_NF-2:0]})));
        2'b01: NaNGood = (((P.IEEE754==0)&AnsNaN&(Res[P.D_LEN-1:0] === {1'b0, {P.D_NE+1{1'b1}}, {P.D_NF-1{1'b0}}})) |
                          (AnsFlg[4]&(Res[P.D_LEN-2:0] === {{P.D_NE+1{1'b1}}, {P.D_NF-1{1'b0}}})) |
                          (XNaN&(Res[P.D_LEN-2:0] === {X[P.D_LEN-2:P.D_NF],1'b1,X[P.D_NF-2:0]})) |
                          (YNaN&(Res[P.D_LEN-2:0] === {Y[P.D_LEN-2:P.D_NF],1'b1,Y[P.D_NF-2:0]})) |
                          (ZNaN&(Res[P.D_LEN-2:0] === {Z[P.D_LEN-2:P.D_NF],1'b1,Z[P.D_NF-2:0]})));
        2'b00: NaNGood = (((P.IEEE754==0)&AnsNaN&(Res[P.S_LEN-1:0] === {1'b0, {P.S_NE+1{1'b1}}, {P.S_NF-1{1'b0}}})) |
                          (AnsFlg[4]&(Res[P.S_LEN-2:0] === {{P.S_NE+1{1'b1}}, {P.S_NF-1{1'b0}}})) |
                          (XNaN&(Res[P.S_LEN-2:0] === {X[P.S_LEN-2:P.S_NF],1'b1,X[P.S_NF-2:0]})) |
                          (YNaN&(Res[P.S_LEN-2:0] === {Y[P.S_LEN-2:P.S_NF],1'b1,Y[P.S_NF-2:0]})) |
                          (ZNaN&(Res[P.S_LEN-2:0] === {Z[P.S_LEN-2:P.S_NF],1'b1,Z[P.S_NF-2:0]})));
        2'b10: NaNGood = (((P.IEEE754==0)&AnsNaN&(Res[P.H_LEN-1:0] === {1'b0, {P.H_NE+1{1'b1}}, {P.H_NF-1{1'b0}}})) |
                          (AnsFlg[4]&(Res[P.H_LEN-2:0] === {{P.H_NE+1{1'b1}}, {P.H_NF-1{1'b0}}})) |
                          (XNaN&(Res[P.H_LEN-2:0] === {X[P.H_LEN-2:P.H_NF],1'b1,X[P.H_NF-2:0]})) |
                          (YNaN&(Res[P.H_LEN-2:0] === {Y[P.H_LEN-2:P.H_NF],1'b1,Y[P.H_NF-2:0]})) |
                          (ZNaN&(Res[P.H_LEN-2:0] === {Z[P.H_LEN-2:P.H_NF],1'b1,Z[P.H_NF-2:0]})));
      endcase
    else if (UnitVal === `CVTFPUNIT) // if converting from FP to FP OpCtrl contains the final FP format
      case (OpCtrlVal[1:0])
        2'b11: NaNGood = (((P.IEEE754==0)&AnsNaN&(Res === {1'b0, {P.Q_NE+1{1'b1}}, {P.Q_NF-1{1'b0}}})) |
                          (AnsFlg[4]&(Res[P.Q_LEN-2:0] === {{P.Q_NE+1{1'b1}}, {P.Q_NF-1{1'b0}}})) |
                          (AnsNaN&(Res[P.Q_LEN-2:0] === Ans[P.Q_LEN-2:0])) |
                          (XNaN&(Res[P.Q_LEN-2:0] === {X[P.Q_LEN-2:P.Q_NF],1'b1,X[P.Q_NF-2:0]})) |
                          (YNaN&(Res[P.Q_LEN-2:0] === {Y[P.Q_LEN-2:P.Q_NF],1'b1,Y[P.Q_NF-2:0]})));
        2'b01: NaNGood = (((P.IEEE754==0)&AnsNaN&(Res[P.D_LEN-1:0] === {1'b0, {P.D_NE+1{1'b1}}, {P.D_NF-1{1'b0}}})) |
                          (AnsFlg[4]&(Res[P.D_LEN-2:0] === {{P.D_NE+1{1'b1}}, {P.D_NF-1{1'b0}}})) |
                          (AnsNaN&(Res[P.D_LEN-2:0] === Ans[P.D_LEN-2:0])) |
                          (XNaN&(Res[P.D_LEN-2:0] === {X[P.D_LEN-2:P.D_NF],1'b1,X[P.D_NF-2:0]})) |
                          (YNaN&(Res[P.D_LEN-2:0] === {Y[P.D_LEN-2:P.D_NF],1'b1,Y[P.D_NF-2:0]})));
        2'b00: NaNGood = (((P.IEEE754==0)&AnsNaN&(Res[P.S_LEN-1:0] === {1'b0, {P.S_NE+1{1'b1}}, {P.S_NF-1{1'b0}}})) |
                          (AnsFlg[4]&(Res[P.S_LEN-2:0] === {{P.S_NE+1{1'b1}}, {P.S_NF-1{1'b0}}})) |
                          (AnsNaN&(Res[P.S_LEN-2:0] === Ans[P.S_LEN-2:0])) |
                          (XNaN&(Res[P.S_LEN-2:0] === {X[P.S_LEN-2:P.S_NF],1'b1,X[P.S_NF-2:0]})) |
                          (YNaN&(Res[P.S_LEN-2:0] === {Y[P.S_LEN-2:P.S_NF],1'b1,Y[P.S_NF-2:0]})));
        2'b10: NaNGood = (((P.IEEE754==0)&AnsNaN&(Res[P.H_LEN-1:0] === {1'b0, {P.H_NE+1{1'b1}}, {P.H_NF-1{1'b0}}})) |
                          (AnsFlg[4]&(Res[P.H_LEN-2:0] === {{P.H_NE+1{1'b1}}, {P.H_NF-1{1'b0}}})) |
                          (AnsNaN&(Res[P.H_LEN-2:0] === Ans[P.H_LEN-2:0])) |
                          (XNaN&(Res[P.H_LEN-2:0] === {X[P.H_LEN-2:P.H_NF],1'b1,X[P.H_NF-2:0]})) |
                          (YNaN&(Res[P.H_LEN-2:0] === {Y[P.H_LEN-2:P.H_NF],1'b1,Y[P.H_NF-2:0]})));
      endcase
    else NaNGood = 1'b0; // integers can't be NaNs
  end

  // An integer result (compare, classify, or conversion to an integer) fills an XLEN-bit register, so only
  // XLEN bits are compared; a 32-bit result is sign-extended to XLEN bits both by Wally and in Ans.
  assign IntResult = (UnitVal == `CMPUNIT) | (UnitVal == `CLASSUNIT) | ((UnitVal == `CVTINTUNIT) & WriteIntVal);
  assign ResMatch  = (IntResult ? (Res[P.XLEN-1:0] === Ans[P.XLEN-1:0]) : (Res[P.FLEN-1:0] === Ans[P.FLEN-1:0])) |
                     NaNGood | (NaNGood === 1'bx);
  assign FlagMatch = ((ResFlg === AnsFlg) | (AnsFlg === 5'bx));

  // compare the result and flags with the TestFloat answer; stop at the first error
  task automatic checkResult();
    if (~(ResMatch & FlagMatch) & (Ans[0] !== 1'bx)) begin
      errors += 1;
      $display("\nError in %s", Tests[TestNum]);
      $display("TestNum %d VectorNum %d OpCtrl %d", TestNum, VectorNum, OpCtrlVal);
      $display("inputs: %h %h %h\nSrcA: %h\n Res: %h %h\n Expected: %h %h",
        X[P.FLEN-1:0], Y[P.FLEN-1:0], Z[P.FLEN-1:0], SrcA, Res[P.FLEN-1:0], ResFlg, Ans[P.FLEN-1:0], AnsFlg);
`ifdef QUESTA
      $stop;  // if this is changed to $finish for Questa, wally.do terminates without allowing GUI debug
`else
      $fatal(1, "TestFloat vector mismatch");
`endif
    end
  endtask
endmodule


module readvectors import cvw::*; #(parameter cvw_t P) (
  input  logic [P.Q_LEN*4+7:0] TestVector,
  input  logic [P.FMTBITS-1:0] ModFmt,
  input  logic [1:0]  Fmt,
  input  logic [3:0]  Unit,
  input  logic [3:0]  OpCtrl,
  output logic [P.Q_LEN-1:0] Ans,
  output logic [P.XLEN-1:0]  SrcA,
  output logic [4:0] AnsFlg,
  output logic            Xs, Ys, Zs,          // sign bits of XYZ
  output logic [P.NE-1:0] Xe, Ye, Ze,          // exponents of XYZ (converted to largest supported precision)
  output logic [P.NF:0]   Xm, Ym, Zm,          // mantissas of XYZ (converted to largest supported precision)
  output logic            XNaN, YNaN, ZNaN,    // is XYZ a NaN
  output logic            XSNaN, YSNaN, ZSNaN, // is XYZ a signaling NaN
  output logic            XSubnorm, ZSubnorm,  // is XYZ denormalized
  output logic            XZero, YZero, ZZero, // is XYZ zero
  output logic            XInf, YInf, ZInf,    // is XYZ infinity
  output logic            XExpMax,
  output logic [P.Q_LEN-1:0]   X, Y, Z,
  output logic [P.FLEN-1:0]    XPostBox,
  output logic [P.NE-2:0]      BiasE,          // Bias of exponent
  output logic [P.LOGFLEN-1:0] NfE             // Number of fractional bits
);

  logic XEn;
  logic YEn;
  int   Len;   // length of the format under test

  // field Pos (0 = the answer) of a vector of Len-bit fields after the flags, NaN-boxed to Q_LEN
  function automatic logic [P.Q_LEN-1:0] Field(input logic [P.Q_LEN*4+7:0] V, input int Pos, input int L);
    logic [P.Q_LEN-1:0] Mask;
    Mask = (L >= P.Q_LEN) ? '1 : ~({P.Q_LEN{1'b1}} << L);
    return (P.Q_LEN'(V >> (8 + Pos*L)) & Mask) | ~Mask;
  endfunction

  always_comb
    case (Fmt)
      2'b11:   Len = P.Q_LEN;
      2'b01:   Len = P.D_LEN;
      2'b00:   Len = P.S_LEN;
      default: Len = P.H_LEN;
    endcase
  logic ZEn;
  logic FPUActive;

  // split the test vector into inputs and the expected answer
  // Format of vectors Inputs(1/2/3)_AnsFlg
  always_comb begin
    AnsFlg = TestVector[4:0];
    X = '0; Y = '0; Z = '0; SrcA = '0; Ans = '0;
    case (Unit)
      `FMAUNIT:
        case (Fmt)
          2'b11:  if (P.Q_SUPPORTED) begin // quad
                    if (OpCtrl === `FMA_OPCTRL) begin
                      X = TestVector[8+4*(P.Q_LEN)-1:8+3*(P.Q_LEN)];
                      Y = TestVector[8+3*(P.Q_LEN)-1:8+2*(P.Q_LEN)];
                      Z = TestVector[8+2*(P.Q_LEN)-1:8+P.Q_LEN];
                    end else begin
                      X = TestVector[8+3*(P.Q_LEN)-1:8+2*(P.Q_LEN)];
                      if (OpCtrl === `MUL_OPCTRL) Y = TestVector[8+2*(P.Q_LEN)-1:8+(P.Q_LEN)];
                      else Y = {2'b0, {P.Q_NE-1{1'b1}}, (P.Q_NF)'(0)};
                      if (OpCtrl === `MUL_OPCTRL) Z = 0;
                      else Z = TestVector[8+2*(P.Q_LEN)-1:8+(P.Q_LEN)];
                    end
                    Ans = TestVector[8+(P.Q_LEN-1):8];
                  end
          2'b01:  if (P.D_SUPPORTED) begin // double
                    if (OpCtrl === `FMA_OPCTRL) begin
                      X = {{P.Q_LEN-P.D_LEN{1'b1}}, TestVector[8+4*(P.D_LEN)-1:8+3*(P.D_LEN)]};
                      Y = {{P.Q_LEN-P.D_LEN{1'b1}}, TestVector[8+3*(P.D_LEN)-1:8+2*(P.D_LEN)]};
                      Z = {{P.Q_LEN-P.D_LEN{1'b1}}, TestVector[8+2*(P.D_LEN)-1:8+P.D_LEN]};
                    end else begin
                      X = {{P.Q_LEN-P.D_LEN{1'b1}}, TestVector[8+3*(P.D_LEN)-1:8+2*(P.D_LEN)]};
                      if (OpCtrl === `MUL_OPCTRL) Y = {{P.Q_LEN-P.D_LEN{1'b1}}, TestVector[8+2*(P.D_LEN)-1:8+(P.D_LEN)]};
                      else Y = {{P.Q_LEN-P.D_LEN{1'b1}}, 2'b0, {P.D_NE-1{1'b1}}, (P.D_NF)'(0)};
                      if (OpCtrl === `MUL_OPCTRL) Z = {{P.Q_LEN-P.D_LEN{1'b1}}, {P.D_LEN{1'b0}}};
                      else Z = {{P.Q_LEN-P.D_LEN{1'b1}}, TestVector[8+2*(P.D_LEN)-1:8+(P.D_LEN)]};
                    end
                    Ans = {{P.Q_LEN-P.D_LEN{1'b1}}, TestVector[8+(P.D_LEN-1):8]};
                  end
          2'b00:  if (P.F_SUPPORTED) begin // single
                    if (OpCtrl === `FMA_OPCTRL) begin
                      X = {{P.Q_LEN-P.S_LEN{1'b1}}, TestVector[8+4*(P.S_LEN)-1:8+3*(P.S_LEN)]};
                      Y = {{P.Q_LEN-P.S_LEN{1'b1}}, TestVector[8+3*(P.S_LEN)-1:8+2*(P.S_LEN)]};
                      Z = {{P.Q_LEN-P.S_LEN{1'b1}}, TestVector[8+2*(P.S_LEN)-1:8+P.S_LEN]};
                    end else begin
                      X = {{P.Q_LEN-P.S_LEN{1'b1}}, TestVector[8+3*(P.S_LEN)-1:8+2*(P.S_LEN)]};
                      if (OpCtrl === `MUL_OPCTRL) Y = {{P.Q_LEN-P.S_LEN{1'b1}}, TestVector[8+2*(P.S_LEN)-1:8+(P.S_LEN)]};
                      else Y = {{P.Q_LEN-P.S_LEN{1'b1}}, 2'b0, {P.S_NE-1{1'b1}}, (P.S_NF)'(0)};
                      if (OpCtrl === `MUL_OPCTRL) Z = {{P.Q_LEN-P.S_LEN{1'b1}}, {P.S_LEN{1'b0}}};
                      else Z = {{P.Q_LEN-P.S_LEN{1'b1}}, TestVector[8+2*(P.S_LEN)-1:8+(P.S_LEN)]};
                    end
                    Ans = {{P.Q_LEN-P.S_LEN{1'b1}}, TestVector[8+(P.S_LEN-1):8]};
                  end
          2'b10:  begin // half
                    if (OpCtrl === `FMA_OPCTRL) begin
                      X = {{P.Q_LEN-P.H_LEN{1'b1}}, TestVector[8+4*(P.H_LEN)-1:8+3*(P.H_LEN)]};
                      Y = {{P.Q_LEN-P.H_LEN{1'b1}}, TestVector[8+3*(P.H_LEN)-1:8+2*(P.H_LEN)]};
                      Z = {{P.Q_LEN-P.H_LEN{1'b1}}, TestVector[8+2*(P.H_LEN)-1:8+P.H_LEN]};
                    end else begin
                      X = {{P.Q_LEN-P.H_LEN{1'b1}}, TestVector[8+3*(P.H_LEN)-1:8+2*(P.H_LEN)]};
                      if (OpCtrl === `MUL_OPCTRL) Y = {{P.Q_LEN-P.H_LEN{1'b1}}, TestVector[8+2*(P.H_LEN)-1:8+(P.H_LEN)]};
                      else Y = {{P.Q_LEN-P.H_LEN{1'b1}}, 2'b0, {P.H_NE-1{1'b1}}, (P.H_NF)'(0)};
                      if (OpCtrl === `MUL_OPCTRL) Z = {{P.Q_LEN-P.H_LEN{1'b1}}, {P.H_LEN{1'b0}}};
                      else Z = {{P.Q_LEN-P.H_LEN{1'b1}}, TestVector[8+2*(P.H_LEN)-1:8+(P.H_LEN)]};
                    end
                    Ans = {{P.Q_LEN-P.H_LEN{1'b1}}, TestVector[8+(P.H_LEN-1):8]};
                  end
        endcase
      `DIVUNIT:
        if (OpCtrl[0])
          case (Fmt)
            2'b11: begin // quad
              X = TestVector[8+2*(P.Q_LEN)-1:8+(P.Q_LEN)];
              Ans = TestVector[8+(P.Q_LEN-1):8];
            end
            2'b01: if (P.D_SUPPORTED) begin // double
              X = {{P.Q_LEN-P.D_LEN{1'b1}}, TestVector[8+2*(P.D_LEN)-1:8+(P.D_LEN)]};
              Ans = {{P.Q_LEN-P.D_LEN{1'b1}}, TestVector[8+(P.D_LEN-1):8]};
            end
            2'b00: if (P.F_SUPPORTED) begin // single
              X = {{P.Q_LEN-P.S_LEN{1'b1}}, TestVector[8+2*(P.S_LEN)-1:8+1*(P.S_LEN)]};
              Ans = {{P.Q_LEN-P.S_LEN{1'b1}}, TestVector[8+(P.S_LEN-1):8]};
            end
            2'b10: begin // half
              X = {{P.Q_LEN-P.H_LEN{1'b1}}, TestVector[8+2*(P.H_LEN)-1:8+(P.H_LEN)]};
              Ans = {{P.Q_LEN-P.H_LEN{1'b1}}, TestVector[8+(P.H_LEN-1):8]};
            end
          endcase
        else
          case (Fmt)
            2'b11: begin // quad
              X = TestVector[8+3*(P.Q_LEN)-1:8+2*(P.Q_LEN)];
              Y = TestVector[8+2*(P.Q_LEN)-1:8+(P.Q_LEN)];
              Ans = TestVector[8+(P.Q_LEN-1):8];
            end
            2'b01: if (P.D_SUPPORTED) begin // double
                X = {{P.Q_LEN-P.D_LEN{1'b1}}, TestVector[8+3*(P.D_LEN)-1:8+2*(P.D_LEN)]};
                Y = {{P.Q_LEN-P.D_LEN{1'b1}}, TestVector[8+2*(P.D_LEN)-1:8+(P.D_LEN)]};
                Ans = {{P.Q_LEN-P.D_LEN{1'b1}}, TestVector[8+(P.D_LEN-1):8]};
            end
            2'b00: if (P.F_SUPPORTED) begin // single
              X = {{P.Q_LEN-P.S_LEN{1'b1}}, TestVector[8+3*(P.S_LEN)-1:8+2*(P.S_LEN)]};
              Y = {{P.Q_LEN-P.S_LEN{1'b1}}, TestVector[8+2*(P.S_LEN)-1:8+1*(P.S_LEN)]};
              Ans = {{P.Q_LEN-P.S_LEN{1'b1}}, TestVector[8+(P.S_LEN-1):8]};
            end
            2'b10: begin // half
              X = {{P.Q_LEN-P.H_LEN{1'b1}}, TestVector[8+3*(P.H_LEN)-1:8+2*(P.H_LEN)]};
              Y = {{P.Q_LEN-P.H_LEN{1'b1}}, TestVector[8+2*(P.H_LEN)-1:8+(P.H_LEN)]};
              Ans = {{P.Q_LEN-P.H_LEN{1'b1}}, TestVector[8+(P.H_LEN-1):8]};
            end
          endcase
      `CMPUNIT:
        case (Fmt)
          2'b11: begin // quad
            X = TestVector[12+2*(P.Q_LEN)-1:12+(P.Q_LEN)];
            Y = TestVector[12+(P.Q_LEN)-1:12];
            Ans = {{P.Q_LEN-1{1'b0}}, TestVector[8]};
          end
          2'b01: if (P.D_SUPPORTED) begin // double
            X = {{P.Q_LEN-P.D_LEN{1'b1}}, TestVector[12+2*(P.D_LEN)-1:12+(P.D_LEN)]};
            Y = {{P.Q_LEN-P.D_LEN{1'b1}}, TestVector[12+(P.D_LEN)-1:12]};
            Ans = {{P.Q_LEN-1{1'b0}}, TestVector[8]};
          end
          2'b00: if (P.F_SUPPORTED) begin // single
            X = {{P.Q_LEN-P.S_LEN{1'b1}}, TestVector[12+2*(P.S_LEN)-1:12+(P.S_LEN)]};
            Y = {{P.Q_LEN-P.S_LEN{1'b1}}, TestVector[12+(P.S_LEN)-1:12]};
            Ans = {{P.Q_LEN-1{1'b0}}, TestVector[8]};
          end
          2'b10: begin // half
            X = {{P.Q_LEN-P.H_LEN{1'b1}}, TestVector[12+2*(P.H_LEN)-1:12+(P.H_LEN)]};
            Y = {{P.Q_LEN-P.H_LEN{1'b1}}, TestVector[12+(P.H_LEN)-1:12]};
            Ans = {{P.Q_LEN-1{1'b0}}, TestVector[8]};
          end
        endcase
      `CVTFPUNIT:
        case (Fmt)
          2'b11: begin // quad
            case (OpCtrl[1:0])
              2'b11: begin // quad
                X = {TestVector[8+P.Q_LEN+P.Q_LEN-1:8+(P.Q_LEN)]};
                Ans = TestVector[8+(P.Q_LEN-1):8];
              end
              2'b01: if (P.D_SUPPORTED) begin // double
                X = {TestVector[8+P.Q_LEN+P.D_LEN-1:8+(P.D_LEN)]};
                Ans = {{P.Q_LEN-P.D_LEN{1'b1}}, TestVector[8+(P.D_LEN-1):8]};
              end
              2'b00: begin // single
                X = {TestVector[8+P.Q_LEN+P.S_LEN-1:8+(P.S_LEN)]};
                Ans = {{P.Q_LEN-P.S_LEN{1'b1}}, TestVector[8+(P.S_LEN-1):8]};
              end
              2'b10: begin // half
                X = {TestVector[8+P.Q_LEN+P.H_LEN-1:8+(P.H_LEN)]};
                Ans = {{P.Q_LEN-P.H_LEN{1'b1}}, TestVector[8+(P.H_LEN-1):8]};
              end
            endcase
          end
          2'b01: if (P.D_SUPPORTED) begin // double
            case (OpCtrl[1:0])
              2'b11: begin // quad
                X = {{P.Q_LEN-P.D_LEN{1'b1}}, TestVector[8+P.D_LEN+P.Q_LEN-1:8+(P.Q_LEN)]};
                Ans = TestVector[8+(P.Q_LEN-1):8];
              end
              2'b01: begin // double
                X = {{P.Q_LEN-P.D_LEN{1'b1}}, TestVector[8+P.D_LEN+P.D_LEN-1:8+(P.D_LEN)]};
                Ans = {{P.Q_LEN-P.D_LEN{1'b1}}, TestVector[8+(P.D_LEN-1):8]};
              end
              2'b00: begin // single
                X = {{P.Q_LEN-P.D_LEN{1'b1}}, TestVector[8+P.D_LEN+P.S_LEN-1:8+(P.S_LEN)]};
                Ans = {{P.Q_LEN-P.S_LEN{1'b1}}, TestVector[8+(P.S_LEN-1):8]};
              end
              2'b10: begin // half
                X = {{P.Q_LEN-P.D_LEN{1'b1}}, TestVector[8+P.D_LEN+P.H_LEN-1:8+(P.H_LEN)]};
                Ans = {{P.Q_LEN-P.H_LEN{1'b1}}, TestVector[8+(P.H_LEN-1):8]};
              end
            endcase
          end
          2'b00: if (P.F_SUPPORTED) begin // single
            case (OpCtrl[1:0])
              2'b11: begin // quad
                X = {{P.Q_LEN-P.S_LEN{1'b1}}, TestVector[8+P.S_LEN+P.Q_LEN-1:8+(P.Q_LEN)]};
                Ans = TestVector[8+(P.Q_LEN-1):8];
              end
              2'b01: if (P.D_SUPPORTED) begin // double
                X = {{P.Q_LEN-P.S_LEN{1'b1}}, TestVector[8+P.S_LEN+P.D_LEN-1:8+(P.D_LEN)]};
                Ans = {{P.Q_LEN-P.D_LEN{1'b1}}, TestVector[8+(P.D_LEN-1):8]};
              end
              2'b00: begin // single
                X = {{P.Q_LEN-P.S_LEN{1'b1}}, TestVector[8+P.S_LEN+P.S_LEN-1:8+(P.S_LEN)]};
                Ans = {{P.Q_LEN-P.S_LEN{1'b1}}, TestVector[8+(P.S_LEN-1):8]};
              end
              2'b10: begin // half
                X = {{P.Q_LEN-P.S_LEN{1'b1}}, TestVector[8+P.S_LEN+P.H_LEN-1:8+(P.H_LEN)]};
                Ans = {{P.Q_LEN-P.H_LEN{1'b1}}, TestVector[8+(P.H_LEN-1):8]};
              end
            endcase
          end
          2'b10: begin // half
            case (OpCtrl[1:0])
              2'b11: begin // quad
                X = {{P.Q_LEN-P.H_LEN{1'b1}}, TestVector[8+P.H_LEN+P.Q_LEN-1:8+(P.Q_LEN)]};
                Ans = TestVector[8+(P.Q_LEN-1):8];
              end
              2'b01: if (P.D_SUPPORTED) begin // double
                X = {{P.Q_LEN-P.H_LEN{1'b1}}, TestVector[8+P.H_LEN+P.D_LEN-1:8+(P.D_LEN)]};
                Ans = {{P.Q_LEN-P.D_LEN{1'b1}}, TestVector[8+(P.D_LEN-1):8]};
              end
              2'b00: if (P.F_SUPPORTED) begin // single
                X = {{P.Q_LEN-P.H_LEN{1'b1}}, TestVector[8+P.H_LEN+P.S_LEN-1:8+(P.S_LEN)]};
                Ans = {{P.Q_LEN-P.S_LEN{1'b1}}, TestVector[8+(P.S_LEN-1):8]};
              end
              2'b10: begin // half
                X = {{P.Q_LEN-P.H_LEN{1'b1}}, TestVector[8+P.H_LEN+P.H_LEN-1:8+(P.H_LEN)]};
                Ans = {{P.Q_LEN-P.H_LEN{1'b1}}, TestVector[8+(P.H_LEN-1):8]};
              end
            endcase
          end
        endcase
      `CVTINTUNIT:
        case (Fmt)
          2'b11: begin // quad
            // {is the integer a long, is the operation to an integer}
            casez ({OpCtrl[2:1]})
              2'b11: begin // long -> quad
                X = {P.Q_LEN{1'bx}};
                SrcA = TestVector[8+P.Q_LEN+P.XLEN-1:8+(P.Q_LEN)];
                Ans = TestVector[8+(P.Q_LEN-1):8];
              end
              2'b10: begin // int -> quad
                // correctly sign extend the integer depending on if it's a signed/unsigned test
                X = {P.Q_LEN{1'bx}};
                SrcA = {{P.XLEN-32{TestVector[8+P.Q_LEN+32-1]}}, TestVector[8+P.Q_LEN+32-1:8+(P.Q_LEN)]};
                Ans = TestVector[8+(P.Q_LEN-1):8];
              end
              2'b01: begin // quad -> long
                X = {TestVector[8+P.XLEN+P.Q_LEN-1:8+(P.XLEN)]};
                SrcA = {P.XLEN{1'bx}};
                Ans = {{(P.Q_LEN-64){1'b0}}, TestVector[8+(64-1):8]};
              end
              2'b00: begin // quad -> int
                X = {TestVector[8+32+P.Q_LEN-1:8+(32)]};
                SrcA = {P.XLEN{1'bx}};
                Ans = {{(P.Q_LEN-32){TestVector[8+32-1]}},TestVector[8+(32-1):8]};
              end
            endcase
          end
          2'b01: if (P.D_SUPPORTED) begin // double
            // {Int->Fp?, is the integer a long}
            casez ({OpCtrl[2:1]})
              2'b11: begin // long -> double
                X = {P.Q_LEN{1'bx}};
                SrcA = TestVector[8+P.D_LEN+P.XLEN-1:8+(P.D_LEN)];
                Ans = {{P.Q_LEN-P.D_LEN{1'b1}}, TestVector[8+(P.D_LEN-1):8]};
              end
              2'b10: begin // int -> double
                // correctly sign extend the integer depending on if it's a signed/unsigned test
                X = {P.Q_LEN{1'bx}};
                SrcA = {{P.XLEN-32{TestVector[8+P.D_LEN+32-1]}}, TestVector[8+P.D_LEN+32-1:8+(P.D_LEN)]};
                Ans = {{P.Q_LEN-P.D_LEN{1'b1}}, TestVector[8+(P.D_LEN-1):8]};
              end
              2'b01: begin // double -> long
                X = {{P.Q_LEN-P.D_LEN{1'b1}}, TestVector[8+P.XLEN+P.D_LEN-1:8+(P.XLEN)]};
                SrcA = {P.XLEN{1'bx}};
                Ans = {{(P.Q_LEN-64){1'b0}}, TestVector[8+(64-1):8]};
              end
              2'b00: begin // double -> int
                X = {{P.Q_LEN-P.D_LEN{1'b1}}, TestVector[8+32+P.D_LEN-1:8+(32)]};
                SrcA = {P.XLEN{1'bx}};
                Ans = {{P.Q_LEN-32{TestVector[8+32-1]}},TestVector[8+(32-1):8]};
              end
            endcase
          end
          2'b00: if (P.F_SUPPORTED) begin // single
            // {is the integer a long, is the operation to an integer}
            casez ({OpCtrl[2:1]})
              2'b11: begin // long -> single
                X = {P.Q_LEN{1'bx}};
                SrcA = TestVector[8+P.S_LEN+P.XLEN-1:8+(P.S_LEN)];
                Ans = {{P.Q_LEN-P.S_LEN{1'b1}}, TestVector[8+(P.S_LEN-1):8]};
              end
              2'b10: begin // int -> single
                // correctly sign extend the integer depending on if it's a signed/unsigned test
                X = {P.Q_LEN{1'bx}};
                SrcA = {{P.XLEN-32{TestVector[8+P.S_LEN+32-1]}}, TestVector[8+P.S_LEN+32-1:8+(P.S_LEN)]};
                Ans = {{P.Q_LEN-P.S_LEN{1'b1}}, TestVector[8+(P.S_LEN-1):8]};
              end
              2'b01: begin // single -> long
                X = {{P.Q_LEN-P.S_LEN{1'b1}}, TestVector[8+P.XLEN+P.S_LEN-1:8+(P.XLEN)]};
                SrcA = {P.XLEN{1'bx}};
                Ans = {{(P.Q_LEN-64){1'b0}}, TestVector[8+(64-1):8]};
              end
              2'b00: begin // single -> int
                X = {{P.Q_LEN-P.S_LEN{1'b1}}, TestVector[8+32+P.S_LEN-1:8+(32)]};
                SrcA = {P.XLEN{1'bx}};
                Ans = {{(P.Q_LEN-32){TestVector[8+32-1]}},TestVector[8+(32-1):8]};
              end
            endcase
          end
          2'b10: begin // half
            // {is the integer a long, is the operation to an integer}
            casez ({OpCtrl[2:1]})
              2'b11: begin // long -> half
                X = {P.Q_LEN{1'bx}};
                SrcA = TestVector[8+P.H_LEN+P.XLEN-1:8+(P.H_LEN)];
                Ans = {{P.Q_LEN-P.H_LEN{1'b1}}, TestVector[8+(P.H_LEN-1):8]};
              end
              2'b10: begin // int -> half
                // correctly sign extend the integer depending on if it's a signed/unsigned test
                X = {P.Q_LEN{1'bx}};
                SrcA = {{P.XLEN-32{TestVector[8+P.H_LEN+32-1]}}, TestVector[8+P.H_LEN+32-1:8+(P.H_LEN)]};
                Ans = {{P.Q_LEN-P.H_LEN{1'b1}}, TestVector[8+(P.H_LEN-1):8]};
              end
              2'b01: begin // half -> long
                X = {{P.Q_LEN-P.H_LEN{1'b1}}, TestVector[8+P.XLEN+P.H_LEN-1:8+(P.XLEN)]};
                SrcA = {P.XLEN{1'bx}};
                Ans = {{(P.Q_LEN-64){1'b0}}, TestVector[8+(64-1):8]};
              end
              2'b00: begin // half -> int
                X = {{P.Q_LEN-P.H_LEN{1'b1}}, TestVector[8+32+P.H_LEN-1:8+(32)]};
                SrcA = {P.XLEN{1'bx}};
                Ans = {{(P.Q_LEN-32){TestVector[8+32-1]}}, TestVector[8+(32-1):8]};
              end
            endcase
          end
        endcase
      // vectors are X_Ans_Flg (round, class) or X_Y_Ans_Flg (sign injection, min/max)
      `ROUNDUNIT: begin
        X = Field(TestVector, 1, Len);
        Ans = Field(TestVector, 0, Len);
      end
      `CLASSUNIT: begin
        X = Field(TestVector, 1, Len);
        Ans = Field(TestVector, 0, Len) & ~({P.Q_LEN{1'b1}} << Len); // an integer result is not NaN-boxed
      end
      `SGNJUNIT, `MINMAXUNIT: begin
        X = Field(TestVector, 2, Len);
        Y = Field(TestVector, 1, Len);
        Ans = Field(TestVector, 0, Len);
      end
      default: ;
    endcase
  end

  assign XEn = ~((Unit == `CVTINTUNIT)&OpCtrl[2]);
  assign YEn = ~((Unit == `CVTINTUNIT)|(Unit == `CVTFPUNIT)|((Unit == `DIVUNIT)&OpCtrl[0])|(Unit == `ROUNDUNIT)|(Unit == `CLASSUNIT));
  assign ZEn = (Unit == `FMAUNIT);
  assign FPUActive = 1'b1;

  unpack #(P) unpack(.X(X[P.FLEN-1:0]), .Y(Y[P.FLEN-1:0]), .Z(Z[P.FLEN-1:0]), .Fmt(ModFmt), .FPUActive, .Xs, .Ys, .Zs, .Xe, .Ye, .Ze,
                     .Xm, .Ym, .Zm, .XNaN, .YNaN, .ZNaN, .XSNaN, .YSNaN, .ZSNaN,
                     .XSubnorm, .XZero, .YZero, .ZZero, .XInf, .YInf, .ZInf,
                     .XEn, .YEn, .ZEn, .XExpMax, .XPostBox, .Bias(BiasE), .Nf(NfE));
endmodule
