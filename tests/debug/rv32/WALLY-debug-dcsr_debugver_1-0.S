//////////////////////////////////////////////////////////////////////
// WALLY-debug-dcsr_debugver_1-0
//
// Rule dcsr_debugver_1-0: "Debug support exists as it is described
// in this document."
//
// Read dcsr: debugver must be 4 (debug support as described in
// version 1.0).
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
