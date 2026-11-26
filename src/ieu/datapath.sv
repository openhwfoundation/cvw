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
  input  logic [2:0]        Slot0ImmSrcD,                 // Selects type of immediate extension
  input  logic [31:0]       Slot0InstrD,                  // Instruction in Decode stage
  input  logic [4:0]        Slot0Rs1D, Slot0Rs2D, Slot0Rs2E,        // Source registers
  input  logic [2:0]        Slot1ImmSrcD,                // Slot 1 (superscalar): immediate format
  input  logic [31:0]       Slot1InstrD,                 // Slot 1: instruction in Decode stage
  input  logic [4:0]        Slot1Rs1D, Slot1Rs2D,          // Slot 1: source registers
  input  logic [4:0]        Slot1Rs2E,                  // Slot 1: source register 2 in Execute (ALU bit-manipulation)
  input  logic [2:0]        Slot1ForwardAE, Slot1ForwardBE,  // Slot 1: forwarding selects
  input  logic              Slot1ALUSrcAE, Slot1ALUSrcBE,    // Slot 1: ALU operands
  input  logic              Slot1ALUResultSrcE,          // Slot 1: selects ALU result or immediate
  input  logic [2:0]        Slot1ALUSelectE,             // Slot 1: ALU mux select
  input  logic [2:0]        Slot1Funct3E,               // Slot 1: funct3
  input  logic [6:0]        Slot1Funct7E,               // Slot 1: funct7
  input  logic              W64_1E, UW64_1E,         // Slot 1: RV64 W-type / .uw-type
  input  logic              Slot1SubArithE,              // Slot 1: subtract or arithmetic shift
  input  logic [3:0]        Slot1BSelectE, Slot1ZBBSelectE,  // Slot 1: bit-manipulation selects
  input  logic [2:0]        Slot1BALUControlE,           // Slot 1: bit-manipulation ALU control
  input  logic              Slot1BMUActiveE,             // Slot 1: bit-manipulation instruction active
  input  logic [1:0]        Slot1CZeroE,                 // Slot 1: czero.* active
  input  logic              Slot1BranchSignedE,          // Slot 1: branch comparison is signed
  input  logic              Slot1FuseBrAE, Slot1FuseBrBE,    // Slot 1's branch is fused with slot 0's ALU op: its rs1 / rs2 is slot 0's result
  input  logic              Slot1FuseBrAddE,             // ... and slot 0's op is an add (else a logic op)
  input  logic              Slot1JumpE,                  // Slot 1: jal, whose result is its link address
  input  logic [P.XLEN-1:0] Slot1PCLinkE,                // Slot 1: its link address, the PC just past it
  output logic [1:0]        Slot1FlagsE,                 // Slot 1: comparison flags ({eq, lt})
  output logic [P.XLEN-1:0] Slot1IEUAdrE,                // Slot 1: ALU sum, which is its branch or jal target
  input  logic              Slot1RegWriteW,              // Slot 1: commits a register write this cycle
  input  logic [4:0]        Slot1RdW,                    // Slot 1: destination register in Writeback
  input  logic              Slot1MemE,                   // Slot 1: holds the bundle's memory operation
  input  logic              Slot1FuseAdrE,               // ... whose address is slot 0's sum (fused add + load/store)
  input  logic              Slot1FuseStE,                // ... whose store data is slot 0's result (fused ALU op + store)
  input  logic [2:0]        Slot1ResultSrcW,             // Slot 1: selects source of its writeback value
  input  logic              Slot1MduE,                   // Slot 1: holds the bundle's multiply
  output logic [P.XLEN-1:0] MDUSrcAE, MDUSrcBE,      // Operands to the MDU, from whichever slot holds its operation
  input  logic [1:0]        Slot1LateSelAE, Slot1LateSelBE,  // Slot 1: late ALU operand source (00 own, 01 slot 0, 10 Slot0ResultW, 11 Slot1ResultW)
  input  logic              LateBrE,                 // The late ALU compares a branch's operands instead
  input  logic              LateBr1E,                // ... slot 1's branch rather than slot 0's
  input  logic              Slot0LateRawE,               // ... or computes slot 0's ALU operation instead (ieu.sv)
  output logic [2:0]        LateFlagsM,              // ... giving {eq, lt, ltu}
  // Execute stage signals
  input  logic [P.XLEN-1:0] PCE,                     // PC in Execute stage
  input  logic [P.XLEN-1:0] Slot0PCLinkE,                 // PC + 4 (of instruction in Execute stage)
  input  logic [2:0]        Funct3E,                 // Funct3 field of instruction in Execute stage
  input  logic [6:0]        Funct7E,                 // Funct7 field of instruction in Execute stage
  input  logic              StallE, FlushE,          // Stall, flush Execute stage
  input  logic [2:0]        Slot0ForwardAE, Slot0ForwardBE,    // Forward ALU operands from later stages
  input  logic              W64E, UW64E,             // W64/.uw-type instruction
  input  logic              Slot0SubArithE,               // Subtraction or arithmetic shift
  input  logic              Slot0ALUSrcAE, Slot0ALUSrcBE,      // ALU operands
  input  logic              Slot0ALUResultSrcE,           // Selects result to pass on to Memory stage
  input  logic [2:0]        Slot0ALUSelectE,              // ALU mux select signal
  input  logic              Slot0JumpE,                   // Jump (jal or jalr) instruction
  input  logic              Slot0BranchSignedE,           // Branch comparison operands are signed (if it's a branch)
  input  logic [3:0]        Slot0BSelectE,                // BMU result select (binary encoded; see bitmanipalu)
  input  logic [3:0]        Slot0ZBBSelectE,              // ZBB mux select signal
  input  logic [2:0]        Slot0BALUControlE,            // ALU Control signals for B instructions in Execute Stage
  input  logic              Slot0BMUActiveE,              // Bit manipulation instruction being executed
  input  logic [1:0]        Slot0CZeroE,                  // {czero.nez, czero.eqz} instructions active
  output logic [1:0]        Slot0FlagsE,                  // Comparison flags ({eq, lt})
  output logic [P.XLEN-1:0] Slot0IEUAdrE,                 // Address computed by ALU: slot 0's branch/jump target
  output logic [P.XLEN-1:0] LSUAdrE,                 // Address computed by ALU: memory address, from either slot
  output logic [P.XLEN-1:0] Slot0ForwardedSrcAE, Slot0ForwardedSrcBE, // ALU sources before the mux chooses between them and PCE to put in srcA/B
  // Memory stage signals
  input  logic              StallM, FlushM,          // Stall, flush Memory stage
  input  logic              FWriteIntM, FCvtIntW,    // FPU writes integer register file, FPU converts float to int
  input  logic [P.XLEN-1:0] FIntResM,                // FPU integer result
  output logic [P.XLEN-1:0] Slot0SrcAM,                   // ALU's Source A in Memory stage to privilege unit for CSR writes
  output logic [P.XLEN-1:0] WriteDataM,              // Write data in Memory stage
  input  logic [1:0]        StDataLateM,             // Store data produced too late: 10 take Slot0ResultW, 11 Slot1ResultW
  // Writeback stage signals
  input  logic              StallW, FlushW,          // Stall, flush Writeback stage
  input  logic              Slot0RegWriteW, IntDivW,      // Write register file, integer divide instruction
  input  logic              SquashSCW,               // Squash a store conditional when a conflict arose
  input  logic [2:0]        ResultSrcW,              // Select source of result to write back to register file
  input  logic [P.XLEN-1:0] FCvtIntResW,             // FPU convert fp to integer result
  input  logic [P.XLEN-1:0] ReadDataW,               // Read data from LSU
  input  logic [P.XLEN-1:0] CSRReadValW,             // CSR read result
  input  logic [P.XLEN-1:0] MDUResultW,              // MDU (Multiply/divide unit) result
  input  logic [P.XLEN-1:0] FIntDivResultW,          // FPU's integer divide result
  input  logic [4:0]        Slot0RdW                      // Destination register
);

  // Decode stage signals
  logic [P.XLEN-1:0] Slot0R1D, R2D;                       // Read data from Rs1 (RD1), Rs2 (RD2)
  logic [P.XLEN-1:0] Slot0ImmExtD;                        // Extended immediate in Decode stage
  logic [P.XLEN-1:0] Slot1R1D, Slot1R2D;                   // Slot 1: read data from Slot1Rs1D, Slot1Rs2D
  logic [P.XLEN-1:0] Slot1ImmExtD;                       // Slot 1: extended immediate in Decode stage
  logic [P.XLEN-1:0] Slot1R1E, Slot1R2E, Slot1ImmExtE;         // Slot 1: the same, in Execute
  logic [P.XLEN-1:0] Slot1ForwardedSrcAE, Slot1ForwardedSrcBE; // Slot 1: operands after forwarding
  logic [P.XLEN-1:0] Slot1SrcAE, Slot1SrcBE;                 // Slot 1: ALU inputs
  logic [P.XLEN-1:0] Slot1ALUResultE;                    // Slot 1: ALU output.  The sum, Slot1IEUAdrE, needs no bit-0
                                                     //   mask as slot 0's does: that is for jalr, and slot 1
                                                     //   only ever jumps with jal, whose target is even.
  logic [P.XLEN-1:0] Slot1AltResultE, Slot1IEUResultE;       // Slot 1: result in Execute
  logic [P.XLEN-1:0] Slot1IEUResultM;                    // Slot 1: result in Memory
  logic [P.XLEN-1:0] Slot1IEUResultW;                    // Slot 1: result in Writeback
  logic [P.XLEN-1:0] Slot1ResultW;                       // Slot 1: value written back
  logic [P.XLEN-1:0] Slot1SrcAM, Slot1SrcBM;                 // Slot 1: ALU inputs, carried to the late ALU
  logic [P.XLEN-1:0] LateSrcAM, LateSrcBM;         // Slot 1: late ALU inputs, with slot 0's result substituted
  logic [P.XLEN-1:0] Slot1LateResultM;                   // Slot 1: late ALU result
  logic [P.XLEN-1:0] Slot1ResultM;                       // Slot 1: result entering Writeback
  logic [2:0]        Slot1ALUSelectM, Slot1Funct3M;         // Slot 1: late ALU control
  logic              Slot1SubArithM, W64_1M;
  logic [1:0]        Slot1LateSelAM, Slot1LateSelBM;         // Slot 1: where the late ALU takes each operand from
  logic              Slot1LateM;                         // Slot 1 executes on the late ALU
  logic              LateBrM;                        // The late ALU compares slot 0's branch instead
  logic              Slot0LateRawM, Slot0LateM;              // The late ALU was given slot 0's ALU operation / and computes it
  logic [2:0]        LateALUSelectE, LateFunct3E;    // Late ALU control, from whichever slot uses it
  logic              LateSubArithE, LateW64E;
  logic [P.XLEN-1:0] IFResultLateM;                  // Slot 0's result entering Writeback, the late ALU's if slot 0 was late
  logic [P.XLEN-1:0] Slot1LateInAE, Slot1LateInBE;           // What the late ALU's operand registers capture
  logic [P.XLEN-1:0] Slot1LateSumM;                      // The late ALU's adder output
  logic              LateSignA, LateSignB, LateNeg;  // ... and the signs the branch flags are formed from
  // Execute stage signals
  logic [P.XLEN-1:0] Slot0R1E, R2E;                       // Source operands read from register file
  logic [P.XLEN-1:0] Slot0ImmExtE;                        // Extended immediate in Execute stage
  logic [P.XLEN-1:0] Slot0SrcAE, Slot0SrcBE;                   // ALU operands
  logic [P.XLEN-1:0] Slot0ALUResultE, Slot0AltResultE, Slot0IEUResultE; // ALU result, Alternative result (Slot0ImmExtE or PC+4), result of execution stage
  logic [P.XLEN-1:0] IEUAdrRawE;                     // ALU sum before clearing bit 0 of a jump target
  logic [P.XLEN-1:0] WriteDataE;                     // Store data of whichever slot holds the memory operation
  logic [P.XLEN-1:0] WriteDataRawM;                  // ... as forwarded in Execute
  // Memory stage signals
  logic [P.XLEN-1:0] Slot0IEUResultM;                     // Result from execution stage
  logic [P.XLEN-1:0] IFResultM;                      // Result from either IEU or single-cycle FPU op writing an integer register
  // Writeback stage signals
  logic [P.XLEN-1:0] SCResultW;                      // Store Conditional result
  logic [P.XLEN-1:0] Slot0ResultW;                        // Result to write to register file
  logic [P.XLEN-1:0] IFResultW;                      // Result from either IEU or single-cycle FPU op writing an integer register
  logic [P.XLEN-1:0] IFCvtResultW;                   // Result from IEU, single-cycle FPU op, or 2-cycle FCVT float to int
  logic [P.XLEN-1:0] MulDivResultW;                  // Multiply always comes from MDU.  Divide could come from MDU or FPU (when using fdivsqrt for integer division)

  // Decode stage
  regfile #(P.XLEN, P.E_SUPPORTED, P.LATCH_BASED_REGISTERFILE, P.SUPERSCALAR_SUPPORTED) regf(clk, reset, Slot0RegWriteW, Slot1RegWriteW, Slot0Rs1D, Slot0Rs2D, Slot0RdW,
    Slot1Rs1D, Slot1Rs2D, Slot1RdW, Slot0ResultW, Slot1ResultW, Slot0R1D, R2D, Slot1R1D, Slot1R2D);
  extend #(P)        ext(.InstrD(Slot0InstrD[31:7]), .ImmSrcD(Slot0ImmSrcD), .ImmExtD(Slot0ImmExtD));

  // Execute stage pipeline register and logic
  //
  // Operand capture.  The Execute stage can be held while Memory and Writeback keep moving: a divide
  // holds it for its whole iteration (DivBusyE, FDivBusyE) while older instructions drain and bubbles
  // follow them.  An operand that was being forwarded from Memory or Writeback when the stall began
  // then loses its source as the producer retires, and Slot0R1E/R2E still hold the register file value read
  // in Decode, before the producer wrote it.  Single-issue Wally never meets this, because the only
  // instruction in Execute during such a stall is the divide itself, which latches its operands when
  // it starts.  With two slots the other instruction of the bundle sits there too, so the registers
  // reload the forwarded operand every cycle of the stall, and hold the right value once forwarding
  // stops.  The two cases cannot overlap with a flush: StallE without StallM means StallECause, which
  // is already gated by ~FlushECause, so FlushE is low whenever CaptureE is high.
  logic              CaptureE;                       // Execute held while Memory advances: keep forwarded operands
  logic [P.XLEN-1:0] Slot0R1ENext, R2ENext, Slot1R1ENext, Slot1R2ENext;
  assign CaptureE = P.SUPERSCALAR_SUPPORTED & StallE & ~StallM;
  if (P.SUPERSCALAR_SUPPORTED) begin : capture
    mux2  #(P.XLEN)  r1enextmux(Slot0R1D, Slot0ForwardedSrcAE, CaptureE, Slot0R1ENext);
    mux2  #(P.XLEN)  r2enextmux(R2D, Slot0ForwardedSrcBE, CaptureE, R2ENext);
  end else begin : nocapture
    assign Slot0R1ENext = Slot0R1D;
    assign R2ENext = R2D;
  end
  flopenrc #(P.XLEN) R1EReg(clk, reset, FlushE, ~StallE | CaptureE, Slot0R1ENext, Slot0R1E);
  flopenrc #(P.XLEN) R2EReg(clk, reset, FlushE, ~StallE | CaptureE, R2ENext, R2E);
  flopenrc #(P.XLEN) ImmExtEReg(clk, reset, FlushE, ~StallE, Slot0ImmExtD, Slot0ImmExtE);

  // Forwarding sources in the order each slot's select encodes them: no forward, own Writeback,
  // own Memory, other Writeback, other Memory.  The encoding is relative to the slot, so slot 1's
  // muxes below take the same four sources with the pairs swapped.  See controller.sv for priority.
  // Without superscalar only the first three sources exist, as in single-issue Wally.
  if (P.SUPERSCALAR_SUPPORTED) begin : fwd5
    mux5  #(P.XLEN)  faemux(Slot0R1E, Slot0ResultW, IFResultM, Slot1ResultW, Slot1IEUResultM, Slot0ForwardAE, Slot0ForwardedSrcAE);
    mux5  #(P.XLEN)  fbemux(R2E, Slot0ResultW, IFResultM, Slot1ResultW, Slot1IEUResultM, Slot0ForwardBE, Slot0ForwardedSrcBE);
  end else begin : fwd3
    mux3  #(P.XLEN)  faemux(Slot0R1E, Slot0ResultW, IFResultM, Slot0ForwardAE[1:0], Slot0ForwardedSrcAE);
    mux3  #(P.XLEN)  fbemux(R2E, Slot0ResultW, IFResultM, Slot0ForwardBE[1:0], Slot0ForwardedSrcBE);
  end
  comparator #(P.XLEN) comp(Slot0ForwardedSrcAE, Slot0ForwardedSrcBE, Slot0BranchSignedE, Slot0FlagsE);
  mux2  #(P.XLEN)  srcamux(Slot0ForwardedSrcAE, PCE, Slot0ALUSrcAE, Slot0SrcAE);
  mux2  #(P.XLEN)  srcbmux(Slot0ForwardedSrcBE, Slot0ImmExtE, Slot0ALUSrcBE, Slot0SrcBE);
  alu   #(P)       alu(Slot0SrcAE, Slot0SrcBE, W64E, UW64E, Slot0SubArithE, Slot0ALUSelectE, Slot0BSelectE, Slot0ZBBSelectE, Funct3E, Funct7E, Slot0Rs2E, Slot0BALUControlE, Slot0BMUActiveE, Slot0CZeroE, Slot0ALUResultE, IEUAdrRawE);
  // jalr sets the least significant bit of the target address to zero.  jal and branch targets are
  // always even, so masking on Slot0JumpE alone is sufficient and leaves load/store addresses untouched.
  assign Slot0IEUAdrE = {IEUAdrRawE[P.XLEN-1:1], IEUAdrRawE[0] & ~Slot0JumpE};
  mux2  #(P.XLEN)  altresultmux(Slot0ImmExtE, Slot0PCLinkE, Slot0JumpE, Slot0AltResultE);
  mux2  #(P.XLEN)  ieuresultmux(Slot0ALUResultE, Slot0AltResultE, Slot0ALUResultSrcE, Slot0IEUResultE);

  if (P.SUPERSCALAR_SUPPORTED) begin : slot1
    extend #(P)        ext1(.InstrD(Slot1InstrD[31:7]), .ImmSrcD(Slot1ImmSrcD), .ImmExtD(Slot1ImmExtD));   // slot 1

    // Slot 1 (superscalar) Execute stage, mirroring slot 0 above.  A conditional branch in slot 1
    // compares with its own comparator, and its target is its ALU's sum of slot 1's PC and immediate.
    mux2  #(P.XLEN)  slot1R1ENextMux(Slot1R1D, Slot1ForwardedSrcAE, CaptureE, Slot1R1ENext);   // operand capture, as for slot 0
    mux2  #(P.XLEN)  slot1R2ENextMux(Slot1R2D, Slot1ForwardedSrcBE, CaptureE, Slot1R2ENext);
    flopenrc #(P.XLEN) Slot1R1EReg(clk, reset, FlushE, ~StallE | CaptureE, Slot1R1ENext, Slot1R1E);
    flopenrc #(P.XLEN) Slot1R2EReg(clk, reset, FlushE, ~StallE | CaptureE, Slot1R2ENext, Slot1R2E);
    flopenrc #(P.XLEN) Slot1ImmExtEReg(clk, reset, FlushE, ~StallE, Slot1ImmExtD, Slot1ImmExtE);

    mux5  #(P.XLEN)  faemux1(Slot1R1E, Slot1ResultW, Slot1IEUResultM, Slot0ResultW, IFResultM, Slot1ForwardAE, Slot1ForwardedSrcAE);
    mux5  #(P.XLEN)  fbemux1(Slot1R2E, Slot1ResultW, Slot1IEUResultM, Slot0ResultW, IFResultM, Slot1ForwardBE, Slot1ForwardedSrcBE);
    // Macro-op fusion: ALU op + dependent branch (issue.sv).  The pair is one compare-and-branch op, decided
    // in Execute.  The branch must not wait for slot 0's ALU result: that would put two carry chains in a
    // row (slot 0's add, then comp1's compare) on the clock's critical path.  So comp1 works from slot 0's
    // ALU inputs (Slot0SrcAE, Slot0SrcBE) instead.  No new adder: slot 0's ALU still makes rd, comp1 does the compare,
    // and slot 1's ALU still makes the target.
    //
    // comp1 compares slot 0's ALU operands, not its result, so it runs alongside slot 0's ALU.  A logic
    // op is re-run here, one gate deep.  An add is compared in carry-save form, so comp1 still has one
    // carry chain.  Example: add t0, a1, a2 ; blt t0, a3, L compares a1 + a2 with a3.
    logic [P.XLEN-1:0] Slot0LogicE;                        // Slot 0's logic result, remade from its ALU inputs
    logic [P.XLEN-1:0] FuseYE, NotYE;                  // Y: the branch operand that is not slot 0's result, and ~Y
    logic [P.XLEN-1:0] CsaSumE, CsaCarryE;             // P + Q + ~Y as two numbers: Sum + (Carry << 1)
    logic [P.XLEN-1:0] Slot1CmpAE, Slot1CmpBE;                 // Slot 1's comparator inputs
    logic [1:0]        Slot1CmpFlagsE;                     // comp1's {eq, lt}
    logic              CarryOutE;                      // Carry out of slot 0's P + Q
    logic              LtuE, LtE;                      // Fused add: X < Y unsigned, X < Y as the branch asks

    always_comb
      case (Slot0ALUSelectE[1:0])                           // slot 0's ALUSelect: 100 xor, 110 or, 111 and
        2'b00:   Slot0LogicE = Slot0SrcAE ^ Slot0SrcBE;
        2'b10:   Slot0LogicE = Slot0SrcAE | Slot0SrcBE;
        default: Slot0LogicE = Slot0SrcAE & Slot0SrcBE;
      endcase

    mux2  #(P.XLEN)  fuseymux(Slot1ForwardedSrcAE, Slot1ForwardedSrcBE, Slot1FuseBrAE, FuseYE);  // slot 0's is rs1: Y is rs2
    assign NotYE     = ~FuseYE;
    assign CsaSumE   = Slot0SrcAE ^ Slot0SrcBE ^ NotYE;                                       // full adder sum, per bit
    assign CsaCarryE = (Slot0SrcAE & Slot0SrcBE) | (Slot0SrcAE & NotYE) | (Slot0SrcBE & NotYE);         // full adder carry, per bit

    // select: 00 slot 1's own register, 01 logic result, 1x carry-save (an add replaces both inputs)
    mux3  #(P.XLEN)  cmp1amux(Slot1ForwardedSrcAE, Slot0LogicE, CsaSumE, {Slot1FuseBrAddE, Slot1FuseBrAE}, Slot1CmpAE);
    mux3  #(P.XLEN)  cmp1bmux(Slot1ForwardedSrcBE, Slot0LogicE, ~{CsaCarryE[P.XLEN-2:0], 1'b0}, {Slot1FuseBrAddE, Slot1FuseBrBE}, Slot1CmpBE);
    comparator #(P.XLEN) comp1(Slot1CmpAE, Slot1CmpBE, Slot1BranchSignedE & ~Slot1FuseBrAddE, Slot1CmpFlagsE);  // an add compares unsigned

    assign CarryOutE = Slot0SrcAE[P.XLEN-1] & Slot0SrcBE[P.XLEN-1] | (Slot0SrcAE[P.XLEN-1] | Slot0SrcBE[P.XLEN-1]) & ~IEUAdrRawE[P.XLEN-1];
    assign LtuE      = Slot1CmpFlagsE[0] ^ CsaCarryE[P.XLEN-1] ^ CarryOutE;
    assign LtE       = Slot1BranchSignedE ? LtuE ^ IEUAdrRawE[P.XLEN-1] ^ FuseYE[P.XLEN-1] : LtuE;  // IEUAdrRawE: P + Q

    always_comb
      if      (Slot1FuseBrAE & Slot1FuseBrBE) Slot1FlagsE = 2'b10;                                  // beq t0, t0: equal
      else if (~Slot1FuseBrAddE)          Slot1FlagsE = Slot1CmpFlagsE;                             // not fused, or a logic op
      else if (Slot1FuseBrAE)             Slot1FlagsE = {Slot1CmpFlagsE[1], LtE};                   // blt X, Y
      else                            Slot1FlagsE = {Slot1CmpFlagsE[1], ~LtE & ~Slot1CmpFlagsE[1]}; // blt Y, X
    // Slot 1 sits one instruction after slot 0, so its PC is Slot0PCLinkE (= PCE + 4, since the issue
    // rules require an uncompressed slot 0).  Using PCE here would make every paired auipc off by 4.
    mux2  #(P.XLEN)  srcamux1(Slot1ForwardedSrcAE, Slot0PCLinkE, Slot1ALUSrcAE, Slot1SrcAE);
    mux2  #(P.XLEN)  srcbmux1(Slot1ForwardedSrcBE, Slot1ImmExtE, Slot1ALUSrcBE, Slot1SrcBE);
    alu   #(P)       alu1(Slot1SrcAE, Slot1SrcBE, W64_1E, UW64_1E, Slot1SubArithE, Slot1ALUSelectE, Slot1BSelectE, Slot1ZBBSelectE,
                          Slot1Funct3E, Slot1Funct7E, Slot1Rs2E, Slot1BALUControlE, Slot1BMUActiveE, Slot1CZeroE, Slot1ALUResultE, Slot1IEUAdrE);
    // Slot 1's result when it is not the ALU's, as slot 0's altresultmux: lui writes its immediate, a jal
    // its link address.  Slot 1's link is one instruction past slot 1, so it is Slot1PCLinkE (ifu.sv), not
    // slot 0's Slot0PCLinkE.  The jal's target is its ALU sum, Slot1IEUAdrE, which goes to the IFU.
    //   0x100 addi a0,a0,1 ; 0x104 jal ra,f     ra = 0x108   (0x106 if the jal is a c.jal)
    mux2  #(P.XLEN)  altresultmux1(Slot1ImmExtE, Slot1PCLinkE, Slot1JumpE, Slot1AltResultE);
    mux2  #(P.XLEN)  ieuresultmux1(Slot1ALUResultE, Slot1AltResultE, Slot1ALUResultSrcE, Slot1IEUResultE);

    // Slot 1 Memory and Writeback.  Slot 0 needs a mux5 in Writeback to choose between the ALU, a load,
    // a CSR read, the multiply/divide unit and a store-conditional.  Slot 1 can only be an ALU operation,
    // a load or a multiply/divide, so it needs just three of those, selected by the same ResultSrc
    // encoding slot 0 uses.  A slot 1 MDU result is always the MDU's own: the FPU only ever divides, and
    // issue.sv admits slot 1 divides only in configurations whose divider is the MDU's.
    flopenrc #(P.XLEN) Slot1IEUResultMReg(clk, reset, FlushM, ~StallM, Slot1IEUResultE, Slot1IEUResultM);
    flopenrc #(P.XLEN) Slot1IEUResultWReg(clk, reset, FlushW, ~StallW, Slot1ResultM, Slot1IEUResultW);
    always_comb
      case (Slot1ResultSrcW)
        3'b001:  Slot1ResultW = ReadDataW;
        3'b011:  Slot1ResultW = MDUResultW;
        default: Slot1ResultW = Slot1IEUResultW;
      endcase

    // The address handed to the load/store unit, selected from whichever slot holds the bundle's one
    // memory operation.  Each slot's ALU already computes its own sum, so this is only a choice of which
    // one the LSU listens to.
    //
    // It is deliberately a separate output from Slot0IEUAdrE rather than a mux on it.  A single instruction
    // is never both a control transfer and a memory access -- srcamux steers its one adder to PC+imm or
    // to rs1+imm -- which is why slot 0 can send one net to both the IFU and the LSU.  That stops being
    // true across slots: a taken branch in slot 0 needs its target at the IFU in the very cycle slot 1
    // needs its address at the LSU.  Keeping the nets apart lets both happen, and leaves the IFU's
    // redirect path exactly as it was.
    // A fused add + load/store (issue.sv) takes slot 0's sum: the add's result is the access's address.
    mux2  #(P.XLEN)  lsuadrmux(Slot0IEUAdrE, Slot1IEUAdrE, Slot1MemE & ~Slot1FuseAdrE, LSUAdrE);
    // The multiplier's operands, from whichever slot holds the bundle's one MDU operation.  These are
    // the forwarded register values, as slot 0's Slot0ForwardedSrcAE/BE always were.  They are separate
    // outputs rather than a mux on Slot0ForwardedSrcAE/BE because the FPU reads those too, for slot 0.
    mux2  #(P.XLEN)  mdusrcamux(Slot0ForwardedSrcAE, Slot1ForwardedSrcAE, Slot1MduE, MDUSrcAE);
    mux2  #(P.XLEN)  mdusrcbmux(Slot0ForwardedSrcBE, Slot1ForwardedSrcBE, Slot1MduE, MDUSrcBE);
    // A store's data is rs2 after forwarding, so it comes from whichever slot's forwarding muxes hold
    // the memory operation.  The slot choice is made before the register, so Memory sees one value.
    // A fused ALU op + store (issue.sv) stores slot 0's result.
    mux3  #(P.XLEN)  writedatamux(Slot0ForwardedSrcBE, Slot1ForwardedSrcBE, Slot0IEUResultE, {Slot1FuseStE, Slot1MemE}, WriteDataE);
  end else begin : noslot1
    // Single issue: slot 1 never issues, so its results are constant and slot 0 owns the LSU and MDU.
    assign Slot1FlagsE     = '0;
    assign Slot1IEUAdrE    = '0;
    assign Slot1SrcAE      = '0;
    assign Slot1SrcBE      = '0;
    assign Slot1IEUResultM = '0;
    assign Slot1IEUResultW = '0;
    assign Slot1ResultW    = '0;
    assign LSUAdrE     = Slot0IEUAdrE;
    assign MDUSrcAE    = Slot0ForwardedSrcAE;
    assign MDUSrcBE    = Slot0ForwardedSrcBE;
    assign WriteDataE  = Slot0ForwardedSrcBE;
  end

  // Late ALU: when an operand is produced too late to forward in Execute, its consumer is recomputed one
  // stage later, in Memory.  The one late ALU serves one instruction per bundle: a slot 1, a late branch,
  // or a late slot 0 (table below).
  //
  // Slot 1 late ALU.  A slot 1 that reads slot 0's result is paired anyway and executes here, one stage
  // late, where slot 0's result is already sitting in Slot0IEUResultM.  Its Execute-stage ALU ran on a stale
  // operand and that result is discarded.  The operands are captured after srcamux1/srcbmux1, so an
  // immediate or the PC arrives as it would have in Execute, and the operand that depended on slot 0 is
  // replaced.  Slot0IEUResultM rather than IFResultM: issue.sv only makes a pair late when slot 0 is an
  // integer ALU operation, so the FPU's integer result never applies, and its mux would lengthen the path.
  //
  // An operand that the bundle ahead produced too late to forward in Execute (a load, say) arrives here
  // from Writeback instead: Slot0ResultW for that bundle's slot 0, Slot1ResultW for its slot 1.  ieu.sv chooses.
  //
  // The late ALU implements only the base operations, so its bit-manipulation and czero inputs are tied
  // off and synthesis removes that logic.  issue.sv keeps every other operation out of it.  Its output
  // goes nowhere but the Writeback register: nothing forwards from it, and ieu.sv's Slot1LateStallD holds
  // back any consumer until the result reaches Slot1ResultW.
  //
  // For a late branch the same registers carry slot 0's branch operands instead -- its rs1 and rs2 after
  // forwarding, which is what the comparator in Execute would have used -- and the late ALU subtracts.
  //
  // A late slot 0 (ieu.sv) uses the late ALU too.  Its operands reach it in two steps, as slot 1's do:
  //   bundle A:  lw   a5, 0(a0)
  //   bundle B:  addi a4, a5, 3     <- slot 0 is late
  //   1. End of Execute (lateinamux): store what is available now.  Operand A is a5, still wrong -- the
  //      load is only in Memory -- and operand B is the immediate 3, which is right.
  //   2. Memory (latesrcamux, below): replace what came too late.  Slot1LateSelAM = 10 swaps the wrong a5
  //      for Slot0ResultW, the loaded a5 now in Writeback; Slot1LateSelBM = 00 keeps the 3.
  // Step 1 is needed because only the slow operand comes from Writeback; the other one (an immediate,
  // or a register that was ready in Execute) must be carried from Execute to Memory.
  //
  // Names: Slot1LateInAE is late ALU operand A as chosen in Execute, Slot1SrcAM the same value stored in
  // Memory, LateSrcAM it after the swap.  The "2" dates from when only slot 1 used the late ALU.
  //
  // What step 1 stores depends on who uses the late ALU (at most one instruction per bundle):
  //   slot 1 (normal)   slot 1's ALU inputs              Slot1SrcAE, Slot1SrcBE        slot 1's operation
  //   late branch       slot 0's two register values     Slot0ForwardedSrcAE/BE     subtract (LateBrM)
  //   late slot 0       slot 0's ALU inputs              Slot0SrcAE, Slot0SrcBE          slot 0's operation
  // A late slot 0 takes Slot0SrcAE/Slot0SrcBE rather than Slot0ForwardedSrcAE/BE because its operand may be the PC or
  // an immediate, which Slot0SrcAE/Slot0SrcBE already include.  LateBrE and Slot0LateRawE are never both set.

  if (P.LATE_ALU_SUPPORTED) begin : lateALU
    if (P.SUPERSCALAR_SUPPORTED) begin : lateinslot1
      // 00 slot 1's ALU inputs, 01 slot 0's branch operands, 10 slot 0's ALU inputs, 11 slot 1's branch operands
      mux4  #(P.XLEN)  lateinamux(Slot1SrcAE, Slot0ForwardedSrcAE, Slot0SrcAE, Slot1ForwardedSrcAE, {Slot0LateRawE | LateBr1E, LateBrE}, Slot1LateInAE);
      mux4  #(P.XLEN)  lateinbmux(Slot1SrcBE, Slot0ForwardedSrcBE, Slot0SrcBE, Slot1ForwardedSrcBE, {Slot0LateRawE | LateBr1E, LateBrE}, Slot1LateInBE);
    end else begin : lateinslot0                          // only slot 0 can be late
      mux2  #(P.XLEN)  lateinamux(Slot0ForwardedSrcAE, Slot0SrcAE, Slot0LateRawE, Slot1LateInAE);
      mux2  #(P.XLEN)  lateinbmux(Slot0ForwardedSrcBE, Slot0SrcBE, Slot0LateRawE, Slot1LateInBE);
    end
    // The operation travels with the operands: slot 0's for a late slot 0, otherwise slot 1's.
    if (P.SUPERSCALAR_SUPPORTED) begin : latectrlslot1
      mux2  #(8)       latectrlmux({Slot1ALUSelectE, Slot1Funct3E, Slot1SubArithE, W64_1E},          // slot 1's operation
                                   {Slot0ALUSelectE,  Funct3E,   Slot0SubArithE,  W64E},            // slot 0's operation
                                   Slot0LateRawE, {LateALUSelectE, LateFunct3E, LateSubArithE, LateW64E});
    end else begin : latectrlslot0
      assign {LateALUSelectE, LateFunct3E, LateSubArithE, LateW64E} = {Slot0ALUSelectE, Funct3E, Slot0SubArithE, W64E};
    end
    flopenrc #(P.XLEN) Slot1SrcAMReg(clk, reset, FlushM, ~StallM, Slot1LateInAE, Slot1SrcAM);
    flopenrc #(P.XLEN) Slot1SrcBMReg(clk, reset, FlushM, ~StallM, Slot1LateInBE, Slot1SrcBM);
    flopenrc #(14)     Slot1LateCtrlMReg(clk, reset, FlushM, ~StallM,
                                     {LateALUSelectE, LateFunct3E, LateSubArithE, LateW64E, Slot1LateSelAE, Slot1LateSelBE, LateBrE, Slot0LateRawE},
                                     {Slot1ALUSelectM, Slot1Funct3M, Slot1SubArithM, W64_1M, Slot1LateSelAM, Slot1LateSelBM, LateBrM, Slot0LateRawM});

    // Whose result the late ALU produced:
    //   Slot0LateM  slot 0's: it was sent late and an operand really was replaced.  If nothing was replaced
    //           (a false match on an immediate field), slot 0's Execute result is right and is used.
    //   Slot1LateM  slot 1's: only when neither a late branch nor a late slot 0 used the late ALU.
    assign Slot0LateM = Slot0LateRawM & (|Slot1LateSelAM | |Slot1LateSelBM);
    assign Slot1LateM = ~LateBrM & ~Slot0LateRawM & (|Slot1LateSelAM | |Slot1LateSelBM);
    if (P.SUPERSCALAR_SUPPORTED) begin : latesrcslot1
      mux4  #(P.XLEN)  latesrcamux(Slot1SrcAM, Slot0IEUResultM, Slot0ResultW, Slot1ResultW, Slot1LateSelAM, LateSrcAM);
      mux4  #(P.XLEN)  latesrcbmux(Slot1SrcBM, Slot0IEUResultM, Slot0ResultW, Slot1ResultW, Slot1LateSelBM, LateSrcBM);
    end else begin : latesrcslot0                         // no slot 1 result to take (select 11)
      mux3  #(P.XLEN)  latesrcamux(Slot1SrcAM, Slot0IEUResultM, Slot0ResultW, Slot1LateSelAM, LateSrcAM);
      mux3  #(P.XLEN)  latesrcbmux(Slot1SrcBM, Slot0IEUResultM, Slot0ResultW, Slot1LateSelBM, LateSrcBM);
    end
    alu   #(P)       latealu(.A(LateSrcAM), .B(LateSrcBM), .W64(W64_1M & ~LateBrM), .UW64(1'b0),
                             .SubArith(Slot1SubArithM | LateBrM),
                             .ALUSelect(Slot1ALUSelectM), .BSelect(4'b0), .ZBBSelect(4'b0), .Funct3(Slot1Funct3M),
                             .Funct7(7'b0), .Rs2E(5'b0), .BALUControl(3'b0), .BMUActive(1'b0), .CZero(2'b0),
                             .ALUResult(Slot1LateResultM), .Sum(Slot1LateSumM));

    // Branch flags from the late ALU's subtraction A - B.  When the signs agree the difference cannot
    // overflow, so its sign answers both comparisons; when they differ, the operand signs alone do --
    // the same reasoning as alu.sv's slt/sltu.  Equality is compared directly rather than by zero-testing
    // the difference, which would wait for the carry chain.
    assign LateSignA = LateSrcAM[P.XLEN-1];
    assign LateSignB = LateSrcBM[P.XLEN-1];
    assign LateNeg   = Slot1LateSumM[P.XLEN-1];
    assign LateFlagsM = {(LateSrcAM == LateSrcBM),
                         (LateSignA & ~LateSignB) | (~(LateSignA ^ LateSignB) & LateNeg),    // lt
                         (~LateSignA & LateSignB) | (~(LateSignA ^ LateSignB) & LateNeg)};   // ltu
    if (P.SUPERSCALAR_SUPPORTED) begin : lateresult1
      mux2  #(P.XLEN)  lateresultmux(Slot1IEUResultM, Slot1LateResultM, Slot1LateM, Slot1ResultM);
    end else begin : nolateresult1
      assign Slot1ResultM = Slot1IEUResultM;
    end

    mux2  #(P.XLEN)  latewbmux(IFResultM, Slot1LateResultM, Slot0LateM, IFResultLateM);
  end else begin : nolateALU
    assign LateFlagsM    = '0;
    assign Slot1ResultM      = Slot1IEUResultM;
    assign IFResultLateM = IFResultM;
  end

  // Memory stage pipeline register
  flopenrc #(P.XLEN) SrcAMReg(clk, reset, FlushM, ~StallM, Slot0SrcAE, Slot0SrcAM);
  flopenrc #(P.XLEN) IEUResultMReg(clk, reset, FlushM, ~StallM, Slot0IEUResultE, Slot0IEUResultM);
  flopenrc #(P.XLEN) WriteDataMReg(clk, reset, FlushM, ~StallM, WriteDataE, WriteDataRawM);
  // Late store data: a store whose data (not address) the bundle ahead produced too late to forward
  // in Execute -- a load, a multiply or a late ALU result -- goes on anyway, and picks the data up here
  // in Memory, where its producer is now in Writeback (ieu.sv).
  //   bundle A:  add a5, a5, s10     <- late: a5 is computed in Memory
  //   bundle B:  sw  a5, 0(t4)       <- would stall a cycle; instead takes a5 from Slot0ResultW in Memory
  // StDataLateM uses the late ALU's codes: 00 none, 10 Slot0ResultW, 11 Slot1ResultW.  Code 01 (slot 0's
  // result in Memory, for a same-bundle consumer) never occurs for store data, so its input repeats 00's.
  mux4 #(P.XLEN) stdatalatemux(WriteDataRawM, WriteDataRawM, Slot0ResultW, Slot1ResultW, StDataLateM, WriteDataM);

  // Writeback stage pipeline register and logic
  // Slot 0's Writeback register normally stores IFResultM, slot 0's Execute result.  For a late slot 0
  // (Slot0LateM) that result is wrong, so it stores the late ALU's result instead; next cycle that is
  // Slot0ResultW, written to the register file and forwarded from Writeback.
  // The late result does not go into IFResultM itself: IFResultM forwards to the next bundle's Execute
  // ALU, and putting the late ALU in front of it would chain two ALUs in one cycle -- the critical path
  // the late ALU exists to avoid.  So a consumer in the next bundle goes late too (takes Slot0ResultW in
  // Memory) or stalls a cycle (Slot0LateStallD in ieu.sv).
  flopenrc #(P.XLEN) IFResultWReg(clk, reset, FlushW, ~StallW, IFResultLateM, IFResultW);

  // floating point inputs: FIntResM comes from fclass, fcmp, fmv; FCvtIntResW comes from fcvt
  if (P.F_SUPPORTED) begin : fpmux
    mux2  #(P.XLEN)  resultmuxM(Slot0IEUResultM, FIntResM, FWriteIntM, IFResultM);
    mux2  #(P.XLEN)  cvtresultmuxW(IFResultW, FCvtIntResW, FCvtIntW, IFCvtResultW);
    if (P.IDIV_ON_FPU & P.F_SUPPORTED) begin
      mux2  #(P.XLEN)  divresultmuxW(MDUResultW, FIntDivResultW, IntDivW, MulDivResultW);
    end else begin
      assign MulDivResultW = MDUResultW;
    end
  end else begin : fpmux
    assign IFResultM = Slot0IEUResultM;
    assign IFCvtResultW = IFResultW;
    assign MulDivResultW = MDUResultW;
  end
  mux5  #(P.XLEN) resultmuxW(IFCvtResultW, ReadDataW, CSRReadValW, MulDivResultW, SCResultW, ResultSrcW, Slot0ResultW);

  // handle Store Conditional result if atomic extension supported
  if (P.ZALRSC_SUPPORTED) assign SCResultW = {{(P.XLEN-1){1'b0}}, SquashSCW};
  else                    assign SCResultW = '0;
endmodule
