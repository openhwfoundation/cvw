//////////////////////////////////////////////////////////////////////
// WALLY-debug-data1-preserve.S
//
// A 32-bit (aarsize=2) abstract read of a GPR must only write data0
// and leave data1 unchanged. The debugger loads data1 with a pattern,
// does a 32-bit read of t0 (x5), then uses an aarsize=3 abstract
// write to copy {data1, data0} into t1 (x6).
//
// Signature (written at test1, once before and once after the
// debugger acts):
//   pass 1: t0 = 0x1122334455667788, t1 = 0x0bad0bad0bad0bad (sentinel)
//   pass 2: t0 = 0x1122334455667788, t1 = {data1, data0}
//           correct DM: 0xcafef00d55667788
//           DM that clobbers data1 on a 32-bit read: 0x1122334455667788
//////////////////////////////////////////////////////////////////////
.text
.globl rvtest_entry_point
rvtest_entry_point:
   la   t2, begin_signature

   li   t0, 0x1122334455667788
   li   t1, 0x0bad0bad0bad0bad   # sentinel, overwritten by the debugger

test1:
   sd t0, 0(t2)
   sd t1, 8(t2)
   addi t2, t2, 16
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
   .fill 4*2, 4, 0xdeadbeef
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
