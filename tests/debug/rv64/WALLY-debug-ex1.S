//////////////////////////////////////////////////////////////////////
// WALLY-debug-ex1.S - Putting it All Together 1
//////////////////////////////////////////////////////////////////////
.text
.globl rvtest_entry_point
rvtest_entry_point:
   la   t2, begin_signature

   li   t0, 42

test1:
   sd t0, 0(t2)
   addi t2, t2, 8
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
