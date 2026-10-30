// pmpcfg part 1
// Kevin Wan, kewan@hmc.edu, 4/18/2023
// Liam Chalk, lchalk@hmc.edu, 4/25/2023
// locks each pmpXcfg bit field in order, from X = 15 to X = 0, with the A[1:0] field set to TOR.
// See the next part in pmpcfg1.S
//
// Checks (rv64gc: 16 entries, G = 4, so NA4 is not selectable):
//   - every pmpcfg write reads back legalized: A = NA4 keeps the old A field, and the bytes of
//     locked entries ignore the write (failure indices 1-24)
//   - pmpcfg1 and pmpcfg3 do not exist on RV64, so writing them is an illegal instruction
//   - after the lock sequence, pmpaddr0 ignores writes because entry 1 is locked TOR although
//     entry 0 itself is unlocked, pmpaddr1 and pmpaddr15 ignore writes because their entries are
//     locked, and entry 0's cfg byte still accepts writes while the locked bytes beside it do
//     not (indices 50-56)
//   - the trap log holds exactly the four illegal instructions (indices 0x100-0x1FF)

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

// CHECK_CSR csr, expected, index: fail with index unless the CSR reads expected
.macro CHECK_CSR csr, expected, index
    csrr a1, \csr
    li a2, \expected
    SC_CHECK_EQ a1, a2, \index
.endm

main:
    la t0, log_trap
    csrw mtvec, t0

    li t0, 0x90000000
    csrw pmpaddr0, t0
    li t0, 0x00000017
    csrw pmpcfg0, t0
    CHECK_CSR pmpcfg0, 0x0F, 1      # entry 0 keeps TOR from WALLY-init-lib.h: NA4 not selectable

    li t0, 0x90000000
    csrw pmpaddr2, t0
    li t0, 0x00000017
    csrw pmpcfg2, t0
    CHECK_CSR pmpcfg2, 0x07, 2      # entry 8 keeps OFF

    li t0, 0x90000000
    csrw pmpaddr0, t0
    li t0, 0x00001700
    csrw pmpcfg0, t0
    CHECK_CSR pmpcfg0, 0x0700, 3

    li t0, 0x90000000
    csrw pmpaddr0, t0
    li t0, 0x00001700
ill_cfg1a:
    csrw pmpcfg1, t0

    li t0, 0x90000000
    csrw pmpaddr0, t0
    li t0, 0x00001700
    csrw pmpcfg2, t0
    CHECK_CSR pmpcfg2, 0x0700, 4

    li t0, 0x90000000
    csrw pmpaddr0, t0
    li t0, 0x00001700
ill_cfg3a:
    csrw pmpcfg3, t0

    li t0, 0x90000000
    csrw pmpaddr1, t0
    li t0, 0x00001700
ill_cfg1b:
    csrw pmpcfg1, t0

    li t0, 0x90000000
    csrw pmpaddr2, t0
    li t0, 0x00001700
    csrw pmpcfg2, t0
    CHECK_CSR pmpcfg2, 0x0700, 5

    li t0, 0x90000000
    csrw pmpaddr3, t0
    li t0, 0x00001700
