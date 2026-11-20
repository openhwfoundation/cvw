// Shift instruction tests
// Tests: sll, slli, srl, srli, sra, srai
// Sadhvi Narayanan
// sanarayanan@hmc.edu
// 2/5/2026


.extern return_shift_tests
.extern fail

    .section .text.init
    .globl shift_tests
    .type  shift_tests, @function

shift_tests:

    // SLL tests - this first test also tests the data hazards
    test_sll_hazard:
        li   t0, 0x00000001
        sll  t2, t0, t0      # Use t0 twice (needs forwarding from WB→EX)
        li   t0, 0x00000002  # 1 << 1 = 2
        beq  t2, t0, test_sll_2
        j    Fail_Sll_1

    test_sll_2:
        li   t0, 1
        li   t1, 4
        sll  t2, t0, t1      # Normal case
        sll  t3, t2, t1      # Back-to-back: t3 uses t2 (needs MEM→EX forwarding)
        li   t4, 0x100       # (1 << 4) << 4 = 256
        beq  t3, t4, test_sll_3
        j    Fail_Sll_2

    test_sll_3:
        li   t0, 1
        sll  t1, t0, t0      # Chain: t1 depends on t0
        sll  t2, t1, t1      # t2 depends on t1
        sll  t3, t2, t2      # t3 depends on t2 (multiple dependencies)
        li   t4, 0x100       # 1 << 1 = 2, 2 << 2 = 8, 8 << 8 = 2048 = 0x800
        # Actually: 1<<1=2, 2<<2=8, 8<<8=2048
        li   t4, 0x800       # 2048
        beq  t3, t4, pass
        j    Fail_Sll_3

    // SLLI tests
    test_slli_1:
        li   t0, 0x00000001
        slli t2, t0, 4
        li   t3, 0x00000010
        beq  t2, t3, test_slli_2
        j    Fail_Slli_1

    test_slli_2:
        li   t0, 0x00000001
        slli t2, t0, 31
        li   t3, 0x80000000
        beq  t2, t3, test_slli_3
        j    Fail_Slli_2

    test_slli_3:
        li   t0, 0xFFFFFFFF
        slli t2, t0, 4
        li   t3, 0xFFFFFFF0
        beq  t2, t3, test_srl_1
        j    Fail_Slli_3

    // SRL tests
    test_srl_1:
        li   t0, 0x80000000
        li   t1, 4
        srl  t2, t0, t1
        li   t3, 0x08000000
        beq  t2, t3, test_srl_2
        j    Fail_Srl_1

    test_srl_2:
        li   t0, 0x80000000
        li   t1, 31
        srl  t2, t0, t1
        li   t3, 0x00000001
        beq  t2, t3, test_srl_3
        j    Fail_Srl_2

    test_srl_3:
        li   t0, 0xFFFFFFFF
        li   t1, 4
        srl  t2, t0, t1
        li   t3, 0x0FFFFFFF
        beq  t2, t3, test_srli_1
        j    Fail_Srl_3

    // SRLI tests
    test_srli_1:
        li   t0, 0x80000000
        srli t2, t0, 4
        li   t3, 0x08000000
        beq  t2, t3, test_srli_2
        j    Fail_Srli_1

    test_srli_2:
        li   t0, 0x80000000
        srli t2, t0, 31
        li   t3, 0x00000001
        beq  t2, t3, test_srli_3
        j    Fail_Srli_2

    test_srli_3:
        li   t0, 0xFFFFFFFF
        srli t2, t0, 4
        li   t3, 0x0FFFFFFF
        beq  t2, t3, test_sra_1
        j    Fail_Srli_3

    // SRA tests
    test_sra_1:
        li   t0, 0x80000000
        li   t1, 4
        sra  t2, t0, t1
        li   t3, 0xF8000000
        beq  t2, t3, test_sra_2
        j    Fail_Sra_1

    test_sra_2:
        li   t0, 0x80000000
        li   t1, 31
        sra  t2, t0, t1
        li   t3, 0xFFFFFFFF
        beq  t2, t3, test_sra_3
        j    Fail_Sra_2

    test_sra_3:
        li   t0, 0x7FFFFFFF
        li   t1, 4
        sra  t2, t0, t1
        li   t3, 0x07FFFFFF
        beq  t2, t3, test_srai_1
        j    Fail_Sra_3

    // SRAI tests
    test_srai_1:
        li   t0, 0x80000000
        srai t2, t0, 4
        li   t3, 0xF8000000
        beq  t2, t3, test_srai_2
        j    Fail_Srai_1

    test_srai_2:
        li   t0, 0x80000000
        srai t2, t0, 31
        li   t3, 0xFFFFFFFF
        beq  t2, t3, test_srai_3
        j    Fail_Srai_2

    test_srai_3:
        li   t0, 0x7FFFFFFF
        srai t2, t0, 4
        li   t3, 0x07FFFFFF
        beq  t2, t3, pass
        j    Fail_Srai_3

    pass:
        j return_shift_tests

Fail_Sll_1:
    li   gp, 403
    j    fail

Fail_Sll_2:
    li   gp, 404
    j    fail

Fail_Sll_3:
    li   gp, 405
    j    fail

Fail_Slli_1:
    li   gp, 406
    j    fail

Fail_Slli_2:
    li   gp, 407
    j    fail

Fail_Slli_3:
    li   gp, 408
    j    fail

Fail_Srl_1:
    li   gp, 409
    j    fail

Fail_Srl_2:
    li   gp, 410
    j    fail

Fail_Srl_3:
    li   gp, 411
    j    fail

Fail_Srli_1:
    li   gp, 412
    j    fail

Fail_Srli_2:
    li   gp, 413
    j    fail

Fail_Srli_3:
    li   gp, 414
    j    fail

Fail_Sra_1:
    li   gp, 415
    j    fail

Fail_Sra_2:
    li   gp, 416
    j    fail

Fail_Sra_3:
    li   gp, 417
    j    fail

Fail_Srai_1:
    li   gp, 418
    j    fail

Fail_Srai_2:
    li   gp, 419
    j    fail

Fail_Srai_3:
    li   gp, 420
    j    fail
