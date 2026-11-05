//////////////////////////////////////////////////////////////////////
// WALLY-debug-dcsr_stepie_interrupts_enabled
//
// Rule dcsr_stepie_interrupts_enabled: "Interrupts (including NMI)
// are enabled during single stepping with step set."
//
// With an interrupt pending and enabled (mstatus.MIE=1, mie.SSIE=1,
// mip.SSIP=1) and dcsr.stepie=1 (Wally implements stepie), step. The
// interrupt is taken and the hart re-enters Debug Mode at the
// handler: dpc = mtvec, mcause = supervisor software interrupt, mepc
// = the addi, which did not execute (s6=0), and no handler
// instruction executed (s11=0).
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

probe:
   addi s6, s6, 1
   addi s6, s6, 1
   ebreak

SDEXT_END
