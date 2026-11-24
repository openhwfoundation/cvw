// euready.S
// Micro-ops of an LMUL > 1 group must dispatch only when an EU takes them. vslidedown runs one extra beat, so at
// LMUL 4 the third micro-op reaches Decode while both integer EUs are busy. Also runs vl = 0, which must not hang
// or write. Self-checking: tohost = 1 pass, (check << 1) | 1 fail.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
    li      t0, (1 << 9)                // mstatus.VS = initial
    csrs    mstatus, t0

    // a different value in each register of the group v16..v19
    li      t0, 4
    vsetvli x0, t0, e64, m1, tu, mu
    li t1, 0x10; vmv.v.x v16, t1
    li t1, 0x11; vmv.v.x v17, t1
    li t1, 0x12; vmv.v.x v18, t1
    li t1, 0x13; vmv.v.x v19, t1

    // LMUL 4 slide by 0 copies the group; then an add right behind it reads the copy
    li      t0, 16
    vsetvli x0, t0, e64, m4, tu, mu
    vslidedown.vi v8, v16, 0
    vadd.vv       v12, v8, v8

    li      t0, 4
    vsetvli x0, t0, e64, m1, tu, mu
    li t2, 1;  vmv.x.s t1, v8;  li t3, 0x10; bne t1, t3, fail
    li t2, 2;  vmv.x.s t1, v9;  li t3, 0x11; bne t1, t3, fail
    li t2, 3;  vmv.x.s t1, v10; li t3, 0x12; bne t1, t3, fail
    li t2, 4;  vmv.x.s t1, v11; li t3, 0x13; bne t1, t3, fail
    li t2, 5;  vmv.x.s t1, v12; li t3, 0x20; bne t1, t3, fail
    li t2, 6;  vmv.x.s t1, v15; li t3, 0x26; bne t1, t3, fail

    // vl = 0: no element is written, so v12 keeps its value
    li      t0, 0
    vsetvli x0, t0, e64, m4, tu, mu
    vadd.vv v12, v16, v16
    li      t0, 4
    vsetvli x0, t0, e64, m1, tu, mu
    li t2, 7;  vmv.x.s t1, v12; li t3, 0x20; bne t1, t3, fail

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
