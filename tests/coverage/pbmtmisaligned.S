///////////////////////////////////////////
// pbmtmisaligned.S
//
// Written: David_Harris@hmc.edu 19 September 2026
//
// Purpose: Test coverage for accesses through Svpbmt non-cacheable (NC) pages: misaligned loads,
//          stores and AMOs to an NC data page, and instruction fetch from an NC code page while
//          the ITLB misses and the pipeline is stalled by data cache misses and stores.
//          Self-checking (WALLY-selfcheck.h), with every check after the sequences: record_trap
//          logs mcause, mepc and mtval of each misaligned or access fault and fails the test on
//          any other trap but an ecall, and the test checks the log against the eight traps
//          expected, that the faulting loads and AMOs left their destinations alone and the
//          faulting stores and AMOs left memory alone, and the values of the aligned accesses and
//          of the loads and stores run from the NC code page.  Failure indices: 1-2 trap log,
//          3-8 faulting destinations, 9-12 aligned accesses and nc_data, 13-23 NC code page,
//          0xF0 an unexpected trap.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"
.option norvc

#define NCPAT 0x3C3C0000            // word k of nc_data holds NCPAT + k
#define COLD  0x5A5A0000            // word k of cold_data holds COLD + k
#define SENT  0x0123456789ABCDEF    // in each destination of a faulting load or AMO
#define STDATA 0xFEDCBA9876543210   // stored by the faulting stores

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
    // built at run time so individual pages can be given a PBMT.
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

    // PBMT = NC (bit 61) on the data page and the code page
    li t2, 0x2000000000000000
    L0_ENTRY nc_data, t0
    ld t1, 0(t0)
    or t1, t1, t2
    sd t1, 0(t0)
    L0_ENTRY nc_code, t0
    ld t1, 0(t0)
    or t1, t1, t2
    sd t1, 0(t0)
    li t0, 0x4000000000000000   # menvcfg.PBMTE
    csrs menvcfg, t0

    la t0, roottable
    srli t0, t0, 12
    li t1, 0x8000000000000000   # MODE = 8, Sv39
    or t0, t0, t1
    csrw satp, t0
    sfence.vma

    li a0, 1
    ecall                       # supervisor mode

    // Misaligned accesses through the NC page, each after an sfence.vma so the DTLB misses while
    // the access is outstanding.  The page is idempotent but not cacheable, so misaligned loads and
    // stores are not handled in hardware and raise address-misaligned exceptions; misaligned AMOs
    // raise access faults.  The handler skips them all.  Each faulting load and AMO has its own
    // destination, preset to SENT, and the faulting stores store STDATA.
    li s3, SENT
    mv s4, s3
    mv s5, s3
    mv s6, s3
    mv s7, s3
    mv s8, s3
    li s9, STDATA
    la a1, nc_data
    sfence.vma
mis_lw:
    lw s3, 1(a1)
    sfence.vma
mis_lh:
    lh s4, 1(a1)
    sfence.vma
mis_sw:
    sw s9, 1(a1)
    sfence.vma
mis_sd:
    sd s9, 2(a1)
    sfence.vma
mis_ld:
    ld s5, 4(a1)
    addi a2, a1, 2
    sfence.vma
mis_amoaddw:
    amoadd.w s6, zero, (a2)     # misaligned AMOs to the NC page take an access fault
    sfence.vma
mis_amoaddd:
    amoadd.d s7, zero, (a2)
    sfence.vma
mis_amoswapw:
    amoswap.w s8, zero, (a2)
    lw a4, 0(a1)                # aligned accesses to the same page
    sw a4, 0(a1)
    amoadd.w a6, zero, (a1)

    // Execute from the NC page after an sfence.vma, so the ITLB misses on a non-cacheable page and
    // every instruction fetch there goes uncached to the bus.
    sfence.vma
    la t0, nc_code
    jalr ra, t0, 0

    li a0, 3
    ecall

    // The eight misaligned accesses trapped in order, each at its own instruction with the
    // misaligned address in mtval
    la a1, traplog
    ld t2, 0(a1)
    li t3, 8
    SC_CHECK_EQ t2, t3, 1       # eight traps
    addi a1, a1, 8
    la a2, expected_traps
    li a3, 24                   # 8 traps x (mcause, mepc, mtval)
