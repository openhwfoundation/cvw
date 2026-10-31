//////////////////////////////////////////////////////////////////////
// WALLY-debug-halt-at-trapvector
//
// The point of this test is to ensure that when stepping or halting
// over an instruction that traps, that we take the trapvector and
// store the trap vector in DPC.
//////////////////////////////////////////////////////////////////////
.text
.globl rvtest_entry_point
rvtest_entry_point:
   la t1, begin_signature
   li t3, 0
   // Regular trap handler used to enable ebreak
   la t0, trap_handler
   csrw mtvec, t0

// Ebreak after DCSR configuration upon reset halt
do_ebreak:
   ebreak

// Should take the trap after stepping through.
trap_here:
   nop
   ecall

// If this is reached, we've failed
failed:
   li t0, 0x00fa11ed
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

trap_handler2:
   li t0, 0xbe57c0de
   sw t0, 0(t1)
   j test_end

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
