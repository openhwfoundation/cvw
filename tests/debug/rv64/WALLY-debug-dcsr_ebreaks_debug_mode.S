//////////////////////////////////////////////////////////////////////
// WALLY-debug-dcsr_ebreaks_debug_mode
//
// Rule dcsr_ebreaks_debug_mode: "ebreak instructions in S-mode enter
// Debug Mode."
//
// Resume in S-mode at an ebreak with dcsr.ebreaks=1 (the other
// ebreak bits clear). The ebreak must enter Debug Mode: the hart is
// halted with dcsr.cause=1, dcsr.prv=1, dpc = the ebreak, and no
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
