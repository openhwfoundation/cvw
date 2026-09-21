//////////////////////////////////////////////////////////////////////
// WALLY-debug-step-wfi.S
//
// The purpose of this test is to ensure that WFI is treated as a NOP
// when stepping through it and to ensure that WFI's behavior in Debug
// Mode is consistent with the Debug Specification.
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

wfitest:
   wfi
   li t0, 0xdead0001
   sw t0, 0(t1)
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
   # j .
   li t0, 0x00fa11ed
   sw t0, 0(t1)
   li a0, 0
   j tohost_exit

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
