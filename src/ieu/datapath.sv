///////////////////////////////////////////
// datapath.sv
//
// Written: David_Harris@hmc.edu, Sarah.Harris@unlv.edu
// Created: 9 January 2021
// Modified:
//
// Purpose: Wally Integer Datapath
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
// except in compliance with the License, or, at your option, the Apache License version 2.0. You
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language governing permissions
// and limitations under the License.
////////////////////////////////////////////////////////////////////////////////////////////////

module datapath import cvw::*;  #(parameter cvw_t P) (
  input  logic              clk, reset,
  // Decode stage signals
  input  logic [2:0]        ImmSrcD,                 // Selects type of immediate extension
  input  logic [31:0]       InstrD,                  // Instruction in Decode stage
  input  logic [4:0]        Rs1D, Rs2D, Rs2E,        // Source registers
  input  logic [2:0]        ImmSrc2D,                // Slot 1 (superscalar): immediate format
  input  logic [31:0]       Instr2D,                 // Slot 1: instruction in Decode stage
  input  logic [4:0]        Rs1_2D, Rs2_2D,          // Slot 1: source registers
  input  logic [4:0]        Rs2_2E,                  // Slot 1: source register 2 in Execute (ALU bit-manipulation)
  input  logic [2:0]        Forward2AE, Forward2BE,  // Slot 1: forwarding selects
  input  logic              ALUSrcA2E, ALUSrcB2E,    // Slot 1: ALU operands
  input  logic              ALUResultSrc2E,          // Slot 1: selects ALU result or immediate
  input  logic [2:0]        ALUSelect2E,             // Slot 1: ALU mux select
  input  logic [2:0]        Funct3_2E,               // Slot 1: funct3
  input  logic [6:0]        Funct7_2E,               // Slot 1: funct7
  input  logic              W64_2E, UW64_2E,         // Slot 1: RV64 W-type / .uw-type
  input  logic              SubArith2E,              // Slot 1: subtract or arithmetic shift
  input  logic [3:0]        BSelect2E, ZBBSelect2E,  // Slot 1: bit-manipulation selects
  input  logic [2:0]        BALUControl2E,           // Slot 1: bit-manipulation ALU control
  input  logic              BMUActive2E,             // Slot 1: bit-manipulation instruction active
  input  logic [1:0]        CZero2E,                 // Slot 1: czero.* active
  input  logic              BranchSigned2E,          // Slot 1: branch comparison is signed
  input  logic              FuseBrA2E, FuseBrB2E,    // Slot 1's branch is fused with slot 0's ALU op: its rs1 / rs2 is slot 0's result
  input  logic              FuseBrAdd2E,             // ... and slot 0's op is an add (else a logic op)
  input  logic              Jump2E,                  // Slot 1: jal, whose result is its link address
  input  logic [P.XLEN-1:0] PCLink2E,                // Slot 1: its link address, the PC just past it
  output logic [1:0]        Flags2E,                 // Slot 1: comparison flags ({eq, lt})
  output logic [P.XLEN-1:0] IEUAdr2E,                // Slot 1: ALU sum, which is its branch or jal target
  input  logic              RegWrite2W,              // Slot 1: commits a register write this cycle
  input  logic [4:0]        Rd2W,                    // Slot 1: destination register in Writeback
  input  logic              Mem2E,                   // Slot 1: holds the bundle's memory operation
  input  logic [2:0]        ResultSrc2W,             // Slot 1: selects source of its writeback value
  input  logic              Mdu2E,                   // Slot 1: holds the bundle's multiply
  output logic [P.XLEN-1:0] MDUSrcAE, MDUSrcBE,      // Operands to the MDU, from whichever slot holds its operation
  input  logic [1:0]        LateSelA2E, LateSelB2E,  // Slot 1: late ALU operand source (00 own, 01 slot 0, 10 ResultW, 11 ResultW2)
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
  logic [P.XLEN-1:0] R1_2D, R2_2D;                   // Slot 1: read data from Rs1_2D, Rs2_2D
  logic [P.XLEN-1:0] ImmExt2D;                       // Slot 1: extended immediate in Decode stage
  logic [P.XLEN-1:0] R1_2E, R2_2E, ImmExt2E;         // Slot 1: the same, in Execute
  logic [P.XLEN-1:0] ForwardedSrc2AE, ForwardedSrc2BE; // Slot 1: operands after forwarding
  logic [P.XLEN-1:0] SrcA2E, SrcB2E;                 // Slot 1: ALU inputs
  logic [P.XLEN-1:0] ALUResult2E;                    // Slot 1: ALU output.  The sum, IEUAdr2E, needs no bit-0
                                                     //   mask as slot 0's does: that is for jalr, and slot 1
                                                     //   only ever jumps with jal, whose target is even.
  logic [P.XLEN-1:0] AltResult2E, IEUResult2E;       // Slot 1: result in Execute
  logic [P.XLEN-1:0] IEUResult2M;                    // Slot 1: result in Memory
  logic [P.XLEN-1:0] IEUResult2W;                    // Slot 1: result in Writeback
  logic [P.XLEN-1:0] ResultW2;                       // Slot 1: value written back
  logic [P.XLEN-1:0] SrcA2M, SrcB2M;                 // Slot 1: ALU inputs, carried to the late ALU
  logic [P.XLEN-1:0] LateSrcA2M, LateSrcB2M;         // Slot 1: late ALU inputs, with slot 0's result substituted
  logic [P.XLEN-1:0] LateResult2M;                   // Slot 1: late ALU result
  logic [P.XLEN-1:0] Result2M;                       // Slot 1: result entering Writeback
  logic [2:0]        ALUSelect2M, Funct3_2M;         // Slot 1: late ALU control
  logic              SubArith2M, W64_2M;
  logic [1:0]        LateSelA2M, LateSelB2M;         // Slot 1: where the late ALU takes each operand from
  logic              Late2M;                         // Slot 1 executes on the late ALU
  logic              LateBrM;                        // The late ALU compares slot 0's branch instead
  logic              Late0RawM, Late0M;              // The late ALU was given slot 0's ALU operation / and computes it
  logic [2:0]        LateALUSelectE, LateFunct3E;    // Late ALU control, from whichever slot uses it
  logic              LateSubArithE, LateW64E;
  logic [P.XLEN-1:0] IFResultLateM;                  // Slot 0's result entering Writeback, the late ALU's if slot 0 was late
  logic [P.XLEN-1:0] LateInA2E, LateInB2E;           // What the late ALU's operand registers capture
  logic [P.XLEN-1:0] LateSum2M;                      // The late ALU's adder output
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
  regfile #(P.XLEN, P.E_SUPPORTED) regf(clk, reset, RegWriteW, RegWrite2W, Rs1D, Rs2D, RdW,
    Rs1_2D, Rs2_2D, Rd2W, ResultW, ResultW2, R1D, R2D, R1_2D, R2_2D);
  extend #(P)        ext(.InstrD(InstrD[31:7]), .ImmSrcD, .ImmExtD);
  extend #(P)        ext2(.InstrD(Instr2D[31:7]), .ImmSrcD(ImmSrc2D), .ImmExtD(ImmExt2D));   // slot 1

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
  logic [P.XLEN-1:0] R1ENext, R2ENext, R1_2ENext, R2_2ENext;
  assign CaptureE = StallE & ~StallM;
  mux2  #(P.XLEN)  r1enextmux(R1D, ForwardedSrcAE, CaptureE, R1ENext);
  mux2  #(P.XLEN)  r2enextmux(R2D, ForwardedSrcBE, CaptureE, R2ENext);
  flopenrc #(P.XLEN) RD1EReg(clk, reset, FlushE, ~StallE | CaptureE, R1ENext, R1E);
  flopenrc #(P.XLEN) RD2EReg(clk, reset, FlushE, ~StallE | CaptureE, R2ENext, R2E);
  flopenrc #(P.XLEN) ImmExtEReg(clk, reset, FlushE, ~StallE, ImmExtD, ImmExtE);

  // Forwarding sources in the order each lane's select encodes them: no forward, own Writeback,
  // own Memory, other Writeback, other Memory.  The encoding is relative to the lane, so lane 2's
  // muxes below take the same four sources with the pairs swapped.  See controller.sv for priority.
  mux5  #(P.XLEN)  faemux(R1E, ResultW, IFResultM, ResultW2, IEUResult2M, ForwardAE, ForwardedSrcAE);
  mux5  #(P.XLEN)  fbemux(R2E, ResultW, IFResultM, ResultW2, IEUResult2M, ForwardBE, ForwardedSrcBE);
  comparator #(P.XLEN) comp(ForwardedSrcAE, ForwardedSrcBE, BranchSignedE, FlagsE);
  mux2  #(P.XLEN)  srcamux(ForwardedSrcAE, PCE, ALUSrcAE, SrcAE);
  mux2  #(P.XLEN)  srcbmux(ForwardedSrcBE, ImmExtE, ALUSrcBE, SrcBE);
  alu   #(P)       alu(SrcAE, SrcBE, W64E, UW64E, SubArithE, ALUSelectE, BSelectE, ZBBSelectE, Funct3E, Funct7E, Rs2E, BALUControlE, BMUActiveE, CZeroE, ALUResultE, IEUAdrRawE);
  // jalr sets the least significant bit of the target address to zero.  jal and branch targets are
  // always even, so masking on JumpE alone is sufficient and leaves load/store addresses untouched.
  assign IEUAdrE = {IEUAdrRawE[P.XLEN-1:1], IEUAdrRawE[0] & ~JumpE};
  mux2  #(P.XLEN)  altresultmux(ImmExtE, PCLinkE, JumpE, AltResultE);
  mux2  #(P.XLEN)  ieuresultmux(ALUResultE, AltResultE, ALUResultSrcE, IEUResultE);

  // Slot 1 (superscalar) Execute stage, mirroring slot 0 above.  A conditional branch in slot 1
  // compares with its own comparator, and its target is its ALU's sum of slot 1's PC and immediate.
  mux2  #(P.XLEN)  r1_2enextmux(R1_2D, ForwardedSrc2AE, CaptureE, R1_2ENext);   // operand capture, as for slot 0
  mux2  #(P.XLEN)  r2_2enextmux(R2_2D, ForwardedSrc2BE, CaptureE, R2_2ENext);
  flopenrc #(P.XLEN) RD1_2EReg(clk, reset, FlushE, ~StallE | CaptureE, R1_2ENext, R1_2E);
  flopenrc #(P.XLEN) RD2_2EReg(clk, reset, FlushE, ~StallE | CaptureE, R2_2ENext, R2_2E);
  flopenrc #(P.XLEN) ImmExt2EReg(clk, reset, FlushE, ~StallE, ImmExt2D, ImmExt2E);

  mux5  #(P.XLEN)  faemux2(R1_2E, ResultW2, IEUResult2M, ResultW, IFResultM, Forward2AE, ForwardedSrc2AE);
  mux5  #(P.XLEN)  fbemux2(R2_2E, ResultW2, IEUResult2M, ResultW, IFResultM, Forward2BE, ForwardedSrc2BE);
  // Macro-op fusion: ALU op + dependent branch (issue.sv).  The pair is one compare-and-branch op, decided
  // in Execute.  The branch must not wait for slot 0's ALU result: that would put two carry chains in a
  // row (slot 0's add, then comp2's compare) on the clock's critical path.  So comp2 works from slot 0's
  // ALU inputs (SrcAE, SrcBE) instead.  No new adder: slot 0's ALU still makes rd, comp2 does the compare,
  // and slot 1's ALU still makes the target.
  //
  // Logic op: no carry chain, so its result is simply remade here, one gate deep, and compared as usual.
  //   andi t0, a1, 1  ; bnez t0, L      comp2 compares (a1 & 1, x0)
  //
  // Add, X = P + Q: the question "X < Y" is the sign/borrow of X - Y = P + Q + ~Y + 1, three numbers.  A full
  // adder per bit, with no carry passing between bits, turns P, Q, ~Y into two numbers, a sum Sum and a
  // carry Carry, with P + Q + ~Y = Sum + (Carry << 1).  comp2 compares a = Sum against b = ~(Carry << 1):
  // its a - b = Sum + (Carry << 1) + 1 = X - Y, the one carry chain.  So comp2's eq is X == Y, and its
  // unsigned lt is X < Y once corrected for the two carries that fall off the top bit: Carry's top bit and
  // slot 0's own carry out of P + Q (made from the top bits of P, Q and slot 0's sum, ready alongside).
  // Signed: X < Y signed is X < Y unsigned, flipped when X and Y have different sign bits.
  //   add t0, a1, a2  ; blt t0, a3, L   is a1 + a2 < a3?   (P = a1, Q = a2, Y = a3)
  //   li  t0, 5       ; beq a4, t0, L   is 0 + 5 == a4?    (P = x0, Q = 5,  Y = a4)
  // When slot 0's result is rs2 (blt a3, t0), comp2 still answers X < Y, and Y < X = not (X < Y or X == Y).
  // When it is both (beq t0, t0), the operands are equal.
  logic [P.XLEN-1:0] Logic0E;                        // Slot 0's logic result, remade from its ALU inputs
  logic [P.XLEN-1:0] FuseYE, NotYE;                  // Y: the branch operand that is not slot 0's result, and ~Y
  logic [P.XLEN-1:0] CsaSumE, CsaCarryE;             // P + Q + ~Y as two numbers: Sum + (Carry << 1)
  logic [P.XLEN-1:0] Cmp2AE, Cmp2BE;                 // Slot 1's comparator inputs
  logic [1:0]        CmpFlags2E;                     // comp2's {eq, lt}
  logic              CarryOutE;                      // Carry out of slot 0's P + Q
  logic              LtuE, LtE;                      // Fused add: X < Y unsigned, X < Y as the branch asks

  always_comb
    case (ALUSelectE[1:0])                           // slot 0's ALUSelect: 100 xor, 110 or, 111 and
      2'b00:   Logic0E = SrcAE ^ SrcBE;
      2'b10:   Logic0E = SrcAE | SrcBE;
      default: Logic0E = SrcAE & SrcBE;
    endcase

  mux2  #(P.XLEN)  fuseymux(ForwardedSrc2AE, ForwardedSrc2BE, FuseBrA2E, FuseYE);  // slot 0's is rs1: Y is rs2
  assign NotYE     = ~FuseYE;
  assign CsaSumE   = SrcAE ^ SrcBE ^ NotYE;                                       // full adder sum, per bit
  assign CsaCarryE = (SrcAE & SrcBE) | (SrcAE & NotYE) | (SrcBE & NotYE);         // full adder carry, per bit

  // select: 00 slot 1's own register, 01 logic result, 1x carry-save (an add replaces both inputs)
  mux3  #(P.XLEN)  cmp2amux(ForwardedSrc2AE, Logic0E, CsaSumE, {FuseBrAdd2E, FuseBrA2E}, Cmp2AE);
  mux3  #(P.XLEN)  cmp2bmux(ForwardedSrc2BE, Logic0E, ~{CsaCarryE[P.XLEN-2:0], 1'b0}, {FuseBrAdd2E, FuseBrB2E}, Cmp2BE);
  comparator #(P.XLEN) comp2(Cmp2AE, Cmp2BE, BranchSigned2E & ~FuseBrAdd2E, CmpFlags2E);  // an add compares unsigned

  assign CarryOutE = SrcAE[P.XLEN-1] & SrcBE[P.XLEN-1] | (SrcAE[P.XLEN-1] | SrcBE[P.XLEN-1]) & ~IEUAdrRawE[P.XLEN-1];
  assign LtuE      = CmpFlags2E[0] ^ CsaCarryE[P.XLEN-1] ^ CarryOutE;
  assign LtE       = BranchSigned2E ? LtuE ^ IEUAdrRawE[P.XLEN-1] ^ FuseYE[P.XLEN-1] : LtuE;  // IEUAdrRawE: P + Q

  always_comb
    if      (FuseBrA2E & FuseBrB2E) Flags2E = 2'b10;                                  // beq t0, t0: equal
    else if (~FuseBrAdd2E)          Flags2E = CmpFlags2E;                             // not fused, or a logic op
    else if (FuseBrA2E)             Flags2E = {CmpFlags2E[1], LtE};                   // blt X, Y
    else                            Flags2E = {CmpFlags2E[1], ~LtE & ~CmpFlags2E[1]}; // blt Y, X
  // Slot 1 sits one instruction after slot 0, so its PC is PCLinkE (= PCE + 4, since the issue
  // rules require an uncompressed slot 0).  Using PCE here would make every paired auipc off by 4.
  mux2  #(P.XLEN)  srcamux2(ForwardedSrc2AE, PCLinkE, ALUSrcA2E, SrcA2E);
  mux2  #(P.XLEN)  srcbmux2(ForwardedSrc2BE, ImmExt2E, ALUSrcB2E, SrcB2E);
  alu   #(P)       alu2(SrcA2E, SrcB2E, W64_2E, UW64_2E, SubArith2E, ALUSelect2E, BSelect2E, ZBBSelect2E,
                        Funct3_2E, Funct7_2E, Rs2_2E, BALUControl2E, BMUActive2E, CZero2E, ALUResult2E, IEUAdr2E);
  // Slot 1's result when it is not the ALU's, as slot 0's altresultmux: lui writes its immediate, a jal
  // its link address.  Slot 1's link is one instruction past slot 1, so it is PCLink2E (ifu.sv), not
  // slot 0's PCLinkE.  The jal's target is its ALU sum, IEUAdr2E, which goes to the IFU.
  //   0x100 addi a0,a0,1 ; 0x104 jal ra,f     ra = 0x108   (0x106 if the jal is a c.jal)
  mux2  #(P.XLEN)  altresultmux2(ImmExt2E, PCLink2E, Jump2E, AltResult2E);
  mux2  #(P.XLEN)  ieuresultmux2(ALUResult2E, AltResult2E, ALUResultSrc2E, IEUResult2E);

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
  mux2  #(P.XLEN)  lsuadrmux(IEUAdrE, IEUAdr2E, Mem2E, LSUAdrE);

  // The multiplier's operands, from whichever slot holds the bundle's one MDU operation.  These are
  // the forwarded register values, as slot 0's ForwardedSrcAE/BE always were.  They are separate
  // outputs rather than a mux on ForwardedSrcAE/BE because the FPU reads those too, for slot 0.
  mux2  #(P.XLEN)  mdusrcamux(ForwardedSrcAE, ForwardedSrc2AE, Mdu2E, MDUSrcAE);
  mux2  #(P.XLEN)  mdusrcbmux(ForwardedSrcBE, ForwardedSrc2BE, Mdu2E, MDUSrcBE);

  // Slot 1 late ALU.  A slot 1 that reads slot 0's result is paired anyway and executes here, one stage
  // late, where slot 0's result is already sitting in IEUResultM.  Its Execute-stage ALU ran on a stale
  // operand and that result is discarded.  The operands are captured after srcamux2/srcbmux2, so an
  // immediate or the PC arrives as it would have in Execute, and the operand that depended on slot 0 is
  // replaced.  IEUResultM rather than IFResultM: issue.sv only makes a pair late when slot 0 is an
  // integer ALU operation, so the FPU's integer result never applies, and its mux would lengthen the path.
  //
  // An operand that the bundle ahead produced too late to forward in Execute (a load, say) arrives here
  // from Writeback instead: ResultW for that bundle's slot 0, ResultW2 for its slot 1.  ieu.sv chooses.
  //
  // The late ALU implements only the base operations, so its bit-manipulation and czero inputs are tied
  // off and synthesis removes that logic.  issue.sv keeps every other operation out of it.  Its output
  // goes nowhere but the Writeback register: nothing forwards from it, and ieu.sv's LateStall2D holds
  // back any consumer until the result reaches ResultW2.
  //
  // For a late branch the same registers carry slot 0's branch operands instead -- its rs1 and rs2 after
  // forwarding, which is what the comparator in Execute would have used -- and the late ALU subtracts.
  //
  // A late slot 0 (ieu.sv) uses the late ALU too.  Its operands reach it in two steps, as slot 1's do:
  //   bundle A:  lw   a5, 0(a0)
  //   bundle B:  addi a4, a5, 3     <- slot 0 is late
  //   1. End of Execute (lateinamux): store what is available now.  Operand A is a5, still wrong -- the
  //      load is only in Memory -- and operand B is the immediate 3, which is right.
  //   2. Memory (latesrcamux, below): replace what came too late.  LateSelA2M = 10 swaps the wrong a5
  //      for ResultW, the loaded a5 now in Writeback; LateSelB2M = 00 keeps the 3.
  // Step 1 is needed because only the slow operand comes from Writeback; the other one (an immediate,
  // or a register that was ready in Execute) must be carried from Execute to Memory.
  //
  // Names: LateInA2E is late ALU operand A as chosen in Execute, SrcA2M the same value stored in
  // Memory, LateSrcA2M it after the swap.  The "2" dates from when only slot 1 used the late ALU.
  //
  // What step 1 stores depends on who uses the late ALU (at most one instruction per bundle):
  //   slot 1 (normal)   slot 1's ALU inputs              SrcA2E, SrcB2E        slot 1's operation
  //   late branch       slot 0's two register values     ForwardedSrcAE/BE     subtract (LateBrM)
  //   late slot 0       slot 0's ALU inputs              SrcAE, SrcBE          slot 0's operation
  // A late slot 0 takes SrcAE/SrcBE rather than ForwardedSrcAE/BE because its operand may be the PC or
  // an immediate, which SrcAE/SrcBE already include.  LateBrE and Late0RawE are never both set.
  mux3  #(P.XLEN)  lateinamux(SrcA2E, ForwardedSrcAE, SrcAE, {Late0RawE, LateBrE}, LateInA2E);
  mux3  #(P.XLEN)  lateinbmux(SrcB2E, ForwardedSrcBE, SrcBE, {Late0RawE, LateBrE}, LateInB2E);
  // The operation travels with the operands: slot 0's for a late slot 0, otherwise slot 1's.
  mux2  #(8)       latectrlmux({ALUSelect2E, Funct3_2E, SubArith2E, W64_2E},          // slot 1's operation
                               {ALUSelectE,  Funct3E,   SubArithE,  W64E},            // slot 0's operation
                               Late0RawE, {LateALUSelectE, LateFunct3E, LateSubArithE, LateW64E});
  flopenrc #(P.XLEN) SrcA2MReg(clk, reset, FlushM, ~StallM, LateInA2E, SrcA2M);
  flopenrc #(P.XLEN) SrcB2MReg(clk, reset, FlushM, ~StallM, LateInB2E, SrcB2M);
  flopenrc #(14)     LateCtrl2MReg(clk, reset, FlushM, ~StallM,
                                   {LateALUSelectE, LateFunct3E, LateSubArithE, LateW64E, LateSelA2E, LateSelB2E, LateBrE, Late0RawE},
                                   {ALUSelect2M, Funct3_2M, SubArith2M, W64_2M, LateSelA2M, LateSelB2M, LateBrM, Late0RawM});

  // Whose result the late ALU produced:
  //   Late0M  slot 0's: it was sent late and an operand really was replaced.  If nothing was replaced
  //           (a false match on an immediate field), slot 0's Execute result is right and is used.
  //   Late2M  slot 1's: only when neither a late branch nor a late slot 0 used the late ALU.
  assign Late0M = Late0RawM & (|LateSelA2M | |LateSelB2M);
  assign Late2M = ~LateBrM & ~Late0RawM & (|LateSelA2M | |LateSelB2M);
  mux4  #(P.XLEN)  latesrcamux(SrcA2M, IEUResultM, ResultW, ResultW2, LateSelA2M, LateSrcA2M);
  mux4  #(P.XLEN)  latesrcbmux(SrcB2M, IEUResultM, ResultW, ResultW2, LateSelB2M, LateSrcB2M);
  alu   #(P)       latealu(.A(LateSrcA2M), .B(LateSrcB2M), .W64(W64_2M & ~LateBrM), .UW64(1'b0),
                           .SubArith(SubArith2M | LateBrM),
                           .ALUSelect(ALUSelect2M), .BSelect(4'b0), .ZBBSelect(4'b0), .Funct3(Funct3_2M),
                           .Funct7(7'b0), .Rs2E(5'b0), .BALUControl(3'b0), .BMUActive(1'b0), .CZero(2'b0),
                           .ALUResult(LateResult2M), .Sum(LateSum2M));

  // Branch flags from the late ALU's subtraction A - B.  When the signs agree the difference cannot
  // overflow, so its sign answers both comparisons; when they differ, the operand signs alone do --
  // the same reasoning as alu.sv's slt/sltu.  Equality is compared directly rather than by zero-testing
  // the difference, which would wait for the carry chain.
  assign LateSignA = LateSrcA2M[P.XLEN-1];
  assign LateSignB = LateSrcB2M[P.XLEN-1];
  assign LateNeg   = LateSum2M[P.XLEN-1];
  assign LateFlagsM = {(LateSrcA2M == LateSrcB2M),
                       (LateSignA & ~LateSignB) | (~(LateSignA ^ LateSignB) & LateNeg),    // lt
                       (~LateSignA & LateSignB) | (~(LateSignA ^ LateSignB) & LateNeg)};   // ltu
  mux2  #(P.XLEN)  lateresultmux(IEUResult2M, LateResult2M, Late2M, Result2M);

  // Slot 1 Memory and Writeback.  Slot 0 needs a mux5 in Writeback to choose between the ALU, a load,
  // a CSR read, the multiply/divide unit and a store-conditional.  Slot 1 can only be an ALU operation,
  // a load or a multiply/divide, so it needs just three of those, selected by the same ResultSrc
  // encoding slot 0 uses.  A slot 1 MDU result is always the MDU's own: the FPU only ever divides, and
  // issue.sv admits slot 1 divides only in configurations whose divider is the MDU's.
  flopenrc #(P.XLEN) IEUResult2MReg(clk, reset, FlushM, ~StallM, IEUResult2E, IEUResult2M);
  flopenrc #(P.XLEN) IEUResult2WReg(clk, reset, FlushW, ~StallW, Result2M, IEUResult2W);
  always_comb
    case (ResultSrc2W)
      3'b001:  ResultW2 = ReadDataW;
      3'b011:  ResultW2 = MDUResultW;
      default: ResultW2 = IEUResult2W;
    endcase

  // Memory stage pipeline register
  flopenrc #(P.XLEN) SrcAMReg(clk, reset, FlushM, ~StallM, SrcAE, SrcAM);
  flopenrc #(P.XLEN) IEUResultMReg(clk, reset, FlushM, ~StallM, IEUResultE, IEUResultM);
  // A store's data is rs2 after forwarding, so it comes from whichever slot's forwarding muxes hold
  // the memory operation.  The lane choice is made before the register, so Memory sees one value.
  mux2  #(P.XLEN)  writedatamux(ForwardedSrcBE, ForwardedSrc2BE, Mem2E, WriteDataE);
  flopenrc #(P.XLEN) WriteDataMReg(clk, reset, FlushM, ~StallM, WriteDataE, WriteDataM);

  // Writeback stage pipeline register and logic
  // Slot 0's Writeback register normally stores IFResultM, slot 0's Execute result.  For a late slot 0
  // (Late0M) that result is wrong, so it stores the late ALU's result instead; next cycle that is
  // ResultW, written to the register file and forwarded from Writeback.
  // The late result does not go into IFResultM itself: IFResultM forwards to the next bundle's Execute
  // ALU, and putting the late ALU in front of it would chain two ALUs in one cycle -- the critical path
  // the late ALU exists to avoid.  So a consumer in the next bundle goes late too (takes ResultW in
  // Memory) or stalls a cycle (LateStall0D in ieu.sv).
  mux2  #(P.XLEN)  latewbmux(IFResultM, LateResult2M, Late0M, IFResultLateM);
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
