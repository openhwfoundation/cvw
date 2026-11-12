//////////////////////////////////////////////////////////////////////
// WALLY-debug-dm_sbdata3_optional
// Rule dm_sbdata3_optional: "This register only exists if sbaccess128
// is 1."
//
// The sbcs.sbaccess bits are 0, so sbdata3 (0x3f) is not present: it
// reads 0 after a write.
//
// Program (shared by the dmabs rule tests): sets x1-x31, f0-f31 and
// mscratch to known values and parks; the debugger
// (WALLY-debug-dm_sbdata3_optional.tcl) checks the rule through the DM
// and resumes at test_end, which stores x0-x31 and f0-f31 to the
// signature.
//////////////////////////////////////////////////////////////////////
.text
.globl rvtest_entry_point
rvtest_entry_point:
   li   t0, 0x6000            # mstatus.FS = dirty: FPRs usable
   csrs mstatus, t0
   li   t0, 0x5c5c5c5ca3a3a3a3
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
   li   x1, 0x111012201330144
   li   x2, 0x211022202330244
   li   x3, 0x311032203330344
   li   x4, 0x411042204330444
   li   x5, 0x511052205330544
   li   x6, 0x611062206330644
   li   x7, 0x711072207330744
   li   x8, 0x811082208330844
   li   x9, 0x911092209330944
   li   x10, 0xa110a220a330a44
   li   x11, 0xb110b220b330b44
   li   x12, 0xc110c220c330c44
   li   x13, 0xd110d220d330d44
   li   x14, 0xe110e220e330e44
   li   x15, 0xf110f220f330f44
   li   x16, 0x1011102210331044
   li   x17, 0x1111112211331144
   li   x18, 0x1211122212331244
   li   x19, 0x1311132213331344
   li   x20, 0x1411142214331444
   li   x21, 0x1511152215331544
   li   x22, 0x1611162216331644
   li   x23, 0x1711172217331744
   li   x24, 0x1811182218331844
   li   x25, 0x1911192219331944
   li   x26, 0x1a111a221a331a44
   li   x27, 0x1b111b221b331b44
   li   x28, 0x1c111c221c331c44
   li   x29, 0x1d111d221d331d44
   li   x30, 0x1e111e221e331e44
   li   x31, 0x1f111f221f331f44
park:
   j    park

# Store x0-x31 and f0-f31 to the signature so Spike checks every
# register the debugger may have changed.
test_end:
   csrw mscratch, x31
   la   x31, begin_signature
   sd   x1, 8(x31)
   sd   x2, 16(x31)
   sd   x3, 24(x31)
   sd   x4, 32(x31)
   sd   x5, 40(x31)
   sd   x6, 48(x31)
   sd   x7, 56(x31)
   sd   x8, 64(x31)
   sd   x9, 72(x31)
   sd   x10, 80(x31)
   sd   x11, 88(x31)
   sd   x12, 96(x31)
   sd   x13, 104(x31)
   sd   x14, 112(x31)
   sd   x15, 120(x31)
   sd   x16, 128(x31)
   sd   x17, 136(x31)
   sd   x18, 144(x31)
   sd   x19, 152(x31)
   sd   x20, 160(x31)
   sd   x21, 168(x31)
   sd   x22, 176(x31)
   sd   x23, 184(x31)
   sd   x24, 192(x31)
   sd   x25, 200(x31)
   sd   x26, 208(x31)
   sd   x27, 216(x31)
   sd   x28, 224(x31)
   sd   x29, 232(x31)
   sd   x30, 240(x31)
   csrr x30, mscratch
   sd   x30, 248(x31)
   fsd  f0, 256(x31)
   fsd  f1, 264(x31)
   fsd  f2, 272(x31)
   fsd  f3, 280(x31)
   fsd  f4, 288(x31)
   fsd  f5, 296(x31)
   fsd  f6, 304(x31)
   fsd  f7, 312(x31)
   fsd  f8, 320(x31)
   fsd  f9, 328(x31)
   fsd  f10, 336(x31)
   fsd  f11, 344(x31)
   fsd  f12, 352(x31)
   fsd  f13, 360(x31)
   fsd  f14, 368(x31)
   fsd  f15, 376(x31)
   fsd  f16, 384(x31)
   fsd  f17, 392(x31)
   fsd  f18, 400(x31)
   fsd  f19, 408(x31)
   fsd  f20, 416(x31)
   fsd  f21, 424(x31)
   fsd  f22, 432(x31)
   fsd  f23, 440(x31)
   fsd  f24, 448(x31)
   fsd  f25, 456(x31)
   fsd  f26, 464(x31)
   fsd  f27, 472(x31)
   fsd  f28, 480(x31)
   fsd  f29, 488(x31)
   fsd  f30, 496(x31)
   fsd  f31, 504(x31)
   li   x30, 0x600dc0de        # reached test_end (x0 slot)
   sw   x30, 0(x31)
   sw   x30, 4(x31)
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
   .fill 128, 4, 0xdeadbeef
end_signature:
   .dword 0

.section .tohost, "aw", @progbits
.align 6
.globl tohost
tohost: .dword 0
.align 6
.globl fromhost
fromhost: .dword 0
