//////////////////////////////////////////////////////////////////////
// WALLY-debug-dcsr_cause_ebreak
//
// Rule dcsr_cause_ebreak: "An ebreak instruction was executed."
//
// Run probe in M-mode with dcsr.ebreakm=1; the ebreak halts the
// hart. dcsr.cause must be 1.
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
