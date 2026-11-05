//////////////////////////////////////////////////////////////////////
// WALLY-debug-Sdext_resume_mprv
//
// Rule Sdext_resume_mprv: "If the new privilege mode is less
// privileged than M-mode, MPRV in mstatus is cleared."
//
// Set mstatus.MPRV=1 while halted, then resume in U-mode and in
// S-mode. The first instruction is an ecall; the handler records
// mstatus, which must show MPRV=0 (cleared by the resume).
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

probe:
   ecall
   ebreak

SDEXT_END
