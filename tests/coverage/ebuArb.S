///////////////////////////////////////////
// ebuArb.S
//
// Written: Rose Thompson rose@rosethompson.net
//
// Purpose: Force EBU arbitration.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-25 Harvey Mudd College & Oklahoma State University
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

        # cannot do this with a loop, must invalidate frequently to force as many possible lsu bus requests.
main:
        la x31, data
        addi x30, x31, 0x40
        addi x29, x31, 0x80
        addi x28, x31, 0xc0
        addi x27, x31, 0x100
        addi x26, x31, 0x140
        addi x25, x31, 0x180
        addi x24, x31, 0x1c0

        ld x0, 0(x31)
        cbo.inval (x31)
        ld x1, 8(x31)
        cbo.inval (x31)
        ld x2, 0x10(x31)
        cbo.inval (x31)
        ld x3, 0x18(x31)
        cbo.inval (x31)
        ld x4, 0x20(x31)
        cbo.inval (x31)
        ld x5, 0x28(x31)
        cbo.inval (x31)
        ld x6, 0x30(x31)
        cbo.inval (x31)
        ld x7, 0x38(x31)
        cbo.inval (x31)
        ld x8, 0x40(x31)
        cbo.inval (x30)
        ld x9, 0x48(x31)
        cbo.inval (x30)
        ld x10, 0x50(x31)
        cbo.inval (x30)
        ld x11, 0x58(x31)
        cbo.inval (x30)
        ld x12, 0x60(x31)
        cbo.inval (x30)
        ld x13, 0x68(x31)
        cbo.inval (x30)
        ld x14, 0x70(x31)
        cbo.inval (x30)
        ld x15, 0x78(x31)
        cbo.inval (x30)
        ld x16, 0x80(x31)
        cbo.inval (x29)
        ld x17, 0x88(x31)
        cbo.inval (x29)
        ld x18, 0x90(x31)
        cbo.inval (x29)
        ld x19, 0x98(x31)
        cbo.inval (x29)
        ld x20, 0xa0(x31)
        cbo.inval (x29)
        ld x21, 0xa8(x31)
        cbo.inval (x29)
        ld x22, 0xb0(x31)
        cbo.inval (x29)
        ld x23, 0xb8(x31)
        cbo.inval (x29)
        ld x23, 0xc0(x31)
        cbo.inval (x28)
        ld x23, 0xc8(x31)
        cbo.inval (x28)
        ld x23, 0xd0(x31)
        cbo.inval (x28)
        ld x23, 0xd8(x31)
        cbo.inval (x28)
        ld x23, 0xe0(x31)
        cbo.inval (x28)
        ld x23, 0xe8(x31)
        cbo.inval (x28)
        ld x23, 0xf0(x31)
        cbo.inval (x28)
        ld x0, 0xf8(x31)
        cbo.inval (x28)
        ld x1, 0x100(x31)
        cbo.inval (x27)
        ld x1, 0x108(x31)
        cbo.inval (x27)
        ld x1, 0x110(x31)
        cbo.inval (x27)
        ld x1, 0x118(x31)
        cbo.inval (x27)
        ld x1, 0x120(x31)
        cbo.inval (x27)
        ld x1, 0x128(x31)
        cbo.inval (x27)
        ld x1, 0x130(x31)
        cbo.inval (x27)
        ld x1, 0x138(x31)
        cbo.inval (x27)
        ld x1, 0x140(x31)
        cbo.inval (x26)
        ld x1, 0x148(x31)
        cbo.inval (x26)
        ld x1, 0x150(x31)
        cbo.inval (x26)
        ld x1, 0x158(x31)
        cbo.inval (x26)
        ld x1, 0x160(x31)
        cbo.inval (x26)
        ld x1, 0x168(x31)
        cbo.inval (x26)
        ld x1, 0x170(x31)
        cbo.inval (x26)
        ld x1, 0x178(x31)
        cbo.inval (x26)
        ld x1, 0x180(x31)
        cbo.inval (x25)
        ld x1, 0x188(x31)
        cbo.inval (x25)
        ld x1, 0x190(x31)
        cbo.inval (x25)
        ld x1, 0x198(x31)
        cbo.inval (x25)
        ld x1, 0x1a0(x31)
        cbo.inval (x25)
        ld x1, 0x1a8(x31)
        cbo.inval (x25)
        ld x1, 0x1b0(x31)
        cbo.inval (x25)
        ld x1, 0x1b8(x31)
        cbo.inval (x25)
        ld x1, 0x1c0(x31)
        cbo.inval (x24)
        ld x1, 0x1c8(x31)
        cbo.inval (x24)
        ld x1, 0x1d0(x31)
        cbo.inval (x24)
        ld x1, 0x1d8(x31)
        cbo.inval (x24)
        ld x1, 0x1e0(x31)
        cbo.inval (x24)
        ld x1, 0x1e8(x31)
        cbo.inval (x24)
        ld x1, 0x1f0(x31)
        cbo.inval (x24)
        ld x1, 0x1f8(x31)



finished:
    j done

.data

.align 3
data:
    .8byte 0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7
    .8byte 0x8, 0x9, 0xa, 0xb, 0xc, 0xd, 0xe, 0xf
    .8byte 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17
    .8byte 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f
    .8byte 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27
    .8byte 0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f
    .8byte 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37
    .8byte 0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e, 0x3f
