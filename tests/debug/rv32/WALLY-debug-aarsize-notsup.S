//////////////////////////////////////////////////////////////////////
// WALLY-debug-aarsize-notsup.S
//
// A 64-bit (aarsize=3) abstract access to a 32-bit GPR on RV32 must
// fail with a nonzero cmderr and must not touch data0/data1. While
// cmderr is nonzero, further commands must be ignored. After cmderr
// is cleared, 32-bit GPR accesses and 64-bit FPR accesses (D
// supported) must work.
//
// The debugger loads data0 = 0xa5a5a5a5 and data1 = 0xcafef00d, then:
//   1. aarsize=3 access to t0 (x5)    -> must fail, data untouched
//   2. aarsize=2 write t1 (x6)        -> ignored (cmderr still set)
//   3. clear cmderr
//   4. aarsize=2 write t2 (x7)        <- data0
//   5. aarsize=3 write f2             <- {data1, data0}
//
// Signature (written at test1, once before and once after the
// debugger acts), per pass: t0, t1, t2, pad, f2 (64 bits)
//   pass 1: 0x55667788, 0x0bad0bad, 0x0badf00d, 0, 0x0bad0bad0bad0bad
//   pass 2 (correct DM):
//           0x55667788, 0x0bad0bad, 0xa5a5a5a5, 0, 0xcafef00da5a5a5a5
//   pass 2 (DM that accepts aarsize=3 on an RV32 GPR):
//           0x55667788, 0x55667788, 0x55667788, 0, 0x0000000055667788
//////////////////////////////////////////////////////////////////////
.text
.globl rvtest_entry_point
rvtest_entry_point:
   la   s1, begin_signature

enable_fpu:
   lui  t2, 0x6
   csrs mstatus, t2

   la   t1, fpr_pattern
   fld  f1, 0(t1)              # read back by the debugger (aarsize=3)
   la   t1, fpr_sentinel
   fld  f2, 0(t1)              # sentinel, overwritten by the debugger
   li   t0, 0x55667788
   li   t1, 0x0bad0bad         # sentinel, must survive (command ignored)
   li   t2, 0x0badf00d         # sentinel, overwritten by the debugger

test1:
   sw  t0,    0(s1)
   sw  t1,    4(s1)
   sw  t2,    8(s1)
   sw  zero, 12(s1)
   fsd f2,   16(s1)
   addi s1, s1, 24
1: j 1b                        # debugger halts here

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
fpr_pattern:
   .dword 0x0123456789abcdef
fpr_sentinel:
   .dword 0x0bad0bad0bad0bad

.align 3
begin_signature:
   .fill 6*2, 4, 0xdeadbeef
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
