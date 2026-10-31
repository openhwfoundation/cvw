///////////////////////////////////////////
// fenceiwalk.S
//
// Written: David_Harris@hmc.edu 27 October 2026
//
// Purpose: rv32gc: an instruction TLB walk while fence.i is in the Memory stage, so the D$ flush request
//          (FlushDCacheM) is held off by the walker (lsu.sv: FlushDCache = FlushDCacheM & ~SelHPTW).
//          In S mode with Sv32 translation, a loop writes code into a fresh page, executes fence.i, and
//          calls the page.  From the second pass on, the branch predictor sends the front end down a
//          wrong path to an untranslated address while fence.i flushes the D$ in M, and the ITLB miss is
//          walked then.  The wrong-path fetch is discarded when fence.i completes.  Same sequence as the
//          fill loop of tests/coverage64gc/tlbGLBHIT.S.
//          Self-checking: each page runs the code written into it, and no trap but the privilege-change
//          ecalls occurs.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

#define CODE_VA  0xC0000000             // virtual address of the first code page (root index 0x300)
#define NPAGES   4
#define PTE_PTR  0x01                   // V: pointer to the next level
#define PTE_RWXAD 0xCF                  // V R W X A D leaf
#define ADDI_A5  0x00000793             // addi a5, x0, 0
#define RET      0x00008067             // jalr x0, 0(ra)

main:
    SC_STRICT_TRAPS                     // fail on any trap but an ecall

    // Sv32 page table: VA 0x80000000-0x803FFFFF identity megapage (V R W X A D);
    // VA CODE_VA + i*4 KiB -> code_pages + i*4 KiB for i < NPAGES
    la a1, pagetable_root
    la a3, pagetable_l0
    li t0, 0x200000CF
    li t1, 0x200*4
    add t1, t1, a1
    sw t0, 0(t1)                        // root[0x200]: identity megapage
    srli t0, a3, 12
    slli t0, t0, 10
    ori t0, t0, PTE_PTR
    li t1, 0x300*4
    add t1, t1, a1
    sw t0, 0(t1)                        // root[0x300] -> level 0 table
    la t1, code_pages
    srli t1, t1, 12
    slli t1, t1, 10
    ori t1, t1, PTE_RWXAD               // leaf PTE of the first code page
    li t2, 0
    li t3, NPAGES
1:  sw t1, 0(a3)                        // level0[i]: code page i
    addi a3, a3, 4
    addi t1, t1, 1 << 10                // next physical page
    addi t2, t2, 1
    blt t2, t3, 1b

    la t0, pagetable_root               // satp = Sv32, root page table
    srli t0, t0, 12
    li t1, 1
    slli t1, t1, 31
    or t0, t0, t1
    csrw satp, t0
    sfence.vma

    li a0, 1
    ecall                               // to S mode
    li t0, CODE_VA
    li t2, 0                            // page number = the value its code returns
    li t3, NPAGES
    li t4, 0x1000
    li s11, ADDI_A5
    li s10, RET
fill:
    slli t1, t2, 20
    or t1, t1, s11                      // addi a5, x0, i
    sw t1, 0(t0)                        // write the code into page i (DTLB fill)
    sw s10, 4(t0)                       // ret
    fence.i
    li a5, -1
    jalr t0                             // fetch and run it (ITLB fill)
    SC_CHECK_EQ a5, t2, 1
    add t0, t0, t4
    addi t2, t2, 1
    blt t2, t3, fill

    li a0, 3
    ecall                               // back to M mode
    csrw satp, zero
    SC_PASS
    j done

.data
.align 12
pagetable_root:
    .fill 1024, 4, 0
.align 12
pagetable_l0:
    .fill 1024, 4, 0
.align 12
code_pages:
    .fill NPAGES*1024, 4, 0
