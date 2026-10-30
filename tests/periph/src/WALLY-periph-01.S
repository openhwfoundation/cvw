///////////////////////////////////////////
// WALLY-periph-01.S
// Exercises the PLIC, GPIO, and UART together through interrupts.
// Compile with -DM_MODE_ONLY to omit the PLIC context 1 (supervisor mode) tests for configurations without S mode.
//
// Ben Bracker (bbracker@hmc.edu)
//
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
// Adapted from Imperas RISCV-TEST_SUITE
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software
// is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
// OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
///////////////////////////////////////////

#include "WALLY-env.h"


.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:

    # ---------------------------------------------------------------------------------------------
    j main_code
# 64 byte alignment for vectored traps to align with xtev
.align 6
###################
###################
trap_handler: #####
###################
###################
    # save registers
    addi sp, sp, 0x28
    SREG t0, 0x00(sp)
    SREG t1, 0x08(sp)
    SREG t2, 0x10(sp)
    SREG t3, 0x18(sp)
    SREG t4, 0x20(sp)

    # ===================================
    # ===== Signature Output Format =====
    # ===================================
    #
    # Base address = <wally_signature>+0x40*<intr_num>
    # Use sigout-translator.py for help with this!
    #
    # <offset>: <contents>
    # 0x00: test ID = 0x<group_num>BEEF<intr_num>
    # 0x04: mcause exception code = 0xB (MEIP) or 0x9 (SEIP)
    # 0x08: mcause interrupt bit = 1
    # ----- If GPIO -----
    # 0x0C: claim ID = 3
    # 0x10: input_val
    # 0x14: output_val
    # 0x18: incoming rise_ip
    # 0x1C: serviced rise_ip = 0
    # 0x20: incoming fall_ip
    # 0x24: serviced fall_ip = 0
    # 0x28: incoming high_ip
    # 0x2C: serviced high_ip = 0
    # 0x30: incoming low_ip
    # 0x34: serviced low_ip  = 0
    # ----- If UART -----
    # 0x0C: claim ID = 0xA
    # 0x10: IIR
    # 0x14: LSR
    # 0x18: LSR (after reading LSR)
    # 0x1C: RBR
    # 0x20: LSR (after reading RBR too)
    # 0x24: IIR (after reading everything else)
    # 0x28: SCR

    # 0x00: test ID = 0x<group_num>BEEF<intr_num>
    la t0, wally_signature
    sub t0, s0, t0 # sigout offset
    srli t0, t0, 6 # intr_num
    add t0, t0, a1
    sw t0, 0x00(s0)

    # 0x04: mcause exception code, 0x08: mcause interrupt bit (split so the signature is the same for RV32 and RV64)
    csrrc t0, mcause, x0
    andi t1, t0, 0x7FF
    srli t2, t0, __riscv_xlen-1
    sw t1, 0x04(s0)
    sw t2, 0x08(s0)
    # MEIP or SEIP?
    #     MEIP is on context 0
    li t4, 0x0C200004
    li t0, 0xB
    beq t1, t0, meip
    #     SEIP is on context 1
    li t4, 0x0C201004
    meip:

    # 0x0C: claim ID
    #    3: GPIO
    #    A: UART
    mv t0, t4
    lw t1, 0(t0)
    sw t1, 0x0C(s0)
    li t2, 0xA
    beq t1, t2, uart_handler
    li t2, 3
    bne t1, t2, trap_handler_end

    gpio_handler:
        # 0x10: input_val
        li t0, 0x10060000
        lw t1, 0x00(t0)
        sw t1, 0x10(s0)
        # 0x14: output_val
        lw t1, 0x0C(t0)
        sw t1, 0x14(s0)
        # 0x18: incoming rise_ip
        lw t1, 0x1C(t0)
        sw t1, 0x18(s0)
        # 0x1C: serviced rise_ip = 0
        sw t1, 0x1C(t0)
        lw t1, 0x1C(t0)
        sw t1, 0x1C(s0)
        # 0x20: incoming fall_ip
        lw t1, 0x24(t0)
        sw t1, 0x20(s0)
        # 0x24: serviced fall_ip = 0
        sw t1, 0x24(t0)
        lw t1, 0x24(t0)
        sw t1, 0x24(s0)
        # 0x28: incoming high_ip
        lw t1, 0x2C(t0)
        sw t1, 0x28(s0)
        # 0x2C: serviced high_ip = 0
        sw t1, 0x2C(t0)
        lw t1, 0x2C(t0)
        sw t1, 0x2C(s0)
        # 0x30: incoming low_ip
        lw t1, 0x34(t0)
        sw t1, 0x30(s0)
        # 0x34: serviced low_ip  = 0
        sw t1, 0x34(t0)
        lw t1, 0x34(t0)
        sw t1, 0x34(s0)
        # disable high_ie and low_ie so interrupt
        # is not taken again immediately
        li t1, 0
        sw t1, 0x28(t0)
        sw t1, 0x30(t0)
        # signal to main code that gpio was serviced
        ori a0, a0, 0b00001000
        # signal to plic that gpio was serviced
        mv t0, t4
        li t1, 3
        sw t1, 0(t0)
        j trap_handler_end

    uart_handler:
        # 0x10: IIR
        li t0, 0x10000000
        lbu t1, 2(t0)
        sw t1, 0x10(s0)
        # 0x14: LSR
        lbu t1, 5(t0)
        sw t1, 0x14(s0)
        # 0x18: LSR (after reading LSR)
        lbu t1, 5(t0)
        sw t1, 0x18(s0)
        # 0x1C: RBR
        lbu t1, 0(t0)
        sw t1, 0x1C(s0)
        # 0x20: LSR (after reading RBR)
        lbu t1, 5(t0)
        sw t1, 0x20(s0)
        # 0x24: IIR (after reading everything else)
        lbu t1, 2(t0)
        sw t1, 0x24(s0)
        # 0x28: SCR
        lbu t1, 7(t0)
        sw t1, 0x28(s0)
        # signal to main code that uart was serviced
        ori a0, a0, 0b00010000
        # signal to plic that uart was serviced
        mv t0, t4
        li t1, 0xA
        sw t1, 0(t0)

    trap_handler_end:
    # ===== Self-check: compare the completed 0x40-byte signature block with expected_signature =====
    # t0-t4 were saved on entry to the trap handler, so they are free to use here.
    la t0, wally_signature
    sub t0, s0, t0             # byte offset of this block within the signature
    la t1, expected_signature
    add t1, t1, t0             # expected values for this block
    mv t2, s0                  # actual values for this block
    addi t3, s0, 0x40          # end of this block
    1:
    lw t0, 0(t2)
    lw t4, 0(t1)
    bne t0, t4, selfcheck_fail
    addi t2, t2, 4
    addi t1, t1, 4
    bne t2, t3, 1b
    # increment signature pointer
    addi s0,s0,0x40
    # restore vars
    LREG t0, 0x00(sp)
    LREG t1, 0x08(sp)
    LREG t2, 0x10(sp)
    LREG t3, 0x18(sp)
    LREG t4, 0x20(sp)
    addi sp, sp, -0x28
    mret

################
################
main_code: #####
################
################

    ##########################
    ##### Initialization #####
    ##########################
    # ========== Global Vars ==========
    la s0, wally_signature # signature output base adr
    la sp, stack           # stack pointer
    li a0, 0               # interrupt complete flag
    # ========== Configure Privileged Unit ==========
    # load address of trap handler
    la t0, trap_handler
    csrrw x0, mtvec, t0
#ifndef M_MODE_ONLY
    # delegate all external interrupts to machine mode
    li t0, 0xD00
    csrrc x0, mideleg, t0
