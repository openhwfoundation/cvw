//////////////////////////////////////////////////////////////////////
// WALLY-debug-Sdext_csr_per_hart_access
//
// Rule Sdext_csr_per_hart_access: "The supported Core Debug
// Registers must be implemented for each hart that can be debugged.
// They are CSRs, accessible using the RISC-V csr opcodes and
// optionally also using abstract debug commands."
//
// Halt the (only) hart and read dcsr and dpc with abstract commands.
// Both reads must succeed (cmderr=0); dcsr.debugver must be nonzero
// and dpc must hold the halt address.
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
