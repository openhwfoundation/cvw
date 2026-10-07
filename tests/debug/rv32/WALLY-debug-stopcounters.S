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

   # Store the initial cycles
   rdcycle t2

halt:
   j .

confirm:
   rdcycle t3
   sub t4, t3, t2
   li t3, 16
   li t2, 0x00ba771e
   sw t2, 0(t1)
   blt t4, t3, test_end
   li t2, 0x00fa11ed
   sw t2, 0(t1)
   li a0, 1
   j tohost_exit

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
