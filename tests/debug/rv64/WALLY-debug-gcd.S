//////////////////////////////////////////////////////////////////////
// WALLY-debug-gcd.S
//////////////////////////////////////////////////////////////////////
.text
.globl rvtest_entry_point
rvtest_entry_point:
   la   t2, begin_signature

   li   s2, 0x67B16B7B      # a = 1739680635  = s2*17
   li   s3, 0x4015F8C2      # b = 1075181762  = s3*17

   # zero-extend to 64-bit (safe on RV64)
   slli s2, s2, 32
   srli s2, s2, 32
   slli s3, s3, 32
   srli s3, s3, 32
   mv   t0, s2
   mv   t1, s3
   csrr t4, minstret        # start count

gcd_loop:
   beqz t1, test1
   remu t3, t0, t1
   mv   t0, t1
   mv   t1, t3
   j    gcd_loop

test1:
   csrr t5, minstret
   sub  t6, t5, t4
   sd t0, 0(t2)
   addi t2, t2, 8
   sd s2, 0(t2)
   addi t2, t2, 8
   sd s3, 0(t2)
   addi t2, t2, 8
   sd t6, 0(t2)
   addi t2, t2, 8
1: j 1b

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
   .fill 5*2, 4, 0xdeadbeef
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
