// banks.S
// Puts different data in each VRF bank (masked writes into splats), then runs back-to-back vector instructions so
// streams overlap. Not self-checking: compare the VRF writes against the flat VRF.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
    li      t0, (1 << 9)                // mstatus.VS = initial
    csrs    mstatus, t0

    li      t0, 4
    vsetvli x0, t0, e64, m1, tu, mu
    li t1, 0x1111; vmv.v.x v1, t1
    li t1, 0x2222; vmv.v.x v2, t1
    li t1, 0x3333; vmv.v.x v3, t1
    // elements 2, 3 of v1 (bank 1) differ
    li t1, 0xc;    vmv.s.x v0, t1
    li t1, 0x10000000; vadd.vx v1, v1, t1, v0.t
    // element 1 of v2 and element 3 of v3 differ
    li t1, 0x2;    vmv.s.x v0, t1
    li t1, 0x7000; vadd.vx v2, v2, t1, v0.t
    li t1, 0x8;    vmv.s.x v0, t1
    li t1, 0x500000; vadd.vx v3, v3, t1, v0.t

    // back-to-back, both EUs
    vadd.vv v4, v1, v2
    vsub.vv v5, v1, v3
    vand.vv v6, v2, v3
    vor.vv  v7, v1, v3
    vmul.vv v8, v1, v2
    li t1, 3
    vsll.vx v9, v3, t1
    vadd.vx v10, v1, t1
    vadd.vi v11, v2, 5

    // LMUL = 2 groups with different data per register and bank
    vmv.v.v v12, v1
    vmv.v.v v13, v3
    vmv.v.v v14, v2
    vmv.v.v v15, v1
    li      t0, 8
    vsetvli x0, t0, e64, m2, tu, mu
    vadd.vv v16, v12, v14
    vsub.vv v18, v14, v12
    vmul.vv v20, v12, v14

    // masked at LMUL = 2: v0 bits 1, 6
    li      t0, 8
    vsetvli x0, t0, e64, m1, tu, mu
    li t1, 0x42;  vmv.s.x v0, t1
    li      t0, 8
    vsetvli x0, t0, e64, m2, tu, mu
    vadd.vv v16, v12, v12, v0.t

    li      t0, 1
    la      t1, tohost
    sd      t0, 0(t1)
1:  j       1b

.section .tohost
.align 8
.globl tohost
tohost: .dword 0
