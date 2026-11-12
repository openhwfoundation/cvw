//////////////////////////////////////////////////////////////////////
// WALLY-debug-dpc_step
//
// Rule dpc_step: "Address of the instruction that would be executed
// next if no debugging was going on"
//
// Step one instruction at a time and check dpc after each: addi
// (pc+4), not-taken bne (pc+4), taken beq (target), jal (target),
// jalr (target), c.addi (pc+2), mret (mepc), sret (sepc).
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

st_addi:
   addi s2, s2, 1
st_bne:
   bne  zero, zero, st_far
st_beq:
   beq  zero, zero, st_beq_tgt
   nop
st_beq_tgt:
   jal  ra, st_jal_tgt
   nop
st_jal_tgt:
   jalr x0, 0(s6)            // s6 = st_jalr_tgt (written by the debugger)
   nop
st_jalr_tgt:
.option push
.option rvc
   c.addi s3, 1
.option pop
st_mret:
   mret
st_far:
   j    st_far
mret_tgt:
   ebreak
sret_tgt:
   ebreak
st_sret:
   sret

SDEXT_END
