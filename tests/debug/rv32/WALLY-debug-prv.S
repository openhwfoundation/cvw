//////////////////////////////////////////////////////////////////////
// WALLY-debug-prv.S
//
// The purpose of this test is to ensure that WFI is treated as a NOP
// when stepping through it and to ensure that WFI's behavior in Debug
// Mode is consistent with the Debug Specification.
//////////////////////////////////////////////////////////////////////
.text
.globl rvtest_entry_point
rvtest_entry_point:
   # Dummy trap handler
   la t0, trap_handler
   csrw mtvec, t0

smode_setup:
   # Read-modify-write mstatus.MPP[12:11] → 01 (Supervisor mode)
   csrr   t0, mstatus
   li     t1, ~(3 << 11)          # clear MPP field (bits 12:11)
   and    t0, t0, t1
   li     t1, (1 << 11)           # set MPP = 01 (S-mode)
   or     t0, t0, t1
   csrw   mstatus, t0

   # Allow all of RAM in S-mode (example for a single NAPOT entry covering 0x8000_0000-0xFFFF_FFFF)
   li     t0, 0x800fffff >> 2          # pmpaddr0 = base >> 2
   csrw   pmpaddr0, t0
   li     t0, 0b00111111               # R=1 W=1 X=1 A=NAPOT L=0 (unlocked)
   csrw   pmpcfg0, t0

   # Point mepc at the code you want to run in supervisor mode
   la     t0, halt1
   csrw   mepc, t0
   la t1, begin_signature

   # Switch to S-mode
   mret

halt1:
   # Trying to use ebreak instead of infinite loops. Doing this is
   # slightly more inconvenient than infinite loops but is correct
   # usage of the Debug Specification. Initially, ebreak's are not
   # configured to halt the processor, thus, they will go straight to
   # the trap handler. The trap_handler needs to
   ebreak

prvtest:
   # The idea of this test is that, I should be able to write to MEPC
   # because the Debugger will already have changed the privileged
   # mode. If the implementation of DCSR's prv field is wrong, a trap
   # will be asserted and the processor will jump to the trap_handler
   # instead. The trap handler will then write a different value to
   # the signature than what would have happened had the test
   # succeeded and exit the test.

   # Write to MEPC so we can jump there on mret
   la t0, test_end
   csrw mepc, t0

   # Write the signature
   li t2, 0x00ba771e
   sw t2, 0(t1)
   mret

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
   # If: ebreak caused the trap, loop continuously until the debugger
   # can enable ebreak in the DCSR.
   csrr t0, mcause
   li t2, 0x0000000000000003
   beq t0, t2, wait
   # Else: fail the test. Something else caused the trap.
   li t0, 0x0000000000fa11ed
   sw t0, 0(t1)
   csrr t0, mcause
   sw t0, 8(t1)
   csrr t0, mepc
   sw t0, 16(t1)
   li a0, 1
   j tohost_exit

wait:
   j .

.data
# Spike memory regions ###############################################
begin_signature:
   .fill 3*2, 4, 0xdeadbeef
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
