//////////////////////////////////////////////////////////////////////
// WALLY-debug-Sdext_debug_mode_trap_no_csr_update
//
// Rule Sdext_debug_mode_trap_no_csr_update: "Because they do not
// trap to M-mode, they do not update registers such as mstatus,
// mepc, mcause, mtval, mtval2, and mtinst. The same is true for the
// equivalent privileged registers that are updated when trapping to
// other modes."
//
// Halt in M-mode and set mcause, mepc and mtval to known values. Run
// two abstract commands that raise an exception in Debug Mode (read
// of the nonexistent CSR 0x8ff, write of read-only mhartid). Check
// that mstatus, mepc, mcause and mtval are unchanged.
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
