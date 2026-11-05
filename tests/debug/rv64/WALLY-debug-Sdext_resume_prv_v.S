//////////////////////////////////////////////////////////////////////
// WALLY-debug-Sdext_resume_prv_v
//
// Rule Sdext_resume_prv_v: "The current privilege mode and
// virtualization mode are changed to that specified by prv and v."
//
// Resume at probe with dcsr.prv = U, then S, then M. probe reads
// mstatus, which traps below M; the handler records mstatus (MPP =
// the mode the hart ran in) and counts the trap. Check the trap
// count, MPP, and dcsr.prv at the next halt for each mode.
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

probe:
   csrr s6, mstatus      // illegal below M
   ebreak

SDEXT_END
