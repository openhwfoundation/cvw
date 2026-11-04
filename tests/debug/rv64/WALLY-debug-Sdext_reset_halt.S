//////////////////////////////////////////////////////////////////////
// WALLY-debug-Sdext_reset_halt
//
// Rule Sdext_reset_halt: "If the halt signal (driven by the hart's
// halt request bit in the Debug Module) or resethaltreq are asserted
// when a hart comes out of reset, the hart must enter Debug Mode
// before executing any instructions, but after performing any
// initialization that would usually happen before the first
// instruction is executed."
//
// Phase 1: hold dmcontrol.haltreq while pulsing ndmreset. Phase 2:
// set resethaltreq and pulse ndmreset. Each time the hart must halt
// before executing any instruction, so dpc = the reset vector
// (0x80000000 on Wally).
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

addi s2, s2, 1

SDEXT_END
