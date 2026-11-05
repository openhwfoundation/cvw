//////////////////////////////////////////////////////////////////////
// WALLY-debug-dcsr_cause_resethaltreq
//
// Rule dcsr_cause_resethaltreq: "The hart halted directly out of
// reset due to resethaltreq."
//
// Wally implements resethaltreq (dmstatus.hasresethaltreq=1). Set
// resethaltreq and pulse ndmreset; the hart halts out of reset.
// dcsr.cause must be 5 (3 is also allowed by the spec).
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
