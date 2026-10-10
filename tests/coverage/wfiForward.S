///////////////////////////////////////////
// wfiForward.S
//
// Written David_Harris@hmc.edu 10/5/26
//
// Purpose: The instruction after a wfi woken by a pending but disabled interrupt must see the result of the instruction before it
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
// except in compliance with the License, or, at your option, the Apache License version 2.0. You
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language governing permissions
// and limitations under the License.
////////////////////////////////////////////////////////////////////////////////////////////////

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

main:
    csrci mstatus, 8          # MIE = 0: the timer interrupt wakes the wfi but is not taken
    la s0, scratch
    li s7, 2                  # run each case twice; the second pass has a warm I$
loop:
    jal settimer
    li a0, 7
    li a1, 0
    j alu
.align 6
alu:                          # ALU operand forwarded across the wfi
    li a0, 42
    wfi
    addi a1, a0, 0            # must read 42
    jal cleartimer
    li s5, 42
    SC_CHECK_EQ a1, s5, 1

    jal settimer
    li a2, 7
    sd zero, 0(s0)
    j store
.align 6
store:                        # store data forwarded across the wfi
    li a2, 43
    wfi
    sd a2, 0(s0)              # must store 43
    jal cleartimer
    ld a3, 0(s0)
    li s5, 43
    SC_CHECK_EQ a3, s5, 2

    addi s7, s7, -1
    bnez s7, loop
    SC_PASS
    j done

settimer:                     # mtimecmp = mtime + 200
    li t0, 0x0200BFF8
    ld t1, 0(t0)
    addi t1, t1, 200
    li t0, 0x02004000
    sd t1, 0(t0)
    ret

cleartimer:                   # mtimecmp = max to clear the pending interrupt
    li t0, -1
    li t1, 0x02004000
    sd t0, 0(t1)
    ret

.data
.align 3
scratch:
    .dword 0
