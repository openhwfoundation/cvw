//////////////////////////////////////////////////////////////////////
// WALLY-debug-catch-replay.S
//
// This test is used to halt not during a looping instruction
//////////////////////////////////////////////////////////////////////
.text
.globl rvtest_entry_point
rvtest_entry_point:
   la t1, begin_signature
   la t0, trap_handler
   csrw mtvec, t0

// Attempt ebreak, though it's not likely set the first time
do_ebreak:
   ebreak

setup_test:
   li t2, 10000

doloop:
   addi t0, t0, 1
   addi t0, t0, 2
   addi t0, t0, 3
   addi t0, t0, 4
   addi t0, t0, 5
   addi t0, t0, 6
   addi t0, t0, 7
   addi t0, t0, 8
   addi t0, t0, 9
   addi t0, t0, 10
   addi t0, t0, 11
   addi t0, t0, 12
   addi t0, t0, 13
   addi t0, t0, 14
   addi t0, t0, 15
   addi t0, t0, 16
   addi t0, t0, 17
   addi t0, t0, 18
   addi t0, t0, 19
   addi t0, t0, 20
   sw t0, 0(t1)
   addi t2, t2, -1
   bnez t2, doloop

test_end:
   # fence.i
   li a0, 0
   j tohost_exit

.globl tohost_exit
tohost_exit:
   slli a0, a0, 1
   ori a0, a0, 1
   la t0, tohost
   sw a0, 0(t0)
1: j 1b

trap_handler:
1: nop
   j 1b

.data
# Spike memory regions ###############################################
begin_signature:
   .fill 1*2, 4, 0xdeadbeef
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
