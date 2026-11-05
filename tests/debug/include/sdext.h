//////////////////////////////////////////////////////////////////////
// sdext.h: shared program pieces for the Sdext rule tests
// (WALLY-debug-Sdext_*, WALLY-debug-dcsr_*, WALLY-debug-dpc_*).
//
// Register conventions
//   s2-s5   observations; test_end stores them as the signature, so
//           Spike's signature checks them
//   s6, a*  scratch observations that are not in the signature
//   s7-s11  written by trap_handler: s7=mstatus, s8=mepc, s9=mcause,
//           s10=mtval at trap entry, s11=number of traps taken
//   t5      clobbered by trap_handler
//
// SDEXT_START clears s2-s11, points mtvec at trap_handler, opens PMP
// entry 0 to all of memory (so S/U code can run), and parks in a
// loop. The debugger halts the hart there, then uses dcsr.prv and dpc
// to run the test's code in any mode. trap_handler records the trap
// and returns past the trapping (4-byte) instruction; for an
// interrupt it clears mip.SSIP and returns.
//////////////////////////////////////////////////////////////////////

#if __riscv_xlen == 64
#define SREG sd
#define LREG ld
#define REGBYTES 8
#else
#define SREG sw
#define LREG lw
#define REGBYTES 4
#endif

.macro SDEXT_START
.option norvc
.option norelax
.text
.globl rvtest_entry_point
rvtest_entry_point:
   li   s2, 0
   li   s3, 0
   li   s4, 0
   li   s5, 0
   li   s6, 0
   li   s7, 0
   li   s8, 0
   li   s9, 0
   li   s10, 0
   li   s11, 0
   la   t0, trap_handler
   csrw mtvec, t0
   li   t0, -1
   csrw pmpaddr0, t0
   li   t0, 0x1f              // entry 0: NAPOT over all memory, RWX
   csrw pmpcfg0, t0
.globl park
park:
   j    park
   // No automatic compression in the tests' code: every trapping
   // instruction is 4 bytes, so trap_handler can skip it.
.option norvc
.endm

.macro SDEXT_END
.option norvc
.balign 64
.globl trap_handler
trap_handler:
   nop                        // Spike may stop here when stepping into the handler
   csrr s7, mstatus
   csrr s8, mepc
   csrr s9, mcause
   csrr s10, mtval
   addi s11, s11, 1
   bltz s9, 1f
   addi t5, s8, 4             // exception: skip the 4-byte trapping instruction
   csrw mepc, t5
   mret
1: csrci mip, 2               // interrupt: clear mip.SSIP
   mret

.balign 4
.globl test_end
test_end:
   la   t6, begin_signature
   SREG s2, 0*REGBYTES(t6)
   SREG s3, 1*REGBYTES(t6)
   SREG s4, 2*REGBYTES(t6)
   SREG s5, 3*REGBYTES(t6)
   li   a0, 0
.globl tohost_exit
tohost_exit:
   slli a0, a0, 1
   ori  a0, a0, 1
   la   t0, tohost
   sw   a0, 0(t0)
1: j 1b

.data
.balign 16
.globl begin_signature
begin_signature:
   .fill 8, 4, 0xdeadbeef
.globl end_signature
end_signature:
   .dword 0
.balign 16
.globl scratch
scratch:
   .fill 8, 8, 0

.section .tohost, "aw", @progbits
.align 6
.globl tohost
tohost: .dword 0
.align 6
.globl fromhost
fromhost: .dword 0
.endm
