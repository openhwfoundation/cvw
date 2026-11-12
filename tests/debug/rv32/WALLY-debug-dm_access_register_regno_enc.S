//////////////////////////////////////////////////////////////////////
// WALLY-debug-dm_access_register_regno_enc
// Rule dm_access_register_regno_enc: "Numbers|Group Description ===
// 0x0000 — 0x0fff|CSRs. The ``PC'' can be accessed here through
// dpc.¶0x1000 — 0x101f|GPRs¶0x1020 — 0x103f|Floating point
// registers¶0xc000 — 0xffff|Reserved for non-standard extensions and
// internal use. ==="
//
// regno 0x1000+n is GPR n (x13, x31), 0x1020+n is FPR n (f5, f31),
// 0x0000-0x0fff are CSRs (mscratch 0x340), and the PC is read through
// dpc (0x7b1).
//
// Program (shared by the dmabs rule tests): sets x1-x31, f0-f31 and
// mscratch to known values and parks; the debugger
// (WALLY-debug-dm_access_register_regno_enc.tcl) checks the rule
// through the DM and resumes at test_end, which stores x0-x31 and
// f0-f31 to the signature.
//////////////////////////////////////////////////////////////////////
.text
.globl rvtest_entry_point
rvtest_entry_point:
   li   t0, 0x6000            # mstatus.FS = dirty: FPRs usable
   csrs mstatus, t0
   li   t0, 0x5c5ca3a3
   csrw mscratch, t0
   la   t0, fpr_init
   fld  f0, 0(t0)
   fld  f1, 8(t0)
   fld  f2, 16(t0)
   fld  f3, 24(t0)
   fld  f4, 32(t0)
   fld  f5, 40(t0)
   fld  f6, 48(t0)
   fld  f7, 56(t0)
   fld  f8, 64(t0)
   fld  f9, 72(t0)
   fld  f10, 80(t0)
   fld  f11, 88(t0)
   fld  f12, 96(t0)
   fld  f13, 104(t0)
   fld  f14, 112(t0)
   fld  f15, 120(t0)
   fld  f16, 128(t0)
   fld  f17, 136(t0)
   fld  f18, 144(t0)
   fld  f19, 152(t0)
   fld  f20, 160(t0)
   fld  f21, 168(t0)
   fld  f22, 176(t0)
   fld  f23, 184(t0)
   fld  f24, 192(t0)
   fld  f25, 200(t0)
   fld  f26, 208(t0)
   fld  f27, 216(t0)
   fld  f28, 224(t0)
   fld  f29, 232(t0)
   fld  f30, 240(t0)
   fld  f31, 248(t0)
   li   x1, 0x15a01a5
   li   x2, 0x25a02a5
   li   x3, 0x35a03a5
   li   x4, 0x45a04a5
   li   x5, 0x55a05a5
   li   x6, 0x65a06a5
   li   x7, 0x75a07a5
   li   x8, 0x85a08a5
   li   x9, 0x95a09a5
   li   x10, 0xa5a0aa5
   li   x11, 0xb5a0ba5
   li   x12, 0xc5a0ca5
   li   x13, 0xd5a0da5
   li   x14, 0xe5a0ea5
   li   x15, 0xf5a0fa5
   li   x16, 0x105a10a5
   li   x17, 0x115a11a5
   li   x18, 0x125a12a5
   li   x19, 0x135a13a5
   li   x20, 0x145a14a5
   li   x21, 0x155a15a5
   li   x22, 0x165a16a5
   li   x23, 0x175a17a5
   li   x24, 0x185a18a5
   li   x25, 0x195a19a5
   li   x26, 0x1a5a1aa5
   li   x27, 0x1b5a1ba5
   li   x28, 0x1c5a1ca5
   li   x29, 0x1d5a1da5
   li   x30, 0x1e5a1ea5
   li   x31, 0x1f5a1fa5
park:
   j    park

