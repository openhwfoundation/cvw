//////////////////////////////////////////////////////////////////////
// WALLY-debug-Sdext_halt_enter_debug_mode
//
// Rule Sdext_halt_enter_debug_mode: "The hart enters Debug Mode."
//
// Request a halt while the hart runs its park loop. The hart must
// enter Debug Mode: dmstatus reports it halted, and dcsr (a Debug
// Mode CSR) can be read (cmderr=0).
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

probe:
   addi s2, s2, 1
probe_ebreak:
   ebreak
   addi s3, s3, 1
   ebreak

SDEXT_END
