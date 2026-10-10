///////////////////////////////////////////
// zama16b.S
//
// Purpose: Check Zama16b misaligned AMO behavior.  A misaligned AMO that stays inside one naturally
//          aligned 16 byte granule is performed in hardware; one that crosses a granule still takes a
//          store/AMO access fault, which WALLY-init-lib.h's handler skips, leaving memory untouched.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

main:
    la a2, zamadata             # 64 byte aligned scratch, one rv64gc cache line
    sd zero, 0(a2)
    sd zero, 8(a2)
    sd zero, 16(a2)
    sd zero, 56(a2)
    sd zero, 64(a2)

    # A doubleword AMO at offset 4 is misaligned but sits in one cache line, so Zama16b performs it
    addi a3, a2, 4
    li a4, 0x1234
    li a5, -1                   # sentinel the AMO must replace with the old value
    amoadd.d a5, a4, (a3)
    SC_CHECK_EQ a5, zero, 1     # returned the old value
    ld a6, 4(a2)                # misaligned load is handled by Zicclsm
    SC_CHECK_EQ a6, a4, 2       # memory was updated

    # Offset 12 crosses a 16 byte boundary but still lies in one cache line, so it is performed too
    addi a3, a2, 12
    li a4, 0x5678
    li a5, -1
    amoadd.d a5, a4, (a3)
    SC_CHECK_EQ a5, zero, 3
    ld a6, 12(a2)
    SC_CHECK_EQ a6, a4, 4

    # A doubleword AMO at offset 60 runs off the end of the line, so align.sv would split it and it
    # still takes a store/AMO access fault, which the handler skips
    addi a3, a2, 60
    li a4, 0x9ABC
    li a5, -1                   # sentinel must survive the skipped instruction
    amoadd.d a5, a4, (a3)
    li a7, -1
    SC_CHECK_EQ a5, a7, 5       # destination untouched
    ld a6, 56(a2)
    SC_CHECK_EQ a6, zero, 6     # memory untouched

    SC_PASS
    j done

.section .data
.align 6
zamadata:
    .dword 0, 0, 0, 0, 0, 0, 0, 0
    .dword 0, 0, 0, 0, 0, 0, 0, 0