#endif
    # set MIE
    li t0, 0x8
    csrrs x0, mstatus, t0

    ##################################
    ##### Test 1 - Signs of Life #####
    ##################################
    li a1, 0x01beef00 # group ID
    # clear MEIE (good to turn off while configuring peripherals)
    li t0, 0x800
    csrrc x0, mie, t0
    # ========== Configure PLIC ==========
    # priority threshold = 0
    li t0, 0xC200000
    li t1, 0
    sw t1, 0(t0)
    # source 3 (GPIO) priority = 6
    li t0, 0xC000000
    li t1, 6
    sw t1, 0x0C(t0)
    # source 0xA (UART) priority = 7
    li t1, 7
    sw t1, 0x28(t0)
    # enable sources 3,0xA
    li t0, 0x0C002000
    li t1, 0b10000001000
    sw t1, 0(t0)
    # ========== Configure UART ==========
    # MCR: Loop = 1
    li t0, 0x10000000
    li t1, 0b10000
    sb t1, 4(t0)
    # LCR: Use 8 data bits plus odd parity bit
    li t1, 0b00001011
    sb t1, 3(t0)
    # IER: Enable Received Data Available Interrupt
    li t1, 0x01
    sb t1, 1(t0)
    # ========== Configure GPIO ==========
    # raise all input_en
    li t0, 0x10060000
    li t1, 0xFFFFFFFF
    sw t1, 0x04(t0)
    # raise all output_en
    sw t1, 0x08(t0)
    # raise all rise_en
    sw t1, 0x18(t0)
    # ========== Execute Test ==========
    # set MEIE
    li t0, 0x800
    csrrs x0, mie, t0
Intr01BEEF00:
    # UART TX 'h'
    li t0, 0x10000000
    li t1, 'h'
    sb t1, 0(t0)
    # wait to finish
    li t1, 0b00010000
    1: bne t1,a0,1b
    li a0, 0
Intr01BEEF01:
    # GPIO raise pin 19
    li t0, 0x10060000
    li t1, 0x00080000
    sw t1, 0x0C(t0)
    # wait to finish
    li t1, 0b00001000
    1: bne t1,a0,1b
    li a0, 0
    # Now let's go bonkers and trigger both!
Intr01BEEF02:
    # TX 'e'
    li t0, 0x10000000
    li t1, 'e'
    sb t1, 0(t0)
Intr01BEEF03:
    # GPIO lower pin 19 raise pin 0
    li t0, 0x10060000
    li t1, 0x00000001
    sw t1, 0x0C(t0)
    # wait to finish
    li t1, 0b00011000
    1: bne t1,a0,1b
    li a0, 0

    ##################################
    ##### Test 2 - GPIO Testing  #####
    ##################################
    li a1, 0x02beef00 # group ID
    # clear MEIE
    li t0, 0x800
    csrrc x0, mie, t0
    # ========== Configure PLIC ==========
    # priority threshold = 0
    li t0, 0xC200000
    li t1, 0
    sw t1, 0(t0)
    # source 3 (GPIO) priority = 1
    li t0, 0xC000000
    li t1, 1
    sw t1, 0x0C(t0)
    # enable source 3
    li t0, 0x0C002000
    li t1, 0b1000
    sw t1, 0(t0)
    # ========== Input Enables ==========
    # Note that this inherits
    # a bit of state from the previous test.
    # Namely output_val = 0x00000001
    #
    # enable some inputs
    li t0, 0x10060000
    li t1, 0x0000FFFF
    sw t1, 0x04(t0)
    # enable all outputs
    li t1, 0xFFFFFFFF
    sw t1, 0x08(t0)
    # enable all rising edge interrupts
    sw t1, 0x18(t0)
    # set MEIE
    li t1, 0x800
    csrrs x0, mie, t1
    # raise some input-disabled pins
    # interrupt should not happen
    li t1, 0xF0F00001
    sw t1, 0x0C(t0)
Intr02BEEF04:
    # change some input-enabled pins
    # interrupt should happen
    li t1, 0x3030F0F0
    sw t1, 0x0C(t0)
    # wait to finish
    li t1, 0b00001000
    1: bne t1,a0,1b
    li a0, 0
Intr02BEEF05:
    # enable some different inputs
    # this itself will cause some rise interrupts
    li t1, 0xFFFF0000
    sw t1, 0x04(t0)
    # wait to finish
    li t1, 0b00001000
    1: bne t1,a0,1b
    li a0, 0
    # ========== Output Enables ==========
    # enable all fall interrupts
    li t1, 0xFFFFFFFF
    sw t1, 0x20(t0)
Intr02BEEF06:
    # disable some outputs
    # should affect input value but not output val register itself
    # this itself will cause some fall interrupts
    li t1, 0xFF0000FF
    sw t1, 0x08(t0)
    # wait to finish
    li t1, 0b00001000
    1: bne t1,a0,1b
    li a0, 0
    # change pins whose inputs and/or outputs are disabled
    # should not cause any rise or fall interrupts
    li t1, 0x300F0F0F
    sw t1, 0x0C(t0)
Intr02BEEF07:
    # change pins whose inputs and outputs are enabled
    li t1, 0x0F0F0F0F
    sw t1, 0x0C(t0)
    # wait to finish
    li t1, 0b00001000
    1: bne t1,a0,1b
    li a0, 0
    # ========== Clear GPIO State ==========
    # (I've gotten a little annoyed with tests depending
    # upon the results of previous tests).
    # disable all interrupts
    sw x0, 0x18(t0)
    sw x0, 0x20(t0)
    sw x0, 0x28(t0)
    sw x0, 0x30(t0)
    # enable all inputs
    li t1, 0xFFFFFFFF
    sw t1, 0x04(t0)
    # enable all outputs
    li t1, 0xFFFFFFFF
    sw t1, 0x08(t0)
    # set initial output state
    sw x0, 0x0C(t0)
    # clear all pending interrupts
    li t1, 0xFFFFFFFF
    sw t1, 0x1C(t0)
    sw t1, 0x24(t0)
    sw t1, 0x2C(t0)
    sw t1, 0x34(t0)
    # ========== Rise Interrupt Enables ==========
    # enable some rising edge interrupts
    li t1, 0x0000FFFF
    sw t1, 0x18(t0)
Intr02BEEF08:
    # raise some pins
    li t1, 0x00FFFF00
    sw t1, 0x0C(t0)
    # wait to finish
    li t1, 0b00001000
    1: bne t1,a0,1b
    li a0, 0
Intr02BEEF09:
    # raise pins whose rise IEs are disabled
    # should not cause an interrupt
    li t1, 0x33FFFF00
    sw t1, 0x0C(t0)
    # raise pins whose rise IEs are enabled
    li t1, 0x33FFFF33
    sw t1, 0x0C(t0)
    # wait to finish
    li t1, 0b00001000
    1: bne t1,a0,1b
    li a0, 0
    # =========== Fall Interrupts ===========
    # (admittedly these are already used elsewhere)
    # disable all rising edge interrupts
    li t1, 0
    sw t1, 0x18(t0)
    # enable some falling edge interrupts
    li t1, 0x0000FFFF
    sw t1, 0x20(t0)
Intr02BEEF0A:
    # lower some pins
    li t1, 0x33000033
    sw t1, 0x0C(t0)
    # wait to finish
    li t1, 0b00001000
    1: bne t1,a0,1b
    li a0, 0
    # lower pins whose fall IEs are disabled
    # and raise a bunch of other pins
    # should not cause an interrupt
    li t1, 0x00CCCC33
    sw t1, 0x0C(t0)
Intr02BEEF0B:
    # lower pins whose fall IEs are enabled
    li t1, 0x00CCCC00
    sw t1, 0x0C(t0)
    # wait to finish
    li t1, 0b00001000
    1: bne t1,a0,1b
    li a0, 0
    # =========== High Interrupts ===========
    # disable all falling edge interrupts
    li t1, 0
    sw t1, 0x20(t0)
    # enable some high_ie's for low pins
    # should not cause an interrupt
    li t1, 0xFF0000FF
    sw t1, 0x28(t0)
