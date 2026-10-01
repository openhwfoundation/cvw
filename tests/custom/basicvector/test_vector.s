.section .text
.global testvector
.type testvector, @function

testvector:
        add t1, t2, t3
        sub t1, t2, t3
        xor t1, t2, t3
        sll t1, t2, t3
        or  t1, t2, t3
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
        ret
