//////////////////////////////////////////////////////////////////////
// WALLY-debug-dcsr_cause_haltreq
//
// Rule dcsr_cause_haltreq: "The debugger requested entry to Debug
// Mode using haltreq."
//
// Halt with dmcontrol.haltreq while the hart runs code in M-mode and
// in U-mode. dcsr.cause must be 3 both times.
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

spin:
   addi s6, s6, 1
   j    spin

SDEXT_END
