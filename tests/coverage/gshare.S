///////////////////////////////////////////
// gshare.S
//
// Written: Rose Thompson rose@rosethompson.net
//
// Purpose: Simple examples of how the global history and gshare branch predictors behave, useful for
//          watching the predictor in a waveform.  oneLoopTest runs five 30-iteration loops whose bodies
//          shrink from six instructions to one.  Each global_hist_N_space_test runs 200 iterations of a
//          loop containing a branch that alternates between taken and not taken, with a different
//          number of instructions around the alternating branch in each test, so the branches land in
//          the global history at different spacings.  A global history predictor should learn the
//          alternating pattern after a few iterations.
//          The test checks each loop's architectural results; it does not check prediction accuracy.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

// load code to initialize stack, handle interrupts, terminate
#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

// CHECK_HIST index: check the global_hist results, t1 = 101 and t3 = a0 (checks index and index+1).
// The values are copied first because SC_CHECK_EQ uses t0 and t1.
.macro CHECK_HIST index
        mv a2, t1
        mv a3, t3
        li a1, 101
        SC_CHECK_EQ a2, a1, \index
        SC_CHECK_EQ a3, a0, (\index + 1)
.endm

main:
        SC_STRICT_TRAPS

        # Each subroutine leaves its alternating-branch count in t1 and its instruction count in t3.
        # In the global_hist tests the alternating branch is taken on the 100 even iterations, which
        # each add 1 to t1, so t1 ends at 101.
        jal ra, oneLoopTest
        li a1, 30
        SC_CHECK_EQ t3, a1, 1
        jal ra, global_hist_6_space_test
        li a0, 2300                 # 200 iterations x 10, plus 3 on each of the 100 taken iterations
        CHECK_HIST 2
        jal ra, global_hist_4_space_test
        li a0, 1100                 # 200 x 5, plus 1 on each taken iteration
        CHECK_HIST 4
        jal ra, global_hist_3_space_test
        li a0, 1100
        CHECK_HIST 6
        jal ra, global_hist_2_space_test
        li a0, 400                  # 200 x 2
        CHECK_HIST 8
        jal ra, global_hist_1_space_test
        li a0, 200
        CHECK_HIST 10
        jal ra, global_hist_0_space_test
        li a0, 0
        CHECK_HIST 12

        fence.I

finished:
        SC_PASS
        j done

        .data

.section .text
.globl oneLoopTest
.type oneLoopTest, @function
oneLoopTest:
  li t1, 0
  li t2, 30

  mv t3, t1
  mv t4, t2
oneLoopTest1:
  # instruction
  addi t3, t3, 1
  li   t5, 10      # filler instructions
  li   t6, 100
  li   a0, 1000
  li   a1, 10000
  bne t3, t4, oneLoopTest1     # loop branch: taken 29 times, then not taken

  mv t3, t1
  mv t4, t2
oneLoopTest2:
  # instruction
  addi t3, t3, 1
  li   t5, 10      # filler instructions
  li   t6, 100
  li   a0, 1000
  bne t3, t4, oneLoopTest2     # loop branch: taken 29 times, then not taken

  mv t3, t1
  mv t4, t2
oneLoopTest3:
  # instruction
  addi t3, t3, 1
  li   t5, 10      # filler instructions
  li   t6, 100
  bne t3, t4, oneLoopTest3     # loop branch: taken 29 times, then not taken

  mv t3, t1
  mv t4, t2
oneLoopTest4:
  # instruction
  addi t3, t3, 1
  li   t5, 10      # filler instructions
  bne t3, t4, oneLoopTest4     # loop branch: taken 29 times, then not taken

  mv t3, t1
  mv t4, t2
oneLoopTest5:
  # instruction
  addi t3, t3, 1
  bne t3, t4, oneLoopTest5     # loop branch: taken 29 times, then not taken

  ret

.section .text
.globl global_hist_6_space_test
.type global_hist_6_space_test, @function
global_hist_6_space_test:
  li t1, 1
  li t2, 200
  li t3, 0
  li t4, 1

loop_6:
  # instruction
  addi t3, t3, 1
  addi t3, t3, 1
  addi t3, t3, 1
  addi t3, t3, 1
  addi t3, t3, 1
  addi t3, t3, 1
  beqz t4, zero_6     # this branch toggles between taken and not taken.
  li t4, 0
  j one_6
zero_6:
  li t4, 1
  addi t3, t3, 1
  addi t3, t3, 1
  addi t3, t3, 1
  add t1, t1, t4

one_6:
  addi t3, t3, 1
  addi t3, t3, 1
  addi t3, t3, 1
  addi t3, t3, 1
  addi t2, t2, -1
  bnez t2, loop_6

  ret

.section .text
.globl global_hist_4_space_test
.type global_hist_4_space_test, @function
global_hist_4_space_test:
  li t1, 1
  li t2, 200
  li t3, 0
  li t4, 1

loop_4:
  # instruction
  addi t3, t3, 1
  addi t3, t3, 1
  addi t3, t3, 1
  addi t3, t3, 1
  beqz t4, zero_4     # this branch toggles between taken and not taken.
  li t4, 0
  j one_4
zero_4:
  li t4, 1
  addi t3, t3, 1
  add t1, t1, t4

one_4:
  addi t3, t3, 1
  addi t2, t2, -1
  bnez t2, loop_4

  ret

.section .text
.globl global_hist_3_space_test
.type global_hist_3_space_test, @function
global_hist_3_space_test:
  li t1, 1
  li t2, 200
  li t3, 0
  li t4, 1

loop_3:
  # instruction
  addi t3, t3, 1
  addi t3, t3, 1
  addi t3, t3, 1
  addi t3, t3, 1
  beqz t4, zero_3     # this branch toggles between taken and not taken.
  li t4, 0
  j one_3
zero_3:
  li t4, 1
  addi t3, t3, 1
  add t1, t1, t4

one_3:
  addi t3, t3, 1
  addi t2, t2, -1
  bnez t2, loop_3

  ret


.section .text
.globl global_hist_2_space_test
.type global_hist_2_space_test, @function
global_hist_2_space_test:
  li t1, 1
  li t2, 200
  li t3, 0
  li t4, 1

loop_2:
  # instruction
  addi t3, t3, 1
  addi t3, t3, 1
  beqz t4, zero_2     # this branch toggles between taken and not taken.
  li t4, 0
  j one_2
zero_2:
  li t4, 1
  add t1, t1, t4

one_2:
  addi t2, t2, -1
  bnez t2, loop_2

  ret

.section .text
.globl global_hist_1_space_test
.type global_hist_1_space_test, @function
global_hist_1_space_test:
  li t1, 1
  li t2, 200
  li t3, 0
  li t4, 1

loop_1:
  # instruction
  addi t3, t3, 1
  beqz t4, zero_1     # this branch toggles between taken and not taken.
  li t4, 0
  j one_1
zero_1:
  li t4, 1
  add t1, t1, t4

one_1:
  addi t2, t2, -1
  bnez t2, loop_1

  ret

.section .text
.globl global_hist_0_space_test
.type global_hist_0_space_test, @function
global_hist_0_space_test:
  li t1, 1
  li t2, 200
  li t3, 0
  li t4, 1

loop_0:
  # instruction
  beqz t4, zero_0     # this branch toggles between taken and not taken.
  li t4, 0
  j one_0
zero_0:
  li t4, 1
  add t1, t1, t4

one_0:
  addi t2, t2, -1
  bnez t2, loop_0

  ret
