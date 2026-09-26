// C Runtime entry point
// James Kaden Cassidy
// kacassidy@hmc.edu
// 1/21/2026

.extern return_or_test
.extern fail

    .section .text.init
    .globl or_test
    .type  or_test, @function

or_test:
    test1:
        li   t0, 0x0F
        li   t1, 0xF0
        or   t2, t0, t1
        li   t3, 0xFF
        beq  t2, t3, test2
        j Fail_Or_1

    test2:
        li   t0, 0x33      # 00110011
        li   t1, 0xCC      # 11001100
        or   t2, t0, t1   # = 11111111
        li   t3, 0xFF
        beq  t2, t3, pass
        j Fail_Or_2

    pass:
        j return_or_test

Fail_Or_1:
    li   gp, 101
    j    fail

Fail_Or_2:
    li   gp, 102
    j    fail
