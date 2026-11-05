//////////////////////////////////////////////////////////////////////
// WALLY-debug-dcsr_prv_unsupported
//
// Rule dcsr_prv_unsupported: "If the encoding written is not
// supported or the debugger is not allowed to change to it, the hart
// may change to any supported privilege mode."
//
// Write dcsr.prv=2, an encoding no hart without H supports, and
// resume at an ecall. The hart may run in any supported mode, so the
// ecall's mcause must be 8, 9 or 11 (U, S or M) and code after it
// must reach the ebreak: s2=1.
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

probe:
   ecall
   li   a0, 8
   beq  s9, a0, 1f
   li   a0, 9
   beq  s9, a0, 1f
   li   a0, 11
   beq  s9, a0, 1f
   j    2f
1: li   s2, 1
2: ebreak

SDEXT_END
