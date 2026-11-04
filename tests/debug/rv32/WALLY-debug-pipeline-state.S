//////////////////////////////////////////////////////////////////////
// WALLY-debug-pipeline-state.S
//
// This test checks if the pipeline state is inconsistent after an
// abstract register write to a GPR. If it is, this means that Wally's
// debug implementation isn't managing pipeline state correctly.
//////////////////////////////////////////////////////////////////////
.text
.globl rvtest_entry_point
rvtest_entry_point:
   la t1, begin_signature
   # Dummy trap handler
   la t0, trap_handler
   csrw mtvec, t0

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
   li t0, 0xffff0000
   addi t0, t0, 4
   addi t0, t0, 4
   addi t0, t0, 4
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
