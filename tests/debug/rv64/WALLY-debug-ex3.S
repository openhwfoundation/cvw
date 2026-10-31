//////////////////////////////////////////////////////////////////////
// WALLY-debug-03.S - CSR reads/writes - Putting it All Together 3
//////////////////////////////////////////////////////////////////////
.text
.globl rvtest_entry_point
rvtest_entry_point:
   la   t2, begin_signature

   # Read M-mode CSRs
   csrr a0, mstatus       # read mstatus -> a0
   csrr a1, misa          # read misa    -> a1

   # Write 42 to mscratch and read it back
   li   t0, 42
   csrw mscratch, t0      # write 42 -> mscratch
   csrr a2, mscratch      # read mscratch -> a2 (should be 42)

test1:
   sd a0, 0(t2)           # mstatus value
   sd a1, 8(t2)           # misa value
   sd a2, 16(t2)          # mscratch value (should be 42)
   addi t2, t2, 24
1: j 1b

test_end:
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
   .fill 3*2, 4, 0xdeadbeef
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
