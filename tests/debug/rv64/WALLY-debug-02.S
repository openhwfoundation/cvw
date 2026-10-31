//////////////////////////////////////////////////////////////////////
// WALLY-debug-02.S
//////////////////////////////////////////////////////////////////////
.text
.globl rvtest_entry_point
rvtest_entry_point:

   li x1,  0x00000000deadbeef
   li x2,  0x00000000cafebabe
   li x3,  0x00000000feedface
   li x4,  0x00000000baadf00d
   li x5,  0x000000000badf00d
   li x6,  0x00000000c001d00d
   li x7,  0x000000008badf00d
   li x8,  0x00000000deadc0de
   li x9,  0x00000000badc0ffe
   li x10, 0x00000000facefeed
   li x11, 0x00000000dead10cc
   li x12, 0x00000000abadbabe
   li x13, 0x00000000fee1dead
   li x14, 0x00000000defec8ed
   li x15, 0x00000000cafed00d
   li x16, 0x00000000d15ea5e5
   li x17, 0x00000000baaaaaad
   li x18, 0x00000000deadfa11
   li x19, 0x00000000b16b00b5
   li x20, 0x000000000d15ea5e
   li x21, 0x00000000600df00d
   li x22, 0x00000000abad1dea
   li x23, 0x00000000deaddead
   li x24, 0x00000000feedf00d
   li x25, 0x00000000bad22222
   li x26, 0x00000000c0ffee00
   li x27, 0x00000000f00dbabe
   li x28, 0x00000000deaddeaf     # intended x28 poison (will get clobbered)
   li x29, 0x00000000fa11ba11
   li x30, 0x00000000cafedade
   li x31, 0x00000000deadcafe

   la  t3, begin_signature        # t3=x28 becomes the pointer (clobbers x28 value)

test2:

   sd x1,    0(t3)
   sd x2,    8(t3)
   sd x3,   16(t3)
   sd x4,   24(t3)
   sd x5,   32(t3)
   sd x6,   40(t3)
   sd x7,   48(t3)
   sd x8,   56(t3)
   sd x9,   64(t3)
   sd x10,  72(t3)
   sd x11,  80(t3)
   sd x12,  88(t3)
   sd x13,  96(t3)
   sd x14, 104(t3)
   sd x15, 112(t3)
   sd x16, 120(t3)
   sd x17, 128(t3)
   sd x18, 136(t3)
   sd x19, 144(t3)
   sd x20, 152(t3)
   sd x21, 160(t3)
   sd x22, 168(t3)
   sd x23, 176(t3)
   sd x24, 184(t3)
   sd x25, 192(t3)
   sd x26, 200(t3)
   sd x27, 208(t3)

   # patch x28 slot (offset = (28-1)*8 = 216)
   # reuse x1 as a temp *after* it has already been stored
   li x1, 0x00000000deaddeaf
   sd x1, 216(t3)

   # store x29..x31
   sd x29, 224(t3)
   sd x30, 232(t3)
   sd x31, 240(t3)

   addi t3, t3, 248              # 31 regs * 8 bytes

1: j 1b

test_end:
   li a0, 0
   j tohost_exit

.globl tohost_exit
tohost_exit:
   slli a0, a0, 1
   ori a0, a0, 1
   la t0, tohost
   sw a0, 0(t0)
1: j 1b

.data

begin_signature:
   .fill 34*2, 4, 0xdeadbeef
end_signature:

.section .tohost, "aw", @progbits
.align 6
.globl tohost
tohost: .dword 0

.align 6
.globl fromhost
fromhost: .dword 0

# a syscall buffer?
.align 6
magic_mem: .word 0, 0, 0, 0, 0, 0, 0, 0
