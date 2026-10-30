// pmpadrdecs
// Liam Chalk, lchalk@hmc.edu, 4/27/2023
// Setting AdrMode to 2 or 3 for pmpadrdecs[0-4]
//
// Checks (rv64gc: 16 entries, G = 4, so NA4 is not selectable and a TOR region is 64-byte aligned):
//   - pmpcfg writes read back legalized: A = NA4 keeps the old A field (indices 1-4, 7-8)
//   - pmpaddr reads back with the low G bits zero in OFF and TOR modes (5-6, 10-25 and the
//     second check of each TOR step)
//   - each TOR step's pmpcfg and top-of-range pmpaddr read back (30-51); the jumps to pmpjump run
//     in M-mode with no lock bits, so they must not fault
//   - the S-mode AMO to a TOR region with X only raises a store/AMO access fault, not a load
//     access fault, with mtval = the address, and leaves memory unchanged (60 and the trap log)
//   - a trap log holds exactly the expected traps (indices 0x100-0x1FF)

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

// CHECK_CSR csr, expected, index: fail with index unless the CSR reads expected
.macro CHECK_CSR csr, expected, index
    csrr a1, \csr
    li a2, \expected
    SC_CHECK_EQ a1, a2, \index
.endm

// CHECK_CSR_REG csr, reg, index: fail with index unless the CSR reads reg with its low 4 bits (G) clear
.macro CHECK_CSR_REG csr, reg, index
    csrr a1, \csr
    andi a2, \reg, -16
    SC_CHECK_EQ a1, a2, \index
.endm

