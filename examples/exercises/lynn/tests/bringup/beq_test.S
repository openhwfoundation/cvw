// beq_test.S
// James Kaden Cassidy
// kacassidy@hmc.edu
// Tests that beq does NOT branch when operands are unequal,
// catching the bug where the comparator always returns Eq=1.

.extern return_beq_test
.extern fail

    .section .text.init
    .globl beq_test
    .type  beq_test, @function

beq_test:
    test1:
        // beq should NOT branch: 5 != 7
        li   t0, 5
        li   t1, 7
        beq  t0, t1, Fail_Beq_1    // must NOT be taken
        j    test2

    test2:
        // beq SHOULD branch: 9 == 9
        li   t0, 9
        li   t1, 9
        beq  t0, t1, pass
        j    Fail_Beq_2

    pass:
        j return_beq_test

Fail_Beq_1:
    li   gp, 501
    j    fail

Fail_Beq_2:
    li   gp, 502
    j    fail
