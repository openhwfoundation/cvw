# // Sadhvi Narayanan
# // sanarayanan@hmc.edu
# // 2/5/2026

# //// ------------- Macro Version ------------- ////

# /*
# Test an instruction (op) with immediate values (a, b) loaded to
# registers t0 and t1. The result is written to t2, the expected value
# is loaded to t3, if the expected and computed values are different
# the test fails and jumps to the FAIL_LABEL macro
# */
#     .macro TEST_RR op, a, b, exp, faillabel
#         li   t0, \a
#         li   t1, \b
#         \op  t2, t0, t1
#         li   t3, \exp
#         bne  t2, t3, \faillabel
#     .endm

#     .macro TEST_RI op, a, imm, exp, faillabel
#         li   t0, \a
#         \op  t2, t0, \imm
#         li   t3, \exp
#         bne  t2, t3, \faillabel
#     .endm

#     .macro TEST_LB_SB val, offset, exp_signed, exp_unsigned, faillabel
#         li   t0, 0x400
#         li   t1, \val
#         sb   t1, \offset(t0)
#         lb   t2, \offset(t0)
#         li   t3, \exp_signed
#         bne  t2, t3, \faillabel
#         lbu  t2, \offset(t0)
#         li   t3, \exp_unsigned
#         bne  t2, t3, \faillabel
#     .endm

#     .macro TEST_LH_SH val, offset, exp_signed, exp_unsigned, faillabel
#         li   t0, 0x400
#         li   t1, \val
#         sh   t1, \offset(t0)
#         lh   t2, \offset(t0)
#         li   t3, \exp_signed
#         bne  t2, t3, \faillabel
#         lhu  t2, \offset(t0)
#         li   t3, \exp_unsigned
#         bne  t2, t3, \faillabel
#     .endm

#     .macro TEST_BRANCH_TAKEN op, a, b, faillabel
#         li   t0, \a
#         li   t1, \b
#         \op  t0, t1, 1f
#         j    \faillabel
#     1:
#     .endm

#     .macro TEST_BRANCH_NOTTAKEN op, a, b, faillabel
#         li   t0, \a
#         li   t1, \b
#         \op  t0, t1, \faillabel
#     .endm

#     .macro TEST_LUI imm, exp, faillabel
#         lui  t0, \imm
#         li   t1, \exp
#         bne  t0, t1, \faillabel
#     .endm



# /*
# Fail label saves the ID of the fail test, which is written to tohost
# by "fail" (see crt0.S). ToHost is written to the log file by the testbench,
# this id number can be used to determine which test failed
# */

#     .macro FAIL_LABEL name, id
# \name:
#         li   gp, \id
#         j    fail
#     .endm

# /*
# similar macro to TEST_RR but for instructions with immediates
# */



# /*
# function where macros are inserted (tests are actually created) and
# code is executed.
# */
#     .section .text
#     .globl new_tests
#     .type  new_tests, @function
# new_tests:

#     TEST_RR or,   0x0F, 0xF0, 0xFF,        Fail_Or_M1
#     TEST_RR xor,  0xAA, 0x0F, 0xA5,        Fail_Xor_M1
#     TEST_RR and,  0x55, 0xAA, 0x00,        Fail_And_M1
#     TEST_RR add,  7,    5,    12,          Fail_Add_M1
#     TEST_RR sub,  9,    4,    5,           Fail_Sub_M1

#     TEST_RI  ori,  0x0F, 0xF0, 0xFF,        Fail_Ori_M1
#     TEST_RI  xori, 0xAA, 0x0F, 0xA5,        Fail_Xori_M1
#     TEST_RI  addi, 100,  -1,   99,          Fail_Addi_M1
#     TEST_RI  andi, 0xFF, 0x0F, 0x0F,        Fail_Andi_M1

#     // SLL tests
#     TEST_RR  sll,  0x00000001, 0,   0x00000001,   Fail_Sll_1    # shift by 0
#     TEST_RR  sll,  0x00000001, 1,   0x00000002,   Fail_Sll_2    # shift by 1
#     TEST_RR  sll,  0x00000001, 7,   0x00000080,   Fail_Sll_3    # shift by 7
#     TEST_RR  sll,  0x00000001, 15,  0x00008000,   Fail_Sll_4    # shift by 15
#     TEST_RR  sll,  0x00000001, 31,  0x80000000,   Fail_Sll_5    # shift by 31 (max)
#     TEST_RR  sll,  0xFFFFFFFF, 4,   0xFFFFFFF0,   Fail_Sll_6    # all 1s
#     TEST_RR  sll,  0x12345678, 4,   0x23456780,   Fail_Sll_7    # arbitrary
#     TEST_RR  sll,  0x80000000, 1,   0x00000000,   Fail_Sll_8    # shift out
#     TEST_RR  sll,  0x21212121, 0,   0x21212121,   Fail_Sll_9    # no shift

