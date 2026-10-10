///////////////////////////////////////////
// fpADUpdate.S
//
// Written David_Harris@hmc.edu 10/5/26
//
// Purpose: Hardware A/D update (menvcfg.ADUE=1) triggered by an FP store or FP load must write the PTE, not FP data
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
    li t0, 1<<13
    csrs mstatus, t0          # mstatus.FS = Initial
    li t0, 1
    slli t0, t0, 61
    csrs menvcfg, t0          # menvcfg.ADUE = 1
    la t0, pt_root
    srli t0, t0, 12
    li t1, 8
    slli t1, t1, 60
    or t0, t0, t1
    csrw satp, t0             # Sv39
    sfence.vma
    li t0, 0x123456789abcdef0
    fmv.d.x f1, t0
    fmv.d.x f8, t0            # fld below has imm=8 -> rs2 field = f8 in some encodings
    fmv.d.x f0, t0
    la s0, scratch            # PA of scratch (identity-mapped through VPN2=2)
    li s1, 0x40000000
    add s2, s0, s1            # VA via VPN2=3 (A=1, D=0)
    add s3, s2, s1            # VA via VPN2=4 (A=0, D=0)
    li a0, 1
    ecall                     # to S mode
    fsd f1, 0(s2)             # store to D=0 page -> HPTW sets D
    fld f2, 8(s3)             # load from A=0 page -> HPTW sets A
    li a0, 3
    ecall                     # back to M mode
    la t0, pt_root
    ld s4, 24(t0)             # PTE[3]
    ld s6, 32(t0)             # PTE[4]
    li s5, 0x200000C7         # V R W A D
    SC_CHECK_EQ s4, s5, 1
    li s5, 0x20000047         # V R W A
    SC_CHECK_EQ s6, s5, 2
    SC_PASS
    j done
fail:
    la t1, tohost
    li t0, 3
    sd t0, 0(t1)
1:  j 1b

.data
.align 12
pt_root:
    .dword 0, 0
    .dword 0x200000CF         # VPN2=2: 0x80000000 -> PA 0x80000000, V R W X A D
    .dword 0x20000047         # VPN2=3: 0xC0000000 -> PA 0x80000000, V R W A (D=0)
    .dword 0x20000007         # VPN2=4: 0x100000000 -> PA 0x80000000, V R W (A=0, D=0)
    .fill 507, 8, 0
.align 6
scratch:
    .fill 8, 8, 0
