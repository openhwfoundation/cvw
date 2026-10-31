//////////////////////////////////////////////////////////////////////
// WALLY-debug-mret-sret
//
// This test checks to see if DPC takes the value of MEPC or SEPC upon
// an MRET or SRET instruction.
//////////////////////////////////////////////////////////////////////
.text
.globl rvtest_entry_point
rvtest_entry_point:
   la t1, begin_signature

   // Handler used to enable ebreak
   la t0, ebreak_handler
   csrw mtvec, t0

   ebreak
post_ebreak_config:
   # Allow all of RAM in S-mode (example for a single NAPOT entry covering 0x8000_0000-0xFFFF_FFFF)
   li     t0, 0x800fffff >> 2          # pmpaddr0 = base >> 2
   csrw   pmpaddr0, t0
   li     t0, 0b00111111               # R=1 W=1 X=1 A=NAPOT L=0 (unlocked)
   csrw   pmpcfg0, t0

   la t0, m_target  # Load target address to return to from machine mode
   csrw mepc, t0    #
   li t0, (1 << 11)
   li t2, (3 << 11)

   // Debugger needs to step through this point after jumping to m_setup
   ebreak

m_setup:
   csrc mstatus, t2
   csrs mstatus, t0

   mret

fallthrough_m:
   j failed

m_target:
   li t0, 0x0000ffff
   sw t0, 0(t1)
   la t0, s_target
   csrw sepc, t0
   li t0, (0 << 8)
   li t2, (1 << 8)
   ebreak
s_setup: // Debugger progresses to this point and steps through to sret
   csrc sstatus, t2
   csrs sstatus, t0
   sret

fallthrough_s:
   j failed

// -------------------------------------------------------------------
// Supervisor mode: if code reaches here, we've succeeded
// -------------------------------------------------------------------
s_target:
   li t0, 0xf0f0f0f0
   sw t0, 4(t1)
   nop
   ecall

// If this is reached, we've failed
failed:
   li t0, 0x00fa11ed
   sw t0, 0(t1)

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

ebreak_handler:
   j .

trap_handler:
   li t0, 0xbe57c0de
   sw t0, 8(t1)
   j test_end

.data
# Spike memory regions ###############################################
begin_signature:
   .fill 1*4, 4, 0xdeadbeef
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
