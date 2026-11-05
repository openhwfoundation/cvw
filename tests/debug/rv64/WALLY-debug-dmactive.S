//////////////////////////////////////////////////////////////////////
// WALLY-debug-dmactive-reset.S
//
// dmcontrol.dmactive deassert/reassert checks. The hart only loads
// known values and spins; all checking is done by
// WALLY-debug-dmactive-reset.tcl through dmcontrol/dmstatus/abstractcs
// and Abstract Access Register reads compared against Spike.
//
// The hart stays halted across every DM reset in the .tcl (Spec leaves
// "does a halted hart resume on DM reset" UNSPECIFIED; Wally and Spike
// both keep it halted), so these GPRs must survive the DM resets:
//
//   t0 (x5) = 0x1122334455667788   read before the first DM reset
//   t1 (x6) = 0x0bad0bad0bad0bad   read after the first DM reset
//   t2 (x7) = 0x0badf00d0badf00d   overwritten by AAR after the first DM
//                                       reset, read back after the second
//
// (Existing WALLY-debug-dmactive stays as the DPC park/resume test.)
//////////////////////////////////////////////////////////////////////
.text
.globl rvtest_entry_point
rvtest_entry_point:
   li   t0, 0x1122334455667788
   li   t1, 0x0bad0bad0bad0bad
   li   t2, 0x0badf00d0badf00d

   la t3, begin_signature

   sw t0, 0(t3)
   sw t1, 8(t3)

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