Intr02BEEF0C:
    # enable some high_ie's for high pins
    li t1, 0x0000FFFF
    sw t1, 0x28(t0)
    # wait to finish
    li t1, 0b00001000
    1: bne t1,a0,1b
    li a0, 0
    # lower all pins
    li t1, 0
    sw t1, 0x0C(t0)
    # lower any existing high_ip's
    li t1, 0xFFFFFFFF
    sw t1, 0x2C(t0)
    # re-enable some high_ie's
    li t1, 0xFFFF0000
    sw t1, 0x28(t0)
    # raise some pins whose high_ie's are disabled
    li t1, 0x0000CCCC
    sw t1, 0x0C(t0)
    # disable some inputs
    li t1, 0xFF00FFFF
    sw t1, 0x04(t0)
    # raise some pins whose inputs are disabled
    li t1, 0x00CCCCCC
    sw t1, 0x0C(t0)
Intr02BEEF0D:
    # raise some pins whose high_ie's and inputs are enabled
    li t1, 0xCCCCCCCC
    sw t1, 0x0C(t0)
    # wait to finish
    li t1, 0b00001000
    1: bne t1,a0,1b
    li a0, 0
    # =========== Low Interrupts ===========
    # disable all high interrupts
    li t1, 0
    sw t1, 0x28(t0)
    # enable all inputs
    li t1, 0xFFFFFFFF
    sw t1, 0x04(t0)
    # enable some low_ie's for high pins
    # should not cause an interrupt
    li t1, 0xCC0000CC
    sw t1, 0x30(t0)
Intr02BEEF0E:
    # enable some low_ie's for low pins
    li t1, 0xCCCCFFFF
    sw t1, 0x30(t0)
    # wait to finish
    li t1, 0b00001000
    1: bne t1,a0,1b
    li a0, 0
    # raise all pins
    li t1, 0xFFFFFFFF
    sw t1, 0x0C(t0)
    # lower any existing low_ip's
    #   actually takes a little time for vals
    #   to propagate through synchronizer
    #   so this extra load is a nop effectively
    li t1, 0xFFFFFFFF
    sw t1, 0x34(t0)
    # re-enable some low_ie's
    li t1, 0xFF0000FF
    sw t1, 0x30(t0)
    # lower some pins whose low_ie's are disabled
    li t1, 0xFF1111FF
    sw t1, 0x0C(t0)
Intr02BEEF0F:
    # disable some inputs of pins whose low_ie's are enabled
    li t1, 0x0000FFFF
    sw t1, 0x04(t0)
    # wait to finish
    li t1, 0b00001000
    1: bne t1,a0,1b
    li a0, 0
    # ========== Clear GPIO State ==========
    # disable all interrupts
    sw x0, 0x18(t0)
    sw x0, 0x20(t0)
    sw x0, 0x28(t0)
    sw x0, 0x30(t0)
    # enable all inputs
    li t1, 0xFFFFFFFF
    sw t1, 0x04(t0)
    # enable all outputs
    li t1, 0xFFFFFFFF
    sw t1, 0x08(t0)
    # set initial output state
    sw x0, 0x0C(t0)
    # clear all pending interrupts
    li t1, 0xFFFFFFFF
    sw t1, 0x1C(t0)
    sw t1, 0x24(t0)
    sw t1, 0x2C(t0)
    sw t1, 0x34(t0)
    # ========== Output XOR Test ==========
    # enable some inputs
    li t1, 0x0000FFFF
    sw t1, 0x04(t0)
    # enable some outputs
    li t1, 0xFF0000FF
    sw t1, 0x08(t0)
    # enable all rising and falling edge interrupts
    li t1, 0xFFFFFFFF
    sw t1, 0x18(t0)
    sw t1, 0x20(t0)
Intr02BEEF10:
    # XOR all outputs
    li t1, 0xFFFFFFFF
    sw t1, 0x40(t0)
    # wait to finish
    li t1, 0b00001000
    1: bne t1,a0,1b
    li a0, 0
Intr02BEEF11:
    # XOR some outputs
    li t1, 0x33333333
    sw t1, 0x40(t0)
    # wait to finish
    li t1, 0b00001000
    1: bne t1,a0,1b
    li a0, 0
    # ========== Clear GPIO State ==========
    # disable all interrupts
    sw x0, 0x18(t0)
    sw x0, 0x20(t0)
    sw x0, 0x28(t0)
    sw x0, 0x30(t0)
    # enable all inputs
    li t1, 0xFFFFFFFF
    sw t1, 0x04(t0)
    # enable all outputs
    li t1, 0xFFFFFFFF
    sw t1, 0x08(t0)
    # set initial output state
    sw x0, 0x0C(t0)
    # clear XOR
    li t1, 0x00000000
    sw t1, 0x40(t0)
    # clear all pending interrupts
    li t1, 0xFFFFFFFF
    sw t1, 0x1C(t0)
    sw t1, 0x24(t0)
    sw t1, 0x2C(t0)
    sw t1, 0x34(t0)

    ##################################
    ##### Test 3 - UART Testing  #####
    ##################################
    li a1, 0x03beef00 # group ID
    # clear MEIE
    li t0, 0x800
    csrrc x0, mie, t0
    # ========== Configure PLIC ==========
    # priority threshold = 0
    li t0, 0xC200000
    li t1, 0
    sw t1, 0(t0)
    # source 0xA (UART) priority = 1
    li t0, 0xC000000
    li t1, 1
    sw t1, 0x28(t0)
    # enable source 0xA
    li t0, 0x0C002000
    li t1, 0b10000000000
    sw t1, 0(t0)
    # ========== Transmitter Holding Register Empty Interrupt (THRE) ==========
    # MCR: Loop = 1
    li t0, 0x10000000
    li t1, 0b00010000
    sb t1, 4(t0)
    # LCR: Use 8 data bits plus odd parity bit
    li t1, 0b00001011
    sb t1, 3(t0)
    # IER: Disable all interrupts for now
    li t1, 0x0
    sb t1, 1(t0)
    # set MEIE
    li t1, 0x800
    csrrs x0, mie, t1
    # THR: TX 'l'
    li t1, 'l'
    sb t1, 0(t0)
    # wait directly on UART for completion
    li t1, 0b01100001
    1: lb t2, 5(t0)
    bne t1, t2, 1b
Intr03BEEF12:
    # IER: enable THR empty intr (ETBEI)
    li t1, 0b00000010
    sb t1, 1(t0)
    # wait to finish
    li t1, 0b00010000
    1: bne t1,a0,1b
    li a0, 0
    # IER: disable THR empty intr (ETBEI)
    sb x0, 1(t0)
    # THR: TX 'l'
    li t1, 'l'
    sb t1, 0(t0)
    # THR: TX 'o'
    li t1, 'o'
    sb t1, 0(t0)
Intr03BEEF13:
    # IER: enable THR empty intr (ETBEI)
    li t1, 0b00000010
    sb t1, 1(t0)
    # This will take a few cycles before UART finishes TX'ing
    # If we see SCR modifications in output, it means UART probably
    # did wait until empty THR before triggering the interrupt.
    sb t1, 7(t0)
    # wait to finish
    li t1, 0b00010000
    1: bne t1,a0,1b
    li a0, 0
    # ========== Received Data Available Interrupt (ERBFI) & Loop Mode ==========
    # Clear SCR
    sb x0, 7(t0)
Intr03BEEF14:
    # IER: enable RBR ready intr ERBFI
    li t1, 0x1
    sb t1, 1(t0)
    # wait to finish
    li t1, 0b00010000
    1: bne t1,a0,1b
    li a0, 0
Intr03BEEF15:
    # THR: TX ' '
    li t1, 0x20
    sb t1, 0(t0)
    # This will take a few cycles before UART finishes RX'ing
    # If we see SCR modifications in output, it means UART probably
    # did wait until received data available before triggering the interrupt.
    li t1, 3
    sb t1, 7(t0)
    # wait to finish
    li t1, 0b00010000
    1: bne t1,a0,1b
    li a0, 0
