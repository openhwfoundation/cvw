//////////////////////////////////////////////////////////////////////
// WALLY-debug-Sdext_step_deferred_fetch_exc_trigger
//
// Rule Sdext_step_deferred_fetch_exc_trigger: "If the instruction
// that is executed causes the PC to change to an address where an
// instruction fetch causes an exception, that exception does not
// occur until the next time the hart is resumed. Similarly, a
// trigger at the new address does not fire until the hart actually
// attempts to execute that instruction."
//
// Step over a jalr to 0x40000000, where there is no memory. The step
// must end with dpc = 0x40000000, dcsr.cause=4 and no trap (mcause
// unchanged). The next step then takes the instruction access fault:
// dpc = trap handler, mcause=1, mepc=0x40000000.
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

m_jump:
   jalr x0, 0(s6)        // s6 = 0x40000000 (no memory there)

SDEXT_END
