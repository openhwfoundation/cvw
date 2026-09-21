// C Runtime entry point
// James Kaden Cassidy
// kacassidy@hmc.edu
// 1/21/2026

.extern return_and_test
.extern fail

    .section .text.init
    .globl and_test
    .type  and_test, @function

and_test:
    test1:
        li   t0, 0x55
        li   t1, 0xAA
        and  t2, t0, t1
        li   t3, 0x00
        beq  t2, t3, test2
        j Fail_And_1

    test2:
        li   t0, 0x3C      # 00111100
        li   t1, 0xC3      # 11000011
        and  t2, t0, t1   # = 00000000
        li   t3, 0x00
        beq  t2, t3, pass
        j Fail_And_2

    pass:
        j return_and_test

Fail_And_1:
    li   gp, 201
    j    fail

Fail_And_2:
    li   gp, 202
    j    fail
