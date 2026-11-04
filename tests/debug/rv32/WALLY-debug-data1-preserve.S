//////////////////////////////////////////////////////////////////////
// WALLY-debug-data1-preserve.S
//
// A 32-bit (aarsize=2) abstract read of a GPR must only write data0
// and leave data1 unchanged. The debugger loads data1 with a pattern,
// does a 32-bit read of t0 (x5), then uses an aarsize=3 abstract
// write to copy {data1, data0} into f2 (RV32 cannot aarsize=3 a GPR).
//
// Signature (written at test1, once before and once after the
// debugger acts):
//   pass 1: t0 = 0x1122334455667788, t1 = 0x0bad0bad0bad0bad (sentinel)
//   pass 2: t0 = 0x1122334455667788, t1 = {data1, data0}
//           correct DM: 0xcafef00d55667788
//           DM that clobbers data1 on a 32-bit read: 0x0000000055667788
//////////////////////////////////////////////////////////////////////
.text
.globl rvtest_entry_point
rvtest_entry_point:
   la   t2, begin_signature

   # Need FPU so aarsize=3 can land {data1,data0} in f2 for the signature.
   lui  t0, 0x6
   csrs mstatus, t0
   la   t1, fpr_sentinel
   fld  f2, 0(t1)

   li   t0, 0x55667788

test1:
   sw t0, 0(t2)
   fsd f2, 8(t2)
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
.align 3
fpr_sentinel:
   .dword 0x0bad0bad0bad0bad

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
