// Minimal sanity test for cv32e40s-tb: print through RVMODEL_IO_WRITE_STR, check that
// misa/marchid/cpuctrl/mcountinhibit read back as expected, then halt with RVMODEL_HALT_*.
#include "rvmodel_macros.h"
  .section .text.init
  .globl rvtest_entry_point
rvtest_entry_point:
  la    s0, msg
  RVMODEL_IO_WRITE_STR(t0, t1, t2, s0)
  csrr  a0, marchid
  li    a1, 0x15
  bne   a0, a1, fail
  csrr  a0, 0xBF0            // cpuctrl: integrity|pc_hardening|dataindtiming at reset
  li    a1, 0x19
  bne   a0, a1, fail
  csrr  a0, mcountinhibit    // cycle+instret inhibited at reset
  li    a1, 0x5
  bne   a0, a1, fail
  csrw  mcountinhibit, zero
  csrr  a2, mcycle
  nop
  nop
  csrr  a3, mcycle
  beq   a2, a3, fail
  li    a0, -1               // pmpaddr15 is writable only with PMP_NUM_REGIONS=16
  csrw  pmpaddr15, a0
  csrr  a0, pmpaddr15
#ifdef EXPECT_PMP
  beqz  a0, fail
#else
  bnez  a0, fail
#endif
#ifdef EXPECT_B
  .option push
  .option arch, +zbb, +zbc
  li    a0, 0x0f0f
  li    a1, 0x00ff
  andn  a2, a0, a1           // 0x0f00
  clmul a3, a0, a1
  .option pop
  li    a1, 0x0f00
  bne   a2, a1, fail
#endif
  la    s0, ok
  RVMODEL_IO_WRITE_STR(t0, t1, t2, s0)
  RVMODEL_HALT_PASS
fail:
  la    s0, bad
  RVMODEL_IO_WRITE_STR(t0, t1, t2, s0)
  RVMODEL_HALT_FAIL
  .data
msg: .asciz "hello from cv32e40s\n"
ok:  .asciz "csr checks ok\n"
bad: .asciz "csr check FAILED\n"
