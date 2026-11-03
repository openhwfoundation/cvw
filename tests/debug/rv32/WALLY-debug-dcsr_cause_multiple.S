//////////////////////////////////////////////////////////////////////
// WALLY-debug-dcsr_cause_multiple
//
// Rule dcsr_cause_multiple: "When there are multiple reasons to
// enter Debug Mode in a single cycle, hardware should set cause to
// the cause with the highest priority."
//
// Step (dcsr.step=1) over an ebreak in U-mode with ebreaku=1. Two
// reasons to enter Debug Mode occur together; dcsr.cause must be the
// higher-priority one, ebreak (1), not step (4).
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
