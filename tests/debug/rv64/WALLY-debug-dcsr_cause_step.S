//////////////////////////////////////////////////////////////////////
// WALLY-debug-dcsr_cause_step
//
// Rule dcsr_cause_step: "The hart single stepped because step was
// set."
//
// Step one instruction (dcsr.step=1) in M-mode and in S-mode.
// dcsr.cause must be 4 both times.
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
