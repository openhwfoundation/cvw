//////////////////////////////////////////////////////////////////////
// WALLY-debug-ebreak-stallw
//
// StallW caused ebreak re-halt: one ebreak at offset 52.
//
// After resume, cause must be 3 (haltreq); 1 (ebreak) fail.  If
// StallW hits, EBreak will happen again before the test finally jumps
// to mark_cause.
//
// word0: pass/fail; word1: dcsr.cause
//////////////////////////////////////////////////////////////////////

.text
.globl rvtest_entry_point
rvtest_entry_point:
   la t1, begin_signature
   la t0, trap_handler
   csrw mtvec, t0

park:
   j park

cold:
   j line

.option push
.option norvc

// Cache line for rv64gc. Ebreak not conditioned on ~StallW will end
// up in the memory stage repeating itself.
.balign 64
line:
   .rept 13
   nop
   .endr
   ebreak          // offset 52
   nop             // 56
   nop             // 60
   .space 64

.option pop

after_ebreak:
   j park

mark_cause:
   la t1, begin_signature
   srli t0, a2, 6
   andi t0, t0, 7
   sw t0, 4(t1)
   j park

check_all:
   la t1, begin_signature
   lw t0, 4(t1)
   li t2, 3

   # Cause of halt should be haltrequest, not ebreak
   bne t0, t2, check_fail
   li t0, 0xbe57c0de
   sw t0, 0(t1)
   j test_end
check_fail:
   li t0, 0x00fa11ed
   sw t0, 0(t1)
   j test_end

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

trap_handler:
   la t1, begin_signature
   li t0, 0x00fa11ed
   sw t0, 0(t1)
   j test_end

.data
begin_signature:
   .fill 2, 4, 0xdeadbeef
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
