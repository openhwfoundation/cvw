//////////////////////////////////////////////////////////////////////
// WALLY-debug-dm_hart_state_running
//
// Rule dm_hart_state_running:
//   "Harts are running when they are executing normally, as if no
//   debugger was attached. This includes being in a low power mode or
//   waiting for an interrupt, as long as a halt request will result in
//   the hart being halted."
//
// Rule-test program (wfi): the hart waits in a wfi loop (no interrupts enabled).
// The debugger (WALLY-debug-dm_hart_state_running.tcl) checks the rule through the
// DM and ends the test by resuming at test_end.
//////////////////////////////////////////////////////////////////////
.text
.globl rvtest_entry_point
rvtest_entry_point:
   la   t2, begin_signature
   csrci mstatus, 8         # MIE = 0
   csrw mie, zero
park:
   wfi
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
