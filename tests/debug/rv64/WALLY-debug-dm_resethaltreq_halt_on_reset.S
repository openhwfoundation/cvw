//////////////////////////////////////////////////////////////////////
// WALLY-debug-dm_resethaltreq_halt_on_reset
//
// Rule dm_resethaltreq_halt_on_reset:
//   "When a hart's halt-on-reset request bit is set, the hart will
//   immediately enter debug mode on the next deassertion of its reset.
//   This is true regardless of the reset's cause."
//
// Rule-test program (park): the hart parks in a loop.
// The debugger (WALLY-debug-dm_resethaltreq_halt_on_reset.tcl) checks the rule through the
// DM and ends the test by resuming at test_end.
//////////////////////////////////////////////////////////////////////
.text
.globl rvtest_entry_point
rvtest_entry_point:
   la   t2, begin_signature
park:
   j    park

test_end:
   la   t2, begin_signature
   li   t0, 0x600dc0de        # reached test_end
   sw   t0, 0(t2)
   sw   t0, 4(t2)
   sw   t0, 8(t2)
   sw   t0, 12(t2)
   li   a0, 0
   j    tohost_exit

.globl tohost_exit
tohost_exit:
   slli a0, a0, 1
   ori  a0, a0, 1
   la   t0, tohost
   sw   a0, 0(t0)
1: j 1b

.data
values:
   .dword 0x0123456789abcdef
begin_signature:
   .fill 4, 4, 0xdeadbeef
end_signature:
   .dword 0

.section .tohost, "aw", @progbits
.align 6
.globl tohost
tohost: .dword 0
.align 6
.globl fromhost
fromhost: .dword 0