main:
    la t0, log_trap
    csrw mtvec, t0

    # Writing values to pmpcfg0 to change AdrMode to 2 or 3
    # pmpadrdec[0]
    li t0, 0x0000000010
    csrw pmpcfg0, t0
    CHECK_CSR pmpcfg0, 0x08, 1      # entry 0 keeps TOR from WALLY-init-lib.h
    # pmpadrdec[1]
    li t0, 0x0000001800
    csrw pmpcfg0, t0
    CHECK_CSR pmpcfg0, 0x1800, 2
    # pmpadrdec[2]
    li t0, 0x0000180000
    csrw pmpcfg0, t0
    CHECK_CSR pmpcfg0, 0x180000, 3
    # pmpadrdec[4]
    li t0, 0x1000000000
    csrw pmpcfg0, t0
    CHECK_CSR pmpcfg0, 0, 4         # entry 4 keeps OFF

    # test hitting each region in NA4 mode for DMMU
    li t0, 0x20000000 # address 0x80000000
    csrw pmpaddr15, t0
    csrw pmpaddr14, t0
    csrw pmpaddr13, t0
    csrw pmpaddr12, t0
    CHECK_CSR pmpaddr15, 0x20000000, 5
    CHECK_CSR pmpaddr12, 0x20000000, 6
    li t0, 0x1717171717171717 # every region is NA4 XWR
    csrw pmpcfg0, t0
    csrw pmpcfg2, t0
    CHECK_CSR pmpcfg0, 0x0707070707070707, 7   # NA4 is not selectable, so every region stays OFF
    CHECK_CSR pmpcfg2, 0x0707070707070707, 8


    # test hitting region in NA4 mode for IMMU
    la t0, pmpjump # address of a jump destination to exercise immu pmpchecker
    srli t1, t0, 2 # shift right by 2 to convert to PMP format
    csrw pmpaddr15, t1
    csrw pmpaddr14, t1
    csrw pmpaddr13, t1
    csrw pmpaddr12, t1
    csrw pmpaddr11, t1
    csrw pmpaddr10, t1
    csrw pmpaddr9, t1
    csrw pmpaddr8, t1
    csrw pmpaddr7, t1
    csrw pmpaddr6, t1
    csrw pmpaddr5, t1
    csrw pmpaddr4, t1
    csrw pmpaddr3, t1
    csrw pmpaddr2, t1
    csrw pmpaddr1, t1
    csrw pmpaddr0, t1
    .irp n, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
    CHECK_CSR_REG pmpaddr\n, t1, 10+\n
    .endr
    jalr t0

    # test hitting region in TOR mode for IMMU
    add t2, t1, 1   # top of range

    # region 0 TOR at pmpjump
    li t3, 0x0F # TOR XWR
    csrw pmpcfg0, t3
    csrw pmpcfg2, 0
    csrw pmpaddr0, t2
    jalr t0
    CHECK_CSR pmpcfg0, 0x0F, 30
    CHECK_CSR_REG pmpaddr0, t2, 31

    # region 1 TOR at pmpjump
    li t3, 0x0F00 # TOR XWR
    csrw pmpcfg0, t3
    csrw pmpcfg2, 0
    csrw pmpaddr0, t1
    csrw pmpaddr1, t2
    jalr t0
    CHECK_CSR pmpcfg0, 0x0F00, 32
    CHECK_CSR_REG pmpaddr1, t2, 33

    # region 1 TOR at pmpjump
    li t3, 0x0F00 # TOR XWR
    csrw pmpcfg0, t3
    csrw pmpcfg2, 0
    csrw pmpaddr0, t1
    csrw pmpaddr1, t2
    jalr t0
    CHECK_CSR pmpcfg0, 0x0F00, 34
    CHECK_CSR_REG pmpaddr1, t2, 35

    # region 8 TOR at pmpjump
    li t3, 0x0F # TOR XWR
    csrw pmpcfg2, t3
    csrw pmpcfg0, 0
    csrw pmpaddr7, t1
    csrw pmpaddr8, t2
    jalr t0
    CHECK_CSR pmpcfg2, 0x0F, 36
    CHECK_CSR_REG pmpaddr8, t2, 37

    # region 9 TOR at pmpjump
    li t3, 0x0F00 # TOR XWR
    csrw pmpcfg2, t3
    csrw pmpcfg0, 0
    csrw pmpaddr8, t1
    csrw pmpaddr9, t2
    jalr t0
    CHECK_CSR pmpcfg2, 0x0F00, 38
    CHECK_CSR_REG pmpaddr9, t2, 39

    # region 10 TOR at pmpjump
    li t3, 0x0F0000 # TOR XWR
    csrw pmpcfg2, t3
    csrw pmpcfg0, 0
    csrw pmpaddr9, t1
    csrw pmpaddr10, t2
    jalr t0
    CHECK_CSR pmpcfg2, 0x0F0000, 40
    CHECK_CSR_REG pmpaddr10, t2, 41

    # region 11 TOR at pmpjump
    li t3, 0x0F000000 # TOR XWR
    csrw pmpcfg2, t3
    csrw pmpcfg0, 0
    csrw pmpaddr10, t1
    csrw pmpaddr11, t2
    jalr t0
    CHECK_CSR pmpcfg2, 0x0F000000, 42
    CHECK_CSR_REG pmpaddr11, t2, 43

    # region 12 TOR at pmpjump
    li t3, 0x0F00000000 # TOR XWR
    csrw pmpcfg2, t3
    csrw pmpcfg0, 0
    csrw pmpaddr11, t1
    csrw pmpaddr12, t2
    jalr t0
    CHECK_CSR pmpcfg2, 0x0F00000000, 44
    CHECK_CSR_REG pmpaddr12, t2, 45

    # region 13 TOR at pmpjump
    li t3, 0x0F0000000000 # TOR XWR
    csrw pmpcfg2, t3
    csrw pmpcfg0, 0
    csrw pmpaddr12, t1
    csrw pmpaddr13, t2
    jalr t0
    CHECK_CSR pmpcfg2, 0x0F0000000000, 46
    CHECK_CSR_REG pmpaddr13, t2, 47

    # region 14 TOR at pmpjump
    li t3, 0x0F000000000000 # TOR XWR
    csrw pmpcfg2, t3
    csrw pmpcfg0, 0
    csrw pmpaddr13, t1
    csrw pmpaddr14, t2
    jalr t0
    CHECK_CSR pmpcfg2, 0x0F000000000000, 48
    CHECK_CSR_REG pmpaddr14, t2, 49

    # region 15 TOR at pmpjump
    li t3, 0x0F00000000000000 # TOR XWR
    csrw pmpcfg2, t3
    csrw pmpcfg0, 0
    csrw pmpaddr14, t1
    csrw pmpaddr15, t2
    jalr t0
    CHECK_CSR pmpcfg2, 0x0F00000000000000, 50
    CHECK_CSR_REG pmpaddr15, t2, 51



    # test AMO not causing Load access fault
    # assign PMPLoadAccessFaultM      = EnforcePMP & ReadAccessM & ~WriteAccessM & ~MatchingR;
    la s0, scratch

    li t0, 0x0F000C00 # region 3 encompassing all addresses has TOR XWR, region 1 has TOR X only
    csrw pmpcfg0, t0

    # give only execute access to scratch
    # set up TOR region 0-1 to do this (yes, NA4 would work too)
    srli t0, s0, 2 # drop bottom two bits
    csrw pmpaddr0, t0
    addi t0, t0, 1 # next word
    csrw pmpaddr1, t0

    # everything else has full access, with a big TOR from 0 t0 FFFFFFFF
    csrw pmpaddr2, zero
    li t0, 0xFFFFFFFF  # full range
    csrw pmpaddr3, t0

    # switch to supervisor mode
    li a0, 1
