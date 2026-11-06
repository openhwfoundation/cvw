// Startup for running CoreMark on a core through its riscv-arch-test (ACT) configuration.
// Boots and halts with the configuration's rvmodel_macros.h and links with its link.ld, so the
// program runs on the core's ACT testbench like any ACT test.  CoreMark's output goes through
// RVMODEL_IO_WRITE_STR.  main returns 0 (CoreMark reports errors in its output), so the halt is
// the pass halt unless the startup itself fails.

#include "rvmodel_macros.h"

// Not every configuration defines every macro
#ifndef RVMODEL_BOOT
#define RVMODEL_BOOT
#endif
#ifndef RVMODEL_DATA_SECTION
#define RVMODEL_DATA_SECTION
#endif
#ifndef RVMODEL_IO_WRITE_STR
#define RVMODEL_IO_WRITE_STR(_R1, _R2, _R3, _STR_PTR)
#endif

#if __riscv_xlen == 64
#define STORE sd
#define LOAD  ld
#define REGBYTES 8
#else
#define STORE sw
#define LOAD  lw
#define REGBYTES 4
#endif

  .section .text.init
  .globl rvtest_entry_point
rvtest_entry_point:
  RVMODEL_BOOT
  la    sp, __stack_top
#ifdef __riscv_flen
  li    t0, 0x6000          // mstatus.FS = dirty: enable the FPU
  csrs  mstatus, t0
  csrwi fcsr, 0
#endif
#ifdef IBEX_ICACHE
  csrsi 0x7c0, 1            // Ibex cpuctrlsts.icache_enable: the cache resets disabled
#endif
#ifdef CV32E40S_NO_DATAINDTIMING
  csrci 0xbf0, 1            // CV32E40S cpuctrl.dataindtiming=0 (resets to 1): variable-latency div/branches
#endif
#ifdef CLEAR_MCOUNTINHIBIT
  csrw  mcountinhibit, zero // the counters reset inhibited
#endif
#ifdef VEER_MRAC
  li    t0, 0x59555555      // VeeR mrac as in VeeR's testbench crt0: cache every region but 0xD; it resets uncached
  csrw  0x7c0, t0
#endif
#ifdef VEER_STACK_TOP
  li    sp, VEER_STACK_TOP  // CoreMark's data is on the stack: put it in the DCCM, as VeeR's own CoreMark does
#endif
  la    t0, __bss_start     // zero .bss
  la    t1, __bss_end
1:
  bgeu  t0, t1, 2f
  sw    zero, 0(t0)
  addi  t0, t0, 4
  j     1b
2:
  call  main
  bnez  a0, act_fail
  RVMODEL_HALT_PASS
act_fail:
  RVMODEL_HALT_FAIL

  // void act_putchar(int c): print one character with the configuration's string macro
  .text
  .globl act_putchar
act_putchar:
  addi  sp, sp, -4*REGBYTES
  STORE ra, 0(sp)
  STORE s0, REGBYTES(sp)
  la    s0, act_putbuf
  sb    a0, 0(s0)
  sb    zero, 1(s0)
#ifdef __riscv_32e
  RVMODEL_IO_WRITE_STR(a3, a4, a5, s0)   // RV32E has no t3-t5 (x28-x30)
#else
  RVMODEL_IO_WRITE_STR(t3, t4, t5, s0)
#endif
  LOAD  ra, 0(sp)
  LOAD  s0, REGBYTES(sp)
  addi  sp, sp, 4*REGBYTES
  ret

#ifndef NO_MEMFUNCS
  // CoreMark is built with -nostdlib and -ffreestanding; GCC may still call these
  .globl memset
memset:
  mv    t0, a0
  beqz  a2, 4f
3:
  sb    a1, 0(t0)
  addi  t0, t0, 1
  addi  a2, a2, -1
  bnez  a2, 3b
4:
  ret
  .globl memcpy
memcpy:
  mv    t0, a0
  beqz  a2, 6f
5:
  lbu   t1, 0(a1)
  sb    t1, 0(t0)
  addi  t0, t0, 1
  addi  a1, a1, 1
  addi  a2, a2, -1
  bnez  a2, 5b
6:
  ret

#endif

  .data
  .align 4
act_putbuf:
  .space 16
RVMODEL_DATA_SECTION
