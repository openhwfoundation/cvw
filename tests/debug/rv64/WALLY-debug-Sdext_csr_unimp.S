//////////////////////////////////////////////////////////////////////
// WALLY-debug-Sdext_csr_unimp
//
// Rule Sdext_csr_unimp: "Attempts to access an unimplemented Core
// Debug Register raise an illegal instruction exception."
//
// Wally does not implement dscratch0/dscratch1. An abstract read of
// either must fail with an exception (cmderr=3). From M-mode outside
// Debug Mode, csrr of either must raise an illegal instruction
// exception (2 traps).
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

probe:
   csrr s6, dscratch0
   csrr s6, dscratch1
   mv   s2, s11
   mv   s3, s9
   ebreak

SDEXT_END