ecall_m1:
    ecall

    # test the AMO
amo:
    amoswap.w t1, zero, (s0)  # attempt amo; should get store but not load access fault because this region is X only

    li a0, 3
ecall_s1:
    ecall     # return to M mode

    lw a1, 0(s0)
    li a2, 0x13579BDF
    SC_CHECK_EQ a1, a2, 60    # the faulting AMO left memory unchanged

    jal check_traps
    SC_PASS
    j done

.align 2
pmpjump:
    ret

.align 6                   # scratch is the last word of a 64-byte PMP grain, so the 4-byte
.skip 60                    # TOR region 1 rounds out to the whole grain rather than to nothing
scratch:
    .word 0x13579BDF

// Trap log: log_trap records mcause, mepc and mtval of every trap, then continues in the
// WALLY-init-lib.h handler, which handles ecalls and skips other faulting instructions.  check_traps
// compares the log with expected_traps, failing with index 0x100 + 3n + k for field k (0 = mcause,
// 1 = mepc, 2 = mtval) of trap n, or 0x1FF if the number of traps differs.
.equ TRAPLOG_MAX, 16
.align 4
log_trap:
    csrrw t0, mscratch, t0          # t0 = trap stack pointer, mscratch = saved t0
    sd t1, -16(t0)
    sd t2, -24(t0)
    sd t3, -32(t0)
    la t1, traplog
    ld t2, 0(t1)
    addi t2, t2, 1                  # count the trap
    sd t2, 0(t1)
    li t1, TRAPLOG_MAX
    bgtu t2, t1, 1f                 # log full: count only
    slli t3, t2, 4
    slli t2, t2, 3
    add t2, t2, t3
    la t1, traplog - 16
    add t1, t1, t2                  # trap n (from 1) goes at traplog + 24n - 16
    csrr t2, mcause
    sd t2, 0(t1)
    csrr t2, mepc
    sd t2, 8(t1)
    csrr t2, mtval
    sd t2, 16(t1)
1:  ld t3, -32(t0)
    ld t2, -24(t0)
    ld t1, -16(t0)
    csrrw t0, mscratch, t0          # restore t0 and the trap stack pointer
    j trap_handler

check_traps:
    la a1, traplog + 8
    la a2, expected_traps
    ld a3, 0(a2)
    addi a2, a2, 8
    slli a4, a3, 1
    add a3, a3, a4                  # fields to compare
    li a4, 0x100
1:  beqz a3, 2f
    ld a5, 0(a1)                    # actual
    ld a6, 0(a2)                    # expected
    bne a5, a6, 3f
    addi a1, a1, 8
    addi a2, a2, 8
    addi a3, a3, -1
    addi a4, a4, 1
    j 1b
2:  la a1, traplog                  # and no extra traps
    ld a5, 0(a1)
    la a2, expected_traps
    ld a6, 0(a2)
    li a4, 0x1FF
    bne a5, a6, 3f
    ret
3:  la t0, selfcheck_record         # record the mismatch as SC_CHECK_EQ does
    li t1, 2
    sd t1, 0(t0)
    sd a4, 8(t0)
    sd zero, 16(t0)
    sd a6, 24(t0)
    sd a5, 32(t0)
    SC_REPORT_FAIL
    j done

.section .data
.align 3
traplog:                            # number of traps, then mcause, mepc and mtval of each
    .fill 1 + 3*TRAPLOG_MAX, 8, 0
expected_traps:                     # number of traps, then mcause, mepc and mtval of each
    .dword (2f - 1f) / 24
1:  .dword 11, ecall_m1, 0                  # ecall from M
    .dword 7, amo, scratch                  # store/AMO access fault: region 1 has X only
    .dword 9, ecall_s1, 0                   # ecall from S
2:
