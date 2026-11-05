//////////////////////////////////////////////////////////////////////
// WALLY-debug-cause-priority.S
//
// Check dcsr.cause priority (Debug Spec tab:dcsrcausepriority):
//   resethaltreq > halt group > haltreq > trigger > ebreak > step
// Covers haltreq, step, and ebreak-vs-step (see the .tcl header for
// why resethaltreq and haltreq overlaps can't come from a Spike .tv).
// The debugger drives the sequences and checks dcsr.cause; this
// program only provides labeled targets and a pass/fail signature.
//////////////////////////////////////////////////////////////////////
.text
.globl rvtest_entry_point
rvtest_entry_point:
   la t1, begin_signature
   la t0, trap_handler
   csrw mtvec, t0

// Park until the debugger redirects dpc.
park:
   j .

// Single nop used for step / haltreq-vs-step.
do_nop:
   nop
   j park

// ebreak for ebreak-vs-step
do_ebreak:
   nop
   ebreak
   j park

test_end:
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

write_cause:
   srli t4, t4, 6
   andi t4, t4, 0x7
   sw t4, 0(t1)
   lw t5, 0(t1)
   addi t1, t1, 4
   ebreak

.data
# Spike memory regions ###############################################
begin_signature:
   .fill 1*4, 4, 0xdeadbeef
end_signature:

.section .tohost, "aw", @progbits
.align 6
.globl tohost
tohost: .dword 0

.align 6
.globl fromhost
fromhost: .dword 0

.align 6
magic_mem: .word 0, 0, 0, 0, 0, 0, 0, 0
