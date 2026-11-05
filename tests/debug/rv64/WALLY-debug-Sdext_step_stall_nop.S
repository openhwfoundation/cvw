//////////////////////////////////////////////////////////////////////
// WALLY-debug-Sdext_step_stall_nop
//
// Rule Sdext_step_stall_nop: "If the instruction being stepped over
// would normally stall the hart, then instead the instruction is
// treated as a nop. This includes wfi, wrs.sto, and wrs.nto."
//
// Step over a wfi in M-mode with no interrupt enabled. The wfi must
// act as a nop: the hart halts again with dcsr.cause=4 and dpc = the
// instruction after the wfi.
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

m_code:
   csrw mie, zero
   csrci mstatus, 8
   ebreak
m_wfi:
   wfi
   addi s2, s2, 1

SDEXT_END
