// Upper immediate and jump tests
// Tests: jalr, lui, auipc
// Sadhvi Narayanan
// sanarayanan@hmc.edu
// 2/5/2026


.extern return_upper_tests
.extern fail

    .section .text.init
    .globl upper_tests
    .type  upper_tests, @function

upper_tests:

    // JALR tests
    test_jalr_1:
        la   t0, jalr_target1
        jalr t1, t0, 0
        j    Fail_Jalr_1
    jalr_target1:

    test_jalr_2:
        la   t0, jalr_target2
        addi t0, t0, -8
        jalr t1, t0, 8
        j    Fail_Jalr_2
    jalr_target2:

    test_jalr_3:
        la   t0, jalr_target3
        addi t0, t0, 12
        jalr t1, t0, -12
        j    Fail_Jalr_3
    jalr_target3:

    // LUI tests
    test_lui_1:
        lui  t0, 0x12345
        li   t1, 0x12345000
        beq  t0, t1, test_lui_2
        j    Fail_Lui_1

    test_lui_2:
        lui  t0, 0xFFFFF
        li   t1, 0xFFFFF000
        beq  t0, t1, test_lui_3
        j    Fail_Lui_2

    test_lui_3:
        lui  t0, 0
        li   t1, 0
        beq  t0, t1, test_lui_4_hazard
        j    Fail_Lui_3

    test_lui_4_hazard:
        lui   t2, 0x1      # t2 = 0x1000
        addi  t2, t2, -4   # t2 = 0xFFC (account for PC increment)
        lui   t3, 0x1      # t3 = 0x1000
        addi  t3, t3, -4   # t3 = 0xFFC (account for PC increment)
        beq   t2, t3, test_auipc_1
        j     Fail_Auipc_4_hazard

    // AUIPC tests
    test_auipc_1:
        auipc t0, 0
        add   t1, t0, zero
        beq   t0, t1, test_auipc_2
        j     Fail_Auipc_1

    test_auipc_2:
        auipc t0, 0x1      # t0 = PC + 0x1000
        auipc t1, 0        # t1 = PC
        sub   t2, t0, t1   # Should be close to 0x1000
        lui   t3, 0x1      # t3 = 0x1000
        addi  t3, t3, -4   # t3 = 0xFFC (account for PC increment)
        beq   t2, t3, test_auipc_3
        j     Fail_Auipc_2

    test_auipc_3:
        auipc t0, 0
        auipc t1, 0
        sub   t2, t1, t0
        li    t3, 4
        beq   t2, t3, pass
        j     Fail_Auipc_3

    pass:
        j return_upper_tests

Fail_Jalr_1:
    li   gp, 453
    j    fail

Fail_Jalr_2:
    li   gp, 454
    j    fail

Fail_Jalr_3:
    li   gp, 455
    j    fail

Fail_Lui_1:
    li   gp, 456
    j    fail

Fail_Lui_2:
    li   gp, 457
    j    fail

Fail_Lui_3:
    li   gp, 458
    j    fail

Fail_Auipc_4_hazard:
    li   gp, 459
    j    fail

Fail_Auipc_1:
    li   gp, 460
    j    fail

Fail_Auipc_2:
    li   gp, 461
    j    fail

Fail_Auipc_3:
    li   gp, 462
    j    fail
