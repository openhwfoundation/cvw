//////////////////////////////////////////////////////////////////////
// WALLY-debug-Sdext_csr_mode
//
// Rule Sdext_csr_mode: "These registers are only accessible from
// Debug Mode."
//
// From M-mode (not Debug Mode), read dcsr, dpc, dscratch0, dscratch1
// and write dcsr and dpc. Each must raise an illegal instruction
// exception: 6 traps, last mcause=2. dcsr must be unchanged by the
// write attempt.
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

probe:
   csrr s6, dcsr
   csrr s6, dpc
   csrr s6, dscratch0
   csrr s6, dscratch1
   csrw dcsr, zero
   csrw dpc, zero
   mv   s2, s11
   mv   s3, s9
   ebreak

SDEXT_END
