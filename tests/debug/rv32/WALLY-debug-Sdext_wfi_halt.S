//////////////////////////////////////////////////////////////////////
// WALLY-debug-Sdext_wfi_halt
//
// Rule Sdext_wfi_halt: "If halt is requested while wfi is executing,
// then the hart must leave the stalled state, completing this
// instruction's execution, and then enter Debug Mode."
//
// Run M-mode code that executes wfi with no interrupt enabled, so
// the hart stalls in wfi. Request a halt. The wfi must complete: dpc
// = the instruction after the wfi. After resume, that instruction
// runs (s2=1) and the hart reaches the next ebreak.
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

m_code:
   csrw mie, zero
   csrci mstatus, 8
wfi_here:
   wfi
after_wfi:
   addi s2, s2, 1
   ebreak

SDEXT_END
