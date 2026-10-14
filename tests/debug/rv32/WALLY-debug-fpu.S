//////////////////////////////////////////////////////////////////////
// WALLY-debug-fpu.S
//
// This test implements a basic newton-raphson method reciprocal
// square root calculation for calculating 1/sqrt(2)
//////////////////////////////////////////////////////////////////////
.text
.globl rvtest_entry_point
rvtest_entry_point:
   # la t0, values
   la t1, begin_signature

enable_fpu:
   lui t2, 0x6
   csrs mstatus, t2

newton_prep:
   li t2, 0x3f000000 # 0.50 = multiplication constant
   li t3, 0x3f400000 # 0.75 = y_0 = initial guess
   li t4, 0x3fc00000 # 1.50 = subtraction constant
   li t5, 0x40000000 # 2.00 = x_0 = target input

   fmv.w.x f0, t2
   fmv.w.x f1, t3
   fmv.w.x f2, t4
   fmv.w.x f3, t5

   # Set index
   li t2, 4          # four iterations

loop:
   # Initial iteration
   fmul.s f4, f1, f1 # square initial guess
   fmul.s f4, f4, f3 # multiply by input value 'a'
   fmul.s f4, f4, f0 # halve the value
   fsub.s f4, f2, f4 # subtract from 1.5
   fmul.s f1, f4, f1 # final result

   fsw f1, 0(t1)     # store iteration result to memory
   addi t1, t1, 4    # increment signature address
   addi t2, t2, -1
1: j 1b              # pause for debugger. Can be implemented as ebreak later

resume_addr:
   bnez t2, loop

test_end:
   # fence.i
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
# Spike memory regions ###############################################
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
