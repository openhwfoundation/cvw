.section .init
.global _start
.type _start, @function

_start:
  # Initialize global pointer
  .option push
  .option norelax
  1:auipc gp, %pcrel_hi(__global_pointer$)
  addi  gp, gp, %pcrel_lo(1b)
  .option pop

  li x1, 0
  li x2, 0
  li x4, 0
  li x5, 0
  li x6, 0
  li x7, 0
  li x8, 0
  li x9, 0
  li x10, 0
  li x11, 0
  li x12, 0
  li x13, 0
  li x14, 0
  li x15, 0
  li x16, 0
  li x17, 0
  li x18, 0
  li x19, 0
  li x20, 0
  li x21, 0
  li x22, 0
  li x23, 0
  li x24, 0
  li x25, 0
  li x26, 0
  li x27, 0
  li x28, 0
  li x29, 0
  li x30, 0
  li x31, 0



  # set the stack pointer to the top of memory - 8 bytes (pointer size)
  li sp, 0x87FFFFF8

  jal ra, main
  jal ra, _halt

.section .text
.global _halt
.type _halt, @function
_halt:
  li gp, 1
  li a0, 0
  ecall
  j _halt
