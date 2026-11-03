//////////////////////////////////////////////////////////////////////
// WALLY-debug-Sdext_debug_mode_int_masked
//
// Rule Sdext_debug_mode_int_masked: "All interrupts (including NMI)
// are masked."
//
// Halt in M-mode, then make a supervisor software interrupt pending
// and enabled (mstatus.MIE=1, mie.SSIE=1, mip.SSIP=1) while in Debug
// Mode. Check that the hart stays halted and mcause/mepc are
// untouched. After resume the interrupt is taken (s3 = mcause
// recorded by the handler).
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

probe:
   addi s2, s2, 1
probe_ebreak:
   ebreak
   addi s3, s3, 1
   ebreak

after:
   mv   s3, s9           // mcause recorded by trap_handler
   mv   s4, s11          // traps taken
   ebreak

SDEXT_END
