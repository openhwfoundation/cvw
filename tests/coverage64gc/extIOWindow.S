///////////////////////////////////////////
// extIOWindow.S
//
// Purpose: Self-checking test of the EXT_IO PMA window: an I/O window inside
//          EXT_MEM that is not cacheable, not idempotent, not atomic and not
//          executable.  Run on extio_rv64gc (EXT_MEM at 0x90000000, EXT_IO at
//          0x90008000-0x90008FFF): stores and loads in the window reach memory,
//          a load in the window does not access the D$ while loads elsewhere in
//          EXT_MEM, including just outside both ends of the window, do;
//          misaligned accesses, AMOs and LR/SC in the window take access faults
//          while they succeed elsewhere in EXT_MEM; a fetch from the window
//          takes an instruction access fault; and an indirect call predicted
//          to the window but resolved elsewhere completes normally (the
//          testbench fails the run if any fetch reaches the window on the bus).
//          The D$ accesses and the exceptions are counted with mhpmcounter13
//          and mhpmcounter23.  On a configuration without external memory at
//          0x90000000 (rv64gc) the first load faults and the test passes
//          without checking anything.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

// Read counter csr into rd after letting earlier instructions retire.
.macro READ_COUNTER rd, csr
    nop
    nop
    nop
    csrr \rd, \csr
.endm

// After READ_COUNTER a1, mhpmcounter23 and one access: check that the access
// took exactly one exception, with mcause cause.
.macro EXPECT_FAULT cause, index
    READ_COUNTER a2, mhpmcounter23
    sub a2, a2, a1
    li a3, 1
    SC_CHECK_EQ a2, a3, \index
    csrr a4, mcause
    li a3, \cause
    SC_CHECK_EQ a4, a3, \index
.endm

// After READ_COUNTER a1, mhpmcounter23 and one access: check that it took no exception.
.macro EXPECT_NO_FAULT index
    READ_COUNTER a2, mhpmcounter23
    SC_CHECK_EQ a2, a1, \index
.endm

// After READ_COUNTER a1, mhpmcounter13 and one load: check whether it accessed the D$.
.macro EXPECT_DCACHE accessed, index
    READ_COUNTER a2, mhpmcounter13
    sub a2, a2, a1
    snez a2, a2
    li a3, \accessed
    SC_CHECK_EQ a2, a3, \index
.endm

