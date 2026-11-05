//////////////////////////////////////////////////////////////////////
// WALLY-debug-dcsr_acc
//
// Rule dcsr_acc: "This CSR is read/write."
//
// Write dcsr with different values of the writable fields
// (ebreakm/s/u, step, prv) and read each back.
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
