// pmpcbo.S
// David_Harris@hmc.edu 1/21/24
// Cover PMP checks of cache management instructions

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

// Run a cache management instruction and check whether it trapped.  The faulting ones run in
// supervisor mode, which cannot read mcause, so record_trap saves mcause and mepc of every trap in
// lasttrap before the library handler skips the instruction.  lasttrap.mcause is set to -1 first,
// so it is still -1 if nothing trapped.
.macro CBO_EXPECT op, adr, cause, index
    la t2, lasttrap
    li t3, -1
    sd t3, 0(t2)
1:
    \op (\adr)
    la t2, lasttrap
    ld t3, 0(t2)
    li t4, \cause
    SC_CHECK_EQ t3, t4, \index
.if \cause != -1
    ld t3, 8(t2)
    la t4, 1b
    SC_CHECK_EQ t3, t4, \index + 1
.endif
.endm

main:
    la t0, record_trap
    csrw mtvec, t0

     # set up PMP so user and supervisor mode can access partial address space
    li t0, 0x080F;
#    li t0, 0x0808;
    csrw pmpcfg0, t0  # configure PMP0 to TOR RWX and PMP1 to TOR no access
    li t0, 0x2003FFFF
    li t1, 0xFFFFFFFF
    csrw pmpaddr0, t0   # configure PMP0 top of range to 0x800FFFFF to allow all 32-bit addresses
    csrw pmpaddr1, t1   # configure PMP1 top of range to 0xFFFFFFFF to prohibit accesses above

    # enable cbo instructions
    li t0, 0xF0
    csrw menvcfg, t0
    csrw senvcfg, t0

    # switch to supervisor mode
    li a0, 1
    ecall

    # cbo instructions to a PMP-forbidden address raise store/AMO access faults (mcause 7)
    li a0, 0x81000000   # forbidden address
    CBO_EXPECT cbo.zero, a0, 7, 1
    CBO_EXPECT cbo.inval, a0, 7, 3

    # Back to machine mode for the case where PMP is not enforced at all.  With every pmpcfg
    # cleared there is no matching region and none of them are locked, so EnforcePMP is low.  That
    # is the only way to evaluate the cache management PMP checks in pmpchecker.sv with EnforcePMP
    # low, which the supervisor mode accesses above cannot do.
    li a0, 3
    ecall

    csrw pmpcfg0, zero
    csrw pmpcfg2, zero
    la a0, cboscratch   # ordinary RAM, so zeroing a line here is harmless
    li t2, -1
    .rept 8             # fill the line cbo.zero clears with a nonzero pattern
    sd t2, 0(a0)
    addi a0, a0, 8
    .endr
    la a0, cboscratch
    CBO_EXPECT cbo.inval, a0, -1, 5
    CBO_EXPECT cbo.clean, a0, -1, 6
    CBO_EXPECT cbo.flush, a0, -1, 7
    CBO_EXPECT cbo.zero, a0, -1, 8
    li t3, 0            # cbo.zero cleared the whole line
    .rept 8
    ld t2, 0(a0)
    SC_CHECK_EQ t2, t3, 9
    addi a0, a0, 8
    .endr

    SC_PASS
    j done

// Record mcause and mepc in lasttrap, then continue in the library trap handler
.align 4
record_trap:
    csrrw t0, mscratch, t0      # t0 = trap stack pointer, mscratch = saved t0
    sd t1, -16(t0)
    sd t2, -24(t0)
    la t1, lasttrap
    csrr t2, mcause
    sd t2, 0(t1)
    csrr t2, mepc
    sd t2, 8(t1)
    ld t2, -24(t0)
    ld t1, -16(t0)
    csrrw t0, mscratch, t0      # restore t0 and the trap stack pointer
    j trap_handler

.section .data
.align 3
lasttrap:               # mcause and mepc of the last trap
    .fill 2, 8, 0
.align 6                # a cache line, so cbo.zero stays inside the scratch area
cboscratch:
    .fill 16, 8, 0
