// debug.S
// David_Harris@hmc.edu 4 February 2023
// Small code snippets for the purpose of debugging issues
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

.global rvtest_entry_point
rvtest_entry_point:
    lui t0, 0x02            # turn on Floating point and XS
    csrs mstatus, t0

    la a6, begin_signature
    la a7, rvtest_data

    # openhwfoundation/cvw Issue #55
    fld f4, 0(a7)
    fld f9, 8(a7)
    fsgnjx.s f12,f9,f4  # expected f 0xffffffff7fc00000, hdl has been giving fff8000000000000
    fsd f12, 0(a6)

    # openhwfoundation/cvw Issue #56
    fld f4, 16(a7) # cfa695b1047553b1
    fld f14, 24(a7)
    fsgnjx.s f10,f4,f14  # expected f 0xffffffff7fc00000, hdl has been giving 0xcfa695b1047553b1
    fsd f19, 16(a6)

    # openhwfoundation/cvw Issue #57
    fld f0, 32(a7)
    fld f15, 40(a7)
    fsgnjx.s f30,f0,f15  # expected f 0xfffffffffb3754ef, hdl has been giving 0xffffffff7b3754ef
    fsd f30, 24(a6)

    # openhwfoundation/cvw Issue #58
    fld f14, 48(a7)
    fclass.s x2, f14 # expected 0x0000000000000200, hdl had been giving 0x0000000000000220
    sd x2, 32(a6)

    # fsgnjx.s, fclass.s, fsgnjn.s, fsgnj.s, fneg.s, fabs.s, fmv.s all treat inputs as dp rather than sp

    #openhwfoundation/cvw Issue #65 #expected 0xffffffffffffffff, hdl had been giving 0x00000000ffffffff
    fld f17, 56(a7)
    fmv.x.s x30, f17
    sd x30, 40(a6)


#########################
# HTIF and signature
#########################

write_tohost:
    la t1, tohost
    li t0, 1            # 1 for success, 3 for failure
    sd t0, 0(t1)        # send success code

self_loop:
    j self_loop         # wait

.align 6
.section .tohost
tohost:                 # write to HTIF
    .dword 0
fromhost:
    .dword 0

.align 6
.data

rvtest_data:
.dword 0x7ff0000000000001
.dword 0x7ff8000000000000
.dword 0xcfa695b1047553b1
.dword 0xffffffff7fc00000
.dword 0xfffffffffb3754ef
.dword 0x7fefffffffffffff
.dword 0x00000000ffffffff

.EQU XLEN,64
begin_signature:
    .fill 8*(XLEN/32),4,0xdeadbeef    #
end_signature:

# Initialize stack with room for 512 bytes
.bss
    .space 512
topofstack:
