//////////////////////////////////////////////////////////////////////
// WALLY-debug-dtm_dtmcs_idle_op
//
// Rule dtm_dtmcs_idle_op: "idle: a hint to the debugger of the
//   minimum number of cycles a debugger should spend in
//   Run-Test/Idle after every DMI scan to avoid a busy return
//   code (dmistat of 3)."
//
// Rule-test program: the hart parks in a loop while the debugger
// (WALLY-debug-dtm_dtmcs_idle_op.tcl) checks one normative rule through the DM. The
// debugger ends the test by resuming at test_end.
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
