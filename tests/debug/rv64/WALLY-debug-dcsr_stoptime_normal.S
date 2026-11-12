//////////////////////////////////////////////////////////////////////
// WALLY-debug-dcsr_stoptime_normal
//
// Rule dcsr_stoptime_normal: "time continues to reflect mtime."
//
// Wally hardwires dcsr.stoptime to 0. Read time, halt on an ebreak,
// wait in Debug Mode, resume, and read time again. time must have
// kept following mtime: the difference exceeds 1000 (s2=1); Wally's
// mtime counts clock cycles and the halt lasts many thousands of
// them.
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

probe:
   csrr s6, time
   ebreak
after:
   csrr a0, time
   sub  a0, a0, s6
   li   a1, 1000
   sltu s2, a1, a0       // s2 = (difference > 1000)
   ebreak

SDEXT_END