#     // SLLI TESTS
#     TEST_RI  slli, 0x00000001, 0,   0x00000001,   Fail_Slli_1   # shift by 0
#     TEST_RI  slli, 0x00000001, 1,   0x00000002,   Fail_Slli_2   # shift by 1
#     TEST_RI  slli, 0x00000001, 7,   0x00000080,   Fail_Slli_3   # shift by 7
#     TEST_RI  slli, 0x00000001, 15,  0x00008000,   Fail_Slli_4   # shift by 15
#     TEST_RI  slli, 0x00000001, 31,  0x80000000,   Fail_Slli_5   # shift by 31
#     TEST_RI  slli, 0xFFFFFFFF, 4,   0xFFFFFFF0,   Fail_Slli_6   # all 1s
#     TEST_RI  slli, 0x12345678, 4,   0x23456780,   Fail_Slli_7   # arbitrary
#     TEST_RI  slli, 0x80000000, 1,   0x00000000,   Fail_Slli_8   # shift out
#     TEST_RI  slli, 0x21212121, 0,   0x21212121,   Fail_Slli_9   # no shift

#     // SRL TESTS
#     TEST_RR  srl,  0x80000000, 1,   0x40000000,   Fail_Srl_1    # shift by 1
#     TEST_RR  srl,  0x80000000, 31,  0x00000001,   Fail_Srl_2    # shift by 31
#     TEST_RR  srl,  0x80000000, 0,   0x80000000,   Fail_Srl_3    # shift by 0
#     TEST_RR  srl,  0xFFFFFFFF, 4,   0x0FFFFFFF,   Fail_Srl_4    # all 1s
#     TEST_RR  srl,  0x12345678, 4,   0x01234567,   Fail_Srl_5    # arbitrary
#     TEST_RR  srl,  0x00000001, 1,   0x00000000,   Fail_Srl_6    # shift out
#     TEST_RR  srl,  0x21212121, 0,   0x21212121,   Fail_Srl_7    # no shift

#     // SRLI TESTS
#     TEST_RI  srli, 0x80000000, 1,   0x40000000,   Fail_Srli_1   # shift by 1
#     TEST_RI  srli, 0x80000000, 31,  0x00000001,   Fail_Srli_2   # shift by 31
#     TEST_RI  srli, 0x80000000, 0,   0x80000000,   Fail_Srli_3   # shift by 0
#     TEST_RI  srli, 0xFFFFFFFF, 4,   0x0FFFFFFF,   Fail_Srli_4   # all 1s
#     TEST_RI  srli, 0x12345678, 4,   0x01234567,   Fail_Srli_5   # arbitrary
#     TEST_RI  srli, 0x00000001, 1,   0x00000000,   Fail_Srli_6   # shift out
#     TEST_RI  srli, 0x21212121, 0,   0x21212121,   Fail_Srli_7   # no shift

#     // SRA TESTS
#     TEST_RR  sra,  0x80000000, 1,   0xC0000000,   Fail_Sra_1    # shift by 1
#     TEST_RR  sra,  0x80000000, 31,  0xFFFFFFFF,   Fail_Sra_2    # shift by 31
#     TEST_RR  sra,  0x80000000, 0,   0x80000000,   Fail_Sra_3    # shift by 0
#     TEST_RR  sra,  0xFFFFFFFF, 4,   0xFFFFFFFF,   Fail_Sra_4    # all 1s
#     TEST_RR  sra,  0x12345678, 4,   0xF1234567,   Fail_Sra_5    # arbitrary
#     TEST_RR  sra,  0x00000001, 1,   0x00000000,   Fail_Sra_6    # shift out
#     TEST_RR  sra,  0x21212121, 0,   0x21212121,   Fail_Sra_7    # no shift

#     // SRAI TESTS
#     TEST_RI  srai, 0x80000000, 1,   0xC0000000,   Fail_Srai_1   # shift by 1
#     TEST_RI  srai, 0x80000000, 31,  0xFFFFFFFF,   Fail_Srai_2   # shift by 31
#     TEST_RI  srai, 0x80000000, 0,   0x80000000,   Fail_Srai_3   # shift by 0
#     TEST_RI  srai, 0xFFFFFFFF, 4,   0xFFFFFFFF,   Fail_Srai_4   # all 1s
#     TEST_RI  srai, 0x12345678, 4,   0xF1234567,   Fail_Srai_5   # arbitrary
#     TEST_RI  srai, 0x00000001, 1,   0x00000000,   Fail_Srai_6   # shift out
#     TEST_RI  srai, 0x21212121, 0,   0x21212121,   Fail_Srai_7   # no shift

