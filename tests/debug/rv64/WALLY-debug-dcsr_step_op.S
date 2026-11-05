//////////////////////////////////////////////////////////////////////
// WALLY-debug-dcsr_step_op
//
// Rule dcsr_step_op: "When set and not in Debug Mode, the hart will
// only execute a single instruction and then enter Debug Mode."
//
// With dcsr.step=1, resume twice. Each resume executes exactly one
// instruction and re-enters Debug Mode: after two steps s2=1, s3=1,
// s4=0, and dpc = the third addi.
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

probe:
   addi s2, s2, 1
   addi s3, s3, 1
   addi s4, s4, 1
   ebreak

SDEXT_END
