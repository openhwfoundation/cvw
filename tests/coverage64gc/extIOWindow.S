///////////////////////////////////////////
// extIOWindow.S
//
// Purpose: Self-checking test of the EXT_IO PMA window: an I/O window inside
//          EXT_MEM that is not cacheable, not idempotent and not atomic.  Run
//          on extio_rv64gc (EXT_MEM at 0x90000000, EXT_IO at 0x90008000):
//          stores and loads in the window reach memory, a load in the window
//          does not access the D$ while one elsewhere in EXT_MEM does, and an
//          AMO in the window takes a store/AMO access fault while one elsewhere
//          in EXT_MEM succeeds.  The D$ accesses and the exceptions are counted
//          with mhpmcounter13 and mhpmcounter23.  On a configuration without
//          external memory at 0x90000000 (rv64gc) the first load faults and the
//          test passes without checking anything.
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

main:
    li t2, 1
    csrw mhpmevent13, t2        # count D$ accesses
    csrw mhpmevent23, t2        # count exceptions
    csrw mcountinhibit, zero

    li s1, 0x90000000           # EXT_MEM, cacheable
    li s3, 0x90008000           # EXT_IO window

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
    READ_COUNTER a2, mhpmcounter13
    sub a2, a2, a1
    SC_CHECK_EQ a2, zero, 2
    READ_COUNTER a1, mhpmcounter13
    ld s5, 0(s1)
    READ_COUNTER a2, mhpmcounter13
    bne a2, a1, 1f
    SC_FAIL 3
1:

    # 3. An AMO in the window takes a store/AMO access fault (mcause 7); the
    #    handler skips it, so rd and memory are unchanged.
    li t2, 2
    li t3, 0x77
    READ_COUNTER a1, mhpmcounter23
    amoadd.d t3, t2, (s3)
    READ_COUNTER a2, mhpmcounter23
    sub a2, a2, a1
    li a3, 1
    SC_CHECK_EQ a2, a3, 4
    csrr a4, mcause
    li a3, 7
    SC_CHECK_EQ a4, a3, 5
    li a3, 0x77
    SC_CHECK_EQ t3, a3, 6
    ld s5, 0(s3)
    SC_CHECK_EQ s5, s4, 7

    # 4. An AMO elsewhere in EXT_MEM succeeds.
    sd s4, 0(s1)
    READ_COUNTER a1, mhpmcounter23
    amoadd.d t3, t2, (s1)
    READ_COUNTER a2, mhpmcounter23
    SC_CHECK_EQ a2, a1, 8
    SC_CHECK_EQ t3, s4, 9
    ld s5, 0(s1)
    addi a3, s4, 2
    SC_CHECK_EQ s5, a3, 10

finished:
    SC_PASS
    j done
