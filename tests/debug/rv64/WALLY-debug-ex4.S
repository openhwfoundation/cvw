//////////////////////////////////////////////////////////////////////
// WALLY-debug-ex4.S - write GPRs - Putting it All Together 4
//////////////////////////////////////////////////////////////////////
.text
.globl rvtest_entry_point
rvtest_entry_point:

   la  t2, begin_signature

   # Load a scattered subset of GPRs with 64-bit recognizable values
   li x3,  0xfeedface8badf00d
   li x11, 0xdead10ccabad1dea
   li x15, 0xcafed00dd15ea5e5
   li x19, 0xb16b00b5fee1dead
   li x23, 0xdeaddeadc0ffee00
   li x27, 0xf00dbabefacefeed
   li x29, 0xba5eba11600df00d
   li x31, 0xdeadcafeba5eba11


test2:
   sd x3,   0(t2)
   sd x11,  8(t2)
   sd x15, 16(t2)
   sd x19, 24(t2)
   sd x23, 32(t2)
   sd x27, 40(t2)
   sd x29, 48(t2)
   sd x31, 56(t2)

   addi t2, t2, 64

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
   .fill 10*2, 4, 0xdeadbeef
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
