//////////////////////////////////////////////////////////////////////
// WALLY-debug-resethaltreq.S
//
// This test is for ensuring that the Debug halting state machine
// waits for committed bus transactions before finally halting.
//////////////////////////////////////////////////////////////////////
.text
.globl rvtest_entry_point
rvtest_entry_point:
   la t1, begin_signature
   # Dummy trap handler
   la t0, trap_handler
   csrw mtvec, t0

halt1:
   li t0, 0x00ba771e
   ebreak

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
   .fill 2*2, 4, 0xdeadbeef
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
