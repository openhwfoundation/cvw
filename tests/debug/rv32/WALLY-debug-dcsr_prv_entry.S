//////////////////////////////////////////////////////////////////////
// WALLY-debug-dcsr_prv_entry
//
// Rule dcsr_prv_entry: "Contains the privilege mode the hart was
// operating in when Debug Mode was entered. The encoding is
// described in <<tab:privmode>>."
//
// Enter Debug Mode from each privilege mode and check dcsr.prv:
// ebreak in M, S and U (3, 1, 0); a step over mret with MPP=U (0,
// the mode after the mret); a step over a U-mode ecall (3, the
// handler's mode).
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

probe:
   ebreak
m_mret:
   mret
u_ecall:
   ecall
   ebreak

SDEXT_END
