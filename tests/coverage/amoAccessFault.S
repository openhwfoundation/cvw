///////////////////////////////////////////
// hptwAccessFault.S
//
// Written: Rose Thompson rose@rosethompson.net
//
// Purpose: Checks that only Store/AMO access faults are generated on AMO operations
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-24 Harvey Mudd College & Oklahoma State University
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

# run-elf.bash find this in project description
main:

    la t1, data # first a valid AMO
    li t2, 2
    li t3, 3
    amoadd.d t3, t2, (t1)

    li t1, 0x90000000 # invalid AMO address
    li t2, 2
    li t3, 3
    amoadd.d t3, t2, (t1)

    fence.I

finished:
    j done

        .data

.align 8
data:
        .8byte 0x1
