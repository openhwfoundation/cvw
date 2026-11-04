//////////////////////////////////////////////////////////////////////
// WALLY-debug-dcsr_extcause_op
//
// Rule dcsr_extcause_op: "When cause is 7, this optional field
// contains the value of a more specific halt reason than "other."
// Otherwise it contains 0."
//
// Enter Debug Mode by haltreq (cause 3), ebreak (1) and step (4).
// extcause (dcsr[26:24]) must read 0 each time, because cause is not
// 7.
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
