//////////////////////////////////////////////////////////////////////
// WALLY-debug-Sdext_debug_mode_abstract_cmd
//
// Rule Sdext_debug_mode_abstract_cmd: "When executing code due to an
// abstract command, the hart stays in Debug Mode"
//
// Halt on an ebreak, then run abstract commands (CSR write and read,
// GPR read). Check that dmstatus still reports the hart halted
// (allhalted=1, allrunning=0) after them.
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
