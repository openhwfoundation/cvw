///////////////////////////////////////////
// datapath.sv
//
// Written:  David Harris David_Harris@hmc.edu, Sarah Harris Sarah.Harris@unlv.edu 9 January 2021
// Modified: Katherine Parry, Rose Thompson, Kevin Kim, James Stine, Kip Macsai-Goren, Madeleine Masser-Frye, Shreya Sanghai
//
// Purpose: Integer datapath.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module datapath import cvw::*; #(parameter cvw_t P) (
  input  logic              clk, reset,
  // Decode stage signals
  input  logic [2:0]        ImmSrcD,                 // Selects type of immediate extension
  input  logic [31:0]       InstrD,                  // Instruction in Decode stage
  input  logic [4:0]        Rs1D, Rs2D, Rs2E,        // Source registers
  input  logic [2:0]        ImmSrc1D,                // Slot 1 (superscalar): immediate format
  input  logic [31:0]       Instr1D,                 // Slot 1: instruction in Decode stage
  input  logic [4:0]        Rs1_1D, Rs2_1D,          // Slot 1: source registers
  input  logic [4:0]        Rs2_1E,                  // Slot 1: source register 2 in Execute (ALU bit-manipulation)
  input  logic [2:0]        ForwardA1E, ForwardB1E,  // Slot 1: forwarding selects
  input  logic              ALUSrcA1E, ALUSrcB1E,    // Slot 1: ALU operands
  input  logic              ALUResultSrc1E,          // Slot 1: selects ALU result or immediate
  input  logic [2:0]        ALUSelect1E,             // Slot 1: ALU mux select
  input  logic [2:0]        Funct3_1E,               // Slot 1: funct3
  input  logic [6:0]        Funct7_1E,               // Slot 1: funct7
  input  logic              W64_1E, UW64_1E,         // Slot 1: RV64 W-type / .uw-type
  input  logic              SubArith1E,              // Slot 1: subtract or arithmetic shift
  input  logic [3:0]        BSelect1E, ZBBSelect1E,  // Slot 1: bit-manipulation selects
  input  logic [2:0]        BALUControl1E,           // Slot 1: bit-manipulation ALU control
  input  logic              BMUActive1E,             // Slot 1: bit-manipulation instruction active
  input  logic [1:0]        CZero1E,                 // Slot 1: czero.* active
  input  logic              BranchSigned1E,          // Slot 1: branch comparison is signed
  input  logic              FuseBrA1E, FuseBrB1E,    // Slot 1's branch is fused with slot 0's ALU op: its rs1 / rs2 is slot 0's result
  input  logic              FuseBrAdd1E,             // ... and slot 0's op is an add (else a logic op)
  input  logic              Jump1E,                  // Slot 1: jal, whose result is its link address
  input  logic [P.XLEN-1:0] PCLink1E,                // Slot 1: its link address, the PC just past it
  output logic [1:0]        Flags1E,                 // Slot 1: comparison flags ({eq, lt})
  output logic [P.XLEN-1:0] IEUAdr1E,                // Slot 1: ALU sum, which is its branch or jal target
  input  logic              RegWrite1W,              // Slot 1: commits a register write this cycle
  input  logic [4:0]        Rd1W,                    // Slot 1: destination register in Writeback
  input  logic              Mem1E,                   // Slot 1: holds the bundle's memory operation
  input  logic [2:0]        ResultSrc1W,             // Slot 1: selects source of its writeback value
  input  logic              Mdu1E,                   // Slot 1: holds the bundle's multiply
  output logic [P.XLEN-1:0] MDUSrcAE, MDUSrcBE,      // Operands to the MDU, from whichever slot holds its operation
  input  logic [1:0]        LateSelA1E, LateSelB1E,  // Slot 1: late ALU operand source (00 own, 01 slot 0, 10 ResultW, 11 Result1W)
  input  logic              LateBrE,                 // The late ALU compares slot 0's branch operands instead
  input  logic              Late0RawE,               // ... or computes slot 0's ALU operation instead (ieu.sv)
  output logic [2:0]        LateFlagsM,              // ... giving {eq, lt, ltu}
  // Execute stage signals
  input  logic [P.XLEN-1:0] PCE,                     // PC in Execute stage
  input  logic [P.XLEN-1:0] PCLinkE,                 // PC + 4 (of instruction in Execute stage)
  input  logic [2:0]        Funct3E,                 // Funct3 field of instruction in Execute stage
  input  logic [6:0]        Funct7E,                 // Funct7 field of instruction in Execute stage
  input  logic              StallE, FlushE,          // Stall, flush Execute stage
  input  logic [2:0]        ForwardAE, ForwardBE,    // Forward ALU operands from later stages
  input  logic              W64E, UW64E,             // W64/.uw-type instruction
  input  logic              SubArithE,               // Subtraction or arithmetic shift
  input  logic              ALUSrcAE, ALUSrcBE,      // ALU operands
  input  logic              ALUResultSrcE,           // Selects result to pass on to Memory stage
  input  logic [2:0]        ALUSelectE,              // ALU mux select signal
  input  logic              JumpE,                   // Jump (jal or jalr) instruction
  input  logic              BranchSignedE,           // Branch comparison operands are signed (if it's a branch)
  input  logic [3:0]        BSelectE,                // BMU result select (binary encoded; see bitmanipalu)
  input  logic [3:0]        ZBBSelectE,              // ZBB mux select signal
  input  logic [2:0]        BALUControlE,            // ALU Control signals for B instructions in Execute Stage
  input  logic              BMUActiveE,              // Bit manipulation instruction being executed
  input  logic [1:0]        CZeroE,                  // {czero.nez, czero.eqz} instructions active
  output logic [1:0]        FlagsE,                  // Comparison flags ({eq, lt})
  output logic [P.XLEN-1:0] IEUAdrE,                 // Address computed by ALU: slot 0's branch/jump target
  output logic [P.XLEN-1:0] LSUAdrE,                 // Address computed by ALU: memory address, from either slot
  output logic [P.XLEN-1:0] ForwardedSrcAE, ForwardedSrcBE, // ALU sources before the mux chooses between them and PCE to put in srcA/B
  // Memory stage signals
  input  logic              StallM, FlushM,          // Stall, flush Memory stage
  input  logic              FWriteIntM, FCvtIntW,    // FPU writes integer register file, FPU converts float to int
  input  logic [P.XLEN-1:0] FIntResM,                // FPU integer result
  output logic [P.XLEN-1:0] SrcAM,                   // ALU's Source A in Memory stage to privilege unit for CSR writes
  output logic [P.XLEN-1:0] WriteDataM,              // Write data in Memory stage
  // Writeback stage signals
  input  logic              StallW, FlushW,          // Stall, flush Writeback stage
  input  logic              RegWriteW, IntDivW,      // Write register file, integer divide instruction
  input  logic              SquashSCW,               // Squash a store conditional when a conflict arose
  input  logic [2:0]        ResultSrcW,              // Select source of result to write back to register file
  input  logic [P.XLEN-1:0] FCvtIntResW,             // FPU convert fp to integer result
  input  logic [P.XLEN-1:0] ReadDataW,               // Read data from LSU
  input  logic [P.XLEN-1:0] CSRReadValW,             // CSR read result
  input  logic [P.XLEN-1:0] MDUResultW,              // MDU (Multiply/divide unit) result
  input  logic [P.XLEN-1:0] FIntDivResultW,          // FPU's integer divide result
  input  logic [4:0]        RdW                      // Destination register
);

  // Decode stage signals
  logic [P.XLEN-1:0] R1D, R2D;                       // Read data from Rs1 (RD1), Rs2 (RD2)
  logic [P.XLEN-1:0] ImmExtD;                        // Extended immediate in Decode stage
  logic [P.XLEN-1:0] R1_1D, R2_1D;                   // Slot 1: read data from Rs1_1D, Rs2_1D
  logic [P.XLEN-1:0] ImmExt1D;                       // Slot 1: extended immediate in Decode stage
  logic [P.XLEN-1:0] R1_1E, R2_1E, ImmExt1E;         // Slot 1: the same, in Execute
  logic [P.XLEN-1:0] ForwardedSrcA1E, ForwardedSrcB1E; // Slot 1: operands after forwarding
  logic [P.XLEN-1:0] SrcA1E, SrcB1E;                 // Slot 1: ALU inputs
  logic [P.XLEN-1:0] ALUResult1E;                    // Slot 1: ALU output.  The sum, IEUAdr1E, needs no bit-0
                                                     //   mask as slot 0's does: that is for jalr, and slot 1
                                                     //   only ever jumps with jal, whose target is even.
  logic [P.XLEN-1:0] AltResult1E, IEUResult1E;       // Slot 1: result in Execute
  logic [P.XLEN-1:0] IEUResult1M;                    // Slot 1: result in Memory
  logic [P.XLEN-1:0] IEUResult1W;                    // Slot 1: result in Writeback
  logic [P.XLEN-1:0] Result1W;                       // Slot 1: value written back
  logic [P.XLEN-1:0] SrcA1M, SrcB1M;                 // Slot 1: ALU inputs, carried to the late ALU
  logic [P.XLEN-1:0] LateSrcA1M, LateSrcB1M;         // Slot 1: late ALU inputs, with slot 0's result substituted
  logic [P.XLEN-1:0] LateResult1M;                   // Slot 1: late ALU result
  logic [P.XLEN-1:0] Result1M;                       // Slot 1: result entering Writeback
  logic [2:0]        ALUSelect1M, Funct3_1M;         // Slot 1: late ALU control
  logic              SubArith1M, W64_1M;
  logic [1:0]        LateSelA1M, LateSelB1M;         // Slot 1: where the late ALU takes each operand from
  logic              Late1M;                         // Slot 1 executes on the late ALU
  logic              LateBrM;                        // The late ALU compares slot 0's branch instead
  logic              Late0RawM, Late0M;              // The late ALU was given slot 0's ALU operation / and computes it
  logic [2:0]        LateALUSelectE, LateFunct3E;    // Late ALU control, from whichever slot uses it
  logic              LateSubArithE, LateW64E;
  logic [P.XLEN-1:0] IFResultLateM;                  // Slot 0's result entering Writeback, the late ALU's if slot 0 was late
  logic [P.XLEN-1:0] LateInA1E, LateInB1E;           // What the late ALU's operand registers capture
  logic [P.XLEN-1:0] LateSum1M;                      // The late ALU's adder output
  logic              LateSignA, LateSignB, LateNeg;  // ... and the signs the branch flags are formed from
  // Execute stage signals
  logic [P.XLEN-1:0] R1E, R2E;                       // Source operands read from register file
  logic [P.XLEN-1:0] ImmExtE;                        // Extended immediate in Execute stage
  logic [P.XLEN-1:0] SrcAE, SrcBE;                   // ALU operands
  logic [P.XLEN-1:0] ALUResultE, AltResultE, IEUResultE; // ALU result, Alternative result (ImmExtE or PC+4), result of execution stage
  logic [P.XLEN-1:0] IEUAdrRawE;                     // ALU sum before clearing bit 0 of a jump target
  logic [P.XLEN-1:0] WriteDataE;                     // Store data of whichever slot holds the memory operation
  // Memory stage signals
  logic [P.XLEN-1:0] IEUResultM;                     // Result from execution stage
  logic [P.XLEN-1:0] IFResultM;                      // Result from either IEU or single-cycle FPU op writing an integer register
  // Writeback stage signals
  logic [P.XLEN-1:0] SCResultW;                      // Store Conditional result
  logic [P.XLEN-1:0] ResultW;                        // Result to write to register file
  logic [P.XLEN-1:0] IFResultW;                      // Result from either IEU or single-cycle FPU op writing an integer register
  logic [P.XLEN-1:0] IFCvtResultW;                   // Result from IEU, single-cycle FPU op, or 2-cycle FCVT float to int
  logic [P.XLEN-1:0] MulDivResultW;                  // Multiply always comes from MDU.  Divide could come from MDU or FPU (when using fdivsqrt for integer division)

  // Decode stage
  regfile #(P.XLEN, P.E_SUPPORTED, P.LATCH_BASED_REGISTERFILE, P.SUPERSCALAR_SUPPORTED) regf(clk, reset, RegWriteW, RegWrite1W, Rs1D, Rs2D, RdW,
    Rs1_1D, Rs2_1D, Rd1W, ResultW, Result1W, R1D, R2D, R1_1D, R2_1D);
  extend #(P)        ext(.InstrD(InstrD[31:7]), .ImmSrcD, .ImmExtD);

  // Execute stage pipeline register and logic
  //
  // Operand capture.  The Execute stage can be held while Memory and Writeback keep moving: a divide
  // holds it for its whole iteration (DivBusyE, FDivBusyE) while older instructions drain and bubbles
  // follow them.  An operand that was being forwarded from Memory or Writeback when the stall began
  // then loses its source as the producer retires, and R1E/R2E still hold the register file value read
  // in Decode, before the producer wrote it.  Single-issue Wally never meets this, because the only
  // instruction in Execute during such a stall is the divide itself, which latches its operands when
  // it starts.  With two slots the other instruction of the bundle sits there too, so the registers
  // reload the forwarded operand every cycle of the stall, and hold the right value once forwarding
  // stops.  The two cases cannot overlap with a flush: StallE without StallM means StallECause, which
  // is already gated by ~FlushECause, so FlushE is low whenever CaptureE is high.
  logic              CaptureE;                       // Execute held while Memory advances: keep forwarded operands
  logic [P.XLEN-1:0] R1ENext, R2ENext, R1_1ENext, R2_1ENext;
  assign CaptureE = P.SUPERSCALAR_SUPPORTED & StallE & ~StallM;
  if (P.SUPERSCALAR_SUPPORTED) begin : capture
    mux2  #(P.XLEN)  r1enextmux(R1D, ForwardedSrcAE, CaptureE, R1ENext);
    mux2  #(P.XLEN)  r2enextmux(R2D, ForwardedSrcBE, CaptureE, R2ENext);
  end else begin : nocapture
    assign R1ENext = R1D;
    assign R2ENext = R2D;
  end
  flopenrc #(P.XLEN) RD1EReg(clk, reset, FlushE, ~StallE | CaptureE, R1ENext, R1E);
  flopenrc #(P.XLEN) RD2EReg(clk, reset, FlushE, ~StallE | CaptureE, R2ENext, R2E);
  flopenrc #(P.XLEN) ImmExtEReg(clk, reset, FlushE, ~StallE, ImmExtD, ImmExtE);

  // Forwarding sources in the order each slot's select encodes them: no forward, own Writeback,
  // own Memory, other Writeback, other Memory.  The encoding is relative to the slot, so slot 1's
  // muxes below take the same four sources with the pairs swapped.  See controller.sv for priority.
  // Without superscalar only the first three sources exist, as in single-issue Wally.
  if (P.SUPERSCALAR_SUPPORTED) begin : fwd5
    mux5  #(P.XLEN)  faemux(R1E, ResultW, IFResultM, Result1W, IEUResult1M, ForwardAE, ForwardedSrcAE);
    mux5  #(P.XLEN)  fbemux(R2E, ResultW, IFResultM, Result1W, IEUResult1M, ForwardBE, ForwardedSrcBE);
  end else begin : fwd3
    mux3  #(P.XLEN)  faemux(R1E, ResultW, IFResultM, ForwardAE[1:0], ForwardedSrcAE);
    mux3  #(P.XLEN)  fbemux(R2E, ResultW, IFResultM, ForwardBE[1:0], ForwardedSrcBE);
  end
  comparator #(P.XLEN) comp(ForwardedSrcAE, ForwardedSrcBE, BranchSignedE, FlagsE);
  mux2  #(P.XLEN)  srcamux(ForwardedSrcAE, PCE, ALUSrcAE, SrcAE);
  mux2  #(P.XLEN)  srcbmux(ForwardedSrcBE, ImmExtE, ALUSrcBE, SrcBE);
  alu   #(P)       alu(SrcAE, SrcBE, W64E, UW64E, SubArithE, ALUSelectE, BSelectE, ZBBSelectE, Funct3E, Funct7E, Rs2E, BALUControlE, BMUActiveE, CZeroE, ALUResultE, IEUAdrRawE);
  // jalr sets the least significant bit of the target address to zero.  jal and branch targets are
  // always even, so masking on JumpE alone is sufficient and leaves load/store addresses untouched.
  assign IEUAdrE = {IEUAdrRawE[P.XLEN-1:1], IEUAdrRawE[0] & ~JumpE};
  mux2  #(P.XLEN)  altresultmux(ImmExtE, PCLinkE, JumpE, AltResultE);
  mux2  #(P.XLEN)  ieuresultmux(ALUResultE, AltResultE, ALUResultSrcE, IEUResultE);

  if (P.SUPERSCALAR_SUPPORTED) begin : slot1
    extend #(P)        ext1(.InstrD(Instr1D[31:7]), .ImmSrcD(ImmSrc1D), .ImmExtD(ImmExt1D));   // slot 1

    // Slot 1 (superscalar) Execute stage, mirroring slot 0 above.  A conditional branch in slot 1
    // compares with its own comparator, and its target is its ALU's sum of slot 1's PC and immediate.
    mux2  #(P.XLEN)  r1_1enextmux(R1_1D, ForwardedSrcA1E, CaptureE, R1_1ENext);   // operand capture, as for slot 0
    mux2  #(P.XLEN)  r2_1enextmux(R2_1D, ForwardedSrcB1E, CaptureE, R2_1ENext);
    flopenrc #(P.XLEN) RD1_1EReg(clk, reset, FlushE, ~StallE | CaptureE, R1_1ENext, R1_1E);
    flopenrc #(P.XLEN) RD2_1EReg(clk, reset, FlushE, ~StallE | CaptureE, R2_1ENext, R2_1E);
    flopenrc #(P.XLEN) ImmExt1EReg(clk, reset, FlushE, ~StallE, ImmExt1D, ImmExt1E);

    mux5  #(P.XLEN)  faemux1(R1_1E, Result1W, IEUResult1M, ResultW, IFResultM, ForwardA1E, ForwardedSrcA1E);
    mux5  #(P.XLEN)  fbemux1(R2_1E, Result1W, IEUResult1M, ResultW, IFResultM, ForwardB1E, ForwardedSrcB1E);
    // Macro-op fusion: ALU op + dependent branch (issue.sv).  The pair is one compare-and-branch op, decided
    // in Execute.  The branch must not wait for slot 0's ALU result: that would put two carry chains in a
    // row (slot 0's add, then comp1's compare) on the clock's critical path.  So comp1 works from slot 0's
    // ALU inputs (SrcAE, SrcBE) instead.  No new adder: slot 0's ALU still makes rd, comp1 does the compare,
    // and slot 1's ALU still makes the target.
    //
    // Logic op: no carry chain, so its result is simply remade here, one gate deep, and compared as usual.
    //   andi t0, a1, 1  ; bnez t0, L      comp1 compares (a1 & 1, x0)
    //
    // Add, X = P + Q: the question "X < Y" is the sign/borrow of X - Y = P + Q + ~Y + 1, three numbers.  A full
    // adder per bit, with no carry passing between bits, turns P, Q, ~Y into two numbers, a sum Sum and a
    // carry Carry, with P + Q + ~Y = Sum + (Carry << 1).  comp1 compares a = Sum against b = ~(Carry << 1):
    // its a - b = Sum + (Carry << 1) + 1 = X - Y, the one carry chain.  So comp1's eq is X == Y, and its
    // unsigned lt is X < Y once corrected for the two carries that fall off the top bit: Carry's top bit and
    // slot 0's own carry out of P + Q (made from the top bits of P, Q and slot 0's sum, ready alongside).
    // Signed: X < Y signed is X < Y unsigned, flipped when X and Y have different sign bits.
    //   add t0, a1, a2  ; blt t0, a3, L   is a1 + a2 < a3?   (P = a1, Q = a2, Y = a3)
    //   li  t0, 5       ; beq a4, t0, L   is 0 + 5 == a4?    (P = x0, Q = 5,  Y = a4)
    // When slot 0's result is rs2 (blt a3, t0), comp1 still answers X < Y, and Y < X = not (X < Y or X == Y).
    // When it is both (beq t0, t0), the operands are equal.
    logic [P.XLEN-1:0] Logic0E;                        // Slot 0's logic result, remade from its ALU inputs
    logic [P.XLEN-1:0] FuseYE, NotYE;                  // Y: the branch operand that is not slot 0's result, and ~Y
    logic [P.XLEN-1:0] CsaSumE, CsaCarryE;             // P + Q + ~Y as two numbers: Sum + (Carry << 1)
    logic [P.XLEN-1:0] CmpA1E, CmpB1E;                 // Slot 1's comparator inputs
    logic [1:0]        CmpFlags1E;                     // comp1's {eq, lt}
    logic              CarryOutE;                      // Carry out of slot 0's P + Q
    logic              LtuE, LtE;                      // Fused add: X < Y unsigned, X < Y as the branch asks

    always_comb
      case (ALUSelectE[1:0])                           // slot 0's ALUSelect: 100 xor, 110 or, 111 and
        2'b00:   Logic0E = SrcAE ^ SrcBE;
        2'b10:   Logic0E = SrcAE | SrcBE;
        default: Logic0E = SrcAE & SrcBE;
      endcase

    mux2  #(P.XLEN)  fuseymux(ForwardedSrcA1E, ForwardedSrcB1E, FuseBrA1E, FuseYE);  // slot 0's is rs1: Y is rs2
    assign NotYE     = ~FuseYE;
    assign CsaSumE   = SrcAE ^ SrcBE ^ NotYE;                                       // full adder sum, per bit
    assign CsaCarryE = (SrcAE & SrcBE) | (SrcAE & NotYE) | (SrcBE & NotYE);         // full adder carry, per bit

    // select: 00 slot 1's own register, 01 logic result, 1x carry-save (an add replaces both inputs)
    mux3  #(P.XLEN)  cmp1amux(ForwardedSrcA1E, Logic0E, CsaSumE, {FuseBrAdd1E, FuseBrA1E}, CmpA1E);
    mux3  #(P.XLEN)  cmp1bmux(ForwardedSrcB1E, Logic0E, ~{CsaCarryE[P.XLEN-2:0], 1'b0}, {FuseBrAdd1E, FuseBrB1E}, CmpB1E);
    comparator #(P.XLEN) comp1(CmpA1E, CmpB1E, BranchSigned1E & ~FuseBrAdd1E, CmpFlags1E);  // an add compares unsigned

    assign CarryOutE = SrcAE[P.XLEN-1] & SrcBE[P.XLEN-1] | (SrcAE[P.XLEN-1] | SrcBE[P.XLEN-1]) & ~IEUAdrRawE[P.XLEN-1];
    assign LtuE      = CmpFlags1E[0] ^ CsaCarryE[P.XLEN-1] ^ CarryOutE;
    assign LtE       = BranchSigned1E ? LtuE ^ IEUAdrRawE[P.XLEN-1] ^ FuseYE[P.XLEN-1] : LtuE;  // IEUAdrRawE: P + Q

    always_comb
      if      (FuseBrA1E & FuseBrB1E) Flags1E = 2'b10;                                  // beq t0, t0: equal
      else if (~FuseBrAdd1E)          Flags1E = CmpFlags1E;                             // not fused, or a logic op
      else if (FuseBrA1E)             Flags1E = {CmpFlags1E[1], LtE};                   // blt X, Y
      else                            Flags1E = {CmpFlags1E[1], ~LtE & ~CmpFlags1E[1]}; // blt Y, X
    // Slot 1 sits one instruction after slot 0, so its PC is PCLinkE (= PCE + 4, since the issue
    // rules require an uncompressed slot 0).  Using PCE here would make every paired auipc off by 4.
    mux2  #(P.XLEN)  srcamux1(ForwardedSrcA1E, PCLinkE, ALUSrcA1E, SrcA1E);
    mux2  #(P.XLEN)  srcbmux1(ForwardedSrcB1E, ImmExt1E, ALUSrcB1E, SrcB1E);
    alu   #(P)       alu1(SrcA1E, SrcB1E, W64_1E, UW64_1E, SubArith1E, ALUSelect1E, BSelect1E, ZBBSelect1E,
                          Funct3_1E, Funct7_1E, Rs2_1E, BALUControl1E, BMUActive1E, CZero1E, ALUResult1E, IEUAdr1E);
    // Slot 1's result when it is not the ALU's, as slot 0's altresultmux: lui writes its immediate, a jal
    // its link address.  Slot 1's link is one instruction past slot 1, so it is PCLink1E (ifu.sv), not
    // slot 0's PCLinkE.  The jal's target is its ALU sum, IEUAdr1E, which goes to the IFU.
    //   0x100 addi a0,a0,1 ; 0x104 jal ra,f     ra = 0x108   (0x106 if the jal is a c.jal)
    mux2  #(P.XLEN)  altresultmux1(ImmExt1E, PCLink1E, Jump1E, AltResult1E);
    mux2  #(P.XLEN)  ieuresultmux1(ALUResult1E, AltResult1E, ALUResultSrc1E, IEUResult1E);

    // Slot 1 Memory and Writeback.  Slot 0 needs a mux5 in Writeback to choose between the ALU, a load,
    // a CSR read, the multiply/divide unit and a store-conditional.  Slot 1 can only be an ALU operation,
    // a load or a multiply/divide, so it needs just three of those, selected by the same ResultSrc
    // encoding slot 0 uses.  A slot 1 MDU result is always the MDU's own: the FPU only ever divides, and
    // issue.sv admits slot 1 divides only in configurations whose divider is the MDU's.
    flopenrc #(P.XLEN) IEUResult1MReg(clk, reset, FlushM, ~StallM, IEUResult1E, IEUResult1M);
    flopenrc #(P.XLEN) IEUResult1WReg(clk, reset, FlushW, ~StallW, Result1M, IEUResult1W);
    always_comb
      case (ResultSrc1W)
        3'b001:  Result1W = ReadDataW;
        3'b011:  Result1W = MDUResultW;
        default: Result1W = IEUResult1W;
      endcase

    // The address handed to the load/store unit, selected from whichever slot holds the bundle's one
    // memory operation.  Each slot's ALU already computes its own sum, so this is only a choice of which
    // one the LSU listens to.
    //
    // It is deliberately a separate output from IEUAdrE rather than a mux on it.  A single instruction
    // is never both a control transfer and a memory access -- srcamux steers its one adder to PC+imm or
    // to rs1+imm -- which is why slot 0 can send one net to both the IFU and the LSU.  That stops being
    // true across slots: a taken branch in slot 0 needs its target at the IFU in the very cycle slot 1
    // needs its address at the LSU.  Keeping the nets apart lets both happen, and leaves the IFU's
    // redirect path exactly as it was.
    mux2  #(P.XLEN)  lsuadrmux(IEUAdrE, IEUAdr1E, Mem1E, LSUAdrE);
    // The multiplier's operands, from whichever slot holds the bundle's one MDU operation.  These are
    // the forwarded register values, as slot 0's ForwardedSrcAE/BE always were.  They are separate
    // outputs rather than a mux on ForwardedSrcAE/BE because the FPU reads those too, for slot 0.
    mux2  #(P.XLEN)  mdusrcamux(ForwardedSrcAE, ForwardedSrcA1E, Mdu1E, MDUSrcAE);
    mux2  #(P.XLEN)  mdusrcbmux(ForwardedSrcBE, ForwardedSrcB1E, Mdu1E, MDUSrcBE);
    // A store's data is rs2 after forwarding, so it comes from whichever slot's forwarding muxes hold
    // the memory operation.  The slot choice is made before the register, so Memory sees one value.
    mux2  #(P.XLEN)  writedatamux(ForwardedSrcBE, ForwardedSrcB1E, Mem1E, WriteDataE);
  end else begin : noslot1
    // Single issue: slot 1 never issues, so its results are constant and slot 0 owns the LSU and MDU.
    assign Flags1E     = '0;
    assign IEUAdr1E    = '0;
    assign SrcA1E      = '0;
    assign SrcB1E      = '0;
    assign IEUResult1M = '0;
    assign IEUResult1W = '0;
    assign Result1W    = '0;
    assign LSUAdrE     = IEUAdrE;
    assign MDUSrcAE    = ForwardedSrcAE;
    assign MDUSrcBE    = ForwardedSrcBE;
    assign WriteDataE  = ForwardedSrcBE;
  end

  // Slot 1 late ALU.  A slot 1 that reads slot 0's result is paired anyway and executes here, one stage
  // late, where slot 0's result is already sitting in IEUResultM.  Its Execute-stage ALU ran on a stale
  // operand and that result is discarded.  The operands are captured after srcamux1/srcbmux1, so an
  // immediate or the PC arrives as it would have in Execute, and the operand that depended on slot 0 is
  // replaced.  IEUResultM rather than IFResultM: issue.sv only makes a pair late when slot 0 is an
  // integer ALU operation, so the FPU's integer result never applies, and its mux would lengthen the path.
  //
  // An operand that the bundle ahead produced too late to forward in Execute (a load, say) arrives here
  // from Writeback instead: ResultW for that bundle's slot 0, Result1W for its slot 1.  ieu.sv chooses.
  //
  // The late ALU implements only the base operations, so its bit-manipulation and czero inputs are tied
  // off and synthesis removes that logic.  issue.sv keeps every other operation out of it.  Its output
  // goes nowhere but the Writeback register: nothing forwards from it, and ieu.sv's LateStall1D holds
  // back any consumer until the result reaches Result1W.
  //
  // For a late branch the same registers carry slot 0's branch operands instead -- its rs1 and rs2 after
  // forwarding, which is what the comparator in Execute would have used -- and the late ALU subtracts.
  //
  // A late slot 0 (ieu.sv) uses the late ALU too.  Its operands reach it in two steps, as slot 1's do:
  //   bundle A:  lw   a5, 0(a0)
  //   bundle B:  addi a4, a5, 3     <- slot 0 is late
  //   1. End of Execute (lateinamux): store what is available now.  Operand A is a5, still wrong -- the
  //      load is only in Memory -- and operand B is the immediate 3, which is right.
  //   2. Memory (latesrcamux, below): replace what came too late.  LateSelA1M = 10 swaps the wrong a5
  //      for ResultW, the loaded a5 now in Writeback; LateSelB1M = 00 keeps the 3.
  // Step 1 is needed because only the slow operand comes from Writeback; the other one (an immediate,
  // or a register that was ready in Execute) must be carried from Execute to Memory.
  //
  // Names: LateInA1E is late ALU operand A as chosen in Execute, SrcA1M the same value stored in
  // Memory, LateSrcA1M it after the swap.  The "2" dates from when only slot 1 used the late ALU.
  //
  // What step 1 stores depends on who uses the late ALU (at most one instruction per bundle):
  //   slot 1 (normal)   slot 1's ALU inputs              SrcA1E, SrcB1E        slot 1's operation
  //   late branch       slot 0's two register values     ForwardedSrcAE/BE     subtract (LateBrM)
  //   late slot 0       slot 0's ALU inputs              SrcAE, SrcBE          slot 0's operation
  // A late slot 0 takes SrcAE/SrcBE rather than ForwardedSrcAE/BE because its operand may be the PC or
  // an immediate, which SrcAE/SrcBE already include.  LateBrE and Late0RawE are never both set.

  if (P.LATE_ALU_SUPPORTED) begin : lateALU
    if (P.SUPERSCALAR_SUPPORTED) begin : lateinslot1
      mux3  #(P.XLEN)  lateinamux(SrcA1E, ForwardedSrcAE, SrcAE, {Late0RawE, LateBrE}, LateInA1E);
      mux3  #(P.XLEN)  lateinbmux(SrcB1E, ForwardedSrcBE, SrcBE, {Late0RawE, LateBrE}, LateInB1E);
    end else begin : lateinslot0                          // only slot 0 can be late
      mux2  #(P.XLEN)  lateinamux(ForwardedSrcAE, SrcAE, Late0RawE, LateInA1E);
      mux2  #(P.XLEN)  lateinbmux(ForwardedSrcBE, SrcBE, Late0RawE, LateInB1E);
    end
    // The operation travels with the operands: slot 0's for a late slot 0, otherwise slot 1's.
    if (P.SUPERSCALAR_SUPPORTED) begin : latectrlslot1
      mux2  #(8)       latectrlmux({ALUSelect1E, Funct3_1E, SubArith1E, W64_1E},          // slot 1's operation
                                   {ALUSelectE,  Funct3E,   SubArithE,  W64E},            // slot 0's operation
                                   Late0RawE, {LateALUSelectE, LateFunct3E, LateSubArithE, LateW64E});
    end else begin : latectrlslot0
      assign {LateALUSelectE, LateFunct3E, LateSubArithE, LateW64E} = {ALUSelectE, Funct3E, SubArithE, W64E};
    end
    flopenrc #(P.XLEN) SrcA1MReg(clk, reset, FlushM, ~StallM, LateInA1E, SrcA1M);
    flopenrc #(P.XLEN) SrcB1MReg(clk, reset, FlushM, ~StallM, LateInB1E, SrcB1M);
    flopenrc #(14)     LateCtrl1MReg(clk, reset, FlushM, ~StallM,
                                     {LateALUSelectE, LateFunct3E, LateSubArithE, LateW64E, LateSelA1E, LateSelB1E, LateBrE, Late0RawE},
                                     {ALUSelect1M, Funct3_1M, SubArith1M, W64_1M, LateSelA1M, LateSelB1M, LateBrM, Late0RawM});

    // Whose result the late ALU produced:
    //   Late0M  slot 0's: it was sent late and an operand really was replaced.  If nothing was replaced
    //           (a false match on an immediate field), slot 0's Execute result is right and is used.
    //   Late1M  slot 1's: only when neither a late branch nor a late slot 0 used the late ALU.
    assign Late0M = Late0RawM & (|LateSelA1M | |LateSelB1M);
    assign Late1M = ~LateBrM & ~Late0RawM & (|LateSelA1M | |LateSelB1M);
    if (P.SUPERSCALAR_SUPPORTED) begin : latesrcslot1
      mux4  #(P.XLEN)  latesrcamux(SrcA1M, IEUResultM, ResultW, Result1W, LateSelA1M, LateSrcA1M);
      mux4  #(P.XLEN)  latesrcbmux(SrcB1M, IEUResultM, ResultW, Result1W, LateSelB1M, LateSrcB1M);
    end else begin : latesrcslot0                         // no slot 1 result to take (select 11)
      mux3  #(P.XLEN)  latesrcamux(SrcA1M, IEUResultM, ResultW, LateSelA1M, LateSrcA1M);
      mux3  #(P.XLEN)  latesrcbmux(SrcB1M, IEUResultM, ResultW, LateSelB1M, LateSrcB1M);
    end
    alu   #(P)       latealu(.A(LateSrcA1M), .B(LateSrcB1M), .W64(W64_1M & ~LateBrM), .UW64(1'b0),
                             .SubArith(SubArith1M | LateBrM),
                             .ALUSelect(ALUSelect1M), .BSelect(4'b0), .ZBBSelect(4'b0), .Funct3(Funct3_1M),
                             .Funct7(7'b0), .Rs2E(5'b0), .BALUControl(3'b0), .BMUActive(1'b0), .CZero(2'b0),
                             .ALUResult(LateResult1M), .Sum(LateSum1M));

    // Branch flags from the late ALU's subtraction A - B.  When the signs agree the difference cannot
    // overflow, so its sign answers both comparisons; when they differ, the operand signs alone do --
    // the same reasoning as alu.sv's slt/sltu.  Equality is compared directly rather than by zero-testing
    // the difference, which would wait for the carry chain.
    assign LateSignA = LateSrcA1M[P.XLEN-1];
    assign LateSignB = LateSrcB1M[P.XLEN-1];
    assign LateNeg   = LateSum1M[P.XLEN-1];
    assign LateFlagsM = {(LateSrcA1M == LateSrcB1M),
                         (LateSignA & ~LateSignB) | (~(LateSignA ^ LateSignB) & LateNeg),    // lt
                         (~LateSignA & LateSignB) | (~(LateSignA ^ LateSignB) & LateNeg)};   // ltu
    if (P.SUPERSCALAR_SUPPORTED) begin : lateresult1
      mux2  #(P.XLEN)  lateresultmux(IEUResult1M, LateResult1M, Late1M, Result1M);
    end else begin : nolateresult1
      assign Result1M = IEUResult1M;
    end

    mux2  #(P.XLEN)  latewbmux(IFResultM, LateResult1M, Late0M, IFResultLateM);
  end else begin : nolateALU
    assign LateFlagsM    = '0;
    assign Result1M      = IEUResult1M;
    assign IFResultLateM = IFResultM;
  end

  // Memory stage pipeline register
  flopenrc #(P.XLEN) SrcAMReg(clk, reset, FlushM, ~StallM, SrcAE, SrcAM);
  flopenrc #(P.XLEN) IEUResultMReg(clk, reset, FlushM, ~StallM, IEUResultE, IEUResultM);
  flopenrc #(P.XLEN) WriteDataMReg(clk, reset, FlushM, ~StallM, WriteDataE, WriteDataM);

  // Writeback stage pipeline register and logic
  // Slot 0's Writeback register normally stores IFResultM, slot 0's Execute result.  For a late slot 0
  // (Late0M) that result is wrong, so it stores the late ALU's result instead; next cycle that is
  // ResultW, written to the register file and forwarded from Writeback.
  // The late result does not go into IFResultM itself: IFResultM forwards to the next bundle's Execute
  // ALU, and putting the late ALU in front of it would chain two ALUs in one cycle -- the critical path
  // the late ALU exists to avoid.  So a consumer in the next bundle goes late too (takes ResultW in
  // Memory) or stalls a cycle (LateStall0D in ieu.sv).
  flopenrc #(P.XLEN) IFResultWReg(clk, reset, FlushW, ~StallW, IFResultLateM, IFResultW);

  // floating point inputs: FIntResM comes from fclass, fcmp, fmv; FCvtIntResW comes from fcvt
  if (P.F_SUPPORTED) begin : fpmux
    mux2  #(P.XLEN)  resultmuxM(IEUResultM, FIntResM, FWriteIntM, IFResultM);
    mux2  #(P.XLEN)  cvtresultmuxW(IFResultW, FCvtIntResW, FCvtIntW, IFCvtResultW);
    if (P.IDIV_ON_FPU & P.F_SUPPORTED) begin
      mux2  #(P.XLEN)  divresultmuxW(MDUResultW, FIntDivResultW, IntDivW, MulDivResultW);
    end else begin
      assign MulDivResultW = MDUResultW;
    end
  end else begin : fpmux
    assign IFResultM = IEUResultM;
    assign IFCvtResultW = IFResultW;
    assign MulDivResultW = MDUResultW;
  end
  mux5  #(P.XLEN) resultmuxW(IFCvtResultW, ReadDataW, CSRReadValW, MulDivResultW, SCResultW, ResultSrcW, ResultW);

  // handle Store Conditional result if atomic extension supported
  if (P.ZALRSC_SUPPORTED) assign SCResultW = {{(P.XLEN-1){1'b0}}, SquashSCW};
  else                    assign SCResultW = '0;
endmodule