#     // SLTU TESTS
#     TEST_RR  sltu, 0x00000001, 0x00000002, 1,           Fail_Sltu_1   # 1 < 2
#     TEST_RR  sltu, 0xFFFFFFFF, 0x00000001, 0,           Fail_Sltu_2   # 0xFFFFFFFF > 1
#     TEST_RR  sltu, 0x7FFFFFFF, 0x80000000, 1,           Fail_Sltu_3   # 0x7FFFFFFF < 0x80000000
#     TEST_RR  sltu, 0x80000000, 0x7FFFFFFF, 0,           Fail_Sltu_4   # 0x80000000 > 0x7FFFFFFF
#     TEST_RR  sltu, 0x00000000, 0x00000000, 0,           Fail_Sltu_5   # 0 == 0
#     TEST_RR  sltu, 0xFFFFFFFF, 0xFFFFFFFF, 0,           Fail_Sltu_6   # 0xFFFFFFFF == 0xFFFFFFFF
#     TEST_RR  sltu, 0x12345678, 0x87654321, 1,           Fail_Sltu_7   # arbitrary: 0x12345678 < 0x87654321
#     TEST_RR  sltu, 0x87654321, 0x12345678, 0,           Fail_Sltu_8   # arbitrary: 0x87654321 > 0x12345678
#     TEST_RR  sltu, 0x00000001, 0x00000000, 0,           Fail_Sltu_9   # 1 > 0

#     // SLTI TESTS
#     TEST_RI  slti, 0x00000001, 2, 1,           Fail_Slti_1    # 1 < 2
#     TEST_RI  slti, 0xFFFFFFFF, 1, 1,           Fail_Slti_2    # 0xFFFFFFFF < 1 (negative number)
#     TEST_RI  slti, 0x7FFFFFFF, 1, 0,           Fail_Slti_3    # 0x7FFFFFFF < 1 (positive number)
#     TEST_RI  slti, 0x80000000, 1, 1,           Fail_Slti_4    # 0x80000000 < 1 (negative number)
#     TEST_RI  slti, 0x00000000, 1, 1,           Fail_Slti_5    # 0 < 1
#     TEST_RI  slti, 0xFFFFFFFF, 0, 0,           Fail_Slti_6    # 0xFFFFFFFF < 0 (negative number)
#     TEST_RI  slti, 0x12345678, 0x20000000, 1,           Fail_Slti_7    # arbitrary: 0x12345678 < 0x20000000
#     TEST_RI  slti, 0x87654321, 0x20000000, 0,           Fail_Slti_8    # arbitrary: 0x87654321 > 0x20000000
#     TEST_RI  slti, 0x00000001, 0, 0,           Fail_Slti_9    # 1 > 0

#     // LB/SB TESTS
#     # Test all byte offsets
#     TEST_LB_SB 0xFF, 0, 0xFFFFFFFF, 0x000000FF, Fail_LB_1   # offset 0, negative
#     TEST_LB_SB 0xFF, 1, 0xFFFFFFFF, 0x000000FF, Fail_LB_2   # offset 1, negative
#     TEST_LB_SB 0xFF, 2, 0xFFFFFFFF, 0x000000FF, Fail_LB_3   # offset 2, negative
#     TEST_LB_SB 0xFF, 3, 0xFFFFFFFF, 0x000000FF, Fail_LB_4   # offset 3, negative

#     TEST_LB_SB 0x7F, 0, 0x0000007F, 0x0000007F, Fail_LB_5   # offset 0, positive
#     TEST_LB_SB 0x7F, 1, 0x0000007F, 0x0000007F, Fail_LB_6   # offset 1, positive
#     TEST_LB_SB 0x7F, 2, 0x0000007F, 0x0000007F, Fail_LB_7   # offset 2, positive
#     TEST_LB_SB 0x7F, 3, 0x0000007F, 0x0000007F, Fail_LB_8   # offset 3, positive

#     TEST_LB_SB 0x80, 0, 0xFFFFFF80, 0x00000080, Fail_LB_9   # boundary value
#     TEST_LB_SB 0x00, 0, 0x00000000, 0x00000000, Fail_LB_10  # zero
#     TEST_LB_SB 0x01, 0, 0x00000001, 0x00000001, Fail_LB_11  # one

#     # Extract byte from larger value
#     TEST_LB_SB 0x12345678, 0, 0x00000078, 0x00000078, Fail_LB_12
#     TEST_LB_SB 0x12345678, 1, 0x00000078, 0x00000078, Fail_LB_13
#     TEST_LB_SB 0x87654321, 0, 0x00000021, 0x00000021, Fail_LB_14
#     TEST_LB_SB 0x87654321, 1, 0x00000021, 0x00000021, Fail_LB_15

