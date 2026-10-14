//////////////////////////////////////////////////////////////////////
// WALLY-debug-ex6.S - breakpoint, resume, run to it, read var
// Putting it All Together 6
//////////////////////////////////////////////////////////////////////
.text
.globl rvtest_entry_point
rvtest_entry_point:

   la   t2, begin_signature

   # Initialize counter and accumulator
   li   t0, 0             # t0 = loop counter
   li   t1, 0             # t1 = accumulator
   li   t3, 10            # t3 = loop limit

loop:
   addi t0, t0, 1         # counter++
   add  t1, t1, t0        # accumulator += counter (1+2+...+10 = 55)
   blt  t0, t3, loop      # if counter < 10, loop back

   # After loop: t0 = 10, t1 = 55 (0x37)
   # Debugger sets a breakpoint here, resumes, and runs to this point
breakpoint_here:
   nop                    # <-- breakpoint target

   # Read var (t1 = accumulator = 55) and store to signature
test1:
   sd t0,  0(t2)          # store counter (should be 10 = 0xa)
   sd t1,  8(t2)          # store accumulator (should be 55 = 0x37)
   addi t2, t2, 16

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
   .fill 2*2, 4, 0xdeadbeef       # 2 doublewords: counter + accumulator
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
