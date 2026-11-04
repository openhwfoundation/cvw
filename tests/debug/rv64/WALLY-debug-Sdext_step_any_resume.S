//////////////////////////////////////////////////////////////////////
// WALLY-debug-Sdext_step_any_resume
//
// Rule Sdext_step_any_resume: "If step is set when a hart resumes
// then it will single step, regardless of the reason for resuming."
//
// With dcsr.step=1, resume at m_code. The hart executes one
// instruction and halts again: dcsr.cause=4, dpc = the next
// instruction, s2=1 and s3=0.
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

m_code:
   addi s2, s2, 1
   addi s3, s3, 1
   ebreak

SDEXT_END