#     // LH/SH TESTS
#     # Test both halfword offsets
#     TEST_LH_SH 0xFFFF, 0, 0xFFFFFFFF, 0x0000FFFF, Fail_LH_1   # offset 0, negative
#     TEST_LH_SH 0xFFFF, 2, 0xFFFFFFFF, 0x0000FFFF, Fail_LH_2   # offset 2, negative

#     TEST_LH_SH 0x7FFF, 0, 0x00007FFF, 0x00007FFF, Fail_LH_3   # offset 0, positive
#     TEST_LH_SH 0x7FFF, 2, 0x00007FFF, 0x00007FFF, Fail_LH_4   # offset 2, positive

#     TEST_LH_SH 0x8000, 0, 0xFFFF8000, 0x00008000, Fail_LH_5   # boundary
#     TEST_LH_SH 0x8000, 2, 0xFFFF8000, 0x00008000, Fail_LH_6   # boundary offset 2
#     TEST_LH_SH 0x0000, 0, 0x00000000, 0x00000000, Fail_LH_7   # zero
#     TEST_LH_SH 0x0001, 0, 0x00000001, 0x00000001, Fail_LH_8   # one

#     # Extract halfword from larger value
#     TEST_LH_SH 0x12345678, 0, 0x00005678, 0x00005678, Fail_LH_9
#     TEST_LH_SH 0x12345678, 2, 0x00005678, 0x00005678, Fail_LH_10
#     TEST_LH_SH 0x87654321, 0, 0x00004321, 0x00004321, Fail_LH_11
#     TEST_LH_SH 0x87654321, 2, 0x00004321, 0x00004321, Fail_LH_12
#     TEST_LH_SH 0xABCD8765, 0, 0xFFFF8765, 0x00008765, Fail_LH_13
#     TEST_LH_SH 0xABCD8765, 2, 0xFFFF8765, 0x00008765, Fail_LH_14

#     //=================================================================
#     // BNE Tests (220-229) - 10 test cases (taken and not taken)
#     //=================================================================

#     TEST_BRANCH_TAKEN    bne, 0x00000000, 0x00000001, Fail_Bne_1   # 0 != 1 (taken)
#     TEST_BRANCH_TAKEN    bne, 0x00000001, 0x00000000, Fail_Bne_2   # 1 != 0 (taken)
#     TEST_BRANCH_TAKEN    bne, 0x7FFFFFFF, 0x80000000, Fail_Bne_3   # different (taken)
#     TEST_BRANCH_TAKEN    bne, 0xFFFFFFFF, 0x00000000, Fail_Bne_4   # -1 != 0 (taken)
#     TEST_BRANCH_NOTTAKEN bne, 0x00000000, 0x00000000, Fail_Bne_5   # 0 == 0 (not taken)
#     TEST_BRANCH_NOTTAKEN bne, 0x00000001, 0x00000001, Fail_Bne_6   # 1 == 1 (not taken)
#     TEST_BRANCH_NOTTAKEN bne, 0xFFFFFFFF, 0xFFFFFFFF, Fail_Bne_7   # -1 == -1 (not taken)
#     TEST_BRANCH_NOTTAKEN bne, 0x80000000, 0x80000000, Fail_Bne_8   # same (not taken)

#     //=================================================================
#     // BLT Tests (230-239) - 10 test cases
#     //=================================================================

#     TEST_BRANCH_TAKEN    blt, 0x00000000, 0x00000001, Fail_Blt_1   # 0 < 1 (taken)
#     TEST_BRANCH_TAKEN    blt, 0xFFFFFFFF, 0x00000000, Fail_Blt_2   # -1 < 0 (taken)
#     TEST_BRANCH_TAKEN    blt, 0x80000000, 0x7FFFFFFF, Fail_Blt_3   # min < max (taken)
#     TEST_BRANCH_TAKEN    blt, 0xFFFFFFFE, 0xFFFFFFFF, Fail_Blt_4   # -2 < -1 (taken)
#     TEST_BRANCH_NOTTAKEN blt, 0x00000001, 0x00000000, Fail_Blt_5   # 1 not < 0
#     TEST_BRANCH_NOTTAKEN blt, 0x00000000, 0x00000000, Fail_Blt_6   # 0 not < 0
#     TEST_BRANCH_NOTTAKEN blt, 0x7FFFFFFF, 0x80000000, Fail_Blt_7   # max not < min
#     TEST_BRANCH_NOTTAKEN blt, 0x00000001, 0x00000001, Fail_Blt_8   # equal

