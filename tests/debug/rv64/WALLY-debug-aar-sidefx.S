//////////////////////////////////////////////////////////////////////
// WALLY-debug-aar-sidefx.S
//
// Abstract Access Register side effects. The hart only sets up mstatus
// / mscratch and spins; WALLY-debug-aar-sidefx.tcl does all checking
// via abstractcs / data0 / data1 against Spike.
//
//   mstatus.FS starts as Initial (01) so an FPR AAR write can be seen
//   to promote it to Dirty (11).
//   mscratch starts as 0x0bad5c6a so a later AAR write is visible.
//////////////////////////////////////////////////////////////////////
.text
.globl rvtest_entry_point
rvtest_entry_point:
   # mstatus.FS = Initial (bits [14:13] = 01); leave other fields alone
   csrr t0, mstatus
   li   t1, ~(3 << 13)
   and  t0, t0, t1
   li   t1, (1 << 13)
   or   t0, t0, t1
   csrw mstatus, t0

   li   t0, 0x0bad5c6a
   csrw mscratch, t0

test1:
1: j 1b                           # debugger halts here

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

.data

begin_signature:
   .fill 4, 4, 0xdeadbeef
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
