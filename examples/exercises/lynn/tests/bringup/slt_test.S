// slt_test.S
// James Kaden Cassidy
// kacassidy@hmc.edu
// Tests slt, including an overflow case that catches the bug
// where LT = Neg instead of the correct Neg ^ Overflow.

.extern return_slt_test
.extern fail

    .section .text.init
    .globl slt_test
    .type  slt_test, @function

slt_test:
    test1:
        // Basic: 3 < 5, slt should write 1
        li   t0, 3
        li   t1, 5
        slt  t2, t0, t1
        li   t3, 1
        beq  t2, t3, test2
        j    Fail_Slt_1

    test2:
        // Overflow case: build t0 = 0x80000000 (-2147483648) via doubling.
        // 0x400 << 21 = 0x80000000  (same trick used in crt0.S)
        // slt t2, t0, t1 with t0=-2147483648, t1=1 must return 1.
        // Sub: Sum = 0x7FFFFFFF, Neg=0, Overflow=1
        // Correct:  LT = Neg ^ Overflow = 0 ^ 1 = 1
        // Bug D:    LT = Neg             = 0     = 0  (wrong)
        li   t0, 0x400
        add  t0, t0, t0     // 0x800
        add  t0, t0, t0     // 0x1000
        add  t0, t0, t0     // 0x2000
        add  t0, t0, t0     // 0x4000
        add  t0, t0, t0     // 0x8000
        add  t0, t0, t0     // 0x10000
        add  t0, t0, t0     // 0x20000
        add  t0, t0, t0     // 0x40000
        add  t0, t0, t0     // 0x80000
        add  t0, t0, t0     // 0x100000
        add  t0, t0, t0     // 0x200000
        add  t0, t0, t0     // 0x400000
        add  t0, t0, t0     // 0x800000
        add  t0, t0, t0     // 0x1000000
        add  t0, t0, t0     // 0x2000000
        add  t0, t0, t0     // 0x4000000
        add  t0, t0, t0     // 0x8000000
        add  t0, t0, t0     // 0x10000000
        add  t0, t0, t0     // 0x20000000
        add  t0, t0, t0     // 0x40000000
        add  t0, t0, t0     // 0x80000000
        li   t1, 1
        slt  t2, t0, t1
        li   t3, 1
        beq  t2, t3, pass
        j    Fail_Slt_2

    pass:
        j return_slt_test

Fail_Slt_1:
    li   gp, 601
    j    fail

Fail_Slt_2:
    li   gp, 602
    j    fail
