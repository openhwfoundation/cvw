//////////////////////////////////////////////////////////////////////
// WALLY-debug-dcsr_entry_update_writable
//
// Rule dcsr_entry_update_writable: "Upon entry into Debug Mode, v
// and prv are updated with the privilege level the hart was
// previously in, and cause is updated with the reason for Debug Mode
// entry. Other than these fields and nmip, the other fields of dcsr
// are only writable by the external debugger."
//
// Set ebreakm/s/u and resume in U-mode at an ebreak, then step an
// instruction in S-mode. On each entry the hart updates only prv and
// cause: the ebreak and step bits keep the debugger's values. From
// M-mode, a csrw to dcsr must trap (only the debugger writes it).
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

u_code:
   ebreak
s_code:
   addi s2, s2, 1
   ebreak
m_code:
   csrw dcsr, zero
   mv   s3, s11
   ebreak

SDEXT_END