Intr03BEEF16:
    # THR: TX 't'
    li t1, 't'
    sb t1, 0(t0)
    # Same shenanigans as before, only now we also confirm
    # that you can read the RBR before new data is available
    # without messing up the receive interrupt.
    lb t1, 0(t0)
    sb t1, 7(t0)
    # wait to finish
    li t1, 0b00010000
    1: bne t1,a0,1b
    li a0, 0
    # MCR: Loop = 0
    li t1, 0b00000000
    sb t1, 4(t0)
    # Clear SCR
    sb x0, 7(t0)
    # THR: TX 'h'
    #   should TX but not not trigger interrupt
    li t1, 'h'
    sb t1, 0(t0)
    # wait directly on UART for completion
    li t1, 0b01100000
    1: lb t2, 5(t0)
    bne t1, t2, 1b
    # Can use THRE test from before to verify we are transmitting
    # THR: TX 'e'
    li t1, 'e'
    sb t1, 0(t0)
    # THR: TX 'r'
    li t1, 'r'
    sb t1, 0(t0)
Intr03BEEF17:
    # IER: enable THR empty intr (ETBEI) and RBR ready intr (ERBFI)
    li t1, 0b00000011
    sb t1, 1(t0)
    sb t1, 7(t0)
    # wait to finish
    li t1, 0b00010000
    1: bne t1,a0,1b
    li a0, 0
    # manually wait until transmitter finishes before enabling loop mode
    li t1, 0b01100000
    1: lb t2, 5(t0)
    bne t1, t2, 1b
    # MCR: Loop = 1
    li t1, 0b00010000
    sb t1, 4(t0)
Intr03BEEF18:
Intr03BEEF19:
    # THR: TX 'e'
    li t1, 'e'
    sb t1, 0(t0)
    # wait to finish
    li t1, 0b00010000
    1: bne t1,a0,1b
    li a0, 0
    # wait to finish again
    li t1, 0b00010000
    1: bne t1,a0,1b
    li a0, 0
    # ========== Receiver Line Status Intr (ELSI) & Overrun Error (OE) ==========
    # IER: Enable Receiver Line Status Intr (ELSI)
    li t1, 0b00000100
    sb t1, 1(t0)
    li t1, 0xFF
    sb t1, 7(t0)
    # We can't cause all kinds of interesting errors, but at least we can
    # cause an overrun error by transmitting twice without reading.
Intr03BEEF1A:
    # THR: TX '\n'
    li t1, 0xD
    sb t1, 0(t0)
    # THR: TX 'G'
    li t1, 'G'
    sb t1, 0(t0)
    # wait to finish
    li t1, 0b00010000
    1: bne t1,a0,1b
    li a0, 0

#ifndef M_MODE_ONLY
    ####################################################
    ##### Test 4 - Signs of Life on PLIC Context 1 #####
    ####################################################
    li a1, 0x04beef00 # group ID
    # clear MEIE (good to turn off while configuring peripherals)
    li t0, 0x800
    csrrc x0, mie, t0
    # ========== Configure PLIC ==========
    # priority threshold = 0
    li t0, 0xC200000
    li t1, 0
    sw t1, 0(t0)
    # source 3 (GPIO) priority = 6
    li t0, 0xC000000
    li t1, 6
    sw t1, 0x0C(t0)
    # source 0xA (UART) priority = 7
    li t1, 7
    sw t1, 0x28(t0)
    # disable sources 3,0xA on context 0
    li t0, 0x0C002000
    li t1, 0
    sw t1, 0(t0)
    # enable sources 3,0xA on context 1
    li t0, 0x0C002080
    li t1, 0b10000001000
    sw t1, 0(t0)
    # ========== Configure UART ==========
    # MCR: Loop = 1
    li t0, 0x10000000
    li t1, 0b10000
    sb t1, 4(t0)
    # LCR: Use 8 data bits plus odd parity bit
    li t1, 0b00001011
    sb t1, 3(t0)
    # IER: Enable Received Data Available Interrupt
    li t1, 0x01
    sb t1, 1(t0)
    # ========== Configure GPIO ==========
    # raise all input_en
    li t0, 0x10060000
    li t1, 0xFFFFFFFF
    sw t1, 0x04(t0)
    # raise all output_en
    sw t1, 0x08(t0)
    # raise all rise_en
    sw t1, 0x18(t0)
    # ========== Execute Test ==========
    # set MEIE and SEIE
    li t0, 0xA00
    csrrs x0, mie, t0
Intr04BEEF1B:
    # UART TX 'e'
    li t0, 0x10000000
    li t1, 'e'
    sb t1, 0(t0)
    # wait to finish
    li t1, 0b00010000
    1: bne t1,a0,1b
    li a0, 0
Intr04BEEF1C:
    # GPIO raise pin 19
    li t0, 0x10060000
    li t1, 0x00080000
    sw t1, 0x0C(t0)
    # wait to finish
    li t1, 0b00001000
    1: bne t1,a0,1b
    li a0, 0
    # Now let's go bonkers and trigger both!
Intr04BEEF1D:
    # TX 'n'
    li t0, 0x10000000
    li t1, 'n'
    sb t1, 0(t0)
Intr04BEEF1E:
    # GPIO lower pin 19 raise pin 0
    li t0, 0x10060000
    li t1, 0x00000001
    sw t1, 0x0C(t0)
    # wait to finish
    li t1, 0b00011000
    1: bne t1,a0,1b
    li a0, 0
    # ---------------------------------------------------------------------------------------------
#endif

    # ===== Self-check: every expected signature block must have been written =====
    la t0, wally_signature
    sub t0, s0, t0              # bytes of signature written
    la t1, expected_signature_end
    la t2, expected_signature
    sub t1, t1, t2              # bytes of signature expected
    bne t0, t1, selfcheck_length_fail
    la t0, selfcheck_record
    li t1, 1
    SREG t1, 0(t0)            # record that all signature entries matched

TEST_HALT

# ===== Self-check failure handlers =====
# selfcheck_record layout (XLEN-bit entries):
#    0: status: 0 = test did not finish, 1 = passed, 2 = entry mismatch, 3 = wrong number of entries
#    1: index of the failing 4-byte entry (or number of entries written)
#    2: address of the failing entry
#    3: expected value (or number of entries expected)
#    4: actual value (or number of entries written)

# Reached from the trap handler when a signature word does not match.
# t0 = actual value, t4 = expected value, t2 = address of the word
selfcheck_fail:
    la t1, selfcheck_record
    li t3, 2
    SREG t3, 0(t1)            # status: entry mismatch
    la t3, wally_signature
    sub t3, t2, t3
    srli t3, t3, 2              # index of the 4-byte entry
    SREG t3, REGBYTES(t1)
    SREG t2, (2*REGBYTES)(t1) # address of the entry
    SREG t4, (3*REGBYTES)(t1) # expected value
    SREG t0, (4*REGBYTES)(t1) # actual value
    li x1, 1
    j write_tohost              # halt

# Reached at the end of the test when the number of signature bytes written (t0) differs from the number expected (t1).
selfcheck_length_fail:
    la t2, selfcheck_record
    li t3, 3
    SREG t3, 0(t2)            # status: wrong number of entries
    srli t0, t0, 2
    SREG t0, REGBYTES(t2)     # number of entries written
    SREG s0, (2*REGBYTES)(t2) # next signature address
    srli t1, t1, 2
    SREG t1, (3*REGBYTES)(t2) # number of entries expected
    SREG t0, (4*REGBYTES)(t2) # number of entries written
    li x1, 1
    j write_tohost              # halt

.data
# stack memory (size 16 words)
.align 3
stack:
.fill 16, 8, 0xdeadbeef

SIGNATURE_BEGIN
# signature output
wally_signature:
.fill 0x200, 8, 0x00000000
sig_end_canary:
.int 0x0
rvtest_sig_end:

.align 3
    .fill 2, 4, 0   # pad so selfcheck_record does not share an address with end_signature (objdump only labels one symbol per address)
.globl selfcheck_record
selfcheck_record:
    .fill 8, REGBYTES, 0

