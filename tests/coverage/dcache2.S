///////////////////////////////////////////
// dcache2.S
//
// Written: avercruysse@hmc.edu 18 April 2023
//
// Purpose: Test Coverage for D$
//          (for all 4 cache ways, trigger a FlushStage while SetDirtyWay=1)
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
main:
        // way 0
        li t0, 0x80100770
        sd zero, 0(t0)
        sd zero, 1(t0)
        lr.d t1, (t0)
        addi t0, t0, 1
        sc.d t2, t1, (t0)

        // way 1
        li t0, 0x80101770
        sd zero, 0(t0)
        sd zero, 1(t0)
        lr.d t1, (t0)
        addi t0, t0, 1
        sc.d t2, t1, (t0)

        // way 2
        li t0, 0x80102770
        sd zero, 0(t0)
        sd zero, 1(t0)
        lr.d t1, (t0)
        addi t0, t0, 1
        sc.d t2, t1, (t0)

        // way 3
        li t0, 0x80103770
        sd zero, 0(t0)
        sd zero, 1(t0)
        lr.d t1, (t0)
        addi t0, t0, 1
        sc.d t2, t1, (t0)

        j done