#     //=================================================================
#     // BLTU Tests (240-249) - 10 test cases
#     //=================================================================

#     TEST_BRANCH_TAKEN    bltu, 0x00000000, 0x00000001, Fail_Bltu_1  # 0 < 1 (taken)
#     TEST_BRANCH_TAKEN    bltu, 0x00000001, 0xFFFFFFFF, Fail_Bltu_2  # 1 < max (taken)
#     TEST_BRANCH_TAKEN    bltu, 0x7FFFFFFF, 0x80000000, Fail_Bltu_3  # 2^31-1 < 2^31 (taken)
#     TEST_BRANCH_TAKEN    bltu, 0xFFFFFFFE, 0xFFFFFFFF, Fail_Bltu_4  # max-1 < max (taken)
#     TEST_BRANCH_NOTTAKEN bltu, 0x00000001, 0x00000000, Fail_Bltu_5  # 1 not < 0
#     TEST_BRANCH_NOTTAKEN bltu, 0x00000000, 0x00000000, Fail_Bltu_6  # equal
#     TEST_BRANCH_NOTTAKEN bltu, 0xFFFFFFFF, 0x00000001, Fail_Bltu_7  # max not < 1
#     TEST_BRANCH_NOTTAKEN bltu, 0x80000000, 0x7FFFFFFF, Fail_Bltu_8  # 2^31 not < 2^31-1

#     //=================================================================
#     // BGE Tests (250-259) - 10 test cases
#     //=================================================================

#     TEST_BRANCH_TAKEN    bge, 0x00000001, 0x00000000, Fail_Bge_1   # 1 >= 0 (taken)
#     TEST_BRANCH_TAKEN    bge, 0x00000000, 0x00000000, Fail_Bge_2   # 0 >= 0 (taken)
#     TEST_BRANCH_TAKEN    bge, 0x00000000, 0xFFFFFFFF, Fail_Bge_3   # 0 >= -1 (taken)
#     TEST_BRANCH_TAKEN    bge, 0x7FFFFFFF, 0x80000000, Fail_Bge_4   # max >= min (taken)
#     TEST_BRANCH_NOTTAKEN bge, 0x00000000, 0x00000001, Fail_Bge_5   # 0 not >= 1
#     TEST_BRANCH_NOTTAKEN bge, 0xFFFFFFFF, 0x00000000, Fail_Bge_6   # -1 not >= 0
#     TEST_BRANCH_NOTTAKEN bge, 0x80000000, 0x7FFFFFFF, Fail_Bge_7   # min not >= max
#     TEST_BRANCH_NOTTAKEN bge, 0xFFFFFFFE, 0xFFFFFFFF, Fail_Bge_8   # -2 not >= -1

#     //=================================================================
#     // BGEU Tests (260-269) - 10 test cases
#     //=================================================================

#     TEST_BRANCH_TAKEN    bgeu, 0x00000001, 0x00000000, Fail_Bgeu_1  # 1 >= 0 (taken)
#     TEST_BRANCH_TAKEN    bgeu, 0x00000000, 0x00000000, Fail_Bgeu_2  # 0 >= 0 (taken)
#     TEST_BRANCH_TAKEN    bgeu, 0xFFFFFFFF, 0x00000001, Fail_Bgeu_3  # max >= 1 (taken)
#     TEST_BRANCH_TAKEN    bgeu, 0x80000000, 0x7FFFFFFF, Fail_Bgeu_4  # 2^31 >= 2^31-1 (taken)
#     TEST_BRANCH_NOTTAKEN bgeu, 0x00000000, 0x00000001, Fail_Bgeu_5  # 0 not >= 1
#     TEST_BRANCH_NOTTAKEN bgeu, 0x00000001, 0xFFFFFFFF, Fail_Bgeu_6  # 1 not >= max
#     TEST_BRANCH_NOTTAKEN bgeu, 0x7FFFFFFF, 0x80000000, Fail_Bgeu_7  # 2^31-1 not >= 2^31
#     TEST_BRANCH_NOTTAKEN bgeu, 0xFFFFFFFE, 0xFFFFFFFF, Fail_Bgeu_8  # max-1 not >= max

#     //=================================================================
#     // JALR Tests (270-279) - 10 test cases
#     //=================================================================

#     # Test JALR with offset 0
#     jalr_test1:
#         la   t0, jalr_target1
#         jalr t1, t0, 0
#         li   gp, 270
#         j    fail
#     jalr_target1:

#     # Test JALR with positive offset
#     jalr_test2:
#         la   t0, jalr_target2
#         addi t0, t0, -8
#         jalr t1, t0, 8
#         li   gp, 271
#         j    fail
#     jalr_target2:

