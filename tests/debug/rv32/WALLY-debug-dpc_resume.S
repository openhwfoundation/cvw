//////////////////////////////////////////////////////////////////////
// WALLY-debug-dpc_resume
//
// Rule dpc_resume: "When resuming, the hart's PC is updated to the
// virtual address stored in dpc."
//
// Write dpc with an address other than the halt address and resume;
// the hart must continue there. (1) M-mode, dpc = a 2-byte-aligned
// c.li: s2=6 at the next ebreak, and dpc = that ebreak. (2) With
// Sv39/Sv32 translation on (virtual 0x40000000 maps to physical
// 0x80000000), resume in S-mode with dpc = the virtual alias of
// s_target: s3=1 at the next ebreak, and dpc = that ebreak's virtual
// address.
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

.option push
.option rvc
.balign 4
   c.nop
target:
   c.li  s2, 5
   c.addi s2, 1
.option pop
target_ebreak:
   ebreak
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
   ebreak
s_target:
   addi s3, s3, 1
s_target_ebreak:
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
