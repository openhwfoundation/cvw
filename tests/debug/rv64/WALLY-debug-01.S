//////////////////////////////////////////////////////////////////////
// WALLY-debug-01.S - immutability
//////////////////////////////////////////////////////////////////////
.text
.globl rvtest_entry_point
rvtest_entry_point:
   la   t2, begin_signature

   li   t4, 0x1234
   add  x0, x0, t4        # attempt to modify x0 (s/b ignored)
   addi t5, x0, 5         # another attempt (ignored), t5 should become 5 (since x0=0)

   mv   t6, x0            # read x0 -> t6 (must be 0)

test1:
   sd t6, 0(t2)
   sd t5, 8(t2)
   sd t6, 16(t2)
   addi t2, t2, 24
1: j 1b

test_end:
   j tohost_exit

.globl tohost_exit
tohost_exit:
   slli a0, a0, 1
   ori a0, a0, 1
   la t0, tohost
   sw a0, 0(t0)
1: j 1b

.data

begin_signature:
   .fill 5*2, 4, 0xdeadbeef
end_signature:

.section .tohost, "aw", @progbits
.align 6
.globl tohost
tohost: .dword 0

.align 6
.globl fromhost
fromhost: .dword 0

# a syscall buffer?
.align 6
magic_mem: .word 0, 0, 0, 0, 0, 0, 0, 0