1:  ld t2, 0(a1)
    ld t3, 0(a2)
    SC_CHECK_EQ_ADR t2, t3, a1, 2
    addi a1, a1, 8
    addi a2, a2, 8
    addi a3, a3, -1
    bnez a3, 1b
    // The faulting loads and AMOs did not write their destinations
    li t3, SENT
    SC_CHECK_EQ s3, t3, 3       # lw
    SC_CHECK_EQ s4, t3, 4       # lh
    SC_CHECK_EQ s5, t3, 5       # ld
    SC_CHECK_EQ s6, t3, 6       # amoadd.w
    SC_CHECK_EQ s7, t3, 7       # amoadd.d
    SC_CHECK_EQ s8, t3, 8       # amoswap.w
    // The aligned accesses: lw and amoadd.w read word 0, and nc_data is unchanged, so neither the
    // faulting stores and AMOs nor the aligned store and amoadd.w of the value already there changed it
    li t3, NCPAT
    SC_CHECK_EQ a4, t3, 9       # lw
    SC_CHECK_EQ a6, t3, 10      # amoadd.w returns the old value
    la a1, nc_data
    ld t2, 0(a1)
    li t3, ((NCPAT + 1) << 32) | NCPAT
    SC_CHECK_EQ t2, t3, 11
    ld t2, 8(a1)
    li t3, ((NCPAT + 3) << 32) | (NCPAT + 2)
    SC_CHECK_EQ t2, t3, 12
    // Loads and stores run from the NC code page: cold_data word k held COLD + k
    li t3, COLD
    SC_CHECK_EQ s0, t3, 13      # lw 0
    li t3, COLD + 32
    SC_CHECK_EQ s1, t3, 14      # lw 128
    li t3, COLD + 64
    SC_CHECK_EQ s2, t3, 15      # lw 256
    li t3, COLD + 96
    SC_CHECK_EQ s10, t3, 16     # lw 384
    li t3, COLD + 160
    SC_CHECK_EQ a7, t3, 17      # lw 640
    la a1, cold_data
    lwu t2, 64(a1)
    li t3, COLD
    SC_CHECK_EQ t2, t3, 18      # sw 64
    lwu t2, 192(a1)
    li t3, COLD + 32
    SC_CHECK_EQ t2, t3, 19      # sw 192
    lwu t2, 320(a1)
    li t3, COLD + 64
    SC_CHECK_EQ t2, t3, 20      # sw 320
    li t3, COLD + 96
    lwu t2, 448(a1)
    SC_CHECK_EQ t2, t3, 21      # sw 448
    lwu t2, 512(a1)
    SC_CHECK_EQ t2, t3, 22      # sw 512
    lwu t2, 576(a1)
    SC_CHECK_EQ t2, t3, 23      # sw 576

    SC_PASS
    j done

// Misaligned load (4), misaligned store/AMO (6) and store/AMO access fault (7): log mcause, mepc and mtval
// in traplog, then let the library handler skip the instruction.  Everything else goes to
// sc_trap_handler, which passes ecalls to the library handler and fails the test on any other trap.
.align 4
record_trap:
    csrrw t0, mscratch, t0      # t0 = trap stack pointer, mscratch = saved t0
    sd t1, -16(t0)
    sd t2, -24(t0)
    sd t3, -32(t0)
    csrr t1, mcause
    li t2, 4
    beq t1, t2, 1f
    li t2, 6
    beq t1, t2, 1f
    li t2, 7
    beq t1, t2, 1f
    ld t3, -32(t0)
    ld t2, -24(t0)
    ld t1, -16(t0)
    csrrw t0, mscratch, t0      # restore t0 and the trap stack pointer
    j sc_trap_handler
1:  la t2, traplog
    ld t3, 0(t2)
    addi t3, t3, 1
    sd t3, 0(t2)                # count every trap
    li t1, 8
    bgtu t3, t1, 2f             # log the first eight
    slli t1, t3, 4
    slli t3, t3, 3
    add t1, t1, t3
    add t1, t1, t2              # traplog + 24 * count: entry count - 1 is at -16(t1)
    csrr t3, mcause
    sd t3, -16(t1)
    csrr t3, mepc
    sd t3, -8(t1)
    csrr t3, mtval
    sd t3, 0(t1)
2:  ld t3, -32(t0)
    ld t2, -24(t0)
    ld t1, -16(t0)
    csrrw t0, mscratch, t0
    j trap_handler

// Runs from the non-cacheable page.  The data cache misses stall the pipeline while the uncached
// fetch of the following instruction is in flight, and each store makes the RAM insert a wait
// state on the read that follows it.
.p2align 12
nc_code:
    la t0, cold_data
    lw s0, 0(t0)
    sw s0, 64(t0)
    lw s1, 128(t0)
    sw s1, 192(t0)
    lw s2, 256(t0)
    sw s2, 320(t0)
    lw s10, 384(t0)
    sw s10, 448(t0)
    sw s10, 512(t0)
    sw s10, 576(t0)
    lw a7, 640(t0)
    ret
.p2align 12

.data
.p2align 12
roottable:
    .fill 512, 8, 0
l1table:
    .fill 512, 8, 0
l0table:
    .fill 512, 8, 0
nc_data:
    .set k, 0
    .rept 1024
    .word NCPAT + k
    .set k, k + 1
    .endr
cold_data:
    .set k, 0
    .rept 1024
    .word COLD + k
    .set k, k + 1
    .endr
traplog:                        # number of traps, then mcause, mepc, mtval of the first eight
    .fill 1 + 3 * 8, 8, 0
expected_traps:                 # mcause, mepc, mtval of each trap expected, in order
    .dword 4, mis_lw, nc_data + 1
    .dword 4, mis_lh, nc_data + 1
    .dword 6, mis_sw, nc_data + 1
    .dword 6, mis_sd, nc_data + 2
    .dword 4, mis_ld, nc_data + 4
    .dword 7, mis_amoaddw, nc_data + 2
    .dword 7, mis_amoaddd, nc_data + 2
    .dword 7, mis_amoswapw, nc_data + 2