main:
    li t2, 1
    csrw mhpmevent13, t2        # count D$ accesses
    csrw mhpmevent23, t2        # count exceptions
    csrw mcountinhibit, zero

    li s1, 0x90000000           # EXT_MEM, cacheable
    li s3, 0x90008000           # EXT_IO window, 4 KiB

    # Probe: without external memory here the load faults; then there is nothing to check.
    READ_COUNTER s0, mhpmcounter23
    ld t2, 0(s1)
    READ_COUNTER s2, mhpmcounter23
    bne s0, s2, finished

    # 1. A store and a load in the window reach memory.
    li s4, 0x0123456789abcdef
    sd s4, 0(s3)
    ld s5, 0(s3)
    SC_CHECK_EQ s5, s4, 1

    # 2. A load in the window does not access the D$; one elsewhere in EXT_MEM does.
    READ_COUNTER a1, mhpmcounter13
    ld s5, 0(s3)
    EXPECT_DCACHE 0, 2
    READ_COUNTER a1, mhpmcounter13
    ld s5, 0(s1)
    EXPECT_DCACHE 1, 3

    # 3. An AMO in the window takes a store/AMO access fault (mcause 7); the
    #    handler skips it, so rd and memory are unchanged.
    li t2, 2
    li t3, 0x77
    READ_COUNTER a1, mhpmcounter23
    amoadd.d t3, t2, (s3)
    EXPECT_FAULT 7, 4
    li a3, 0x77
    SC_CHECK_EQ t3, a3, 6
    ld s5, 0(s3)
    SC_CHECK_EQ s5, s4, 7

    # 4. An AMO elsewhere in EXT_MEM succeeds.
    sd s4, 0(s1)
    READ_COUNTER a1, mhpmcounter23
    amoadd.d t3, t2, (s1)
    EXPECT_NO_FAULT 8
    SC_CHECK_EQ t3, s4, 9
    ld s5, 0(s1)
    addi a3, s4, 2
    SC_CHECK_EQ s5, a3, 10

    # 5. Window boundaries: the last doubleword of the window is uncached; the
    #    doublewords just below and just above the window are cached.
    li t4, 0x90008FF8
    READ_COUNTER a1, mhpmcounter13
    ld s5, 0(t4)
    EXPECT_DCACHE 0, 11
    li t4, 0x90007FF8
    READ_COUNTER a1, mhpmcounter13
    ld s5, 0(t4)
    EXPECT_DCACHE 1, 12
    li t4, 0x90009000
    READ_COUNTER a1, mhpmcounter13
    ld s5, 0(t4)
    EXPECT_DCACHE 1, 13

    # 6. Misaligned accesses: the window is not idempotent, so they take access
    #    faults (load 5, store 7); elsewhere in EXT_MEM they succeed.
    READ_COUNTER a1, mhpmcounter23
    ld s5, 1(s3)
    EXPECT_FAULT 5, 14
    READ_COUNTER a1, mhpmcounter23
    sd s4, 1(s3)
    EXPECT_FAULT 7, 15
    ld s5, 0(s3)
    SC_CHECK_EQ s5, s4, 16
    READ_COUNTER a1, mhpmcounter23
    ld s5, 1(s1)
    EXPECT_NO_FAULT 17

    # 7. LR/SC in the window take access faults (LR 5, SC 7); elsewhere they succeed.
    READ_COUNTER a1, mhpmcounter23
    lr.d t3, (s3)
    EXPECT_FAULT 5, 18
    READ_COUNTER a1, mhpmcounter23
    sc.d t3, t2, (s3)
    EXPECT_FAULT 7, 19
    ld s5, 0(s3)
    SC_CHECK_EQ s5, s4, 20
    READ_COUNTER a1, mhpmcounter23
    lr.d t3, (s1)
    sc.d t3, t2, (s1)
    EXPECT_NO_FAULT 21
    SC_CHECK_EQ t3, zero, 22

    # 8. Fetches.  A ret is placed at the start of the window, so a fetch that
    #    wrongly succeeded would return normally.  A local handler records
    #    mcause and mtval and returns to ra.
    li t4, 0x00008067           # ret
    sw t4, 0(s3)
    fence.i
    la t4, fetchtrap
    csrrw s7, mtvec, t4

    #    a. Two indirect calls to the window take instruction access faults
    #       (mcause 1, mtval the window address); they also train the
    #       predictor of the call site with the window as target.
    li s6, 2
1:  li s8, 0
    li s9, 0
    mv a5, s3
    jal ra, callsite
    li a3, 1
    SC_CHECK_EQ s8, a3, 23
    SC_CHECK_EQ s9, s3, 24
    addi s6, s6, -1
    bnez s6, 1b

    #    b. The same call site now calls normal code.  The prediction points
    #       into the window, but the wrong-path fetch must not reach the bus
    #       (checked by the testbench) and the call completes without a trap.
    li s8, 0
    la a5, nearby
    jal ra, callsite
    SC_CHECK_EQ s8, zero, 25
    li a3, 0x5a
    SC_CHECK_EQ s10, a3, 26
    csrw mtvec, s7

finished:
    SC_PASS
    j done

# One indirect call site, shared by every call in step 8; returns to the caller of callsite.
callsite:
    mv s11, ra
    jalr ra, 0(a5)
    mv ra, s11
    ret

nearby:
    li s10, 0x5a
    ret

.align 2
fetchtrap:
    csrr s8, mcause
    csrr s9, mtval
    csrw mepc, ra
    mret