# Store x0-x31 and f0-f31 to the signature so Spike checks every
# register the debugger may have changed.
test_end:
   csrw mscratch, x31
   la   x31, begin_signature
   sw   x1, 4(x31)
   sw   x2, 8(x31)
   sw   x3, 12(x31)
   sw   x4, 16(x31)
   sw   x5, 20(x31)
   sw   x6, 24(x31)
   sw   x7, 28(x31)
   sw   x8, 32(x31)
   sw   x9, 36(x31)
   sw   x10, 40(x31)
   sw   x11, 44(x31)
   sw   x12, 48(x31)
   sw   x13, 52(x31)
   sw   x14, 56(x31)
   sw   x15, 60(x31)
   sw   x16, 64(x31)
   sw   x17, 68(x31)
   sw   x18, 72(x31)
   sw   x19, 76(x31)
   sw   x20, 80(x31)
   sw   x21, 84(x31)
   sw   x22, 88(x31)
   sw   x23, 92(x31)
   sw   x24, 96(x31)
   sw   x25, 100(x31)
   sw   x26, 104(x31)
   sw   x27, 108(x31)
   sw   x28, 112(x31)
   sw   x29, 116(x31)
   sw   x30, 120(x31)
   csrr x30, mscratch
   sw   x30, 124(x31)
   fsd  f0, 128(x31)
   fsd  f1, 136(x31)
   fsd  f2, 144(x31)
   fsd  f3, 152(x31)
   fsd  f4, 160(x31)
   fsd  f5, 168(x31)
   fsd  f6, 176(x31)
   fsd  f7, 184(x31)
   fsd  f8, 192(x31)
   fsd  f9, 200(x31)
   fsd  f10, 208(x31)
   fsd  f11, 216(x31)
   fsd  f12, 224(x31)
   fsd  f13, 232(x31)
   fsd  f14, 240(x31)
   fsd  f15, 248(x31)
   fsd  f16, 256(x31)
   fsd  f17, 264(x31)
   fsd  f18, 272(x31)
   fsd  f19, 280(x31)
   fsd  f20, 288(x31)
   fsd  f21, 296(x31)
   fsd  f22, 304(x31)
   fsd  f23, 312(x31)
   fsd  f24, 320(x31)
   fsd  f25, 328(x31)
   fsd  f26, 336(x31)
   fsd  f27, 344(x31)
   fsd  f28, 352(x31)
   fsd  f29, 360(x31)
   fsd  f30, 368(x31)
   fsd  f31, 376(x31)
   li   x30, 0x600dc0de        # reached test_end (x0 slot)
   sw   x30, 0(x31)
   li   a0, 0
   j    tohost_exit

.globl tohost_exit
tohost_exit:
   slli a0, a0, 1
   ori  a0, a0, 1
   la   t0, tohost
   sw   a0, 0(t0)
1: j 1b

.data
.align 3
fpr_init:
   .dword 0x0066007700880099
   .dword 0x0166017701880199
   .dword 0x0266027702880299
   .dword 0x0366037703880399
   .dword 0x0466047704880499
   .dword 0x0566057705880599
   .dword 0x0666067706880699
   .dword 0x0766077707880799
   .dword 0x0866087708880899
   .dword 0x0966097709880999
   .dword 0x0a660a770a880a99
   .dword 0x0b660b770b880b99
   .dword 0x0c660c770c880c99
   .dword 0x0d660d770d880d99
   .dword 0x0e660e770e880e99
   .dword 0x0f660f770f880f99
   .dword 0x1066107710881099
   .dword 0x1166117711881199
   .dword 0x1266127712881299
   .dword 0x1366137713881399
   .dword 0x1466147714881499
   .dword 0x1566157715881599
   .dword 0x1666167716881699
   .dword 0x1766177717881799
   .dword 0x1866187718881899
   .dword 0x1966197719881999
   .dword 0x1a661a771a881a99
   .dword 0x1b661b771b881b99
   .dword 0x1c661c771c881c99
   .dword 0x1d661d771d881d99
   .dword 0x1e661e771e881e99
   .dword 0x1f661f771f881f99
begin_signature:
   .fill 96, 4, 0xdeadbeef
end_signature:
   .dword 0

.section .tohost, "aw", @progbits
.align 6
.globl tohost
tohost: .dword 0
.align 6
.globl fromhost
fromhost: .dword 0
