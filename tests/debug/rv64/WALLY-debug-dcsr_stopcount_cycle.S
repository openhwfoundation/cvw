//////////////////////////////////////////////////////////////////////
// WALLY-debug-dcsr_stopcount_cycle
//
// Rule dcsr_stopcount_cycle: "On single-hart cores cycle should be
// stopped, but on multi-hart cores it must keep incrementing."
//
// Wally is a single-hart core. With dcsr.stopcount=1, read mcycle,
// halt on an ebreak, wait in Debug Mode, resume, and read mcycle
// again. cycle should be stopped while halted: the difference is
// below 1000 (a1=1) although the halt lasts many thousands of
// cycles.
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

probe:
   csrr s6, mcycle
   ebreak
after:
   csrr a0, mcycle
   sub  a0, a0, s6
   sltiu a1, a0, 1000    // a1 = (difference < 1000)
   ebreak

SDEXT_END
