// C Runtime entry point
// James Kaden Cassidy
// kacassidy@hmc.edu
// 12/19/2025

    .extern main

    .section .text.init
    .globl fail
    .globl finish
    .globl pass
    .globl end
    .globl rvtest_entry_point
    .type  rvtest_entry_point, @function

rvtest_entry_point:
    /* ---- stack pointer ---- */
    li   sp, 0

    /* ---- zero all integer registers (except x0, sp) ---- */
    li   ra, 0        /* x1  */
    li   gp, 0        /* x3  */
    li   tp, 0        /* x4  */

    li   t0, 0        /* x5  */
    li   t1, 0        /* x6  */
    li   t2, 0        /* x7  */

    li   s0, 0        /* x8  / fp */
    li   s1, 0        /* x9  */

    li   a0, 0        /* x10 */
    li   a1, 0        /* x11 */
    li   a2, 0        /* x12 */
    li   a3, 0        /* x13 */
    li   a4, 0        /* x14 */
    li   a5, 0        /* x15 */
    li   a6, 0        /* x16 */
    li   a7, 0        /* x17 */

    li   s2, 0        /* x18 */
    li   s3, 0        /* x19 */
    li   s4, 0        /* x20 */
    li   s5, 0        /* x21 */
    li   s6, 0        /* x22 */
    li   s7, 0        /* x23 */
    li   s8, 0        /* x24 */
    li   s9, 0        /* x25 */
    li   s10, 0       /* x26 */
    li   s11, 0       /* x27 */

    li   t3, 0        /* x28 */
    li   t4, 0        /* x29 */
    li   t5, 0        /* x30 */
    li   t6, 0        /* x31 */

    /* ---- main entry ---- */
    j main

finish:
    /* write gp (exit code) to tohost and end simulation */
    /* la   t0, tohost */
    li  t0, 0x400        # 1024, safe imm12
    li  t1, 0x001        # 1, safe imm12

    # t0 = 0x400 << 21 = 0x80000000
    add t0, t0, t0       # 1
    add t0, t0, t0       # 2
    add t0, t0, t0       # 3
    add t0, t0, t0       # 4
    add t0, t0, t0       # 5
    add t0, t0, t0       # 6
    add t0, t0, t0       # 7
    add t0, t0, t0       # 8
    add t0, t0, t0       # 9
    add t0, t0, t0       # 10
    add t0, t0, t0       # 11
    add t0, t0, t0       # 12
    add t0, t0, t0       # 13
    add t0, t0, t0       # 14
    add t0, t0, t0       # 15
    add t0, t0, t0       # 16
    add t0, t0, t0       # 17
    add t0, t0, t0       # 18
    add t0, t0, t0       # 19
    add t0, t0, t0       # 20
    add t0, t0, t0       # 21   -> t0 = 0x8000_0000

    sw   gp, 0(t0)
    sw   x0, 4(t0)
1:
    j    1b

    la   t0,tohost # need to load tohost so garbage collection sees it

fail:
    /* encode a non-1 fail code (gp already holds something else if you want) */
    add  gp, gp, gp # failure code needs to be shifted left by 1 # exit needs 1 in bottom most bit
    addi gp, gp, 1
    j    finish

pass:
    /* encode a non-1 fail code (gp already holds something else if you want) */
    li   gp, 1
    j    finish

/* to host data section */
    .section .tohost,"aw",@progbits
    .balign 4
    .globl tohost

tohost:
    .dword 0
