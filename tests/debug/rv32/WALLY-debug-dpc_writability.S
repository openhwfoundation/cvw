//////////////////////////////////////////////////////////////////////
// WALLY-debug-dpc_writability
//
// Rule dpc_writability: "The writability of dpc follows the same
// rules as mepc as defined in the Privileged Spec. In particular,
// dpc must be able to hold all valid virtual addresses and the
// writability of the low bits depends on IALIGN."
//
// dpc follows mepc's writability: it holds every XLEN-bit value
// except bit 0, which is 0 because IALIGN=16 (C is implemented).
// Write all ones, then a value with bits 1 and 0 set, and read each
// back.
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
