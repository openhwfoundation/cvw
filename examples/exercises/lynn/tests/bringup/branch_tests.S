// Branch instruction tests
// Tests: bne, blt, bltu, bge, bgeu
// Sadhvi Narayanan
// sanarayanan@hmc.edu
// 2/5/2026

.extern return_branch_tests
.extern fail

    .section .text.init
    .globl branch_tests
    .type  branch_tests, @function

branch_tests:

    // BNE tests
    test_bne_1:
        li   t0, 5
        li   t1, 10
        bne  t0, t1, test_bne_2
        j    Fail_Bne_1

    test_bne_2:
        li   t0, 5
        li   t1, 5
        bne  t0, t1, Fail_Bne_2
        j    test_blt_1

    // BLT tests
    test_blt_1:
        li   t0, 5
        li   t1, 10
        blt  t0, t1, test_blt_2
        j    Fail_Blt_1

    test_blt_2:
        li   t0, -5
        li   t1, 10
        blt  t0, t1, test_blt_3
        j    Fail_Blt_2

    test_blt_3:
        li   t0, 10
        li   t1, 5
        blt  t0, t1, Fail_Blt_3
        j    test_bltu_1

    // BLTU tests
    test_bltu_1:
        li   t0, 5
        li   t1, 10
        bltu t0, t1, test_bltu_2
        j    Fail_Bltu_1

    test_bltu_2:
        li   t0, 5
        li   t1, 0xFFFFFFFF
        bltu t0, t1, test_bltu_3
        j    Fail_Bltu_2

    test_bltu_3:
        li   t0, 0xFFFFFFFF
        li   t1, 5
        bltu t0, t1, Fail_Bltu_3
        j    test_bge_1

    // BGE tests
    test_bge_1:
        li   t0, 10
        li   t1, 5
        bge  t0, t1, test_bge_2
        j    Fail_Bge_1

    test_bge_2:
        li   t0, 5
        li   t1, 5
        bge  t0, t1, test_bge_3
        j    Fail_Bge_2

    test_bge_3:
        li   t0, 5
        li   t1, 10
        bge  t0, t1, Fail_Bge_3
        j    test_bgeu_1

    // BGEU tests
    test_bgeu_1:
        li   t0, 10
        li   t1, 5
        bgeu t0, t1, test_bgeu_2
        j    Fail_Bgeu_1

    test_bgeu_2:
        li   t0, 0xFFFFFFFF
        li   t1, 5
        bgeu t0, t1, test_bgeu_3
        j    Fail_Bgeu_2

    test_bgeu_3:
        li   t0, 5
        li   t1, 10
        bgeu t0, t1, Fail_Bgeu_3
        // j    pass

    # Test 1: Predicted-taken but actually not-taken branch
    test_pred_taken_not_taken:
        li   t0, 5
        li   t1, 10
        li   t2, 0

        # This branch should NOT be taken, but predictor might predict taken
        beq  t0, t1, wrong_path_1   # t0 != t1, don't branch
        addi t2, t2, 1              # Should execute this
        j    check_1

    wrong_path_1:
        li   t2, 99                 # Should NOT get here
        j    check_1                # ADD THIS - jump to check

    check_1:
        li   t3, 1
        bne  t2, t3, Fail_Pred_1    # t2 should be 1, not 0 or 99
        j    test_backward_branch   # Continue to next test


    # Test 2: Backward branch (simple loop)
    test_backward_branch:
        li   t0, 0                  # counter
        li   t1, 3                  # loop limit

    loop_start:
        addi t0, t0, 1              # increment counter
        blt  t0, t1, loop_start     # loop while t0 < 3

        # After loop, t0 should be 3
        li   t2, 3
        bne  t0, t2, Fail_Loop


    # Test 3: Branch in branch delay (consecutive branches)
    test_consecutive_branches:
        li   t0, 5
        li   t1, 5
        li   t2, 0

        beq  t0, t1, next_branch    # First branch - taken
        j    Fail_Consec_1

    next_branch:
        li   t3, 10
        li   t4, 10
        beq  t3, t4, consec_pass    # Second branch right after - taken
        j    Fail_Consec_2

    consec_pass:
        j    test_pred_pattern


    # Test 4: Pattern that trains predictor then breaks it
    test_pred_pattern:
        li   t0, 0
        li   t1, 5

    pattern_loop:
        addi t0, t0, 1
        blt  t0, t1, pattern_loop   # Taken 4 times (trains predictor)

        # Now t0 = 5, same branch should NOT be taken
        blt  t0, t1, Fail_Pattern   # Not taken - predictor might mispredict


    # Test 5: Branch to self (infinite loop detector)
    test_branch_to_self:
        li   t0, 5
        li   t1, 10
        beq  t0, t1, test_branch_to_self  # Should NOT branch to self


    # Test 6: Back-to-back mispredictions
    test_double_mispredict:
        li   t0, 1
        li   t1, 2
        li   t2, 3
        li   t3, 4

        # Neither should be taken (if predictor predicts taken)
        beq  t0, t1, Fail_Double_1   # Not taken
        beq  t2, t3, Fail_Double_2   # Not taken - right after mispredict

        j    pass

    pass:
        j return_branch_tests

Fail_Bne_1:
    li   gp, 439
    j    fail

Fail_Bne_2:
    li   gp, 440
    j    fail

Fail_Blt_1:
    li   gp, 441
    j    fail

Fail_Blt_2:
    li   gp, 442
    j    fail

Fail_Blt_3:
    li   gp, 443
    j    fail

Fail_Bltu_1:
    li   gp, 444
    j    fail

Fail_Bltu_2:
    li   gp, 445
    j    fail

Fail_Bltu_3:
    li   gp, 446
    j    fail

Fail_Bge_1:
    li   gp, 447
    j    fail

Fail_Bge_2:
    li   gp, 448
    j    fail

Fail_Bge_3:
    li   gp, 449
    j    fail

Fail_Bgeu_1:
    li   gp, 450
    j    fail

Fail_Bgeu_2:
    li   gp, 451
    j    fail

Fail_Bgeu_3:
    li   gp, 452
    j    fail

# Failure handlers
Fail_Pred_1:
    li   gp, 453
    j    fail

Fail_Loop:
    li   gp, 454
    j    fail

Fail_Consec_1:
    li   gp, 455
    j    fail

Fail_Consec_2:
    li   gp, 456
    j    fail

Fail_Pattern:
    li   gp, 457
    j    fail

Fail_Double_1:
    li   gp, 458
    j    fail

Fail_Double_2:
    li   gp, 459
    j    fail
