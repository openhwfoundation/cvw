// Load/Store byte and halfword tests
// Tests: lb, lbu, lh, lhu, sb, sh
// Sadhvi Narayanan
// sanarayanan@hmc.edu
// 2/5/2026


.extern return_loadstore_tests
.extern fail

    .section .text.init
    .globl loadstore_tests
    .type  loadstore_tests, @function

loadstore_tests:

    // Setup base address
    // li   s0, 0x200
    li   s0, 0x80001100

    // LB/LBU/SB tests
    test_lb_1:
        li   t0, 0xFF
        sb   t0, 0(s0)
        lb   t1, 0(s0)
        li   t2, 0xFFFFFFFF
        beq  t1, t2, test_lbu_1
        j    Fail_Lb_1

    test_lbu_1:
        lbu  t1, 0(s0)
        li   t2, 0x000000FF
        beq  t1, t2, test_lb_2
        j    Fail_Lbu_1

    test_lb_2:
        li   t0, 0x7F
        sb   t0, 1(s0)
        lb   t1, 1(s0)
        li   t2, 0x0000007F
        beq  t1, t2, test_lb_3
        j    Fail_Lb_2

    test_lb_3:
        li   t0, 0x80
        sb   t0, 2(s0)
        lb   t1, 2(s0)
        li   t2, 0xFFFFFF80
        beq  t1, t2, test_lb_4
        j    Fail_Lb_3

    test_lb_4:
        li   t0, 0x12
        sb   t0, 3(s0)
        lbu  t1, 3(s0)
        li   t2, 0x12
        beq  t1, t2, test_lh_1
        j    Fail_Lb_4

    // LH/LHU/SH tests
    test_lh_1:
        li   t0, 0xFFFF
        sh   t0, 4(s0)
        lh   t1, 4(s0)
        li   t2, 0xFFFFFFFF
        beq  t1, t2, test_lhu_1
        j    Fail_Lh_1

    test_lhu_1:
        lhu  t1, 4(s0)
        li   t2, 0x0000FFFF
        beq  t1, t2, test_lh_2
        j    Fail_Lhu_1

    test_lh_2:
        li   t0, 0x7FFF
        sh   t0, 6(s0)
        lh   t1, 6(s0)
        li   t2, 0x00007FFF
        beq  t1, t2, test_lh_3
        j    Fail_Lh_2

    test_lh_3:
        li   t0, 0x8000
        sh   t0, 8(s0)
        lh   t1, 8(s0)
        li   t2, 0xFFFF8000
        beq  t1, t2, test_lh_4
        j    Fail_Lh_3

    test_lh_4:
        li   t0, 0x1234
        sh   t0, 10(s0)
        lhu  t1, 10(s0)
        li   t2, 0x1234
        beq  t1, t2, pass
        j    Fail_Lh_4

    pass:
        j return_loadstore_tests

Fail_Lb_1:
    li   gp, 429
    j    fail

Fail_Lbu_1:
    li   gp, 430
    j    fail

Fail_Lb_2:
    li   gp, 431
    j    fail

Fail_Lb_3:
    li   gp, 432
    j    fail

Fail_Lb_4:
    li   gp, 433
    j    fail

Fail_Lh_1:
    li   gp, 434
    j    fail

Fail_Lhu_1:
    li   gp, 435
    j    fail

Fail_Lh_2:
    li   gp, 436
    j    fail

Fail_Lh_3:
    li   gp, 437
    j    fail

Fail_Lh_4:
    li   gp, 438
    j    fail
