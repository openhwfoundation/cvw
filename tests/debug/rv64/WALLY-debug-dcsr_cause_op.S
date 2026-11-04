//////////////////////////////////////////////////////////////////////
// WALLY-debug-dcsr_cause_op
//
// Rule dcsr_cause_op: "Explains why Debug Mode was entered."
//
// dcsr.cause records why Debug Mode was entered and is read-only.
// Halt by haltreq (cause 3), then write dcsr with cause=7: the read-
// back cause must still be 3.
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
