// C Runtime entry point
// James Kaden Cassidy
// kacassidy@hmc.edu
// 1/21/2026

.extern return_add_test
.extern fail

    .section .text.init
    .globl add_test
    .type  add_test, @function

add_test:
    test1:
        li   t0, 7
        li   t1, 5
        add  t2, t0, t1
        li   t3, 12
        beq  t2, t3, test2
        j Fail_Add_1

    test2:
        li   t0, 19
        li   t1, 23
        add  t2, t0, t1
        li   t3, 42
        beq  t2, t3, pass
        j Fail_Add_2

    pass:
        j return_add_test

Fail_Add_1:
    li   gp, 301
    j    fail

Fail_Add_2:
    li   gp, 302
    j    fail
