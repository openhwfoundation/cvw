///////////////////////////////////////////
// spillbothhalvesfault.S
//
// Written: David_Harris@hmc.edu 16 October 2026
//
// Purpose: A 4-byte instruction straddles from page A into page B, and both halves fault: the first
//          halfword is in a PMP grain without execute permission at the end of page A, and page B is
//          not executable.  The first half's access fault must be reported alone (mcause 1, mtval at
//          the first half): its bits are not an instruction, so the IFU must not spill to the second
//          half and report that half's page fault.  The straddling line is executed once while it is
//          still allowed, to bring it into the instruction cache, so the bits the IFU sees for the
//          faulting first half still look like a 32-bit instruction.
//          Self-checking (WALLY-selfcheck.h): the straddling instruction is an addi that counts its
//          executions, so the test checks that it ran once in the warm-up pass and not again, and,
//          from what record_trap logs, that exactly one instruction access fault and no instruction
//          page fault were taken, with mepc and mtval at the start of the straddling instruction.
//          Failure indices: 1 warm-up count, 2 page faults, 3-5 access fault, 6 final count,
//          0xF0 any other trap.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"
.option norvc

// address of the level-0 PTE that maps a label, into reg (clobbers t6)
.macro L0_ENTRY label, reg
    la \reg, \label
    srli \reg, \reg, 12
    andi \reg, \reg, 0x1FF
    slli \reg, \reg, 3
    la t6, l0table
    add \reg, \reg, t6
.endm

main:
    la t0, record_trap
    csrw mtvec, t0

    // Identity-map the first 2 MiB of RAM with 4 KiB pages (Sv39: root -> level 1 -> level 0),
    // built at run time so a single page can be marked non-executable.
    la t0, l0table
    li t1, 0x80000              # PPN of 0x80000000
    li t2, 512
build_l0:
    slli t3, t1, 10
    ori t3, t3, 0xCF            # V R W X A D
    sd t3, 0(t0)
    addi t0, t0, 8
    addi t1, t1, 1
    addi t2, t2, -1
    bnez t2, build_l0
    la t0, l1table
    la t1, l0table
    srli t1, t1, 12
    slli t1, t1, 10
    ori t1, t1, 1               # non-leaf
    sd t1, 0(t0)                # level-1 entry 0: VA 0x80000000-0x801FFFFF
    la t0, roottable
    la t1, l1table
    srli t1, t1, 12
    slli t1, t1, 10
    ori t1, t1, 1
    sd t1, 16(t0)               # root entry 2: VA 0x80000000-0xBFFFFFFF

    la t0, roottable
    srli t0, t0, 12
    li t1, 0x8000000000000000   # MODE = 8, Sv39
    or t0, t0, t1
    csrw satp, t0
    sfence.vma

    li a0, 1
    ecall                       # supervisor mode

    // Warm-up pass: run through the straddling line while it is still executable, so the instruction
    // cache holds it.  s2 = 0 makes the code after the straddle return.  The straddling instruction
    // counts its executions in s3.
    li s2, 0
    li s3, 0
    la t0, nx_grain
    jalr ra, t0, 0              # the grain at the end of page A, then the straddle into page B

    li a0, 3
    ecall                       # machine mode to change the page table and the PMP
    li t2, 1
    SC_CHECK_EQ s3, t2, 1       # the straddle ran once while executable

    // page B: readable but not executable
    L0_ENTRY page_b, t0
    ld t1, 0(t0)
    li t2, -9                   # clear X (bit 3)
    and t1, t1, t2
    sd t1, 0(t0)
    sfence.vma

    // PMP: the last 64 bytes of page A are readable and writable but not executable, inside RWX memory
    la t0, nx_grain
    srli t0, t0, 2
    csrw pmpaddr0, t0           # TOR [0, nx_grain): RWX
    addi t0, t0, 16
    csrw pmpaddr1, t0           # TOR [nx_grain, page B): RW
    li t0, 0xFFFFFFFF
    csrw pmpaddr2, t0           # TOR [page B, 4 GiB): RWX, but page B is not executable in the page table
    li t0, 0x0F0B0F
    csrw pmpcfg0, t0

    li a0, 1
    ecall                       # supervisor mode: paging and PMP both apply
    li s2, 1

    // Jump to the last halfword of page A.  The first half of the instruction there is in the no-execute
    // grain, the second half on non-executable page B.  The handler resumes at both_resume.
    la t0, nx_grain
    addi t0, t0, 62
    jalr zero, t0, 0
both_resume:

    li a0, 3
    ecall

    la a1, pagefault
    ld t2, 0(a1)
    SC_CHECK_EQ t2, zero, 2     # no instruction page fault: the second half was not fetched
    la a1, accessfault
    ld t2, 0(a1)
    li t3, 1
    SC_CHECK_EQ t2, t3, 3       # one instruction access fault
    la t3, nx_grain
    addi t3, t3, 62
    ld t2, 8(a1)
    SC_CHECK_EQ t2, t3, 4       # mepc = straddling instruction
    ld t2, 16(a1)
    SC_CHECK_EQ t2, t3, 5       # mtval = its first half, the one that faulted
    li t2, 1
    SC_CHECK_EQ s3, t2, 6       # the faulting straddle did not execute

    SC_PASS
    j done

// Instruction page faults (12) and instruction access faults (1): count them, save mepc and mtval in
// pagefault or accessfault, and resume at both_resume, since page B, where the straddling instruction
// ends, cannot be executed.  Everything else goes to sc_trap_handler, which passes ecalls to the library
// handler and fails the test on any other trap.
.option push
.option rvc                 # let the alignment padding use 2-byte nops after the compressed library code
.p2align 2
.option pop
record_trap:
    csrrw t0, mscratch, t0      # t0 = trap stack pointer, mscratch = saved t0
    sd t1, -16(t0)
    sd t2, -24(t0)
    csrr t2, mcause
    la t1, pagefault
    addi t2, t2, -12
    beqz t2, 1f
    la t1, accessfault
    addi t2, t2, 11
    beqz t2, 1f
    ld t2, -24(t0)
    ld t1, -16(t0)
    csrrw t0, mscratch, t0      # restore t0 and the trap stack pointer
    j sc_trap_handler
1:  ld t2, 0(t1)
    addi t2, t2, 1
    sd t2, 0(t1)                # count
    csrr t2, mepc
    sd t2, 8(t1)
    csrr t2, mtval
    sd t2, 16(t1)
    la t2, both_resume
    csrw mepc, t2
    ld t2, -24(t0)
    ld t1, -16(t0)
    csrrw t0, mscratch, t0
    mret

// The last 64 bytes of page A are real code so the warm-up pass can execute them: 15 nops, a c.nop,
// and the low half of an addi s3, s3, 1 whose high half is the first halfword of page B.
.option push
.option rvc
.p2align 12
.option pop
page_a:
    .fill 4032, 1, 0
nx_grain:
    .rept 15
    nop
    .endr
    .half 0x0001
    .half 0x8993                # addi s3, s3, 1 = 0x00198993
page_b:
    .half 0x0019
    bnez s2, both_resume
    ret

.data
.p2align 12
roottable:
    .fill 512, 8, 0
l1table:
    .fill 512, 8, 0
l0table:
    .fill 512, 8, 0
pagefault:                      # instruction page faults: count, mepc, mtval
    .fill 3, 8, 0
accessfault:                    # instruction access faults: count, mepc, mtval
    .fill 3, 8, 0
