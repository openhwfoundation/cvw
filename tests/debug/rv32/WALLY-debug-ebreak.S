//////////////////////////////////////////////////////////////////////
// WALLY-debug-fpu.S
//
// This test implements a basic newton-raphson method reciprocal
// square root calculation for calculating 1/sqrt(2)
//////////////////////////////////////////////////////////////////////
.text
.globl rvtest_entry_point
rvtest_entry_point:
   la t1, begin_signature
   la t0, trap_handler
   csrw mtvec, t0

// Attempt ebreak, though it's not likely set the first time
do_ebreak:
   li t0, 0x00ba771e
   ebreak
   li t0, 0x00fa11ed

resume_addr:
1: j 1b

write_val:
   sw t0, 0(t1)

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
   j .

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
