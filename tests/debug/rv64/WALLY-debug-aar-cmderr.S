//////////////////////////////////////////////////////////////////////
// WALLY-debug-aar-cmderr.S
//
// Abstract Access Register command checks. The hart only loads known
// values and spins; all checking is done by WALLY-debug-aar-cmderr.tcl
// through abstractcs/data0/data1 reads compared against Spike.
//
//   t0 (x5) = 0x1122334455667788   read target
//   t1 (x6) = 0x0bad0bad0bad0bad   sentinel, only the happy-path write may change it
//   t2 (x7) = 0x0badf00d0badf00d   sentinel, must survive a command issued while
//                                       cmderr is set
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