#     # Test JALR with negative offset
#     jalr_test3:
#         la   t0, jalr_target3
#         addi t0, t0, 12
#         jalr t1, t0, -12
#         li   gp, 272
#         j    fail
#     jalr_target3:

#     # Test JALR return address
#     jalr_test4:
#         la   t0, jalr_target4
#         jalr t1, t0, 0
#         # Check return address
#         la   t0, jalr_return4
#         bne  t1, t0, Fail_Jalr_4
#         j    jalr_test5
#     jalr_target4:
#         jalr t2, t1, 0
#     jalr_return4:

#     # Test JALR with large offset
#     jalr_test5:
#         la   t0, jalr_target5
#         addi t0, t0, -2040
#         jalr t1, t0, 2040
#         li   gp, 274
#         j    fail
#     jalr_target5:

#     //=================================================================
#     // LUI Tests (280-289) - 10 test cases
#     //=================================================================

#     TEST_LUI 0x00000, 0x00000000, Fail_Lui_1   # zero
#     TEST_LUI 0x00001, 0x00001000, Fail_Lui_2   # smallest positive
#     TEST_LUI 0xFFFFF, 0xFFFFF000, Fail_Lui_3   # all 1s
#     TEST_LUI 0x7FFFF, 0x7FFFF000, Fail_Lui_4   # positive boundary
#     TEST_LUI 0x80000, 0x80000000, Fail_Lui_5   # negative boundary
#     TEST_LUI 0x12345, 0x12345000, Fail_Lui_6   # arbitrary
#     TEST_LUI 0xABCDE, 0xABCDE000, Fail_Lui_7   # arbitrary
#     TEST_LUI 0x55555, 0x55555000, Fail_Lui_8   # pattern
#     TEST_LUI 0xAAAAA, 0xAAAAA000, Fail_Lui_9   # pattern

#     //=================================================================
#     // AUIPC Tests (290-299) - 10 test cases
#     //=================================================================

#     # Test AUIPC with zero offset
#     auipc_test1:
#         auipc t0, 0
#         auipc t1, 0
#         sub   t2, t1, t0
#         li    t3, 4
#         bne   t2, t3, Fail_Auipc_1

#     # Test AUIPC with small offset
#     auipc_test2:
#         auipc t0, 0x1
#         auipc t1, 0
#         sub   t2, t0, t1
#         lui   t3, 0x00001
#         bne   t2, t3, Fail_Auipc_2

#     # Test AUIPC with large offset
#     auipc_test3:
#         auipc t0, 0x100
#         auipc t1, 0
#         sub   t2, t0, t1
#         lui   t3, 0x00100
#         bne   t2, t3, Fail_Auipc_3

#     # Test AUIPC with max offset
#     auipc_test4:
#         auipc t0, 0x7FFFF
#         auipc t1, 0
#         sub   t2, t0, t1
#         lui   t3, 0x7FFFF
#         bne   t2, t3, Fail_Auipc_4

#     # Test AUIPC with negative offset
#     auipc_test5:
#         auipc t0, 0xFFFFF
#         auipc t1, 0
#         sub   t2, t0, t1
#         lui   t3, 0xFFFFF
#         bne   t2, t3, Fail_Auipc_5

#     # Test sequential AUIPC values
#     auipc_test6:
#         auipc t0, 0
#         nop
#         nop
#         auipc t1, 0
#         sub   t2, t1, t0
#         li    t3, 12
#         bne   t2, t3, Fail_Auipc_6

#     j pass

# pass:
#     li  a0, 1
#     ret

# fail:
#     li  a0, 0
#     ret

# /* fail macros */

#     //=================================================================
#     // Fail Labels
#     //=================================================================

#     // Basic instruction failures (10-50)
#     FAIL_LABEL Fail_Or_M1,    10
#     FAIL_LABEL Fail_Xor_M1,   11
#     FAIL_LABEL Fail_And_M1,   12
#     FAIL_LABEL Fail_Add_M1,   13
#     FAIL_LABEL Fail_Sub_M1,   14
#     FAIL_LABEL Fail_Ori_M1,   20
#     FAIL_LABEL Fail_Xori_M1,  21
#     FAIL_LABEL Fail_Addi_M1,  22
#     FAIL_LABEL Fail_Andi_M1,  23

#     // SLL failures (100-109)
#     FAIL_LABEL Fail_Sll_1,    100
#     FAIL_LABEL Fail_Sll_2,    101
#     FAIL_LABEL Fail_Sll_3,    102
#     FAIL_LABEL Fail_Sll_4,    103
#     FAIL_LABEL Fail_Sll_5,    104
#     FAIL_LABEL Fail_Sll_6,    105
#     FAIL_LABEL Fail_Sll_7,    106
#     FAIL_LABEL Fail_Sll_8,    107
#     FAIL_LABEL Fail_Sll_9,    108

