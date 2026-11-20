// Unsigned comparison tests
// Tests: sltu, sltiu
// Sadhvi Narayanan
// sanarayanan@hmc.edu
// 2/5/2026


.extern return_sltu_tests
.extern fail

    .section .text.init
    .globl sltu_tests
    .type  sltu_tests, @function

sltu_tests:

    // SLTU tests
    test_sltu_1:
        li   t0, 0x00000001
        li   t1, 0x00000002
        sltu t2, t0, t1
        li   t3, 1
        beq  t2, t3, test_sltu_2
        j    Fail_Sltu_1

    test_sltu_2:
        li   t0, 0xFFFFFFFF
        li   t1, 0x00000001
        sltu t2, t0, t1
        li   t3, 0
        beq  t2, t3, test_sltu_3
        j    Fail_Sltu_2

    test_sltu_3:
        li   t0, 0x7FFFFFFF
        li   t1, 0x80000000
        sltu t2, t0, t1
        li   t3, 1
        beq  t2, t3, test_sltu_4
        j    Fail_Sltu_3

    test_sltu_4:
        li   t0, 0x00000000
        li   t1, 0x00000000
        sltu t2, t0, t1
        li   t3, 0
        beq  t2, t3, test_sltiu_1
        j    Fail_Sltu_4

    // SLTIU tests
    test_sltiu_1:
        li   t0, 0x00000001
        sltiu t2, t0, 2
        li   t3, 1
        beq  t2, t3, test_sltiu_2
        j    Fail_Sltiu_1

    test_sltiu_2:
        li   t0, 0xFFFFFFFF
        sltiu t2, t0, 10
        li   t3, 0
        beq  t2, t3, test_sltiu_3
        j    Fail_Sltiu_2

    test_sltiu_3:
        li   t0, 0x00000001
        sltiu t2, t0, -1
        li   t3, 1
        beq  t2, t3, test_sltiu_4
        j    Fail_Sltiu_3

    test_sltiu_4:
        li   t0, 0x00000000
        sltiu t2, t0, -1
        li   t3, 1
        beq  t2, t3, pass
        j    Fail_Sltiu_4

    pass:
        j return_sltu_tests

Fail_Sltu_1:
    li   gp, 421
    j    fail

Fail_Sltu_2:
    li   gp, 422
    j    fail

Fail_Sltu_3:
    li   gp, 423
    j    fail

Fail_Sltu_4:
    li   gp, 424
    j    fail

Fail_Sltiu_1:
    li   gp, 425
    j    fail

Fail_Sltiu_2:
    li   gp, 426
    j    fail

Fail_Sltiu_3:
    li   gp, 427
    j    fail

Fail_Sltiu_4:
    li   gp, 428
    j    fail
