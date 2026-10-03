// pmpcbo.S
// David_Harris@hmc.edu 1/21/24
// Cover PMP checks of cache management instructions

#include "WALLY-init-lib.h"
main:

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

    # cbo instructions to PMP-forbidded address
    li a0, 0x81000000   # forbidden address
    cbo.zero (a0)
    cbo.inval (a0)

    # Back to machine mode for the case where PMP is not enforced at all.  With every pmpcfg
    # cleared there is no matching region and none of them are locked, so EnforcePMP is low.  That
    # is the only way to evaluate the cache management PMP checks in pmpchecker.sv with EnforcePMP
    # low, which the supervisor mode accesses above cannot do.
    li a0, 3
    ecall

    csrw pmpcfg0, zero
    csrw pmpcfg2, zero
    la a0, cboscratch   # ordinary RAM, so zeroing a line here is harmless
    cbo.inval (a0)
    cbo.clean (a0)
    cbo.flush (a0)
    cbo.zero (a0)

    j done

.section .data
.align 6                # a cache line, so cbo.zero stays inside the scratch area
cboscratch:
    .fill 16, 8, 0