ill_cfg3b:
    csrw pmpcfg3, t0

    li t0, 0x90000000
    csrw pmpaddr0, t0
    li t0, 0x00170000
    csrw pmpcfg0, t0
    CHECK_CSR pmpcfg0, 0x070000, 6

    li t0, 0x90000000
    csrw pmpaddr2, t0
    li t0, 0x00170000
    csrw pmpcfg2, t0
    CHECK_CSR pmpcfg2, 0x070000, 7

    li t0, 0x90000000
    csrw pmpaddr0, t0
    li t0, 0x17000000
    csrw pmpcfg0, t0
    CHECK_CSR pmpcfg0, 0x07000000, 8

    li t0, 0x90000000
    csrw pmpaddr2, t0
    li t0, 0x17000000
    csrw pmpcfg2, t0
    CHECK_CSR pmpcfg2, 0x07000000, 9

    # Lock entries 15 down to 1 as TOR with no permissions.  The other bytes of each write are 0,
    # so the read back shows that the entries locked earlier ignored them.  Every TOR region is
    # empty (pmpaddr0-3 = 0x90000000, pmpaddr4-15 = 0), so the locked entries deny nothing.
    li t0, 0x8800000000000000
    csrw pmpcfg2, t0
    CHECK_CSR pmpcfg2, 0x8800000000000000, 10
    li t0, 0x88000000000000
    csrw pmpcfg2, t0
    CHECK_CSR pmpcfg2, 0x8888000000000000, 11
    li t0, 0x880000000000
    csrw pmpcfg2, t0
    CHECK_CSR pmpcfg2, 0x8888880000000000, 12
    li t0, 0x8800000000
    csrw pmpcfg2, t0
    CHECK_CSR pmpcfg2, 0x8888888800000000, 13
    li t0, 0x88000000
    csrw pmpcfg2, t0
    CHECK_CSR pmpcfg2, 0x8888888888000000, 14
    li t0, 0x880000
    csrw pmpcfg2, t0
    CHECK_CSR pmpcfg2, 0x8888888888880000, 15
    li t0, 0x8800
    csrw pmpcfg2, t0
    CHECK_CSR pmpcfg2, 0x8888888888888800, 16
    li t0, 0x88
    csrw pmpcfg2, t0
    CHECK_CSR pmpcfg2, 0x8888888888888888, 17
    li t0, 0x8800000000000000
    csrw pmpcfg0, t0
    CHECK_CSR pmpcfg0, 0x8800000000000000, 18
    li t0, 0x88000000000000
    csrw pmpcfg0, t0
    CHECK_CSR pmpcfg0, 0x8888000000000000, 19
    li t0, 0x880000000000
    csrw pmpcfg0, t0
    CHECK_CSR pmpcfg0, 0x8888880000000000, 20
    li t0, 0x8800000000
    csrw pmpcfg0, t0
    CHECK_CSR pmpcfg0, 0x8888888800000000, 21
    li t0, 0x88000000
    csrw pmpcfg0, t0
    CHECK_CSR pmpcfg0, 0x8888888888000000, 22
    li t0, 0x880000
    csrw pmpcfg0, t0
    CHECK_CSR pmpcfg0, 0x8888888888880000, 23
    li t0, 0x8800
    csrw pmpcfg0, t0
    CHECK_CSR pmpcfg0, 0x8888888888888800, 24

    # Locked addresses and entries ignore writes
    li t0, 0x12345670
    csrw pmpaddr0, t0               # entry 0 is unlocked, but entry 1 is locked TOR
    CHECK_CSR pmpaddr0, 0x90000000, 50
    csrw pmpaddr1, t0               # entry 1 is locked
    CHECK_CSR pmpaddr1, 0x90000000, 51
    csrw pmpaddr15, t0              # entry 15 is locked
    CHECK_CSR pmpaddr15, 0, 52
    li t0, -1
    csrw pmpcfg2, t0                # entries 8-15 are all locked
    CHECK_CSR pmpcfg2, 0x8888888888888888, 53
    li t0, 0x0F                     # TOR RWX for entry 0; try to clear entries 1-7
    csrw pmpcfg0, t0
    CHECK_CSR pmpcfg0, 0x888888888888880F, 54
    csrw pmpcfg0, zero              # entry 0 is still unlocked
    CHECK_CSR pmpcfg0, 0x8888888888888800, 55
    CHECK_CSR pmpaddr2, 0x90000000, 56

    jal check_traps
    SC_PASS
    j done

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
1:  .dword 2, ill_cfg1a, 0x3a129073         # illegal instruction: pmpcfg1 does not exist on RV64
    .dword 2, ill_cfg3a, 0x3a329073
    .dword 2, ill_cfg1b, 0x3a129073
    .dword 2, ill_cfg3b, 0x3a329073
2:
