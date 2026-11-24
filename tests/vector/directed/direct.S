// direct.S
// vrgather and vcompress between ordinary vector instructions, at LMUL 1 and 2.  There is no gather/compress EU yet,
// so their results are not checked; the test checks that dispatch holds and releases around the direct bank access
// (no hang) and that the instructions after them still compute correctly.
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
    vid.v   v3

    // direct accesses back to back and between streams
    vadd.vv       v4, v1, v2
    vrgather.vv   v5, v1, v3
    vrgather.vv   v6, v2, v3
    vsub.vv       v7, v2, v1
    vcompress.vm  v8, v1, v2
    vadd.vv       v9, v4, v7

    li t2, 1                            // v4 = 0x3333
    vmv.x.s t1, v4
    li t3, 0x3333
    bne t1, t3, fail
    li t2, 2                            // v9 = 0x3333 + 0x1111
    vmv.x.s t1, v9
    li t3, 0x4444
    bne t1, t3, fail

    // LMUL = 2: every micro-op of a direct instruction waits for the banks to drain
    li      t0, 8
    vsetvli x0, t0, e64, m2, tu, mu
    li t1, 0x1111; vmv.v.x v10, t1
    vrgather.vv   v12, v10, v10
    vadd.vv       v14, v10, v10
    vcompress.vm  v16, v10, v1
    vadd.vv       v18, v14, v10

    li      t0, 4
    vsetvli x0, t0, e64, m1, tu, mu
    li t2, 3                            // v18 = 3 * 0x1111
    vmv.x.s t1, v18
    li t3, 0x3333
    bne t1, t3, fail
    li t2, 4                            // second register of the group
    vmv.x.s t1, v19
    bne t1, t3, fail

    li      t0, 1
    j       done
fail:
    slli    t0, t2, 1
    ori     t0, t0, 1
done:
    la      t1, tohost
    sd      t0, 0(t1)
1:  j       1b

.section .tohost
.align 8
.globl tohost
tohost: .dword 0