#     // SLLI failures (110-119)
#     FAIL_LABEL Fail_Slli_1,   110
#     FAIL_LABEL Fail_Slli_2,   111
#     FAIL_LABEL Fail_Slli_3,   112
#     FAIL_LABEL Fail_Slli_4,   113
#     FAIL_LABEL Fail_Slli_5,   114
#     FAIL_LABEL Fail_Slli_6,   115
#     FAIL_LABEL Fail_Slli_7,   116
#     FAIL_LABEL Fail_Slli_8,   117
#     FAIL_LABEL Fail_Slli_9,   118

#     // SRL failures (120-129)
#     FAIL_LABEL Fail_Srl_1,    120
#     FAIL_LABEL Fail_Srl_2,    121
#     FAIL_LABEL Fail_Srl_3,    122
#     FAIL_LABEL Fail_Srl_4,    123
#     FAIL_LABEL Fail_Srl_5,    124
#     FAIL_LABEL Fail_Srl_6,    125
#     FAIL_LABEL Fail_Srl_7,    126

#     // SRLI failures (130-139)
#     FAIL_LABEL Fail_Srli_1,   130
#     FAIL_LABEL Fail_Srli_2,   131
#     FAIL_LABEL Fail_Srli_3,   132
#     FAIL_LABEL Fail_Srli_4,   133
#     FAIL_LABEL Fail_Srli_5,   134
#     FAIL_LABEL Fail_Srli_6,   135
#     FAIL_LABEL Fail_Srli_7,   136

#     // SRA failures (140-149)
#     FAIL_LABEL Fail_Sra_1,    140
#     FAIL_LABEL Fail_Sra_2,    141
#     FAIL_LABEL Fail_Sra_3,    142
#     FAIL_LABEL Fail_Sra_4,    143
#     FAIL_LABEL Fail_Sra_5,    144
#     FAIL_LABEL Fail_Sra_6,    145
#     FAIL_LABEL Fail_Sra_7,    146

#     // SRAI failures (150-159)
#     FAIL_LABEL Fail_Srai_1,   150
#     FAIL_LABEL Fail_Srai_2,   151
#     FAIL_LABEL Fail_Srai_3,   152
#     FAIL_LABEL Fail_Srai_4,   153
#     FAIL_LABEL Fail_Srai_5,   154
#     FAIL_LABEL Fail_Srai_6,   155
#     FAIL_LABEL Fail_Srai_7,   156

#     // SLTU failures (160-169)
#     FAIL_LABEL Fail_Sltu_1,   160
#     FAIL_LABEL Fail_Sltu_2,   161
#     FAIL_LABEL Fail_Sltu_3,   162
#     FAIL_LABEL Fail_Sltu_4,   163
#     FAIL_LABEL Fail_Sltu_5,   164
#     FAIL_LABEL Fail_Sltu_6,   165
#     FAIL_LABEL Fail_Sltu_7,   166
#     FAIL_LABEL Fail_Sltu_8,   167
#     FAIL_LABEL Fail_Sltu_9,   168

#     // SLTI failures (170-179)
#     FAIL_LABEL Fail_Slti_1,   170
#     FAIL_LABEL Fail_Slti_2,   171
#     FAIL_LABEL Fail_Slti_3,   172
#     FAIL_LABEL Fail_Slti_4,   173
#     FAIL_LABEL Fail_Slti_5,   174
#     FAIL_LABEL Fail_Slti_6,   175
#     FAIL_LABEL Fail_Slti_7,   176
#     FAIL_LABEL Fail_Slti_8,   177
#     FAIL_LABEL Fail_Slti_9,   178

#     // LB/LBU/SB failures (180-199)
#     FAIL_LABEL Fail_LB_1,     180
#     FAIL_LABEL Fail_LB_2,     181
#     FAIL_LABEL Fail_LB_3,     182
#     FAIL_LABEL Fail_LB_4,     183
#     FAIL_LABEL Fail_LB_5,     184
#     FAIL_LABEL Fail_LB_6,     185
#     FAIL_LABEL Fail_LB_7,     186
#     FAIL_LABEL Fail_LB_8,     187
#     FAIL_LABEL Fail_LB_9,     188
#     FAIL_LABEL Fail_LB_10,    189
#     FAIL_LABEL Fail_LB_11,    190
#     FAIL_LABEL Fail_LB_12,    191
#     FAIL_LABEL Fail_LB_13,    192
#     FAIL_LABEL Fail_LB_14,    193
#     FAIL_LABEL Fail_LB_15,    194

