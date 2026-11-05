//////////////////////////////////////////////////////////////////////
// WALLY-debug-Sdext_debug_mode_m_priv
//
// Rule Sdext_debug_mode_m_priv: "All operations are executed with
// machine mode privilege, except that additional Debug Mode CSRs are
// accessible and mprv in mstatus may be ignored according to
// mprven."
//
// Halt the hart in U-mode (ebreak with ebreaku=1, mcounteren=0).
// Abstract commands then write and read M-mode CSRs (mscratch, mepc)
// and read mcycle; each must succeed (cmderr=0) and return the
// written value, because Debug Mode runs with M-mode privilege.
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
