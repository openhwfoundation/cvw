// C Runtime entry point
// James Kaden Cassidy
// kacassidy@hmc.edu
// 1/21/2026

.extern return_sub_test
.extern fail

    .section .text.init
    .globl sub_test
    .type  sub_test, @function

sub_test:
    test1:
        li   t0, 9
        li   t1, 4
        sub  t2, t0, t1
        li   t3, 5
        beq  t2, t3, test2
        j Fail_Sub_1

    test2:
        li   t0, 27
        li   t1, 14
        sub  t2, t0, t1
        li   t3, 13
        beq  t2, t3, pass
        j Fail_Sub_2

    pass:
        j return_sub_test

Fail_Sub_1:
    li   gp, 401
    j    fail

Fail_Sub_2:
    li   gp, 402
    j    fail