#     // LH/LHU/SH failures (200-219)
#     FAIL_LABEL Fail_LH_1,     200
#     FAIL_LABEL Fail_LH_2,     201
#     FAIL_LABEL Fail_LH_3,     202
#     FAIL_LABEL Fail_LH_4,     203
#     FAIL_LABEL Fail_LH_5,     204
#     FAIL_LABEL Fail_LH_6,     205
#     FAIL_LABEL Fail_LH_7,     206
#     FAIL_LABEL Fail_LH_8,     207
#     FAIL_LABEL Fail_LH_9,     208
#     FAIL_LABEL Fail_LH_10,    209
#     FAIL_LABEL Fail_LH_11,    210
#     FAIL_LABEL Fail_LH_12,    211
#     FAIL_LABEL Fail_LH_13,    212
#     FAIL_LABEL Fail_LH_14,    213

#     // BNE failures (220-229)
#     FAIL_LABEL Fail_Bne_1,    220
#     FAIL_LABEL Fail_Bne_2,    221
#     FAIL_LABEL Fail_Bne_3,    222
#     FAIL_LABEL Fail_Bne_4,    223
#     FAIL_LABEL Fail_Bne_5,    224
#     FAIL_LABEL Fail_Bne_6,    225
#     FAIL_LABEL Fail_Bne_7,    226
#     FAIL_LABEL Fail_Bne_8,    227

#     // BLT failures (230-239)
#     FAIL_LABEL Fail_Blt_1,    230
#     FAIL_LABEL Fail_Blt_2,    231
#     FAIL_LABEL Fail_Blt_3,    232
#     FAIL_LABEL Fail_Blt_4,    233
#     FAIL_LABEL Fail_Blt_5,    234
#     FAIL_LABEL Fail_Blt_6,    235
#     FAIL_LABEL Fail_Blt_7,    236
#     FAIL_LABEL Fail_Blt_8,    237

#     // BLTU failures (240-249)
#     FAIL_LABEL Fail_Bltu_1,   240
#     FAIL_LABEL Fail_Bltu_2,   241
#     FAIL_LABEL Fail_Bltu_3,   242
#     FAIL_LABEL Fail_Bltu_4,   243
#     FAIL_LABEL Fail_Bltu_5,   244
#     FAIL_LABEL Fail_Bltu_6,   245
#     FAIL_LABEL Fail_Bltu_7,   246
#     FAIL_LABEL Fail_Bltu_8,   247

#     // BGE failures (250-259)
#     FAIL_LABEL Fail_Bge_1,    250
#     FAIL_LABEL Fail_Bge_2,    251
#     FAIL_LABEL Fail_Bge_3,    252
#     FAIL_LABEL Fail_Bge_4,    253
#     FAIL_LABEL Fail_Bge_5,    254
#     FAIL_LABEL Fail_Bge_6,    255
#     FAIL_LABEL Fail_Bge_7,    256
#     FAIL_LABEL Fail_Bge_8,    257

#     // BGEU failures (260-269)
#     FAIL_LABEL Fail_Bgeu_1,   260
#     FAIL_LABEL Fail_Bgeu_2,   261
#     FAIL_LABEL Fail_Bgeu_3,   262
#     FAIL_LABEL Fail_Bgeu_4,   263
#     FAIL_LABEL Fail_Bgeu_5,   264
#     FAIL_LABEL Fail_Bgeu_6,   265
#     FAIL_LABEL Fail_Bgeu_7,   266
#     FAIL_LABEL Fail_Bgeu_8,   267

#     // JALR failures (270-279)
#     FAIL_LABEL Fail_Jalr_4,   273

#     // LUI failures (280-289)
#     FAIL_LABEL Fail_Lui_1,    280
#     FAIL_LABEL Fail_Lui_2,    281
#     FAIL_LABEL Fail_Lui_3,    282
#     FAIL_LABEL Fail_Lui_4,    283
#     FAIL_LABEL Fail_Lui_5,    284
#     FAIL_LABEL Fail_Lui_6,    285
#     FAIL_LABEL Fail_Lui_7,    286
#     FAIL_LABEL Fail_Lui_8,    287
#     FAIL_LABEL Fail_Lui_9,    288

#     // AUIPC failures (290-299)
#     FAIL_LABEL Fail_Auipc_1,  290
#     FAIL_LABEL Fail_Auipc_2,  291
#     FAIL_LABEL Fail_Auipc_3,  292
#     FAIL_LABEL Fail_Auipc_4,  293
#     FAIL_LABEL Fail_Auipc_5,  294
#     FAIL_LABEL Fail_Auipc_6,  295
