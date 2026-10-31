//////////////////////////////////////////////////////////////////////
// WALLY-debug-step-loop.S
//
// This test is for testing the step feature implementation in Wally.
// This variant of the step test specifically tests how stepping
// performs when jumping or branching
//////////////////////////////////////////////////////////////////////
.text
.globl rvtest_entry_point
rvtest_entry_point:
   la t1, begin_signature
   # Dummy trap handler
   la t0, trap_handler
   csrw mtvec, t0
   li t2, 4

halt1:
   # Infinite loop here instead of ebreak. Ebreak introduces trigger
   # module register reads in OpenOCD for some reason. Until this is
   # configurable in Spike or until we actually have trigger modules
   # in Wally, we don't want these extra testvectors cluttering the
   # output.
   j .

dosteps:
   # stepping through all of this code should cause writes to the
   # memory signature.
1: li t0, 0x00ba771e
   sw t0, 0(t1)
   addi t0, t0, 1
   addi t1, t1, 4
   addi t2, t2, -1
   j 1b

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
