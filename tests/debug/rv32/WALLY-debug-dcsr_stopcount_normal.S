//////////////////////////////////////////////////////////////////////
// WALLY-debug-dcsr_stopcount_normal
//
// Rule dcsr_stopcount_normal: "Increment counters as usual."
//
// With dcsr.stopcount=0, read mcycle, halt on an ebreak, wait in
// Debug Mode, resume, and read mcycle again. The counter must have
// kept counting while halted: the difference exceeds 1000 (s2=1).
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

probe:
   csrr s6, mcycle
   ebreak
after:
   csrr a0, mcycle
   sub  a0, a0, s6
   li   a1, 1000
   sltu s2, a1, a0       // s2 = (difference > 1000)
   ebreak

SDEXT_END
