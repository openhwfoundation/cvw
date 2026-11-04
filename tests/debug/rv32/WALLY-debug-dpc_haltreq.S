//////////////////////////////////////////////////////////////////////
// WALLY-debug-dpc_haltreq
//
// Rule dpc_haltreq: "Address of the next instruction to be executed
// at the time that debug mode was entered."
//
// The hart runs a loop of non-idempotent instructions (addi,
// amoadd.w, lw/addi/sw, csrr/addi/csrw of mscratch, ecall whose
// handler counts) 3000 times, while the debugger halts and resumes
// it 12 times with haltreq. If dpc is the next instruction to
// execute at every halt, no instruction is skipped or repeated, so
// every counter ends at 3000 (s4=1). The body appears twice so
// consecutive ecalls trap at different PCs (the testbench watchdog
// flags 100 traps in a row at one PC).
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

.option push
.option arch, +a
loop_setup:
   li   a0, 1500
   la   a1, scratch
   li   a2, 1
   sw   zero, 0(a1)
   sw   zero, 4(a1)
   csrw mscratch, zero
   li   s11, 0
lp:
   addi s2, s2, 1
   amoadd.w zero, a2, (a1)
   lw   a3, 4(a1)
   addi a3, a3, 1
   sw   a3, 4(a1)
   csrr a4, mscratch
   addi a4, a4, 1
   csrw mscratch, a4
   ecall
   addi s3, s3, 1
   addi s2, s2, 1
   amoadd.w zero, a2, (a1)
   lw   a3, 4(a1)
   addi a3, a3, 1
   sw   a3, 4(a1)
   csrr a4, mscratch
   addi a4, a4, 1
   csrw mscratch, a4
   ecall
   addi s3, s3, 1
   addi a0, a0, -1
   bnez a0, lp
   li   a5, 3000
   lw   a3, 0(a1)
   bne  a3, a5, bad
   lw   a3, 4(a1)
   bne  a3, a5, bad
   csrr a4, mscratch
   bne  a4, a5, bad
   bne  s11, a5, bad
   bne  s2, a5, bad
   bne  s3, a5, bad
   li   s4, 1
bad:
   ebreak
.option pop

SDEXT_END
