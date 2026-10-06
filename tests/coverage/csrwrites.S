///////////////////////////////////////////
// csrwrites.S
//
// Written: David_Harris@hmc.edu 21 March 2023
//
// Purpose: Test writes to CSRs
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
    li t0, -5
    csrw stimecmp, t0   # initialize so ImperasDV agrees
    csrrw t0, stimecmp, t0
    csrrw t0, satp, zero
    csrrw t0, stvec, zero
    csrrw t0, sscratch, zero
    li t0, -2
    csrrw t1, menvcfg, t0
    csrrw t2, senvcfg, t0

    # Test writing to TIME CSR
    csrw time, zero

    # testing FIOM with different privilege modes
    # setting environment config (to both 1 and 0) in each privilege mode
    csrsi menvcfg, 1
    li a0, 1
    ecall               # enter supervisor mode

    li a0, 0
    ecall               # enter user mode

    li a0, 1
    ecall               # enter supervisor mode

    csrsi senvcfg, 1
    li a0, 0
    ecall               # enter user mode

    li a0, 3
    ecall               # enter machine mode
    csrci menvcfg, 1

    li a0, 1
    ecall               # enter supervisor mode

    li a0, 0
    ecall               # enter user mode


    j done
