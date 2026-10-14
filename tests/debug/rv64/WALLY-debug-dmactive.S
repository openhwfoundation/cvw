//////////////////////////////////////////////////////////////////////
// WALLY-debug-01.S
//////////////////////////////////////////////////////////////////////
.text
.globl rvtest_entry_point
rvtest_entry_point:
   la t1, values
   la t2, begin_signature

   # first batch of values written to signature
test1:
   li t0, 8
2: ld t3, 0(t1)
   sd t3, 0(t2)
   addi t1, t1, 8
   addi t2, t2, 8
   addi t0, t0, -1
   bnez t0, 2b
1: j 1b

test2:
   li t0, 8
2: ld t3, 0(t1)
   sd t3, 0(t2)
   addi t1, t1, 8
   addi t2, t2, 8
   addi t0, t0, -1
   bnez t0, 2b
1: j 1b

test3:
   li t0, 8
2: ld t3, 0(t1)
   sd t3, 0(t2)
   addi t1, t1, 8
   addi t2, t2, 8
   addi t0, t0, -1
   bnez t0, 2b
1: j 1b

test4:
   li t0, 8
2: ld t3, 0(t1)
   sd t3, 0(t2)
   addi t1, t1, 8
   addi t2, t2, 8
   addi t0, t0, -1
   bnez t0, 2b
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
# Storing 32 unique 64-bit values as dwords
values:
   .dword 0xCAFEBABE
   .dword 0xDECAF4CE
   .dword 0xBEEFCACE
   .dword 0xF00DCAFE
   .dword 0xC0DEBA5E
   .dword 0xFADED1CE
   .dword 0xB00CFACE
   .dword 0xDABBAD00
   .dword 0xC0FFEEB0
   .dword 0xFEEDBABE
   .dword 0xC0C0B0B0
   .dword 0xD1CEB0A7
   .dword 0xBADD00D5
   .dword 0xF0E1D0E5
   .dword 0xC0DED00D
   .dword 0xBEEF1E57
   .dword 0xCA5EFADE
   .dword 0xF00DBEAD
   .dword 0xD0D0BEAD
   .dword 0xBABEFADE
   .dword 0xC0FEB0B5
   .dword 0xDEADB00F
   .dword 0xF1E1DCAF
   .dword 0xB0B0C0DE
   .dword 0xCAFEF00D
   .dword 0xD1CEFA5E
   .dword 0xBEEFB007
   .dword 0xF0E5C0DE
   .dword 0xC0C0FA5E
   .dword 0xBAD1DEA5
   .dword 0xFEEDB0B5
   .dword 0xDEADFAC7

begin_signature:
   .fill 32*2, 4, 0xdeadbeef
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
