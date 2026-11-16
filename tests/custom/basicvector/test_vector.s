.section .text
.global testvector
.type testvector, @function

testvector:
        add t1, t2, t3
        sub t1, t2, t3
        xor t1, t2, t3
        sll t1, t2, t3
        or  t1, t2, t3
        la  t1, test
        vle64.v v0, (t1)
        vadd.vv v8, v12, v16
        vadd.vv v4, v0, v8
        add t1, t2, t3
        sub t1, t2, t3
        xor t1, t2, t3
        vadd.vv v12, v8, v16
        xor t1, t2, t3
        vadd.vv v8, v0, v8
        sll t1, t2, t3
        or  t1, t2, t3
        vand.vv v12, v8, v16
        vand.vv v4, v0, v12
        vor.vv v4, v8, v12
        vmul.vv v12, v8, v16
        vmul.vv v4, v0, v12
        add t1, t2, t3
        sub t1, t2, t3
        xor t1, t2, t3
        vmul.vv v16, v4, v12
        xor t1, t2, t3

        ret

.section .data
.align 3

test:
        .dword 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0xa, 0xb, 0xc, 0xd, 0xe, 0xf
