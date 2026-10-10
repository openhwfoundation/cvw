///////////////////////////////////////////
// misalignedADSpill.S
//
// Written David_Harris@hmc.edu 10/5/26
//
// Purpose: A/D update for the second half of a misaligned store crossing into a D=0 page must set D in memory
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"
main:
    li t0, 1
    slli t0, t0, 61
    csrs menvcfg, t0          # menvcfg.ADUE = 1
    la t0, pt_l1
    srli t0, t0, 12
    slli t0, t0, 10
    ori t0, t0, 1             # non-leaf PTE -> pt_l1
    la t1, pt_root
    sd t0, 24(t1)             # VPN2=3 (0xC0000000) -> pt_l1
    srli t1, t1, 12
    li t2, 8
    slli t2, t2, 60
    or t1, t1, t2
    csrw satp, t1             # Sv39
    sfence.vma
    li s2, 0xC01FFFFC         # last 4 bytes of megapage 0 (D=1); next 4 in megapage 1 (D=0)
    li s3, 0x1122334455667788
    li a0, 1
    ecall                     # to S mode
    sd s3, 0(s2)              # misaligned store crossing megapages
    li a0, 3
    ecall                     # back to M mode
    la t0, pt_l1
    ld s4, 8(t0)              # pt_l1[1]
    li s5, 0x200800C7         # V R W A D
    SC_CHECK_EQ s4, s5, 1
    li t0, 0x801FFFFC
    lwu s4, 0(t0)
    lwu s6, 4(t0)
    slli s6, s6, 32
    or s4, s4, s6
    SC_CHECK_EQ s4, s3, 2
    SC_PASS
    j done

.data
.align 12
pt_root:
    .dword 0, 0
    .dword 0x200000CF         # VPN2=2: identity gigapage, V R W X A D
    .dword 0                  # VPN2=3: filled in at run time
    .fill 508, 8, 0
pt_l1:
    .dword 0x200000C7         # 0xC0000000 -> PA 0x80000000 megapage, V R W A D
    .dword 0x20080047         # 0xC0200000 -> PA 0x80200000 megapage, V R W A (D=0)
    .fill 510, 8, 0
