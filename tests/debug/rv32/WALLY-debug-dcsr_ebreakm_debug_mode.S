//////////////////////////////////////////////////////////////////////
// WALLY-debug-dcsr_ebreakm_debug_mode
//
// Rule dcsr_ebreakm_debug_mode: "ebreak instructions in M-mode enter
// Debug Mode."
//
// Resume in M-mode at an ebreak with dcsr.ebreakm=1 (the other
// ebreak bits clear). The ebreak must enter Debug Mode: the hart is
// halted with dcsr.cause=1, dcsr.prv=3, dpc = the ebreak, and no
// trap was taken (mcause unchanged, s11=0).
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

probe:
   ebreak
   mv   s2, s9            // mcause recorded by trap_handler
   mv   s3, s11           // traps taken
done:
   j    done

SDEXT_END
