//////////////////////////////////////////////////////////////////////
// WALLY-debug-Sdext_step_trap
//
// Rule Sdext_step_trap: "If control is transferred to a trap handler
// while executing the instruction, then Debug Mode is re-entered
// immediately after the PC is changed to the trap handler, and the
// appropriate tval and cause registers are updated. In this case
// none of the trap handler is executed, and if the cause was a
// pending interrupt no instructions might be executed at all."
//
// Step over an instruction that traps: an illegal instruction in
// M-mode, and an ecall in U-mode. Each time the hart must halt with
// dpc = the trap handler (mtvec), mcause/mepc/mtval updated,
// dcsr.prv = M (the handler's mode), and no handler instruction
// executed (s11=0).
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

m_illegal:
   csrr s6, 0x8ff        // illegal instruction
   addi s2, s2, 1
u_ecall:
   ecall
   addi s3, s3, 1

SDEXT_END
