//////////////////////////////////////////////////////////////////////
// WALLY-debug-dcsr_stepie_interrupts_disabled
//
// Rule dcsr_stepie_interrupts_disabled: "Interrupts (including NMI)
// are disabled during single stepping with step set. This value
// should be supported."
//
// With an interrupt pending and enabled (mstatus.MIE=1, mie.SSIE=1,
// mip.SSIP=1) and dcsr.stepie=0, step one instruction. The interrupt
// must not be taken: dpc = the next instruction, the stepped addi
// executed (s6=1), mcause unchanged, dcsr.cause=4.
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

probe:
   addi s6, s6, 1
   addi s6, s6, 1
   ebreak

SDEXT_END
