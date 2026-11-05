//////////////////////////////////////////////////////////////////////
// WALLY-debug-dpc_acc
//
// Rule dpc_acc: "This CSR is read/write."
//
// Write dpc with two different values and read each back.
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
