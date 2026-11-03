//////////////////////////////////////////////////////////////////////
// WALLY-debug-Sdext_resume_exit_debug_mode
//
// Rule Sdext_resume_exit_debug_mode: "The hart is no longer in debug
// mode."
//
// Resume at probe in M-mode. probe reads dcsr, which is only
// accessible in Debug Mode, so it must trap (mcause=2), showing the
// hart left Debug Mode.
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

probe:
   csrr s6, dcsr         // illegal outside Debug Mode
   mv   s2, s9
   mv   s3, s11
   ebreak

SDEXT_END
