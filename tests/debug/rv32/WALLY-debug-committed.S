//////////////////////////////////////////////////////////////////////
// WALLY-debug-step-committed.S
//
// This test is for ensuring that the Debug halting state machine
// waits for committed bus transactions before finally halting.
//////////////////////////////////////////////////////////////////////
.text
.globl rvtest_entry_point
rvtest_entry_point:
   la t1, begin_signature
   # Dummy trap handler
   la t0, trap_handler
   csrw mtvec, t0
   la t2, values

   la t4, 16 # Loop must be stepped through this many times from the debugger

halt1:
   # Infinite loop here instead of ebreak. Ebreak introduces trigger
   # module register reads in OpenOCD for some reason. Until this is
   # configurable in Spike or until we actually have trigger modules
   # in Wally, we don't want these extra testvectors cluttering the
   # output.
   j .

dosteps:
1: lw t3, 0(t2)
   addi t3, t3, 1
   sw t3, 0(t1)
   addi t2, t2, 8
   addi t1, t1, 4
   addi t4, t4, -1
   bnez t4, 1b

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

trap_handler:
   j .

.data

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

# Spike memory regions ###############################################
begin_signature:
   .fill 8*2, 4, 0xdeadbeef
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
