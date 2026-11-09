  .option norvc
  .section .text.init
  .globl _start
_start:
  la    t0, trap
  csrw  mtvec, t0
  li    s11, 0xC0002200
  li    s1, 0xC0002000

  /* 0: load from the erroring address: expect cause 5, no register update */
  li    s2, 0xC0006000
  li    a0, 0x0
  lw    a0, 0(s2)
  li    t0, 0xC0002000
  sw    a0, 0(t0)

  /* 1: store to the erroring address: expect cause 7, no bus commit */
  li    t1, 0x5A5A5A5A
  sw    t1, 0(s2)
  li    t0, 0xC0002004
  sw    t1, 0(t0)

  /* 2: plain access to a good address (control) */
  li    s3, 0xC0006100
  li    t1, 0x12345678
  sw    t1, 0(s3)
  lw    t2, 0(s3)
  li    t0, 0xC0002008
  sw    t2, 0(t0)

  /* 3: how many traps were recorded */
  csrr  t0, mscratch
  li    t1, 0xC0002200
  sub   t0, t0, t1
  srli  t0, t0, 4
  li    t1, 0xC000200c
  sw    t0, 0(t1)

  j     done
done:
  li    t0, 0xC0003000
  li    t1, 0x0051AB1E
  sw    t1, 0(t0)
1:
  j     1b

  .section .text.init
  .align 2
trap:
  csrr  t0, mscratch
  bnez  t0, 1f
  li    t0, 0xC0002200
1:
  csrr  t1, mcause
  sw    t1, 0(t0)
  csrr  t1, mepc
  sw    t1, 4(t0)
  csrr  t1, mtval
  sw    t1, 8(t0)
  csrr  t1, mstatus
  sw    t1, 12(t0)
  addi  t0, t0, 16
  csrw  mscratch, t0
  csrr  t1, mepc
  addi  t1, t1, 4
  csrw  mepc, t1
  mret
