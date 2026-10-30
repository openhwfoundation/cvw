// crt0.S
// Embench startup code for Wally, for RV32 and RV64 (and RV32E, which has no t3-t6)
// Adapted from addins/embench-iot/config/riscv32/boards/rv32wallyverilog/startup/crt0.S

#if __riscv_xlen == 64
#define LREG ld
#define SREG sd
#define REGBYTES 8
#define XWORD .dword
#else
#define LREG lw
#define SREG sw
#define REGBYTES 4
#define XWORD .word
#endif

.section ".text.start"
.globl _start
_start:

.option push
.option norelax
  la gp, __global_pointer$
.option pop

  // enable floating-point
  li t0, 0x2000
  csrs mstatus, t0  // mstatus.FS = 01 to enable floating-point

  // set the thread pointer
  la  tp, _end + 63
  and tp, tp, -64

  // set the stack pointer 128k
  li t0, 0x0002000
  add sp, tp, t0

  la t0, __bss_start
  andi t1, t0, 3 # skips initializing .bss if its not aligned
  bne t1, zero, bssdone
  la t1, __BSS_END__

bssinit: #initializing .bss section to zeros
  sw x0, 0(t0)
  addi t0, t0, 4
  blt t0, t1, bssinit
bssdone:
  jal main

  .align 2

// The signature holds five XLEN-bit words, read back by testbench.sv and run_wally.py:
// start cycle, stop cycle, start instret, stop instret, and the success code
.global write_tohost
write_tohost:
    la t2, begin_signature
    LREG a2, startcycle
    LREG a3, stopcycle
    LREG a4, startinst
    LREG a5, stopinst
    SREG a2, 0*REGBYTES(t2)
    SREG a3, 1*REGBYTES(t2)
    SREG a4, 2*REGBYTES(t2)
    SREG a5, 3*REGBYTES(t2)
    la t1, tohost
    slli a0, a0, 1 # 1 for success, 3 for failure
    addi t0, a0, 1
    SREG t0, 4*REGBYTES(t2) # put the success code in the signature
    sw t0, 0(t1)        # send success code tohost

self_loop:
    j self_loop         # wait

.global stop_trigger
stop_trigger:
  la t2, stopcycle
  j record_trigger

.global start_trigger
start_trigger:
  la t2, startcycle

record_trigger:
  csrr t0, mcycle
  csrr t1, minstret
  SREG t0, 0(t2)
  SREG t1, REGBYTES(t2)
  ret

.data
.align 3
// record_trigger stores instret one word after cycles
startcycle: XWORD 0
startinst: XWORD 0
stopcycle: XWORD 0
stopinst: XWORD 0

.section ".tohost"
.align 6
.globl tohost
tohost: .dword 0
.align 6
.globl fromhost
fromhost: .dword 0
.align 6
.globl begin_signature
begin_signature:
    .fill 5,8,0x00000000  # five XLEN-bit words, initially zero
end_signature: .dword 0

# Initialize stack with room for 512 bytes
.bss
    .space 512
topofstack:
