///////////////////////////////////////////
// issue.sv
//
// Written: September 2026
//
// Purpose: Decide whether the two instructions in the fetch window may issue together.
//
//          This runs in the Fetch stage because the PC advance is computed there: when both
//          slots issue the PC must move by both their lengths in the same cycle.  Everything it
//          needs is a fixed bit field of an uncompressed instruction, so no decode is required.
//
//          The rule is a whitelist for pairing, not for execution.  When Issue1F is low the core
//          behaves exactly as the original single-issue Wally: slot 0 issues by itself and slot 1
//          is fetched again next cycle as the next slot 0.  No instruction is ever skipped.
//
//          Slot 1 is restricted by the hardware it has, not by legality.  It may hold anything its
//          own ALU can finish in one cycle -- including the Zb*/Zk*/Zicond encodings, since its
//          controller has its own bitmanip decoder -- plus one integer load or store and one multiply
//          or divide, because the single load/store unit and the single multiply/divide unit can each
//          be steered to either slot.  It may hold a conditional branch, which slot 1 resolves with
//          its own comparator, or a jal (also c.j, c.jal), whose target its own ALU computes, but no
//          jalr and no CSR access.
//
//          Legality is left to the decoder that already knows it.  Where slot 1 turns out to hold an
//          instruction this configuration does not implement, or one whose memory access faults, the
//          Memory stage cannot describe the trap -- it holds slot 0's PC, cause and tval -- so slot 1
//          is discarded and refetched to run alone, and traps through the ordinary single-issue path.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
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

module issue import cvw::*;  #(parameter cvw_t P) (
  input  logic [31:0] Instr0F,        // Slot 0 raw instruction (at PCF)
  input  logic [31:0] Instr1F,        // Slot 1 raw instruction, already aligned to bit 0
  input  logic        Instr1ValidF,   // Slot 1 holds a complete instruction from the I$
  input  logic        BPPCSrcF,       // Branch predictor says this fetch is a taken branch or jump
  output logic        Issue1F,        // Both slots may issue together this cycle
  output logic        LateA1F, LateB1F, // Slot 1's rs1 / rs2 is slot 0's rd: its operand comes from the late ALU's bypass
  output logic        LateOK1F,         // Slot 1 is an operation the late ALU implements
  output logic        Fuse1F,           // The pair is fused into one indexed load, executed by slot 0
  output logic        FuseBr1F,         // The pair is fused into one ALU op + compare-and-branch
  output logic        FuseBrAdd1F       // ... and slot 0 is an add (else a logic op); see datapath.sv
);

  // Opcodes
  localparam [6:0] LUI      = 7'b0110111;
  localparam [6:0] AUIPC    = 7'b0010111;
  localparam [6:0] OP       = 7'b0110011;
  localparam [6:0] OP_IMM   = 7'b0010011;
  localparam [6:0] OP_32    = 7'b0111011;   // RV64 only: addw, subw, sllw, srlw, sraw
  localparam [6:0] OP_IMM_32= 7'b0011011;   // RV64 only: addiw, slliw, srliw, sraiw
  localparam [6:0] BRANCH   = 7'b1100011;
  localparam [6:0] JAL      = 7'b1101111;
  localparam [6:0] JALR     = 7'b1100111;
  localparam [6:0] SYSTEM   = 7'b1110011;
  localparam [6:0] MISC_MEM = 7'b0001111;
  // LOAD and STORE are still named for the access-width checks below.  The other memory opcodes --
  // the floating-point loads and stores, and the atomics -- are not listed here: instrfields reports
  // which slots occupy the load/store unit, for compressed and 32-bit instructions alike.
  localparam [6:0] LOAD     = 7'b0000011;
  localparam [6:0] STORE    = 7'b0100011;

  logic [6:0] Op0F, Op1F, Funct7_1F;
  logic [2:0] Funct3_1F;
  logic [4:0] Rd0F;                          // What slot 0 writes -- its sources do not matter, it runs first
  logic [4:0] Rd1F, Rs1_1F, Rs2_1F;          // Slot 1's register fields, whatever its length
  logic       Recognized0F, Recognized1F;    // instrfields decoded this slot's fields
  logic [1:0] MemRW0F, MemRW1F;              // ... and whether it uses the load/store unit
  logic       IsBranch0F, IsBranch1F;        // ... and whether each slot is a conditional branch
  logic       BothRecognizedF, Slot0CanPairF, Slot1CanPairF, DependencyOKF;
  logic       Slot0EarlyF;                // Slot 0 is an integer ALU operation: its result is in IEUResultM
  logic       Slot1LateOKF;               // Slot 1 is an operation the late ALU implements
  logic       SrcDepF, SameRdF;           // Slot 1 reads / overwrites slot 0's destination (SameRdF: statistics only)
  logic       Slot0IsMemF, Slot1IsMemF, OneMemOpF;
  logic       MExtF;                      // Slot 1 is a multiply/divide, which needs the one MDU
  logic       MulF;                       // ... and specifically a multiply, which the MDU can take from slot 1
  logic       DivF;                       // ... or a divide, which it can take when the divider is the MDU's
  logic       MduOKF;                     // Slot 1's multiply or divide may pair
  logic       Slot0ReadsFPF;              // Slot 0 reads floating-point registers
  logic       Slot0IsMduF, Slot1IsMduF, OneMduOpF;
  logic       Branch1OKF;                 // A conditional branch or a jal in slot 1 may pair
  logic       IsJal0F, IsJal1F;           // Each slot is a jal, c.j or c.jal
  logic       FuseAdd0F;                  // Slot 0 is add, sh1add, sh2add, sh3add, c.add or c.mv
  logic       FuseLoad1F;                 // Slot 1 is a load with offset 0
  logic       FuseBrAdd0F;                // Slot 0 is add, addi, c.addi, c.li, c.mv or c.add (li, mv are addi)
  logic       FuseBrLogic0F;              // Slot 0 is and, or, xor, andi, ori, xori, c.andi, c.and, c.or or c.xor

  assign Op0F      = Instr0F[6:0];
  assign Op1F      = Instr1F[6:0];
  assign Funct3_1F = Instr1F[14:12];
  assign Funct7_1F = Instr1F[31:25];

  // The register fields come from instrfields rather than from fixed bit positions, because a
  // compressed instruction keeps them elsewhere.  Each slot reports Recognized low for any encoding
  // whose fields are not decoded, and the dependency check below refuses to pair in that case.
  // Slot 0's sources are not connected: only what it writes can create a hazard with slot 1.  A
  // write-after-read cannot arise, because slot 0 read its operands in Decode and slot 1 does not
  // write until Writeback, and the two move together through the pipeline.
  instrfields #(P) fields0(.Instr(Instr0F), .Rd(Rd0F), .Rs1(), .Rs2(), .MemRW(MemRW0F), .IsBranch(IsBranch0F), .IsJal(IsJal0F), .Recognized(Recognized0F));
  instrfields #(P) fields1(.Instr(Instr1F), .Rd(Rd1F), .Rs1(Rs1_1F), .Rs2(Rs2_1F), .MemRW(MemRW1F), .IsBranch(IsBranch1F), .IsJal(IsJal1F), .Recognized(Recognized1F));

  // A slot is admitted only if its register fields are known.  For a 32-bit instruction that is
  // always true, so this reduces to the previous behaviour; for a compressed one it is instrfields'
  // verdict, which is low for every format not decoded there.  That is what makes a gap in
  // instrfields cost pairing opportunities rather than correctness -- and it covers slot 0 too,
  // whose Op0F comparisons below are meaningless when it is compressed.
  assign BothRecognizedF = Recognized0F & Recognized1F;

  // Which instructions may carry a partner in slot 1.  These all still execute normally on their
  // own when they cannot pair.
  //   ~BPPCSrcF, unless slot 1 is a branch, and is about the PC mux rather than the opcode: when
  //     BPPCSrcF is high the next PC becomes the predicted target and the sequential PC is discarded,
  //     so a paired slot 1 would issue while the machine jumped somewhere else.  The predictor can
  //     say taken for an instruction that is not a branch at all (a class misprediction on a stale
  //     or aliased BTB entry), so this cannot be qualified by slot 0's opcode.
  //     With it, a conditional branch predicted not-taken DOES pair; if it later resolves taken,
  //     Kill1E in ifu.sv squashes slot 1 before it commits and the redirect re-fetches it.
  //     When slot 1 is a branch, slot 0 is not one (Branch1OKF), so the prediction made at the
  //     bundle's address is slot 1's: the BTB has no slot field, and the predictor trains a slot 1
  //     branch at slot 0's PC, which is where fetch looks it up.  Both slots issue and fetch goes
  //     on to the target.  Whatever the BTB said, Execute checks the bundle's next PC against the
  //     resolved one, so a prediction attributed to the wrong slot costs a misprediction, never
  //     correctness.
  //     A jal in slot 1 is the same case: the BTB entry at the bundle's address is slot 1's jump.
  //       0x100 addi a0,a0,1   slot 0
  //       0x104 j    loop      slot 1     BTB[0x100] = jump to loop, so BPPCSrcF is high -- and it pairs
  //   jal/jalr in slot 0: never pair.  The instruction after an unconditional jump is never the next
  //     one executed, and BPJumpF forces BPPCSrcF high for them anyway.  ~IsJal0F also covers c.j and
  //     c.jal, which instrfields recognizes; c.jr and c.jalr it does not, so they never pair.
  //   SYSTEM: mret and sret redirect the PC from the Memory stage without flushing Writeback, so a
  //     slot 1 sharing that stage would commit after the return had already been taken.  This one
  //     cannot be fixed by killing slot 1 later -- it is already past the point of no return.
  //   MISC_MEM: fence.i flushes the pipeline behind it.
  assign Slot0CanPairF = (~BPPCSrcF | IsBranch1F | IsJal1F) & ~IsJal0F & (Op0F != JALR) &
                         (Op0F != SYSTEM) & (Op0F != MISC_MEM);

  // What slot 1 may hold is a statement about hardware, not about legality.  Slot 1 has its own full
  // controller, including its own bmuctrl, so it already decodes every Zba/Zbb/Zbs/Zbc/Zbk/Zk/Zicond
  // encoding this configuration enables and flags the rest as illegal.  Fetch cannot make that
  // judgement and does not try: sh1add and an illegal encoding are the same bits, separated only by
  // P.ZBA_SUPPORTED, so an encoding that turns out illegal is replayed from the Memory stage and traps
  // as an unpaired instruction (see Replay1M).  That keeps the one copy of the encoding table in the
  // decoder that owns it, rather than a second copy here that could silently disagree with it.
  //
  // Multiplies and divides share the OP and OP-32 opcodes with the ALU instructions but need the one
  // multiply/divide unit, and the decoder calls them perfectly legal -- so nothing downstream would
  // catch one that slot 1 could not execute.  ieu.sv steers the MDU's operands, funct3, W64 and
  // divide start to whichever slot holds the bundle's MDU operation, and slot 1's writeback takes its
  // result -- the same arrangement as the one load/store unit.  OP-IMM needs no such check: the M
  // extension has no OP-IMM encoding, and bits 31:25 of an addi are immediate bits that may hold any
  // value.
  //
  // Multiplies (mul, mulh, mulhsu, mulhu, and mulw on RV64) may always pair.  The multiplier has no
  // enable and no side effect, so a slot 1 multiply that is later killed or replayed costs nothing:
  // its register write is stopped by the commit gate like any slot 1 ALU operation.  RV64 OP-32 with
  // funct7 = 0000001 is mulw only at funct3 000; the other multiply funct3 values are reserved there.
  //
  // Divides (div, divu, rem, remu, and the RV64 W forms) may pair when the divider is the MDU's own --
  // the same condition under which mdu.sv builds one.  With IDIV_ON_FPU the FPU divides instead, from
  // slot 0's operands, so slot 1 divides stay out there.  And not beside a conditional branch in slot
  // 0: unlike the multiplier, the divider acts as soon as it starts, taking DivBusyE high and holding
  // the pipeline for the whole divide.  A branch that resolved taken in the same cycle would have
  // started a divide for the fall-through, which must not execute, and hazard.sv deliberately keeps a
  // busy divider from being flushed by a misprediction.  Refusing the pair keeps the divider from ever
  // starting on a slot 1 that can be killed: the other way slot 1 is killed is a jump, which never
  // pairs, and a slot 0 predicted taken does not pair either.
  //
  // Nor beside a slot 0 that reads floating-point registers.  The divide holds the Execute stage for
  // its whole iteration while Memory and Writeback drain, so slot 0 sits there with operands whose
  // forwarding sources retire under it.  datapath.sv's operand capture keeps the integer operands
  // right through such a stall, but the FPU's Execute registers have no equivalent, so a slot 0 FP
  // store, FP arithmetic or fused multiply-add stays out.  Compressed FP loads and stores are not
  // recognized by instrfields, so only 32-bit encodings need checking.
  assign MExtF  = (Funct7_1F == 7'b0000001);
  assign MulF   = P.ZMMUL_SUPPORTED & MExtF & ~Funct3_1F[2];
  assign DivF   = P.M_SUPPORTED & ~(P.IDIV_ON_FPU & P.F_SUPPORTED) & MExtF & Funct3_1F[2];
  assign Slot0ReadsFPF = (&Instr0F[1:0]) &
                         ((Op0F == 7'b0100111) | (Op0F == 7'b1010011) |       // FP store, FP arithmetic
                          (Op0F[6:4] == 3'b100) & (Op0F[1:0] == 2'b11));      // fmadd, fmsub, fnmsub, fnmadd
  assign MduOKF = MulF | (DivF & ~IsBranch0F & ~Slot0ReadsFPF);

  // A conditional branch may sit in slot 1 when:
  //   slot 0 is not also a branch.  The bundle then has one branch, so one BTB entry and one
  //     direction prediction describe it.  Slot 0 jumps never pair at all.
  //   slot 0 is not a divide or a floating-point operation, either of which can hold Execute
  //     (DivBusyE, FDivBusyE).  hazard.sv does not let a misprediction flush Execute while it is held,
  //     but it still flushes Decode, which drops InstrValidD and with it BPWrongE, so the redirect
  //     would be lost before the stall ends.  Single-issue Wally never has a branch in Execute
  //     beside a busy divider; this keeps it that way.  A multiply never holds Execute, so it pairs.
  //   compressed instructions are supported.  Then a branch target is never misaligned; without
  //     them it can be, and the fault would belong to slot 1, which has no trap identity.
  // A jal (or c.j, c.jal) in slot 1 follows the same rules: the predictor sees it exactly as it sees
  // a slot 1 branch that is always taken -- one control transfer per bundle, looked up and trained at
  // the bundle's address -- and the first time it is seen it redirects from Execute like a mispredicted
  // branch.  It may sit beside a slot 0 load or store: its target reaches the BTB in Memory on its own
  // register (IEUAdr1M in ifu.sv), not on the load/store unit's address.
  //   addi a0,a0,1 ; j loop       pairs
  //   sw   a0,0(a1); jal ra,f     pairs
  //   beqz a0,out  ; j loop       does not: two control transfers
  assign Branch1OKF = P.ZCA_SUPPORTED & ~IsBranch0F & ~(Slot0IsMduF & Instr0F[14]) & ~Slot0ReadsFPF;

  always_comb
    // A compressed slot 1 cannot go through the opcode whitelist below -- Instr1F[6:0] is not an
    // opcode for a 16-bit instruction.  instrfields vouches for it instead: the formats it decodes
    // today are all single-cycle ALU operations, so recognition and class-legality coincide.  Adding
    // a non-ALU compressed format there for its register fields must come with a separate class
    // signal, or it would silently become pairable here.
    // A compressed slot 1 is admitted on instrfields' recognition, which includes c.sw/c.swsp (and
    // c.sd/c.sdsp on RV64) but not the FP loads and stores.  c.beqz, c.bnez, c.j and c.jal follow the
    // same control-transfer rule as their 32-bit forms below (IsBranch1F and IsJal1F are only ever set
    // for an encoding instrfields recognized).
    //   addi a5,a5,1 ; c.j loop     pairs: Branch1OKF is 1
    //   beqz a4,out  ; c.j loop     does not: two control transfers in one bundle
    if (~&Instr1F[1:0]) begin
      if (IsBranch1F | IsJal1F) Slot1CanPairF = Branch1OKF;     // c.beqz, c.bnez, c.j, c.jal
      else                      Slot1CanPairF = Recognized1F;   // everything else instrfields decodes
    end else case (Op1F)
      BRANCH, JAL: Slot1CanPairF = Branch1OKF;
      LUI, AUIPC: Slot1CanPairF = 1'b1;
      OP_IMM:     Slot1CanPairF = 1'b1;
      OP:         Slot1CanPairF = ~MExtF | MduOKF;
      OP_IMM_32:  Slot1CanPairF = (P.XLEN == 64);
      // On OP-32, funct3 001-011 with funct7 = 0000001 is reserved; mulw and the four W divides are not
      OP_32:      Slot1CanPairF = (P.XLEN == 64) & (~MExtF | (MduOKF & ((Funct3_1F == 3'b000) | Funct3_1F[2])));
      // A load or a store may pair; the load/store unit handles either slot equally well.  A slot 1
      // access that faults is replayed, which withholds FlushW so that slot 0 can still commit, so for
      // a store something else must keep the write from reaching memory.  The LSU does it: an access
      // that raises its own fault drives LSUFlushW (SelfFaultM in lsu.sv), which stops the cache, bus
      // and DTIM write in the same cycle, before the replay refetches the store to trap alone.  A store
      // beside a slot 0 branch is safe because ieu.sv never makes that branch a late one: it resolves
      // in Execute, and Kill1E removes the store before it reaches Memory.
      //
      // Funct3 is checked even though replay would also catch an illegal width: the decoder's LFunctD
      // leaves ControlsD at its illegal default, which carries MemRW = 00, so no access is made either
      // way.  Checking here declines to pair rather than issuing and then undoing it, and keeps the
      // rule the same for a configuration whose decoder does not examine funct3 at all.
      LOAD:       case (Funct3_1F)
                    3'b011, 3'b110: Slot1CanPairF = (P.XLEN == 64);   // ld, lwu
                    3'b111:         Slot1CanPairF = 1'b0;             // reserved
                    default:        Slot1CanPairF = 1'b1;             // lb, lh, lw, lbu, lhu
                  endcase
      STORE:      case (Funct3_1F)
                    3'b000, 3'b001, 3'b010: Slot1CanPairF = 1'b1;              // sb, sh, sw
                    3'b011:                 Slot1CanPairF = (P.XLEN == 64);   // sd
                    default:                Slot1CanPairF = 1'b0;             // reserved
                  endcase
      default:    Slot1CanPairF = 1'b0;
    endcase

  // Slot 1 may read slot 0's result only through the late ALU in the Memory stage.  Forwarding it
  // within Execute would chain one ALU into the other and roughly double the critical path; one
  // stage later slot 0's result is already in its IEUResultM register, and the late ALU takes it
  // from there.  Rd0F is treated as a destination whenever it is nonzero, which is conservative for
  // stores and branches (where those bits are part of the immediate) but never unsafe.
  assign SrcDepF = (Rd0F != 5'b0) & ((Rs1_1F == Rd0F) | (Rs2_1F == Rd0F));
  assign SameRdF = (Rd0F != 5'b0) & (Rd1F == Rd0F);

  // A dependent pair needs slot 0's result at the start of Memory, so slot 0 must be an integer ALU
  // operation -- not a load, a multiply or divide, a CSR read or an FPU-to-integer move, whose results
  // arrive later.  The opcodes are the ones whose IEUResultE is final; a compressed slot 0 has already
  // been vouched for by instrfields, and with its memory operations and branches excluded the formats
  // left are all ALU operations.  OP and OP-32 carry the multiplies and divides at funct7 = 0000001.
  always_comb
    if (~&Instr0F[1:0]) Slot0EarlyF = ~|MemRW0F & ~IsBranch0F;
    else case (Op0F)
      LUI, AUIPC, OP_IMM: Slot0EarlyF = 1'b1;
      OP_IMM_32:          Slot0EarlyF = (P.XLEN == 64);
      OP:                 Slot0EarlyF = (Instr0F[31:25] != 7'b0000001);
      OP_32:              Slot0EarlyF = (P.XLEN == 64) & (Instr0F[31:25] != 7'b0000001);
      default:            Slot0EarlyF = 1'b0;
    endcase

  // Which operations the late ALU implements (lateok.sv).  A dependent bitmanip slot 1 simply does not
  // pair.  An encoding admitted that turns out illegal is still caught by c1 and replayed, as for any
  // slot 1.  Slot 0 is checked separately, in Decode (ieu.sv).  A compressed jump is kept out the same
  // way as a compressed branch: instrfields recognizes it, but it is not an ALU operation.
  lateok #(P) lateok1(.Instr(Instr1F), .MemRW(MemRW1F), .IsBranch(IsBranch1F | IsJal1F), .Recognized(Recognized1F), .LateOK(Slot1LateOKF));

  // Both slots may write the same register.  Slot 1 is the later instruction, so its value must win
  // everywhere: regfile.sv writes port 6 second, and controller.sv's forwarding prefers slot 1 over slot
  // 0 within a stage.  Every stall is keyed on each slot's own destination, so a younger slot 1 that
  // overwrites a slow slot 0 result (a load, say) can only cost an unneeded stall, never a stale value.
  //
  // A late pair that also shares its destination is still refused, for performance rather than
  // correctness.  Such pairs are almost always the first two links of a chain (addi a5,a5,1; slli
  // a5,a5,2; ...) whose next instruction reads the late result at once and stalls for it.  Issuing the
  // first link alone leaves the late ALU free for the second link, which gets the same work done one
  // instruction further on.  Admitting them cost rv64gc CoreMark 0.3%.
  assign DependencyOKF = ~SrcDepF | (Slot0EarlyF & LateOK1F & ~SameRdF) | Fuse1F | FuseBr1F;

  // Macro-op fusion: ALU op + dependent branch.  A branch that compares slot 0's result is fused with it
  // into one compare-and-branch op: slot 0 writes its result as usual, and the branch compares that result
  // straight from slot 0's ALU in the same Execute cycle (datapath.sv), so it resolves in Execute like any
  // other branch.
  //   andi a5, a5, 1   ; bnez a5, L        branch if (a5 & 1) != 0
  //   addw a5, a5, a4  ; blt  a5, s1, L    branch if (a5 + a4) < s1
  // Slot 0 must be an add or a logic op: the two kinds the branch can compare without waiting for slot 0's
  // ALU (datapath.sv), which keeps the fused pair off the critical path.  An add (li and mv are addi) is
  // compared by carry-save; a logic op has no carry chain, so its result is remade beside the comparator.
  // sub, shifts, slt, lui, auipc, the *w ops and Zb ops do not fuse.  The other slot 1 branch rules
  // (Branch1OKF) still apply.  The register fields of a branch are exact, so SameRdF (rd is immediate bits
  // there) does not apply.
  //   compressed:  c.addi 01_000, c.li 01_010, c.mv/c.add 10_100 (rs2 != 0, else c.jr/c.jalr/c.ebreak)
  //                c.andi 01_100 [11:10]=10;  c.xor/c.or/c.and 01_100 [11:10]=11, [12]=0, [6:5]!=00 (00 is c.sub)
  //   32-bit:      addi, add (funct3 000);  xor(i) 100, or(i) 110, and(i) 111;  add/xor/or/and need funct7 = 0
  always_comb
    if (~&Instr0F[1:0]) begin
      FuseBrAdd0F   = ({Instr0F[1:0], Instr0F[15:13]} == 5'b01_000) |                                // c.addi
                      ({Instr0F[1:0], Instr0F[15:13]} == 5'b01_010) |                                // c.li
                      ({Instr0F[1:0], Instr0F[15:13]} == 5'b10_100) & (Instr0F[6:2] != 5'b0);        // c.mv, c.add
      FuseBrLogic0F = ({Instr0F[1:0], Instr0F[15:13]} == 5'b01_100) &
                      ((Instr0F[11:10] == 2'b10) |                                                   // c.andi
                       (Instr0F[11:10] == 2'b11) & ~Instr0F[12] & (Instr0F[6:5] != 2'b00));          // c.xor, c.or, c.and
    end else begin
      FuseBrAdd0F   = ((Op0F == OP_IMM) | (Op0F == OP) & (Instr0F[31:25] == 7'b0)) & (Instr0F[14:12] == 3'b000);
      FuseBrLogic0F = ((Op0F == OP_IMM) | (Op0F == OP) & (Instr0F[31:25] == 7'b0)) &
                      Instr0F[14] & (Instr0F[13:12] != 2'b01);                                       // 100, 110, 111
    end

  assign FuseBr1F    = P.FUSION_SUPPORTED & (FuseBrAdd0F | FuseBrLogic0F) & IsBranch1F & SrcDepF;
  assign FuseBrAdd1F = FuseBrAdd0F;

  // Macro-op fusion: Indexed Load (Celio et al., arXiv 1607.02318).  An add whose only use is as the
  // address of the load right after it, which then overwrites it, is fused with that load into one
  // operation, executed by slot 0 alone:
  //   add    a0, a1, a2      \   a0 = mem[a1 + a2]          slot 0's adder makes the address, slot 0
  //   ld     a0, 0(a0)       /                              loads and writes a0; slot 1 is a bubble
  //   sh2add a5, a5, s1      \   a5 = mem[(a5 << 2) + s1]   the paper's three-instruction LEA +
  //   lw     a5, 0(a5)       /                              Indexed Load, with Zba's sh2add as the LEA
  // The pair must be strict, as in the paper: the load writes the register the add wrote, so the add's
  // result is never seen by a later instruction and the fused op needs only one register write.  And
  // the load's offset must be 0, so its address is exactly the add's sum (alu.sv's Sum, which includes
  // shNadd's pre-shift).  These do not fuse:
  //   mv  s0, a4   ; lw a4, 0(s0)     different destinations: s0 is still live after the load
  //   add a0,a1,a2 ; lw a0, 8(a0)     the address would be a1 + a2 + 8, two additions
  // Slot 0: add, sh1add/sh2add/sh3add (Zba), and c.add and c.mv, which decompress to add.  addw and the
  // .uw forms are left out: their RV64 results are not the raw sum.  Slot 1: a load that may pair at all
  // (Slot1CanPairF checks its width), or c.lw/c.ld with a zero offset ([12:10] and [6:5]).  Issue1F is
  // set as for any pair, so the PC moves past both; ieu.sv makes slot 0 the load and slot 1 a bubble.
  always_comb
    if (~&Instr0F[1:0])
      FuseAdd0F = ({Instr0F[1:0], Instr0F[15:13]} == 5'b10_100) & (Instr0F[6:2] != 5'b0);   // c.mv, c.add
    else
      FuseAdd0F = (Op0F == OP) & ((Instr0F[31:25] == 7'b0000000) & (Instr0F[14:12] == 3'b000) |  // add
                                  P.ZBA_SUPPORTED & (Instr0F[31:25] == 7'b0010000) &             // sh1add,
                                  ~Instr0F[12] & (Instr0F[14:13] != 2'b00));                     // sh2add, sh3add

  always_comb
    if (~&Instr1F[1:0])
      case ({Instr1F[1:0], Instr1F[15:13]})
        5'b00_010: FuseLoad1F = (Instr1F[12:10] == 3'b0) & (Instr1F[6:5] == 2'b0);                  // c.lw
        5'b00_011: FuseLoad1F = (P.XLEN == 64) & (Instr1F[12:10] == 3'b0) & (Instr1F[6:5] == 2'b0); // c.ld
        default:   FuseLoad1F = 1'b0;
      endcase
    else FuseLoad1F = (Op1F == LOAD) & (Instr1F[31:20] == 12'b0);

  assign Fuse1F = P.FUSION_SUPPORTED & FuseAdd0F & FuseLoad1F & (Rd0F != 5'b0) & (Rs1_1F == Rd0F) & (Rd1F == Rd0F);

  // Which of slot 1's operands are slot 0's result.  These are the same fields the pairing decision
  // used, so a dependency that permitted the pair is always marked; ieu.sv clears a bit whose operand
  // is an immediate or the PC rather than a register.
  // With LATE_ALU_SUPPORTED = 0 nothing is late, so a dependent slot 1 pairs only when fused.
  assign LateOK1F = P.LATE_ALU_SUPPORTED & Slot1LateOKF;
  assign LateA1F = (Rd0F != 5'b0) & (Rs1_1F == Rd0F);
  assign LateB1F = (Rd0F != 5'b0) & (Rs2_1F == Rd0F);

  // The core has one load/store unit, so a bundle may contain at most one memory operation -- but it
  // may sit in either slot, and ieu.sv steers the LSU's inputs to whichever one holds it.  Slot 0's
  // list is the wider: slot 1 may only hold an integer load or store, while slot 0 may also hold a
  // floating-point load or store, or an atomic, each of which occupies the LSU just the same.
  assign Slot0IsMemF = |MemRW0F;
  assign Slot1IsMemF = |MemRW1F;
  assign OneMemOpF   = ~(Slot0IsMemF & Slot1IsMemF);

  // Likewise there is one multiply/divide unit, so a bundle may hold at most one MDU operation.  Only
  // 32-bit encodings are MDU operations here: c.mul is not recognized by instrfields, so a compressed
  // slot never pairs as one, and for a compressed slot 0 bits 31:25 belong to the next instruction.
  assign Slot0IsMduF = (&Instr0F[1:0]) & ((Op0F == OP) | (Op0F == OP_32)) & (Instr0F[31:25] == 7'b0000001);
  assign Slot1IsMduF = (&Instr1F[1:0]) & ((Op1F == OP) | (Op1F == OP_32)) & MExtF;
  assign OneMduOpF   = ~(Slot0IsMduF & Slot1IsMduF);

  // With SUPERSCALAR_SUPPORTED = 0 slot 1 never issues, and every slot 1 path below is constant.
  assign Issue1F = P.SUPERSCALAR_SUPPORTED & Instr1ValidF & BothRecognizedF & Slot0CanPairF & Slot1CanPairF &
                   DependencyOKF & OneMemOpF & OneMduOpF;

endmodule
