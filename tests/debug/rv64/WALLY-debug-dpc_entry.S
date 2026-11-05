//////////////////////////////////////////////////////////////////////
// WALLY-debug-dpc_entry
//
// Rule dpc_entry: "Upon entry to debug mode, dpc is updated with the
// virtual address of the next instruction to be executed."
//
// dpc must hold the virtual address. The program maps virtual
// 0x40000000 onto physical 0x80000000 (Sv39 gigapage on RV64, Sv32
// megapage on RV32) plus an identity mapping. M-mode setup code
// turns on translation and enters S-mode at the virtual alias of
// s_code with mret. The S-mode ebreak must halt with dpc = the
// ebreak's virtual address; then a step from the virtual address of
// s_code must give dpc = the next virtual address.
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

vm_setup:
   la   t0, pt_root
   srli t0, t0, 12
#if __riscv_xlen == 64
   li   t1, 8
   slli t1, t1, 60
#else
   li   t1, 1
   slli t1, t1, 31
#endif
   or   t0, t0, t1
   csrw satp, t0
   sfence.vma
   la   t0, s_code
   li   t1, 0x40000000
   sub  t0, t0, t1           // virtual alias of s_code
   csrw mepc, t0
   li   t0, 0x1800
   csrc mstatus, t0
   li   t0, 0x0800           // MPP = S
   csrs mstatus, t0
   mret
s_code:
   addi s2, s2, 1
s_ebreak:
   ebreak

SDEXT_END
.data
.balign 4096
pt_root:
#if __riscv_xlen == 64
   .dword 0
   .dword (0x80000 << 10) | 0xcf     // VA 0x40000000 -> PA 0x80000000
   .dword (0x80000 << 10) | 0xcf     // VA 0x80000000 -> PA 0x80000000
   .fill 509, 8, 0
#else
   .fill 0x100, 4, 0
   .word (0x80000 << 10) | 0xcf      // VA 0x40000000 -> PA 0x80000000
   .fill 0xff, 4, 0
   .word (0x80000 << 10) | 0xcf      // VA 0x80000000 -> PA 0x80000000
   .fill 0x1ff, 4, 0
#endif