# ---------------------------------------------------------------------------------------------
# Expected signature
#
#   One 0x40-byte block (16 entries) per interrupt, in the order the interrupts are taken.
#   Entry 1 of each block is the mcause exception code and entry 2 is the mcause interrupt bit.
#   The trap handler checks each block as soon as it has been written; a mismatch halts the test
#   and reports the entry index below.  The first entry of each block is the test ID, which
#   matches the Intr* label in the code that triggers the interrupt.
# ---------------------------------------------------------------------------------------------

.align 2
expected_signature:
// ---- entries 0-15: Intr01BEEF00 ----
.4byte 0x01BEEF00 // 0 (+0x00): Test 1 interrupt 0
.4byte 0x0000000B // 1 (+0x04): MEIP
.4byte 0x00000001 // 2 (+0x08): interrupt bit
.4byte 0x0000000A // 3 (+0x0C): claim ID
.4byte 0x00000004 // 4 (+0x10): IIR
.4byte 0x00000061 // 5 (+0x14): LSR
.4byte 0x00000061 // 6 (+0x18): LSR after reading LSR
.4byte 0x00000068 // 7 (+0x1C): RBR
.4byte 0x00000060 // 8 (+0x20): LSR after erading RBR too
.4byte 0x00000001 // 9 (+0x24): SCR
.4byte 0x00000000 // 10 (+0x28): null
.4byte 0x00000000 // 11 (+0x2C): null
.4byte 0x00000000 // 12 (+0x30): null
.4byte 0x00000000 // 13 (+0x34): null
.4byte 0x00000000 // 14 (+0x38): null
.4byte 0x00000000 // 15 (+0x3C): null
// ---- entries 16-31: Intr01BEEF01 ----
.4byte 0x01BEEF01 // 0 (+0x00): Test 1 interrupt 1
.4byte 0x0000000B // 1 (+0x04)
.4byte 0x00000001 // 2 (+0x08)
.4byte 0x00000003 // 3 (+0x0C)
.4byte 0x00080000 // 4 (+0x10)
.4byte 0x00080000 // 5 (+0x14)
.4byte 0x00080000 // 6 (+0x18)
.4byte 0x00000000 // 7 (+0x1C)
.4byte 0x00000000 // 8 (+0x20)
.4byte 0x00000000 // 9 (+0x24)
.4byte 0x00080000 // 10 (+0x28)
.4byte 0x00080000 // 11 (+0x2C)
.4byte 0xFFFFFFFF // 12 (+0x30)
.4byte 0xFFF7FFFF // 13 (+0x34)
.4byte 0x00000000 // 14 (+0x38)
.4byte 0x00000000 // 15 (+0x3C)
// ---- entries 32-47: Intr01BEEF02 ----
.4byte 0x01BEEF02 // 0 (+0x00): Test 1 interrupt 2
.4byte 0x0000000B // 1 (+0x04)
.4byte 0x00000001 // 2 (+0x08)
.4byte 0x00000003 // 3 (+0x0C)
.4byte 0x00000001 // 4 (+0x10)
.4byte 0x00000001 // 5 (+0x14)
.4byte 0x00000001 // 6 (+0x18)
.4byte 0x00000000 // 7 (+0x1C)
.4byte 0x00080000 // 8 (+0x20)
.4byte 0x00000000 // 9 (+0x24)
.4byte 0x00080001 // 10 (+0x28)
.4byte 0x00000001 // 11 (+0x2C)
.4byte 0xFFFFFFFF // 12 (+0x30)
.4byte 0xFFFFFFFE // 13 (+0x34)
.4byte 0x00000000 // 14 (+0x38)
.4byte 0x00000000 // 15 (+0x3C)
// ---- entries 48-63: Intr01BEEF03 ----
.4byte 0x01BEEF03 // 0 (+0x00): Test 1 interrupt 3
.4byte 0x0000000B // 1 (+0x04)
.4byte 0x00000001 // 2 (+0x08)
.4byte 0x0000000A // 3 (+0x0C)
.4byte 0x00000004 // 4 (+0x10)
.4byte 0x00000061 // 5 (+0x14)
.4byte 0x00000061 // 6 (+0x18)
.4byte 0x00000065 // 7 (+0x1C)
.4byte 0x00000060 // 8 (+0x20)
.4byte 0x00000001 // 9 (+0x24)
.4byte 0x00000000 // 10 (+0x28)
.4byte 0x00000000 // 11 (+0x2C)
.4byte 0x00000000 // 12 (+0x30)
.4byte 0x00000000 // 13 (+0x34)
.4byte 0x00000000 // 14 (+0x38)
.4byte 0x00000000 // 15 (+0x3C)
// ---- entries 64-79: Intr02BEEF04 ----
.4byte 0x02BEEF04 // 0 (+0x00): Test 2 interrupt 4
.4byte 0x0000000B // 1 (+0x04)
.4byte 0x00000001 // 2 (+0x08)
.4byte 0x00000003 // 3 (+0x0C)
.4byte 0x0000F0F0 // 4 (+0x10)
.4byte 0x3030F0F0 // 5 (+0x14)
.4byte 0x0000F0F0 // 6 (+0x18)
.4byte 0x00000000 // 7 (+0x1C)
.4byte 0x00000001 // 8 (+0x20)
.4byte 0x00000000 // 9 (+0x24)
.4byte 0x0000F0F1 // 10 (+0x28)
.4byte 0x0000F0F0 // 11 (+0x2C)
.4byte 0xFFFFFFFF // 12 (+0x30)
.4byte 0xFFFF0F0F // 13 (+0x34)
.4byte 0x00000000 // 14 (+0x38)
.4byte 0x00000000 // 15 (+0x3C)
// ---- entries 80-95: Intr02BEEF05 ----
.4byte 0x02BEEF05 // 0 (+0x00): Test 2 interrupt 5
.4byte 0x0000000B // 1 (+0x04)
.4byte 0x00000001 // 2 (+0x08)
.4byte 0x00000003 // 3 (+0x0C)
.4byte 0x30300000 // 4 (+0x10)
.4byte 0x3030F0F0 // 5 (+0x14)
.4byte 0x30300000 // 6 (+0x18)
.4byte 0x00000000 // 7 (+0x1C)
.4byte 0x0000F0F0 // 8 (+0x20)
.4byte 0x00000000 // 9 (+0x24)
.4byte 0x3030F0F0 // 10 (+0x28)
.4byte 0x30300000 // 11 (+0x2C)
.4byte 0xFFFFFFFF // 12 (+0x30)
.4byte 0xCFCFFFFF // 13 (+0x34)
.4byte 0x00000000 // 14 (+0x38)
.4byte 0x00000000 // 15 (+0x3C)
// ---- entries 96-111: Intr02BEEF06 ----
.4byte 0x02BEEF06 // 0 (+0x00): Test 2 interrupt 6
.4byte 0x0000000B // 1 (+0x04)
.4byte 0x00000001 // 2 (+0x08)
.4byte 0x00000003 // 3 (+0x0C)
.4byte 0x30000000 // 4 (+0x10)
.4byte 0x3030F0F0 // 5 (+0x14)
.4byte 0x00000000 // 6 (+0x18)
.4byte 0x00000000 // 7 (+0x1C)
.4byte 0x00300000 // 8 (+0x20)
.4byte 0x00000000 // 9 (+0x24)
.4byte 0x30300000 // 10 (+0x28)
.4byte 0x30000000 // 11 (+0x2C)
.4byte 0xCFFFFFFF // 12 (+0x30)
.4byte 0xCFFFFFFF // 13 (+0x34)
.4byte 0x00000000 // 14 (+0x38)
.4byte 0x00000000 // 15 (+0x3C)
// ---- entries 112-127: Intr02BEEF07 ----
.4byte 0x02BEEF07 // 0 (+0x00): Test 2 interrupt 7
.4byte 0x0000000B // 1 (+0x04)
.4byte 0x00000001 // 2 (+0x08)
.4byte 0x00000003 // 3 (+0x0C)
.4byte 0x0F000000 // 4 (+0x10)
.4byte 0x0F0F0F0F // 5 (+0x14)
.4byte 0x0F000000 // 6 (+0x18)
.4byte 0x00000000 // 7 (+0x1C)
.4byte 0x30000000 // 8 (+0x20)
.4byte 0x00000000 // 9 (+0x24)
.4byte 0x3F000000 // 10 (+0x28)
.4byte 0x0F000000 // 11 (+0x2C)
.4byte 0xFFFFFFFF // 12 (+0x30)
.4byte 0xF0FFFFFF // 13 (+0x34)
.4byte 0x00000000 // 14 (+0x38)
.4byte 0x00000000 // 15 (+0x3C)
// ---- entries 128-143: Intr02BEEF08 ----
.4byte 0x02BEEF08 // 0 (+0x00): Test 2 interrupt 8
.4byte 0x0000000B // 1 (+0x04)
.4byte 0x00000001 // 2 (+0x08)
.4byte 0x00000003 // 3 (+0x0C)
.4byte 0x00FFFF00 // 4 (+0x10)
.4byte 0x00FFFF00 // 5 (+0x14)
.4byte 0x00FFFF00 // 6 (+0x18)
.4byte 0x00000000 // 7 (+0x1C)
.4byte 0x00000000 // 8 (+0x20)
.4byte 0x00000000 // 9 (+0x24)
.4byte 0x00FFFF00 // 10 (+0x28)
.4byte 0x00FFFF00 // 11 (+0x2C)
.4byte 0xFFFFFFFF // 12 (+0x30)
.4byte 0xFF0000FF // 13 (+0x34)
.4byte 0x00000000 // 14 (+0x38)
.4byte 0x00000000 // 15 (+0x3C)
// ---- entries 144-159: Intr02BEEF09 ----
.4byte 0x02BEEF09 // 0 (+0x00): Test 2 interrupt 9
.4byte 0x0000000B // 1 (+0x04)
.4byte 0x00000001 // 2 (+0x08)
.4byte 0x00000003 // 3 (+0x0C)
.4byte 0x33FFFF33 // 4 (+0x10)
.4byte 0x33FFFF33 // 5 (+0x14)
.4byte 0x33000033 // 6 (+0x18)
.4byte 0x00000000 // 7 (+0x1C)
.4byte 0x00000000 // 8 (+0x20)
.4byte 0x00000000 // 9 (+0x24)
.4byte 0x33FFFF33 // 10 (+0x28)
.4byte 0x33FFFF33 // 11 (+0x2C)
.4byte 0xFF0000FF // 12 (+0x30)
.4byte 0xCC0000CC // 13 (+0x34)
.4byte 0x00000000 // 14 (+0x38)
.4byte 0x00000000 // 15 (+0x3C)
// ---- entries 160-175: Intr02BEEF0A ----
.4byte 0x02BEEF0A // 0 (+0x00): Test 2 interrupt 10
.4byte 0x0000000B // 1 (+0x04)
.4byte 0x00000001 // 2 (+0x08)
.4byte 0x00000003 // 3 (+0x0C)
.4byte 0x33000033 // 4 (+0x10)
.4byte 0x33000033 // 5 (+0x14)
.4byte 0x00000000 // 6 (+0x18)
.4byte 0x00000000 // 7 (+0x1C)
.4byte 0x00FFFF00 // 8 (+0x20)
.4byte 0x00000000 // 9 (+0x24)
.4byte 0x33FFFF33 // 10 (+0x28)
.4byte 0x33000033 // 11 (+0x2C)
.4byte 0xCCFFFFCC // 12 (+0x30)
.4byte 0xCCFFFFCC // 13 (+0x34)
.4byte 0x00000000 // 14 (+0x38)
.4byte 0x00000000 // 15 (+0x3C)
// ---- entries 176-191: Intr02BEEF0B ----
.4byte 0x02BEEF0B // 0 (+0x00): Test 2 interrupt 11
.4byte 0x0000000B // 1 (+0x04)
.4byte 0x00000001 // 2 (+0x08)
.4byte 0x00000003 // 3 (+0x0C)
.4byte 0x00CCCC00 // 4 (+0x10)
.4byte 0x00CCCC00 // 5 (+0x14)
.4byte 0x00CCCC00 // 6 (+0x18)
.4byte 0x00000000 // 7 (+0x1C)
.4byte 0x33000033 // 8 (+0x20)
.4byte 0x00000000 // 9 (+0x24)
.4byte 0x33CCCC33 // 10 (+0x28)
.4byte 0x00CCCC00 // 11 (+0x2C)
.4byte 0xFFFFFFFF // 12 (+0x30)
.4byte 0xFF3333FF // 13 (+0x34)
.4byte 0x00000000 // 14 (+0x38)
.4byte 0x00000000 // 15 (+0x3C)
// ---- entries 192-207: Intr02BEEF0C ----
.4byte 0x02BEEF0C // 0 (+0x00): Test 2 interrupt 12
.4byte 0x0000000B // 1 (+0x04)
.4byte 0x00000001 // 2 (+0x08)
.4byte 0x00000003 // 3 (+0x0C)
.4byte 0x00CCCC00 // 4 (+0x10)
.4byte 0x00CCCC00 // 5 (+0x14)
.4byte 0x00000000 // 6 (+0x18)
.4byte 0x00000000 // 7 (+0x1C)
.4byte 0x00000000 // 8 (+0x20)
.4byte 0x00000000 // 9 (+0x24)
.4byte 0x00CCCC00 // 10 (+0x28)
.4byte 0x00CCCC00 // 11 (+0x2C)
.4byte 0xFF3333FF // 12 (+0x30)
.4byte 0xFF3333FF // 13 (+0x34)
.4byte 0x00000000 // 14 (+0x38)
.4byte 0x00000000 // 15 (+0x3C)
// ---- entries 208-223: Intr02BEEF0D ----
.4byte 0x02BEEF0D // 0 (+0x00): Test 2 interrupt 13
.4byte 0x0000000B // 1 (+0x04)
.4byte 0x00000001 // 2 (+0x08)
.4byte 0x00000003 // 3 (+0x0C)
.4byte 0xCC00CCCC // 4 (+0x10)
.4byte 0xCCCCCCCC // 5 (+0x14)
.4byte 0xCC00CCCC // 6 (+0x18)
.4byte 0x00000000 // 7 (+0x1C)
.4byte 0x00CCCC00 // 8 (+0x20)
.4byte 0x00000000 // 9 (+0x24)
.4byte 0xCC00CCCC // 10 (+0x28)
.4byte 0xCC00CCCC // 11 (+0x2C)
.4byte 0xFFFFFFFF // 12 (+0x30)
.4byte 0x33FF3333 // 13 (+0x34)
.4byte 0x00000000 // 14 (+0x38)
.4byte 0x00000000 // 15 (+0x3C)
// ---- entries 224-239: Intr02BEEF0E ----
.4byte 0x02BEEF0E // 0 (+0x00): Test 2 interrupt 14
.4byte 0x0000000B // 1 (+0x04)
.4byte 0x00000001 // 2 (+0x08)
.4byte 0x00000003 // 3 (+0x0C)
.4byte 0xCCCCCCCC // 4 (+0x10)
.4byte 0xCCCCCCCC // 5 (+0x14)
.4byte 0x00CC0000 // 6 (+0x18)
.4byte 0x00000000 // 7 (+0x1C)
.4byte 0x00000000 // 8 (+0x20)
.4byte 0x00000000 // 9 (+0x24)
.4byte 0xCCCCCCCC // 10 (+0x28)
.4byte 0xCCCCCCCC // 11 (+0x2C)
.4byte 0x33FF3333 // 12 (+0x30)
.4byte 0x33333333 // 13 (+0x34)
.4byte 0x00000000 // 14 (+0x38)
.4byte 0x00000000 // 15 (+0x3C)
// ---- entries 240-255: Intr02BEEF0F ----
.4byte 0x02BEEF0F // 0 (+0x00): Test 2 interrupt 15
.4byte 0x0000000B // 1 (+0x04)
.4byte 0x00000001 // 2 (+0x08)
.4byte 0x00000003 // 3 (+0x0C)
.4byte 0x000011FF // 4 (+0x10)
.4byte 0xFF1111FF // 5 (+0x14)
.4byte 0x33333333 // 6 (+0x18)
.4byte 0x00000000 // 7 (+0x1C)
.4byte 0xFFFFEE00 // 8 (+0x20)
.4byte 0x00000000 // 9 (+0x24)
.4byte 0xFFFFFFFF // 10 (+0x28)
.4byte 0x000011FF // 11 (+0x2C)
.4byte 0xFFFFEE00 // 12 (+0x30)
.4byte 0xFFFFEE00 // 13 (+0x34)
.4byte 0x00000000 // 14 (+0x38)
.4byte 0x00000000 // 15 (+0x3C)
// ---- entries 256-271: Intr02BEEF10 ----
.4byte 0x02BEEF10 // 0 (+0x00): Test 2 interrupt 16
.4byte 0x0000000B // 1 (+0x04)
.4byte 0x00000001 // 2 (+0x08)
.4byte 0x00000003 // 3 (+0x0C)
.4byte 0x000000FF // 4 (+0x10)
.4byte 0x00000000 // 5 (+0x14)
.4byte 0x000000FF // 6 (+0x18)
.4byte 0x00000000 // 7 (+0x1C)
.4byte 0x00000000 // 8 (+0x20)
.4byte 0x00000000 // 9 (+0x24)
.4byte 0x000000FF // 10 (+0x28)
.4byte 0x000000FF // 11 (+0x2C)
.4byte 0xFFFFFFFF // 12 (+0x30)
.4byte 0xFFFFFF00 // 13 (+0x34)
.4byte 0x00000000 // 14 (+0x38)
.4byte 0x00000000 // 15 (+0x3C)
// ---- entries 272-287: Intr02BEEF11 ----
.4byte 0x02BEEF11 // 0 (+0x00): Test 2 interrupt 17
.4byte 0x0000000B // 1 (+0x04)
.4byte 0x00000001 // 2 (+0x08)
.4byte 0x00000003 // 3 (+0x0C)
.4byte 0x00000033 // 4 (+0x10): input
.4byte 0x00000000 // 5 (+0x14): output
.4byte 0x00000000 // 6 (+0x18): rise ip
.4byte 0x00000000 // 7 (+0x1C): serviced rise ip
.4byte 0x000000CC // 8 (+0x20): fall ip
.4byte 0x00000000 // 9 (+0x24)
.4byte 0x000000FF // 10 (+0x28): high ip
.4byte 0x00000033 // 11 (+0x2C): why is this 0x33?
.4byte 0xFFFFFFCC // 12 (+0x30): low ip
.4byte 0xFFFFFFCC // 13 (+0x34): serviced low ip
.4byte 0x00000000 // 14 (+0x38)
.4byte 0x00000000 // 15 (+0x3C)
// ---- entries 288-303: Intr03BEEF12 ----
.4byte 0x03BEEF12 // 0 (+0x00): test 3 interrupt 18
.4byte 0x0000000B // 1 (+0x04)
.4byte 0x00000001 // 2 (+0x08)
.4byte 0x0000000A // 3 (+0x0C)
.4byte 0x00000002 // 4 (+0x10)
.4byte 0x00000061 // 5 (+0x14)
.4byte 0x00000061 // 6 (+0x18)
.4byte 0x0000006C // 7 (+0x1C)
.4byte 0x00000060 // 8 (+0x20)
.4byte 0x00000001 // 9 (+0x24)
.4byte 0x00000000 // 10 (+0x28)
.4byte 0x00000000 // 11 (+0x2C)
.4byte 0x00000000 // 12 (+0x30)
.4byte 0x00000000 // 13 (+0x34)
.4byte 0x00000000 // 14 (+0x38)
.4byte 0x00000000 // 15 (+0x3C)
// ---- entries 304-319: Intr03BEEF13 ----
.4byte 0x03BEEF13 // 0 (+0x00): Test 3 interrupt 19
.4byte 0x0000000B // 1 (+0x04)
.4byte 0x00000001 // 2 (+0x08)
.4byte 0x0000000A // 3 (+0x0C)
.4byte 0x00000002 // 4 (+0x10)
.4byte 0x00000021 // 5 (+0x14)
.4byte 0x00000021 // 6 (+0x18)
.4byte 0x0000006C // 7 (+0x1C)
.4byte 0x00000020 // 8 (+0x20)
.4byte 0x00000001 // 9 (+0x24)
.4byte 0x00000002 // 10 (+0x28)
.4byte 0x00000000 // 11 (+0x2C)
.4byte 0x00000000 // 12 (+0x30)
.4byte 0x00000000 // 13 (+0x34)
.4byte 0x00000000 // 14 (+0x38)
.4byte 0x00000000 // 15 (+0x3C)
// ---- entries 320-335: Intr03BEEF14 ----
.4byte 0x03BEEF14 // 0 (+0x00): Test 3 interrupt 20
.4byte 0x0000000B // 1 (+0x04)
.4byte 0x00000001 // 2 (+0x08)
.4byte 0x0000000A // 3 (+0x0C)
.4byte 0x00000004 // 4 (+0x10)
.4byte 0x00000061 // 5 (+0x14)
.4byte 0x00000061 // 6 (+0x18)
.4byte 0x0000006F // 7 (+0x1C)
.4byte 0x00000060 // 8 (+0x20)
.4byte 0x00000001 // 9 (+0x24)
.4byte 0x00000000 // 10 (+0x28)
.4byte 0x00000000 // 11 (+0x2C)
.4byte 0x00000000 // 12 (+0x30)
.4byte 0x00000000 // 13 (+0x34)
.4byte 0x00000000 // 14 (+0x38)
.4byte 0x00000000 // 15 (+0x3C)
// ---- entries 336-351: Intr03BEEF15 ----
.4byte 0x03BEEF15 // 0 (+0x00): Test 3 interrupt 21
.4byte 0x0000000B // 1 (+0x04)
.4byte 0x00000001 // 2 (+0x08)
.4byte 0x0000000A // 3 (+0x0C)
.4byte 0x00000004 // 4 (+0x10)
.4byte 0x00000061 // 5 (+0x14)
.4byte 0x00000061 // 6 (+0x18)
.4byte 0x00000020 // 7 (+0x1C)
.4byte 0x00000060 // 8 (+0x20)
.4byte 0x00000001 // 9 (+0x24)
.4byte 0x00000003 // 10 (+0x28)
.4byte 0x00000000 // 11 (+0x2C)
.4byte 0x00000000 // 12 (+0x30)
.4byte 0x00000000 // 13 (+0x34)
.4byte 0x00000000 // 14 (+0x38)
.4byte 0x00000000 // 15 (+0x3C)
// ---- entries 352-367: Intr03BEEF16 ----
.4byte 0x03BEEF16 // 0 (+0x00): Test 3 interrupt 22
.4byte 0x0000000B // 1 (+0x04)
.4byte 0x00000001 // 2 (+0x08)
.4byte 0x0000000A // 3 (+0x0C)
.4byte 0x00000004 // 4 (+0x10)
.4byte 0x00000061 // 5 (+0x14)
.4byte 0x00000061 // 6 (+0x18)
.4byte 0x00000074 // 7 (+0x1C)
.4byte 0x00000060 // 8 (+0x20)
.4byte 0x00000001 // 9 (+0x24)
.4byte 0x00000020 // 10 (+0x28)
.4byte 0x00000000 // 11 (+0x2C)
.4byte 0x00000000 // 12 (+0x30)
.4byte 0x00000000 // 13 (+0x34)
.4byte 0x00000000 // 14 (+0x38)
.4byte 0x00000000 // 15 (+0x3C)
// ---- entries 368-383: Intr03BEEF17 ----
.4byte 0x03BEEF17 // 0 (+0x00): Test 3 interrupt 23
.4byte 0x0000000B // 1 (+0x04)
.4byte 0x00000001 // 2 (+0x08)
.4byte 0x0000000A // 3 (+0x0C)
.4byte 0x00000002 // 4 (+0x10)
.4byte 0x00000020 // 5 (+0x14)
.4byte 0x00000020 // 6 (+0x18)
.4byte 0x00000074 // 7 (+0x1C)
.4byte 0x00000020 // 8 (+0x20)
.4byte 0x00000001 // 9 (+0x24)
.4byte 0x00000003 // 10 (+0x28)
.4byte 0x00000000 // 11 (+0x2C)
.4byte 0x00000000 // 12 (+0x30)
.4byte 0x00000000 // 13 (+0x34)
.4byte 0x00000000 // 14 (+0x38)
.4byte 0x00000000 // 15 (+0x3C)
// ---- entries 384-399: Intr03BEEF18 ----
.4byte 0x03BEEF18 // 0 (+0x00): Test 3 interrupt 24
.4byte 0x0000000B // 1 (+0x04)
.4byte 0x00000001 // 2 (+0x08)
.4byte 0x0000000A // 3 (+0x0C)
.4byte 0x00000002 // 4 (+0x10)
.4byte 0x00000020 // 5 (+0x14)
.4byte 0x00000020 // 6 (+0x18)
.4byte 0x00000074 // 7 (+0x1C)
.4byte 0x00000020 // 8 (+0x20)
.4byte 0x00000001 // 9 (+0x24)
.4byte 0x00000003 // 10 (+0x28)
.4byte 0x00000000 // 11 (+0x2C)
.4byte 0x00000000 // 12 (+0x30)
.4byte 0x00000000 // 13 (+0x34)
.4byte 0x00000000 // 14 (+0x38)
.4byte 0x00000000 // 15 (+0x3C)
// ---- entries 400-415: Intr03BEEF19 ----
.4byte 0x03BEEF19 // 0 (+0x00): Test 3 interrupt 25
.4byte 0x0000000B // 1 (+0x04)
.4byte 0x00000001 // 2 (+0x08)
.4byte 0x0000000A // 3 (+0x0C)
.4byte 0x00000004 // 4 (+0x10)
.4byte 0x00000061 // 5 (+0x14)
.4byte 0x00000061 // 6 (+0x18)
.4byte 0x00000065 // 7 (+0x1C)
.4byte 0x00000060 // 8 (+0x20)
.4byte 0x00000001 // 9 (+0x24)
.4byte 0x00000003 // 10 (+0x28)
.4byte 0x00000000 // 11 (+0x2C)
.4byte 0x00000000 // 12 (+0x30)
.4byte 0x00000000 // 13 (+0x34)
.4byte 0x00000000 // 14 (+0x38)
.4byte 0x00000000 // 15 (+0x3C)
// ---- entries 416-431: Intr03BEEF1A ----
.4byte 0x03BEEF1A // 0 (+0x00): Test 3 interrupt 26
.4byte 0x0000000B // 1 (+0x04)
.4byte 0x00000001 // 2 (+0x08)
.4byte 0x0000000A // 3 (+0x0C)
.4byte 0x00000006 // 4 (+0x10)
.4byte 0x00000063 // 5 (+0x14)
.4byte 0x00000061 // 6 (+0x18)
.4byte 0x00000047 // 7 (+0x1C)
.4byte 0x00000060 // 8 (+0x20)
.4byte 0x00000001 // 9 (+0x24)
.4byte 0x000000FF // 10 (+0x28)
.4byte 0x00000000 // 11 (+0x2C)
.4byte 0x00000000 // 12 (+0x30)
.4byte 0x00000000 // 13 (+0x34)
.4byte 0x00000000 // 14 (+0x38)
.4byte 0x00000000 // 15 (+0x3C)
// ---- entries 432-447: Intr04BEEF1B ----
#ifndef M_MODE_ONLY
.4byte 0x04BEEF1B // 0 (+0x00): Test 4 interrupt 27
.4byte 0x00000009 // 1 (+0x04)
.4byte 0x00000001 // 2 (+0x08)
.4byte 0x0000000A // 3 (+0x0C)
.4byte 0x00000004 // 4 (+0x10)
.4byte 0x00000061 // 5 (+0x14)
.4byte 0x00000061 // 6 (+0x18)
.4byte 0x00000065 // 7 (+0x1C)
.4byte 0x00000060 // 8 (+0x20)
.4byte 0x00000001 // 9 (+0x24)
.4byte 0x000000FF // 10 (+0x28)
.4byte 0x00000000 // 11 (+0x2C)
.4byte 0x00000000 // 12 (+0x30)
.4byte 0x00000000 // 13 (+0x34)
.4byte 0x00000000 // 14 (+0x38)
.4byte 0x00000000 // 15 (+0x3C)
// ---- entries 448-463: Intr04BEEF1C ----
.4byte 0x04BEEF1C // 0 (+0x00): Test 4 interrupt 28
.4byte 0x00000009 // 1 (+0x04)
.4byte 0x00000001 // 2 (+0x08)
.4byte 0x00000003 // 3 (+0x0C)
.4byte 0x00080000 // 4 (+0x10)
.4byte 0x00080000 // 5 (+0x14)
.4byte 0x00080000 // 6 (+0x18)
.4byte 0x00000000 // 7 (+0x1C)
.4byte 0x00000000 // 8 (+0x20)
.4byte 0x00000000 // 9 (+0x24)
.4byte 0x00080000 // 10 (+0x28)
.4byte 0x00080000 // 11 (+0x2C)
.4byte 0xFFFFFFFF // 12 (+0x30)
.4byte 0xFFF7FFFF // 13 (+0x34)
.4byte 0x00000000 // 14 (+0x38)
.4byte 0x00000000 // 15 (+0x3C)
// ---- entries 464-479: Intr04BEEF1D ----
.4byte 0x04BEEF1D // 0 (+0x00): Test 4 interrupt 29
.4byte 0x00000009 // 1 (+0x04)
.4byte 0x00000001 // 2 (+0x08)
.4byte 0x00000003 // 3 (+0x0C)
.4byte 0x00000001 // 4 (+0x10)
.4byte 0x00000001 // 5 (+0x14)
.4byte 0x00000001 // 6 (+0x18)
.4byte 0x00000000 // 7 (+0x1C)
.4byte 0x00080000 // 8 (+0x20)
.4byte 0x00000000 // 9 (+0x24)
.4byte 0x00080001 // 10 (+0x28)
.4byte 0x00000001 // 11 (+0x2C)
.4byte 0xFFFFFFFF // 12 (+0x30)
.4byte 0xFFFFFFFE // 13 (+0x34)
.4byte 0x00000000 // 14 (+0x38)
.4byte 0x00000000 // 15 (+0x3C)
// ---- entries 480-495: Intr04BEEF1E ----
.4byte 0x04BEEF1E // 0 (+0x00): Test 4 interrupt 30
.4byte 0x00000009 // 1 (+0x04)
.4byte 0x00000001 // 2 (+0x08)
.4byte 0x0000000A // 3 (+0x0C)
.4byte 0x00000004 // 4 (+0x10)
.4byte 0x00000061 // 5 (+0x14)
.4byte 0x00000061 // 6 (+0x18)
.4byte 0x0000006E // 7 (+0x1C)
.4byte 0x00000060 // 8 (+0x20)
.4byte 0x00000001 // 9 (+0x24)
.4byte 0x000000FF // 10 (+0x28)
.4byte 0x00000000 // 11 (+0x2C)
.4byte 0x00000000 // 12 (+0x30)
.4byte 0x00000000 // 13 (+0x34)
.4byte 0x00000000 // 14 (+0x38)
.4byte 0x00000000 // 15 (+0x3C)
#endif
expected_signature_end:
