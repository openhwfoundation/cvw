//////////////////////////////////////////////////////////////////////
// WALLY-debug-dcsr_nmip_op
//
// Rule dcsr_nmip_op: "When set, there is a Non-Maskable-Interrupt
// (NMI) pending for the hart."
//
// Wally has no NMI, so no NMI is ever pending and dcsr.nmip must
// read 0. Read dcsr after a halt, then write nmip=1 (a read-only
// field) and read it again.
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
