// lmul.S
// Directed test of LMUL > 1 micro-ops and active elements for rv64gcv (VLEN = 256, e64: 4 elements per register).
// Each case reads element 0 of a vd register with vmv.x.s.
// tohost = 1 on pass, (case << 1) | 1 on the first failing case.
// Run: tests/vector/directed/run lmul
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

#define FAIL(n) li a7, n; j fail

.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
    li      t0, (1 << 9)                // mstatus.VS = initial
    csrs    mstatus, t0

// sources v16+j = j+1, v24+j = 100*(j+1); destination v8+j = 0x50+j before each case
.macro INITALL
    li      t0, 4
    vsetvli x0, t0, e64, m1, tu, mu
    li t1, 1;   vmv.v.x v16, t1
    li t1, 2;   vmv.v.x v17, t1
    li t1, 3;   vmv.v.x v18, t1
    li t1, 4;   vmv.v.x v19, t1
    li t1, 5;   vmv.v.x v20, t1
    li t1, 6;   vmv.v.x v21, t1
    li t1, 7;   vmv.v.x v22, t1
    li t1, 8;   vmv.v.x v23, t1
    li t1, 100; vmv.v.x v24, t1
    li t1, 200; vmv.v.x v25, t1
    li t1, 300; vmv.v.x v26, t1
    li t1, 400; vmv.v.x v27, t1
    li t1, 500; vmv.v.x v28, t1
    li t1, 600; vmv.v.x v29, t1
    li t1, 700; vmv.v.x v30, t1
    li t1, 800; vmv.v.x v31, t1
    li t1, 0x50; vmv.v.x v8,  t1
    li t1, 0x51; vmv.v.x v9,  t1
    li t1, 0x52; vmv.v.x v10, t1
    li t1, 0x53; vmv.v.x v11, t1
    li t1, 0x54; vmv.v.x v12, t1
    li t1, 0x55; vmv.v.x v13, t1
    li t1, 0x56; vmv.v.x v14, t1
    li t1, 0x57; vmv.v.x v15, t1
.endm

// element 0 of register vreg must equal value
.macro CHECK vreg, value, case
    li      t0, 4
    vsetvli x0, t0, e64, m1, tu, mu
    vmv.x.s a0, \vreg
    li      a1, \value
    beq     a0, a1, 1f
    FAIL(\case)
1:
.endm

    // case 1-2: LMUL=2, vl = VLMAX
    INITALL
    li      t0, 8
    vsetvli x0, t0, e64, m2, tu, mu
    vadd.vv v8, v16, v24
    CHECK v8,  101, 1
    CHECK v9,  202, 2

    // case 3-6: LMUL=4, vl = VLMAX
    INITALL
    li      t0, 16
    vsetvli x0, t0, e64, m4, tu, mu
    vadd.vv v8, v16, v24
    CHECK v8,  101, 3
    CHECK v9,  202, 4
    CHECK v10, 303, 5
    CHECK v11, 404, 6

    // case 7-14: LMUL=8, vl = VLMAX
    INITALL
    li      t0, 32
    vsetvli x0, t0, e64, m8, tu, mu
    vadd.vv v8, v16, v24
    CHECK v8,  101, 7
    CHECK v9,  202, 8
    CHECK v10, 303, 9
    CHECK v11, 404, 10
    CHECK v12, 505, 11
    CHECK v13, 606, 12
    CHECK v14, 707, 13
    CHECK v15, 808, 14

    // case 15-16: LMUL=2, vl = 4: the second register is all tail and keeps its old value
    INITALL
    li      t0, 4
    vsetvli x0, t0, e64, m2, tu, mu
    vadd.vv v8, v16, v24
    CHECK v8,  101,  15
    CHECK v9,  0x51, 16

    // case 17-18: LMUL=2, masked: v0 bit 4 (element 0 of v9) off, bit 0 on
    INITALL
    li      t0, 4
    vsetvli x0, t0, e64, m1, tu, mu
    li      t1, 0xEF
    vmv.v.x v0, t1
    li      t0, 8
    vsetvli x0, t0, e64, m2, tu, mu
    vadd.vv v8, v16, v24, v0.t
    CHECK v8,  101,  17
    CHECK v9,  0x51, 18

    // case 19-20: LMUL=2, masked: v0 bit 0 (element 0 of v8) off, bit 4 on
    INITALL
    li      t0, 4
    vsetvli x0, t0, e64, m1, tu, mu
    li      t1, 0xFE
    vmv.v.x v0, t1
    li      t0, 8
    vsetvli x0, t0, e64, m2, tu, mu
    vadd.vv v8, v16, v24, v0.t
    CHECK v8,  0x50, 19
    CHECK v9,  202,  20

    li      a7, 0
pass:
    li      t0, 1
    j       write_tohost
fail:
    slli    t0, a7, 1
    ori     t0, t0, 1
write_tohost:
    la      t1, tohost
    sd      t0, 0(t1)
1:  j       1b

.section .tohost, "aw", @progbits
.align 6
.globl tohost
tohost: .dword 0
.align 6
.globl fromhost
fromhost: .dword 0
