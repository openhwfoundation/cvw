///////////////////////////////////////////
// btbtrash.S
//
// Written: Rose Thompson rose@rosethompson.net 23 October 2024
//
// Purpose: Test the branch target buffer alias with divide and cache pipeline stalls
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

// load code to initialize stack, handle interrupts, terminate
#include "WALLY-init-lib.h"

main:

    # Division test (having trouble with buildroot)
        li x1, 1938759018
        li x2, 3745029
        li x3, 458
        li x4, 29587209347
        li x5, 28957
        li x6, 298
        li x7, 238562
        li x8, 198674
        li x9, 134
        li x10, 906732
        li x11, 29
        li x12, 50912
        li x13, 59
        li x14, 6902385
        li x15, 1923857
        li x16, 3985
        li x17, 3947
        li x18, 15984
        li x19, 5
        li x20, 9684658489
        li x21, 6548
        li x22, 3564
        li x23, 94
        li x24, 689464
        li x25, 42567
        li x26, 98453
        li x27, 648
        li x28, 984
        li x29, 6984
        li x30, 864

        # x31 will be our loop counter
        li x31, 4

.align 12
jump1:
        divuw x0, x1, x2
        j jump3
jump4:
        divuw x0, x5, x6
        j jump5
jump6:
        divuw x0, x10, x9
        j jump7
jump8:
        divuw x0, x14, x3
        j jump9
jump10:
        divuw x0, x18, x17
        j jump11
jump12:
        divuw x0, x21, x22
        j jump13
jump14:
        divuw x0, x24, x25
        j jump15
jump16:
        divuw x0, x29, x28
        j jump17
jump18:
        divuw x0, x1, x30
        j jump19
jump20:
        divuw x0, x3, x19
        j jump21
jump22:
        divuw x0, x12, x13
        j jump23

.align 12 # size of the 1024 btb apart
jump2:
        j jump1
jump3:
        divuw x0, x4, x3
        j jump4
jump5:
        divuw x0, x7, x8
        j jump6
jump7:
        divuw x0, x12, x11
        j jump8
jump9:
        divuw x0, x15, x16
        j jump10
jump11:
        divuw x0, x20, x19
        j jump12
jump13:
        divuw x0, x24, x23
        j jump14
jump15:
        divuw x0, x26, x27
        j jump16
jump17:
        divuw x0, x29, x30
        j jump18
jump19:
        divuw x0, x2, x3
        j jump20
jump21:
        divuw x0, x4, x5
        j jump22
jump23:
        divuw x0, x20, x21
        #j jump22

        fence.i

        addi x31, x31, -1
        bne x31, x0, jump1
finished:
    j done
