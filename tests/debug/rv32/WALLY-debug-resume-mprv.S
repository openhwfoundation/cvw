//////////////////////////////////////////////////////////////////////
// WALLY-debug-resume-mprv
//
// Debug Spec 1.0 sec. 4.6 (dret / resume): the hart changes to the
// privilege mode in dcsr.prv, and "if the new privilege mode is less
// privileged than M-mode, MPRV in mstatus is cleared."
//
// Setup (M-mode): mstatus.MPRV=1, mstatus.MPP=M, and a single PMP
// entry that gives U-mode execute-only access to all memory. Halt on
// ebreak. The debugger writes dcsr.prv=U and dpc=u_code, then resumes.
//
// Correct hart: MPRV is cleared on resume, so the U-mode load in
// u_code checks PMP as U, faults (mcause=5), and the trap handler
// halts on ebreak with t3=5.
//
// Buggy hart (MPRV left set): the U-mode load is translated/checked
// as MPP=M, PMP is bypassed, the load succeeds, t3=0xbad and u_code
// halts on ebreak (ebreaku).
//
// At the second halt the debugger copies mstatus -> a2 (abstract
// CSR->GPR copy), sets dpc=check, dcsr.prv=M and resumes. check
// self-checks:
//   word0: 0xbe57c0de pass / 0x00fa11ed fail
//   word1: mstatus.MPRV seen at the second halt (expect 0)
//   word2: t3 (expect 5 = load access fault)
//////////////////////////////////////////////////////////////////////

.text
.globl rvtest_entry_point
rvtest_entry_point:
   la   t1, begin_signature
   la   t0, trap_handler
   csrw mtvec, t0

   # PMP entry 0: NAPOT over all memory, X only (R=W=0, L=0).
   # M-mode ignores it (unlocked); U-mode may fetch but not load/store.
   li   t0, -1
   csrw pmpaddr0, t0
   li   t0, 0x1c                 # A=NAPOT(0x18) | X(0x4)
   csrw pmpcfg0, t0

   # mstatus.MPP = M, mstatus.MPRV = 1. Legal and harmless in M-mode.
   li   t0, (3 << 11) | (1 << 17)
   csrs mstatus, t0

   li   t3, 0
   ebreak                        # halt #1: cause=ebreak, prv=M
park:
   j    park

   # Entered from the debugger with dcsr.prv = U.
u_code:
   lw   t3, 0(t1)                # must fault: U has no R permission
   li   t3, 0xbad                # only reached if MPRV leaked (load ran as M)
   ebreak                        # halt #2 (buggy path, ebreaku)
1: j 1b

   # M-mode trap handler. No loads/stores here: on the buggy path
   # MPRV/MPP could make them misbehave.
trap_handler:
   csrr t3, mcause
   li   t4, 3                    # breakpoint before the debugger set
   beq  t3, t4, spin             # dcsr.ebreakm (free-run after reset)
   ebreak                        # halt #2 (correct path, ebreakm)
spin:
   j    spin

   # Resumed by the debugger in M with a2 = mstatus snapshot.
check:
   li   t0, (1 << 17)
   csrc mstatus, t0              # make our own stores plain M-mode
   la   t1, begin_signature
   srli t0, a2, 17
   andi t0, t0, 1
   sw   t0, 4(t1)                # word1: MPRV after resume to U
   sw   t3, 8(t1)                # word2: t3 (mcause or 0xbad)
   bnez t0, check_fail
   li   t2, 5
   bne  t3, t2, check_fail
   li   t0, 0xbe57c0de
   sw   t0, 0(t1)
   j    test_end
check_fail:
   li   t0, 0x00fa11ed
   sw   t0, 0(t1)
   j    test_end

test_end:
   li   a0, 0
   j    tohost_exit

.globl tohost_exit
tohost_exit:
   slli a0, a0, 1
   ori  a0, a0, 1
   la   t0, tohost
   sw   a0, 0(t0)
3: j 3b

.data
begin_signature:
   .fill 2*2, 4, 0xdeadbeef
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
