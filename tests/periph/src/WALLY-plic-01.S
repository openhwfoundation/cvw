///////////////////////////////////////////
//
// WALLY-plic
//
// Author: Nicholas Lucio <nlucio@hmc.edu>
//
// Created 2022-06-16
//
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
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

#include "WALLY-TEST-LIB.h"


INIT_TESTS

TRAP_HANDLER m

j run_test_loop // begin test loop/table tests instead of executing inline code.

INIT_TEST_TABLE

END_TESTS

TEST_STACK_AND_DATA

.align REGSHIFT
test_cases:
# ---------------------------------------------------------------------------------------------
# Test Contents
#
#   Here is where the actual tests are held, or rather, what the actual tests do.
#   each entry consists of 3 values that will be read in as follows:
#
#   'WORD [x28 Value], [x29 Value], [x30 value]'
#                     or
#   'WORD [address], [value], [test type]'
#
#   The encoding for x30 test type values can be found in the test handler in the framework file
#
# ---------------------------------------------------------------------------------------------

# =========== Define PLIC registers ===========

.equ PLIC, 0x0C000000
.equ PLIC_INTPRI_GPIO, (PLIC+0x00000C)       # GPIO is interrupt 3
.equ PLIC_INTPRI_UART, (PLIC+0x000028)       # UART is interrupt 10
.equ PLIC_INTPENDING0, (PLIC+0x001000)       # intPending0 register
.equ PLIC_INTEN00,     (PLIC+0x002000)       # interrupt enables for context 0 (machine mode) sources 31:1
.equ PLIC_INTEN10,     (PLIC+0x002080)       # interrupt enables for context 1 (supervisor mode) sources 31:1
.equ PLIC_THRESH0,     (PLIC+0x200000)       # Priority threshold for context 0 (machine mode)
.equ PLIC_CLAIM0,      (PLIC+0x200004)       # Claim/Complete register for context 0
.equ PLIC_THRESH1,     (PLIC+0x201000)       # Priority threshold for context 1 (supervisor mode)
.equ PLIC_CLAIM1,      (PLIC+0x201004)       # Claim/Complete register for context 1

# =========== Define GPIO registers ===========

.equ GPIO, 0x10060000
.equ input_val, (GPIO+0x00)
.equ input_en, (GPIO+0x04)
.equ output_en, (GPIO+0x08)
.equ output_val, (GPIO+0x0C)
.equ rise_ie, (GPIO+0x18)
.equ rise_ip, (GPIO+0x1C)
.equ fall_ie, (GPIO+0x20)
.equ fall_ip, (GPIO+0x24)
.equ high_ie, (GPIO+0x28)
.equ high_ip, (GPIO+0x2C)
.equ low_ie, (GPIO+0x30)
.equ low_ip, (GPIO+0x34)
.equ iof_en, (GPIO+0x38)
.equ iof_sel, (GPIO+0x3C)
.equ out_xor, (GPIO+0x40)

# =========== Define UART registers ===========

.equ UART, 0x10000000
.equ UART_IER, (UART+0x01)
.equ UART_MCR, (UART+0x04)
.equ UART_MSR, (UART+0x06)

# =========== Initialize UART and GPIO ===========

# GPIO Initialization
WORD input_en, 0x00000001, write32_test   # enable bit 0 of input_en
WORD output_en, 0x00000001, write32_test  # enable bit 0 of output_en
WORD output_val, 0x00000000, write32_test # make sure output_val is 0
WORD rise_ie, 0x00000001, write32_test    # enable rise interrupts

# =========== Initialize relevant PLIC registers ===========

WORD PLIC_INTPRI_GPIO, 0x00000000, write32_test   # set GPIO priority to zero
WORD PLIC_INTPRI_UART, 0x00000000, write32_test   # set UART priority to zero
WORD PLIC_INTEN00, 0x00000408, write32_test       # enable m-mode interrupts
WORD PLIC_INTEN10, 0x00000408, write32_test       # enable s-mode interrupts
WORD PLIC_THRESH0, 0x00000000, write32_test       # set m-mode threshold to 0
WORD PLIC_THRESH1, 0x00000007, write32_test       # set s-mode threshold to max

# =========== Machine-Mode Priority Testing (1.T.X) ===========

# Test 1.0.0: GPIO int lacks priority (0 = 0)
WORD PLIC_THRESH0, 0x00000000, write32_test       # change threshold
WORD output_val, 0x00000001, write32_test         # set GPIO rise_ip high
WORD 0x0, 0x00000000, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # expect interrupt pending on bit 3
WORD PLIC_CLAIM0, 0x00000000, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # interrupt pending
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear interrupt
#WORD PLIC_CLAIM0, 0x00000003, write32_test        # complete claim
WORD 0x0, 0x00000000, claim_m_plic_interrupts     # clear interrupt one
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # no interrupt pending

# Test 1.0.1: GPIO int has priority (1 > 0)
WORD PLIC_INTPRI_GPIO, 0x00000001, write32_test   # let GPIO cause interrupts
WORD output_val, 0x00000001, write32_test         # set GPIO rise_ip high
WORD 0x0, 0x00000800, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # expect interrupt pending on bit 3
WORD PLIC_CLAIM0, 0x00000003, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # interrupt pending was cleared
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear interrupt
WORD PLIC_CLAIM0, 0x00000003, write32_test        # complete claim
WORD 0x0, 0x00000000, claim_m_plic_interrupts     # clear interrupt one
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # no interrupt pending

# Test 1.0.2: meip and c/c clear without interrupt pending
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear interrupt
WORD 0x0, 0x00000000, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # expect no interrupt pending
WORD PLIC_CLAIM0, 0x00000000, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # no interrupt pending
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear interrupt
WORD PLIC_CLAIM0, 0x00000003, write32_test        # complete claim
WORD 0x0, 0x00000000, claim_m_plic_interrupts     # clear interrupt one
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # no interrupt pending

# Test 1.1.0: GPIO lacks priority (1 = 1)
WORD PLIC_THRESH0, 0x00000001, write32_test       # change threshold
WORD output_val, 0x00000001, write32_test         # set GPIO rise_ip high
WORD 0x0, 0x00000000, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # expect interrupt pending on bit 3
WORD PLIC_CLAIM0, 0x00000003, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # interrupt pending
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear interrupt
WORD PLIC_CLAIM0, 0x00000003, write32_test        # complete claim from earlier
WORD 0x0, 0x00000000, claim_m_plic_interrupts     # clear interrupt one
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # no interrupt pending

# Test 1.1.1: GPIO int has priority (2 > 1)
WORD PLIC_INTPRI_GPIO, 0x00000002, write32_test   # let GPIO cause interrupts
WORD output_val, 0x00000001, write32_test         # set GPIO rise_ip high
WORD 0x0, 0x00000800, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # expect interrupt pending on bit 3
WORD PLIC_CLAIM0, 0x00000003, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # interrupt pending was cleared
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear interrupt
WORD PLIC_CLAIM0, 0x00000003, write32_test        # complete claim
WORD 0x0, 0x00000000, claim_m_plic_interrupts     # clear interrupt one
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # no interrupt pending

# Test 1.2.0: GPIO int lacks priority (2 = 2)
WORD PLIC_THRESH0, 0x00000002, write32_test       # change threshold
WORD output_val, 0x00000001, write32_test         # set GPIO rise_ip high
WORD 0x0, 0x00000000, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # expect interrupt pending on bit 3
WORD PLIC_CLAIM0, 0x00000003, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # interrupt pending was cleared
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear interrupt
WORD PLIC_CLAIM0, 0x00000003, write32_test        # complete claim from earlier
WORD 0x0, 0x00000000, claim_m_plic_interrupts     # clear interrupt one
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # no interrupt pending

# Test 1.2.1: GPIO int has priority (3 > 2)
WORD PLIC_INTPRI_GPIO, 0x00000003, write32_test   # let GPIO cause interrupts
WORD output_val, 0x00000001, write32_test         # set GPIO rise_ip high
WORD 0x0, 0x00000800, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # expect interrupt pending on bit 3
WORD PLIC_CLAIM0, 0x00000003, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # interrupt pending was cleared
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear interrupt
WORD PLIC_CLAIM0, 0x00000003, write32_test        # complete claim
WORD 0x0, 0x00000000, claim_m_plic_interrupts     # clear interrupt one
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # no interrupt pending

# Test 1.3.0: GPIO int lacks priority (3 = 3)
WORD PLIC_THRESH0, 0x00000003, write32_test       # change threshold
WORD output_val, 0x00000001, write32_test         # set GPIO rise_ip high
WORD 0x0, 0x00000000, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # expect interrupt pending on bit 3
WORD PLIC_CLAIM0, 0x00000003, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # interrupt pending was cleared
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear interrupt
WORD PLIC_CLAIM0, 0x00000003, write32_test        # complete claim from earlier
WORD 0x0, 0x00000000, claim_m_plic_interrupts     # clear interrupt one
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # no interrupt pending

# Test 1.3.1: GPIO int has priority (4 > 3)
WORD PLIC_INTPRI_GPIO, 0x00000004, write32_test   # let GPIO cause interrupts
WORD output_val, 0x00000001, write32_test         # set GPIO rise_ip high
WORD 0x0, 0x00000800, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # expect interrupt pending on bit 3
WORD PLIC_CLAIM0, 0x00000003, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # interrupt pending was cleared
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear interrupt
WORD PLIC_CLAIM0, 0x00000003, write32_test        # complete claim
WORD 0x0, 0x00000000, claim_m_plic_interrupts     # clear interrupt one
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # no interrupt pending

# Test 1.4.0: GPIO int lacks priority (4 = 4)
WORD PLIC_THRESH0, 0x00000004, write32_test       # change threshold
WORD output_val, 0x00000001, write32_test         # set GPIO rise_ip high
WORD 0x0, 0x00000000, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # expect interrupt pending on bit 3
WORD PLIC_CLAIM0, 0x00000003, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # interrupt pending was cleared
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear interrupt
WORD PLIC_CLAIM0, 0x00000003, write32_test        # complete claim from earlier
WORD 0x0, 0x00000000, claim_m_plic_interrupts     # clear interrupt one
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # no interrupt pending

# Test 1.4.1: GPIO int has priority (5 > 4)
WORD PLIC_INTPRI_GPIO, 0x00000005, write32_test   # let GPIO cause interrupts
WORD output_val, 0x00000001, write32_test         # set GPIO rise_ip high
WORD 0x0, 0x00000800, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # expect interrupt pending on bit 3
WORD PLIC_CLAIM0, 0x00000003, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # interrupt pending was cleared
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear interrupt
WORD PLIC_CLAIM0, 0x00000003, write32_test        # complete claim
WORD 0x0, 0x00000000, claim_m_plic_interrupts     # clear interrupt one
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # no interrupt pending

# Test 1.5.0: GPIO int lacks priority (5 = 5)
WORD PLIC_THRESH0, 0x00000005, write32_test       # change threshold
WORD output_val, 0x00000001, write32_test         # set GPIO rise_ip high
WORD 0x0, 0x00000000, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # expect interrupt pending on bit 3
WORD PLIC_CLAIM0, 0x00000003, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # interrupt pending was cleared
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear interrupt
WORD PLIC_CLAIM0, 0x00000003, write32_test        # complete claim from earlier
WORD 0x0, 0x00000000, claim_m_plic_interrupts     # clear interrupt one
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # no interrupt pending

# Test 1.5.1: GPIO int has priority (6 > 5)
WORD PLIC_INTPRI_GPIO, 0x00000006, write32_test   # let GPIO cause interrupts
WORD output_val, 0x00000001, write32_test         # set GPIO rise_ip high
WORD 0x0, 0x00000800, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # expect interrupt pending on bit 3
WORD PLIC_CLAIM0, 0x00000003, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # interrupt pending was cleared
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear interrupt
WORD PLIC_CLAIM0, 0x00000003, write32_test        # complete claim
WORD 0x0, 0x00000000, claim_m_plic_interrupts     # clear interrupt one
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # no interrupt pending

# Test 1.6.0: GPIO int lacks priority (6 = 6)
WORD PLIC_THRESH0, 0x00000006, write32_test       # change threshold
WORD output_val, 0x00000001, write32_test         # set GPIO rise_ip high
WORD 0x0, 0x00000000, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # expect interrupt pending on bit 3
WORD PLIC_CLAIM0, 0x00000003, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # interrupt pending was cleared
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear interrupt
WORD PLIC_CLAIM0, 0x00000003, write32_test        # complete claim from earlier
WORD 0x0, 0x00000000, claim_m_plic_interrupts     # clear interrupt one
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # no interrupt pending

# Test 1.6.1: GPIO int has priority (7 > 6)
WORD PLIC_INTPRI_GPIO, 0x00000007, write32_test   # let GPIO cause interrupts
WORD output_val, 0x00000001, write32_test         # set GPIO rise_ip high
WORD 0x0, 0x00000800, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # expect interrupt pending on bit 3
WORD PLIC_CLAIM0, 0x00000003, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # interrupt pending was cleared
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear interrupt
WORD PLIC_CLAIM0, 0x00000003, write32_test        # complete claim
WORD 0x0, 0x00000000, claim_m_plic_interrupts     # clear interrupt one
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # no interrupt pending

# Test 1.7.0: GPIO int lacks priority (7 = 7)
WORD PLIC_THRESH0, 0x00000007, write32_test       # change threshold
WORD output_val, 0x00000001, write32_test         # set GPIO rise_ip high
WORD 0x0, 0x00000000, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # expect interrupt pending on bit 3
WORD PLIC_CLAIM0, 0x00000003, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # interrupt pending was cleared
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear interrupt
WORD PLIC_CLAIM0, 0x00000003, write32_test        # complete claim from earlier
WORD 0x0, 0x00000000, claim_m_plic_interrupts     # clear interrupt one
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # no interrupt pending

# =========== UART vs GPIO priority (2.X) ===========

WORD PLIC_INTEN00, 0x00000408, write32_test       # enable m-mode interrupts
WORD PLIC_INTEN10, 0x00000408, write32_test       # enable s-mode interrupts
WORD PLIC_THRESH0, 0x00000000, write32_test       # set m-mode threshold to 0
WORD PLIC_THRESH1, 0x00000007, write32_test       # set s-mode threshold to max
# UART Initialization
WORD UART_IER, 0x08, write08_test   # enable modem status interrupts from CTS
WORD UART_MCR, 0x10, write08_test   # enable loopback mode, RTS = 0
WORD UART_MSR, 0x00, write08_test   # disable UART interrupt

# Test 2.0: GPIO Priority = UART Priority

WORD PLIC_INTPRI_GPIO, 0x00000001, write32_test   # GPIOPriority = 1
WORD PLIC_INTPRI_UART, 0x00000001, write32_test   # UARTPriority = 1
WORD output_val, 0x00000001, write32_test         # cause rise_ip to go high
WORD UART_MSR, 0x0F, write08_test                 # cause UART interrupt
WORD 0x0, 0x00000800, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000408, read32_test    # interrupt pending for GPIO and UART
WORD PLIC_CLAIM0, 0x00000003, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000400, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD UART_MSR, 0x00000000, write08_test           # clear UART interrupt
WORD PLIC_CLAIM0, 0x00000003, write32_test        # complete claim made earlier
WORD 0x0, 0x0, claim_m_plic_interrupts            # clear interrupt one
WORD 0x0, 0x0, claim_m_plic_interrupts            # clear interrupt two
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # no interrupts pending

# Test 2.1: GPIO Priority > UART Priority

WORD PLIC_INTPRI_GPIO, 0x00000003, write32_test   # GPIOPriority = 3
WORD PLIC_INTPRI_UART, 0x00000002, write32_test   # UARTPriority = 2
WORD output_val, 0x00000001, write32_test         # cause rise_ip to go high
WORD UART_MSR, 0x0F, write08_test                 # cause UART interrupt
WORD 0x0, 0x00000800, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000408, read32_test    # interrupt pending for GPIO and UART
WORD PLIC_CLAIM0, 0x00000003, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000400, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD UART_MSR, 0x00000000, write08_test           # clear UART interrupt
WORD PLIC_CLAIM0, 0x00000003, write32_test        # complete claim made earlier
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt two
WORD PLIC_INTPENDING0, 0x00000000, read32_test   # no interrupts pending

# Test 2.2: GPIO Priority < UART Priority

WORD PLIC_INTPRI_GPIO, 0x00000004, write32_test   # GPIOPriority = 4
WORD PLIC_INTPRI_UART, 0x00000005, write32_test   # UARTPriority = 5
WORD output_val, 0x00000001, write32_test         # cause rise_ip to go high
WORD UART_MSR, 0x0F, write08_test                 # cause UART interrupt
WORD 0x0, 0x00000800, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000408, read32_test    # interrupt pending for GPIO and UART
WORD PLIC_CLAIM0, 0x0000000A, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # interrupt pending cleared for UART
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD UART_MSR, 0x00000000, write08_test           # clear UART interrupt
WORD PLIC_CLAIM0, 0x0000000A, write32_test        # complete claim made earlier
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt two
WORD PLIC_INTPENDING0, 0x00000000, read32_test   # no interrupts pending

# Test 2.3: GPIO Priority < UART Priority

WORD PLIC_INTPRI_GPIO, 0x00000006, write32_test   # GPIOPriority = 6
WORD PLIC_INTPRI_UART, 0x00000007, write32_test   # UARTPriority = 7
WORD output_val, 0x00000001, write32_test         # cause rise_ip to go high
WORD UART_MSR, 0x0F, write08_test                 # cause UART interrupt
WORD 0x0, 0x00000800, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000408, read32_test    # interrupt pending for GPIO and UART
WORD PLIC_CLAIM0, 0x0000000A, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # interrupt pending cleared for UART
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD UART_MSR, 0x00000000, write08_test           # clear UART interrupt
WORD PLIC_CLAIM0, 0x0000000A, write32_test        # complete claim made earlier
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt two
WORD PLIC_INTPENDING0, 0x00000000, read32_test   # no interrupts pending

# Test 2.4: Interrupts don't have enough priority

WORD PLIC_INTPRI_GPIO, 0x00000004, write32_test   # GPIOPriority = 4
WORD PLIC_INTPRI_UART, 0x00000005, write32_test   # UARTPriority = 5
WORD PLIC_THRESH0, 0x00000006, write32_test       # set m-mode threshold to 6
WORD output_val, 0x00000001, write32_test         # cause rise_ip to go high
WORD UART_MSR, 0x0F, write08_test                 # cause UART interrupt
WORD 0x0, 0x00000000, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000408, read32_test    # interrupt pending for GPIO and UART
WORD PLIC_CLAIM0, 0x0000000A, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD UART_MSR, 0x00000000, write08_test           # clear UART interrupt
WORD PLIC_CLAIM0, 0x0000000A, write32_test        # complete claim made earlier
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt two
WORD PLIC_INTPENDING0, 0x00000000, read32_test   # no interrupts pending

# =========== SEIP tests (3.X) ===========

WORD PLIC_INTEN00, 0x00000408, write32_test       # enable m-mode interrupts
WORD PLIC_INTEN10, 0x00000408, write32_test       # enable s-mode interrupts
WORD PLIC_THRESH0, 0x00000000, write32_test       # set m-mode threshold to 0
WORD PLIC_THRESH1, 0x00000000, write32_test       # set s-mode threshold to 0

# Test 3.0: Cause machine and supervisor interrupts

WORD PLIC_INTPRI_GPIO, 0x00000001, write32_test   # GPIOPriority = 1
WORD PLIC_INTPRI_UART, 0x00000001, write32_test   # UARTPriority = 1
WORD PLIC_THRESH0, 0x00000000, write32_test       # set m-mode threshold to 0
WORD PLIC_THRESH1, 0x00000000, write32_test       # set s-mode threshold to 0
WORD output_val, 0x00000001, write32_test         # cause rise_ip to go high
WORD UART_MSR, 0x0F, write08_test                 # cause UART interrupt
WORD 0x0, 0x00000A00, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000408, read32_test    # interrupt pending for GPIO and UART
WORD PLIC_CLAIM0, 0x00000003, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000400, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD UART_MSR, 0x00000000, write08_test           # clear UART interrupt
WORD PLIC_CLAIM0, 0x00000003, write32_test        # complete claim made earlier
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt two
WORD PLIC_INTPENDING0, 0x00000000, read32_test   # no interrupts pending

# Test 3.1: Suppress machine mode interrupts

WORD PLIC_INTPRI_GPIO, 0x00000003, write32_test   # GPIOPriority = 3
WORD PLIC_INTPRI_UART, 0x00000002, write32_test   # UARTPriority = 2
WORD PLIC_THRESH0, 0x00000007, write32_test       # set m-mode threshold to 7
WORD PLIC_THRESH1, 0x00000000, write32_test       # set s-mode threshold to 0
WORD output_val, 0x00000001, write32_test         # cause rise_ip to go high
WORD UART_MSR, 0x0F, write08_test                 # cause UART interrupt
WORD 0x0, 0x00000200, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000408, read32_test    # interrupt pending for GPIO and UART
WORD PLIC_CLAIM0, 0x00000003, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000400, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD UART_MSR, 0x00000000, write08_test           # clear UART interrupt
WORD PLIC_CLAIM0, 0x00000003, write32_test        # complete claim made earlier
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt two
WORD PLIC_INTPENDING0, 0x00000000, read32_test   # no interrupts pending

# Test 3.2: Cause SEIP with UART first

WORD PLIC_INTPRI_GPIO, 0x00000006, write32_test   # GPIOPriority = 6
WORD PLIC_INTPRI_UART, 0x00000007, write32_test   # UARTPriority = 7
WORD PLIC_THRESH0, 0x00000007, write32_test       # set m-mode threshold to 7
WORD PLIC_THRESH1, 0x00000000, write32_test       # set s-mode threshold to 0
WORD output_val, 0x00000001, write32_test         # cause rise_ip to go high
WORD UART_MSR, 0x0F, write08_test                 # cause UART interrupt
WORD 0x0, 0x00000200, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000408, read32_test    # interrupt pending for GPIO and UART
WORD PLIC_CLAIM0, 0x0000000A, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD UART_MSR, 0x00000000, write08_test           # clear UART interrupt
WORD PLIC_CLAIM0, 0x0000000A, write32_test        # complete claim made earlier
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt two
WORD PLIC_INTPENDING0, 0x00000000, read32_test   # no interrupts pending

# Test 3.3: Low SEIP due to insufficient priority

WORD PLIC_INTPRI_GPIO, 0x00000002, write32_test   # GPIOPriority = 2
WORD PLIC_INTPRI_UART, 0x00000003, write32_test   # UARTPriority = 3
WORD PLIC_THRESH0, 0x00000004, write32_test       # set m-mode threshold to 4
WORD PLIC_THRESH1, 0x00000005, write32_test       # set s-mode threshold to 5
WORD output_val, 0x00000001, write32_test         # cause rise_ip to go high
WORD UART_MSR, 0x0F, write08_test                 # cause UART interrupt
WORD 0x0, 0x00000000, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000408, read32_test    # interrupt pending for GPIO and UART
WORD PLIC_CLAIM0, 0x0000000A, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000408, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD UART_MSR, 0x00000000, write08_test           # clear UART interrupt
WORD PLIC_CLAIM0, 0x0000000A, write32_test        # complete claim made earlier
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt two
WORD PLIC_INTPENDING0, 0x00000000, read32_test   # no interrupts pending

# =========== UART interrupt enable tests (4.X) ===========

WORD PLIC_THRESH0, 0x00000000, write32_test       # set m-mode threshold to 0
WORD PLIC_THRESH1, 0x00000000, write32_test       # set s-mode threshold to 0
WORD PLIC_INTPRI_GPIO, 0x00000001, write32_test   # GPIO Priority = 1
WORD PLIC_INTPRI_UART, 0x00000001, write32_test   # UART Priority = 1

# Test 4.0: GPIO m-mode disabled

WORD PLIC_INTEN00, 0x00000400, write32_test       # disable GPIO m-mode interrupts
WORD PLIC_INTEN10, 0x00000408, write32_test       # enable all s-mode interrupts
WORD UART_MSR, 0x0F, write08_test                 # cause UART interrupt
WORD 0x0, 0x00000A00, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000400, read32_test    # interrupt pending for GPIO and UART
WORD PLIC_CLAIM0, 0x0000000A, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD UART_MSR, 0x00000000, write08_test           # clear UART interrupt
WORD PLIC_CLAIM0, 0x0000000A, write32_test        # complete claim made earlier
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt two
WORD 0x0, 0x0, claim_s_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_s_plic_interrupts       # clear interrupt two
WORD PLIC_INTPENDING0, 0x00000000, read32_test   # no interrupts pending

# Test 4.1: UART m-mode disabled

WORD PLIC_INTEN00, 0x00000008, write32_test       # disable UART m-mode interrupts
WORD PLIC_INTEN10, 0x00000408, write32_test       # enable all s-mode interrupts
WORD UART_MSR, 0x0F, write08_test                 # cause UART interrupt
WORD 0x0, 0x00000200, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000400, read32_test    # interrupt pending for GPIO and UART
WORD PLIC_CLAIM0, 0x00000000, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000400, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD UART_MSR, 0x00000000, write08_test           # clear UART interrupt
WORD PLIC_CLAIM0, 0x00000000, write32_test        # complete claim made earlier
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt two
WORD 0x0, 0x0, claim_s_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_s_plic_interrupts       # clear interrupt two
WORD PLIC_INTPENDING0, 0x00000000, read32_test   # no interrupts pending

# Test 4.2: GPIO s-mode disabled

WORD PLIC_INTEN00, 0x00000408, write32_test       # enable all m-mode interrupts
WORD PLIC_INTEN10, 0x00000400, write32_test       # enable all s-mode interrupts
WORD UART_MSR, 0x0F, write08_test                 # cause UART interrupt
WORD 0x0, 0x00000A00, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000400, read32_test    # interrupt pending for GPIO and UART
WORD PLIC_CLAIM0, 0x0000000A, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD UART_MSR, 0x00000000, write08_test           # clear UART interrupt
WORD PLIC_CLAIM0, 0x0000000A, write32_test        # complete claim made earlier
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt two
WORD 0x0, 0x0, claim_s_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_s_plic_interrupts       # clear interrupt two
WORD PLIC_INTPENDING0, 0x00000000, read32_test   # no interrupts pending

# Test 4.3: UART s-mode disabled

WORD PLIC_INTEN00, 0x00000408, write32_test       # enable all m-mode interrupts
WORD PLIC_INTEN10, 0x00000008, write32_test       # enable all s-mode interrupts
WORD UART_MSR, 0x0F, write08_test                 # cause UART interrupt
WORD 0x0, 0x00000800, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000400, read32_test    # interrupt pending for GPIO and UART
WORD PLIC_CLAIM0, 0x0000000A, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD UART_MSR, 0x00000000, write08_test           # clear UART interrupt
WORD PLIC_CLAIM0, 0x0000000A, write32_test        # complete claim made earlier
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt two
WORD 0x0, 0x0, claim_s_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_s_plic_interrupts       # clear interrupt two
WORD PLIC_INTPENDING0, 0x00000000, read32_test   # no interrupts pending

# Test 4.4: GPIO and UART s-mode disabled

WORD PLIC_INTEN00, 0x00000408, write32_test       # enable all m-mode interrupts
WORD PLIC_INTEN10, 0x00000000, write32_test       # enable all s-mode interrupts
WORD UART_MSR, 0x0F, write08_test                 # cause UART interrupt
WORD 0x0, 0x00000800, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000400, read32_test    # interrupt pending for GPIO and UART
WORD PLIC_CLAIM0, 0x0000000A, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD UART_MSR, 0x00000000, write08_test           # clear UART interrupt
WORD PLIC_CLAIM0, 0x0000000A, write32_test        # complete claim made earlier
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt two
WORD 0x0, 0x0, claim_s_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_s_plic_interrupts       # clear interrupt two
WORD PLIC_INTPENDING0, 0x00000000, read32_test   # no interrupts pending

# Test 4.5: GPIO and UART m-mode disabled

WORD PLIC_INTEN00, 0x00000000, write32_test       # disable GPIO interrupts
WORD PLIC_INTEN10, 0x00000408, write32_test       # enable all s-mode interrupts
WORD UART_MSR, 0x0F, write08_test                 # cause UART interrupt
WORD 0x0, 0x00000200, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000400, read32_test    # interrupt pending for GPIO and UART
WORD PLIC_CLAIM0, 0x00000000, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000400, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD UART_MSR, 0x00000000, write08_test           # clear UART interrupt
WORD PLIC_CLAIM0, 0x00000000, write32_test        # complete claim made earlier
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt two
WORD 0x0, 0x0, claim_s_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_s_plic_interrupts       # clear interrupt two
WORD PLIC_INTPENDING0, 0x00000000, read32_test   # no interrupts pending

# Test 4.6: GPIO and UART fully disabled

WORD PLIC_INTEN00, 0x00000000, write32_test       # disable GPIO interrupts
WORD PLIC_INTEN10, 0x00000000, write32_test       # enable all s-mode interrupts
WORD UART_MSR, 0x0F, write08_test                 # cause UART interrupt
WORD 0x0, 0x00000200, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000400, read32_test    # interrupt pending for GPIO and UART
WORD PLIC_CLAIM0, 0x00000000, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000400, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD UART_MSR, 0x00000000, write08_test           # clear UART interrupt
WORD PLIC_CLAIM0, 0x00000000, write32_test        # complete claim made earlier
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt two
WORD 0x0, 0x0, claim_s_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_s_plic_interrupts       # clear interrupt two
WORD PLIC_INTPENDING0, 0x00000000, read32_test   # no interrupts pending

# =========== GPIO interrupt enable tests (5.X) ===========

WORD PLIC_THRESH0, 0x00000000, write32_test       # set m-mode threshold to 0
WORD PLIC_THRESH1, 0x00000000, write32_test       # set s-mode threshold to 0
WORD PLIC_INTPRI_GPIO, 0x00000001, write32_test   # GPIO Priority = 1
WORD PLIC_INTPRI_UART, 0x00000001, write32_test   # UART Priority = 1

# Test 5.0: GPIO m-mode disabled

WORD PLIC_INTEN00, 0x00000400, write32_test       # disable GPIO m-mode interrupts
WORD PLIC_INTEN10, 0x00000408, write32_test       # enable all s-mode interrupts
WORD output_val, 0x00000001, write32_test         # cause rise_ip to go high
WORD 0x0, 0x00000200, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # interrupt pending for GPIO and UART
WORD PLIC_CLAIM0, 0x00000000, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD PLIC_CLAIM0, 0x00000000, write32_test        # complete claim made earlier
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt two
WORD 0x0, 0x0, claim_s_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_s_plic_interrupts       # clear interrupt two
WORD PLIC_INTPENDING0, 0x00000000, read32_test   # no interrupts pending

# Test 5.1: UART m-mode disabled

WORD PLIC_INTEN00, 0x00000008, write32_test       # disable UART m-mode interrupts
WORD PLIC_INTEN10, 0x00000408, write32_test       # enable all s-mode interrupts
WORD output_val, 0x00000001, write32_test         # cause rise_ip to go high
WORD 0x0, 0x00000A00, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # interrupt pending for GPIO and UART
WORD PLIC_CLAIM0, 0x00000003, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD PLIC_CLAIM0, 0x00000003, write32_test        # complete claim made earlier
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt two
WORD 0x0, 0x0, claim_s_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_s_plic_interrupts       # clear interrupt two
WORD PLIC_INTPENDING0, 0x00000000, read32_test   # no interrupts pending

# Test 5.2: GPIO s-mode disabled

WORD PLIC_INTEN00, 0x00000408, write32_test       # enable all m-mode interrupts
WORD PLIC_INTEN10, 0x00000400, write32_test       # enable all s-mode interrupts
WORD output_val, 0x00000001, write32_test         # cause rise_ip to go high
WORD 0x0, 0x00000800, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # interrupt pending for GPIO and UART
WORD PLIC_CLAIM0, 0x00000003, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD PLIC_CLAIM0, 0x00000003, write32_test        # complete claim made earlier
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt two
WORD 0x0, 0x0, claim_s_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_s_plic_interrupts       # clear interrupt two
WORD PLIC_INTPENDING0, 0x00000000, read32_test   # no interrupts pending

# Test 5.3: UART s-mode disabled

WORD PLIC_INTEN00, 0x00000408, write32_test       # enable all m-mode interrupts
WORD PLIC_INTEN10, 0x00000008, write32_test       # enable all s-mode interrupts
WORD output_val, 0x00000001, write32_test         # cause rise_ip to go high
WORD 0x0, 0x00000A00, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # interrupt pending for GPIO and UART
WORD PLIC_CLAIM0, 0x00000003, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD PLIC_CLAIM0, 0x00000003, write32_test        # complete claim made earlier
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt two
WORD 0x0, 0x0, claim_s_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_s_plic_interrupts       # clear interrupt two
WORD PLIC_INTPENDING0, 0x00000000, read32_test   # no interrupts pending

# Test 5.4: GPIO and UART s-mode disabled

WORD PLIC_INTEN00, 0x00000408, write32_test       # enable all m-mode interrupts
WORD PLIC_INTEN10, 0x00000000, write32_test       # enable all s-mode interrupts
WORD output_val, 0x00000001, write32_test         # cause rise_ip to go high
WORD 0x0, 0x00000800, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # interrupt pending for GPIO and UART
WORD PLIC_CLAIM0, 0x00000003, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD PLIC_CLAIM0, 0x00000003, write32_test        # complete claim made earlier
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt two
WORD 0x0, 0x0, claim_s_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_s_plic_interrupts       # clear interrupt two
WORD PLIC_INTPENDING0, 0x00000000, read32_test   # no interrupts pending

# Test 5.5: GPIO and UART m-mode disabled

WORD PLIC_INTEN00, 0x00000000, write32_test       # disable GPIO interrupts
WORD PLIC_INTEN10, 0x00000408, write32_test       # enable all s-mode interrupts
WORD output_val, 0x00000001, write32_test         # cause rise_ip to go high
WORD 0x0, 0x00000200, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # interrupt pending for GPIO and UART
WORD PLIC_CLAIM0, 0x00000000, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # interrupt pending for GPIO and UART
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD PLIC_CLAIM0, 0x00000000, write32_test        # complete claim made earlier
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt two
WORD 0x0, 0x0, claim_s_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_s_plic_interrupts       # clear interrupt two
WORD PLIC_INTPENDING0, 0x00000000, read32_test   # no interrupts pending

# Test 5.6: GPIO and UART fully disabled

WORD PLIC_INTEN00, 0x00000000, write32_test       # disable GPIO interrupts
WORD PLIC_INTEN10, 0x00000000, write32_test       # enable all s-mode interrupts
WORD output_val, 0x00000001, write32_test         # cause rise_ip to go high
WORD 0x0, 0x00000000, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # interrupt pending for GPIO and UART
WORD PLIC_CLAIM0, 0x00000000, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # interrupt pending for GPIO and UART
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD PLIC_CLAIM0, 0x00000000, write32_test        # complete claim made earlier
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_m_plic_interrupts       # clear interrupt two
WORD 0x0, 0x0, claim_s_plic_interrupts       # clear interrupt one
WORD 0x0, 0x0, claim_s_plic_interrupts       # clear interrupt two
WORD PLIC_INTPENDING0, 0x00000000, read32_test   # no interrupts pending

# =========== S-mode enable tests (7.X) ===========

WORD 0x0, 0x222, write_mideleg                    # delegate supervisor interrupts to S mode
WORD 0x0, 0x0, goto_s_mode                        # go to s-mode. 0xb written to output
WORD PLIC_THRESH0, 0x00000000, write32_test       # set m-mode threshold to 0
WORD PLIC_THRESH1, 0x00000000, write32_test       # set s-mode threshold to 0
WORD PLIC_INTPRI_GPIO, 0x00000001, write32_test   # GPIO Priority = 1
WORD PLIC_INTPRI_UART, 0x00000001, write32_test   # UART Priority = 1

# Test 7.0: GPIO m-mode disabled

WORD PLIC_INTEN00, 0x00000400, write32_test       # disable GPIO m-mode interrupts
WORD PLIC_INTEN10, 0x00000408, write32_test       # enable all s-mode interrupts
WORD output_val, 0x00000001, write32_test         # cause rise_ip to go high
WORD UART_MSR, 0x0F, write08_test                 # cause UART interrupt
WORD 0x0, 0x00000200, readsip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000408, read32_test    # interrupt pending for GPIO and UART
WORD PLIC_CLAIM1, 0x00000003, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000400, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD UART_MSR, 0x00000000, write08_test           # clear UART interrupt
WORD PLIC_CLAIM1, 0x00000003, write32_test        # complete claim made earlier
WORD 0x0, 0x00000000, claim_s_plic_interrupts     # clear interrupt one
WORD 0x0, 0x00000000, claim_s_plic_interrupts     # clear interrupt two
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # no interrupts pending

# Test 7.1: UART m-mode disabled

WORD PLIC_INTEN00, 0x00000008, write32_test       # disable UART m-mode interrupts
WORD PLIC_INTEN10, 0x00000408, write32_test       # enable all s-mode interrupts
WORD output_val, 0x00000001, write32_test         # cause rise_ip to go high
WORD UART_MSR, 0x0F, write08_test                 # cause UART interrupt
WORD 0x0, 0x00000200, readsip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000408, read32_test    # interrupt pending for GPIO and UART
WORD PLIC_CLAIM1, 0x00000003, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000400, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD UART_MSR, 0x00000000, write08_test           # clear UART interrupt
WORD PLIC_CLAIM1, 0x00000003, write32_test        # complete claim made earlier
WORD 0x0, 0x00000000, claim_s_plic_interrupts     # clear interrupt one
WORD 0x0, 0x00000000, claim_s_plic_interrupts     # clear interrupt two
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # no interrupts pending

# Test 7.2: GPIO s-mode disabled

WORD PLIC_INTEN00, 0x00000408, write32_test       # enable all m-mode interrupts
WORD PLIC_INTEN10, 0x00000400, write32_test       # enable all s-mode interrupts
WORD output_val, 0x00000001, write32_test         # cause rise_ip to go high
WORD UART_MSR, 0x0F, write08_test                 # cause UART interrupt
WORD 0x0, 0x00000200, readsip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000408, read32_test    # interrupt pending for GPIO and UART
WORD PLIC_CLAIM1, 0x0000000A, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD UART_MSR, 0x00000000, write08_test           # clear UART interrupt
WORD PLIC_CLAIM1, 0x0000000A, write32_test        # complete claim made earlier
WORD 0x0, 0x00000000, claim_s_plic_interrupts     # clear interrupt one
WORD 0x0, 0x00000000, claim_s_plic_interrupts     # clear interrupt two
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # no interrupts pending

# Test 7.3: UART s-mode disabled

WORD PLIC_INTEN00, 0x00000408, write32_test       # enable all m-mode interrupts
WORD PLIC_INTEN10, 0x00000008, write32_test       # enable all s-mode interrupts
WORD output_val, 0x00000001, write32_test         # cause rise_ip to go high
WORD UART_MSR, 0x0F, write08_test                 # cause UART interrupt
WORD 0x0, 0x00000200, readsip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000408, read32_test    # interrupt pending for GPIO and UART
WORD PLIC_CLAIM1, 0x00000003, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000400, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD UART_MSR, 0x00000000, write08_test           # clear UART interrupt
WORD PLIC_CLAIM1, 0x00000003, write32_test        # complete claim made earlier
WORD 0x0, 0x00000000, claim_s_plic_interrupts     # clear interrupt one
WORD 0x0, 0x00000000, claim_s_plic_interrupts     # clear interrupt two
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # no interrupts pending

# Test 7.4: GPIO and UART s-mode disabled

WORD PLIC_INTEN00, 0x00000408, write32_test       # enable all m-mode interrupts
WORD PLIC_INTEN10, 0x00000000, write32_test       # enable all s-mode interrupts
WORD output_val, 0x00000001, write32_test         # cause rise_ip to go high
WORD UART_MSR, 0x0F, write08_test                 # cause UART interrupt
WORD 0x0, 0x00000000, readsip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000408, read32_test    # interrupt pending for GPIO and UART
WORD PLIC_CLAIM1, 0x00000000, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000408, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD UART_MSR, 0x00000000, write08_test           # clear UART interrupt
WORD PLIC_CLAIM1, 0x00000000, write32_test        # complete claim made earlier
WORD 0x0, 0x00000000, claim_s_plic_interrupts     # clear interrupt one
WORD 0x0, 0x00000000, claim_s_plic_interrupts     # clear interrupt two
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # no interrupts pending

# Test 7.5: GPIO and UART m-mode disabled

WORD PLIC_INTEN00, 0x00000000, write32_test       # disable GPIO interrupts
WORD PLIC_INTEN10, 0x00000408, write32_test       # enable all s-mode interrupts
WORD output_val, 0x00000001, write32_test         # cause rise_ip to go high
WORD UART_MSR, 0x0F, write08_test                 # cause UART interrupt
WORD 0x0, 0x00000200, readsip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000408, read32_test    # interrupt pending for GPIO and UART
WORD PLIC_CLAIM1, 0x00000003, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000400, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD UART_MSR, 0x00000000, write08_test           # clear UART interrupt
WORD PLIC_CLAIM1, 0x00000003, write32_test        # complete claim made earlier
WORD 0x0, 0x00000000, claim_s_plic_interrupts     # clear interrupt one
WORD 0x0, 0x00000000, claim_s_plic_interrupts     # clear interrupt two
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # no interrupts pending

# Test 7.6: GPIO and UART fully disabled

WORD PLIC_INTEN00, 0x00000000, write32_test       # disable GPIO interrupts
WORD PLIC_INTEN10, 0x00000000, write32_test       # enable all s-mode interrupts
WORD output_val, 0x00000001, write32_test         # cause rise_ip to go high
WORD UART_MSR, 0x0F, write08_test                 # cause UART interrupt
WORD 0x0, 0x00000000, readsip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000408, read32_test    # interrupt pending for GPIO and UART
WORD PLIC_CLAIM1, 0x00000000, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000408, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD UART_MSR, 0x00000000, write08_test           # clear UART interrupt
WORD PLIC_CLAIM1, 0x00000000, write32_test        # complete claim made earlier
WORD 0x0, 0x00000000, claim_s_plic_interrupts     # clear interrupt one
WORD 0x0, 0x00000000, claim_s_plic_interrupts     # clear interrupt two
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # no interrupts pending

# =========== Special claim tests (8) ===========

WORD 0x0, 0x0, goto_m_mode                        # write 0x9 to output

WORD PLIC_INTPRI_GPIO, 0x00000006, write32_test   # GPIO Priority = 6
WORD PLIC_INTPRI_UART, 0x00000007, write32_test   # UART Priority = 7
WORD PLIC_INTEN00, 0x00000408, write32_test       # enable all m-mode interrupts
WORD PLIC_INTEN10, 0x00000000, write32_test       # enable all s-mode interrupts
WORD PLIC_THRESH0, 0x00000005, write32_test       # set m-mode threshold to 5

# Test 8

WORD output_val, 0x00000001, write32_test         # cause rise_ip to go high
WORD UART_MSR, 0x0F, write08_test                 # cause UART interrupt
WORD 0x0, 0x00000800, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000408, read32_test    # read interrupt pending
WORD PLIC_CLAIM0, 0x0000000A, read32_test         # claim UART
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # UART interrupt cleared
WORD PLIC_CLAIM0, 0x00000003, read32_test         # claim GPIO
WORD 0x0, 0x00000000, readmip_test                # no interrupts, meip is low
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # both interrupts claimed
WORD PLIC_CLAIM0, 0x00000003, write32_test        # complete GPIO
WORD 0x0, 0x00000800, readmip_test                # GPIO interrupt sets MEIP
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # GPIO bit is set
WORD PLIC_CLAIM0, 0x00000003, read32_test         # claim GPIO again
WORD 0x0, 0x00000000, readmip_test                # meip is zeroed
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # both interrupts claimed
WORD PLIC_CLAIM0, 0x0000000A, write32_test        # complete UART claim
WORD 0x0, 0x00000800, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000400, read32_test    # UART pending
WORD PLIC_CLAIM0, 0x00000003, write32_test        # complete GPIO claim
WORD 0x0, 0x00000800, readmip_test                # read mip
WORD PLIC_INTPENDING0, 0x00000408, read32_test    # GPIO and UART pending
WORD PLIC_CLAIM0, 0x0000000A, read32_test         # claim UART

WORD 0x0, 0x0, terminate_test # terminate tests

// ---------------------------------------------------------------------------------------------
// Expected signature
//
//   One entry per signature write, in order (XLEN bits each; SEXT32 marks values that are sign extended on RV64).  SIG_NEXT in WALLY-TEST-LIB.h checks each
//   entry as soon as it is written; a mismatch halts the test and reports the entry index below.
// ---------------------------------------------------------------------------------------------

.align REGSHIFT
expected_signature:
WORD 0x00000000 // 0: read empty MIP (1.0.0)
WORD 0x00000008 // 1: check GPIO interrupt pending on intPending0
WORD 0x00000000 // 2: Claim gives no interrupt due to zero priority
WORD 0x00000008 // 3: interrupt still pending due to no claim
WORD 0x00000000 // 4: check no interrupts pending
WORD 0x00000800 // 5: MEIP set due to PLIC priority (1.0.1)
WORD 0x00000008 // 6: check GPIO interrupt pending on intPending0
WORD 0x00000003 // 7: claim gives 3 for ID of GPIO
WORD 0x00000000 // 8: check no interrupts pending
WORD 0x00000000 // 9: check no interrupts pending
WORD 0x00000000 // 10: read empty MIP (1.0.2)
WORD 0x00000000 // 11: check GPIO interrupt pending on intPending0
WORD 0x00000000 // 12: claim gives no interrupt due to no intPending
WORD 0x00000000 // 13: no interrupts pending after clear
WORD 0x00000000 // 14: still no interrupts after clear
WORD 0x00000000 // 15: read empty MIP (1.1.0)
WORD 0x00000008 // 16: check GPIO interrupt pending on intPending0
WORD 0x00000003 // 17: Claim gives 3 for ID of GPIO
WORD 0x00000000 // 18: interrupt still pending due to no claim
WORD 0x00000000 // 19: check no interrupts pending
WORD 0x00000800 // 20: MEIP set due to PLIC priority (1.1.1)
WORD 0x00000008 // 21: check GPIO interrupt pending on intPending0
WORD 0x00000003 // 22: claim gives 3 for ID of GPIO
WORD 0x00000000 // 23: check no interrupts pending after claim
WORD 0x00000000 // 24: check no interrupts pending
WORD 0x00000000 // 25: read empty MIP (1.2.0)
WORD 0x00000008 // 26: check GPIO interrupt pending on intPending0
WORD 0x00000003 // 27: Claim gives 3 for ID of GPIO
WORD 0x00000000 // 28: check no interrupts pending after claim
WORD 0x00000000 // 29: check no interrupts pending
WORD 0x00000800 // 30: MEIP set due to PLIC priority (1.2.1)
WORD 0x00000008 // 31: check GPIO interrupt pending on intPending0
WORD 0x00000003 // 32: claim gives 3 for ID of GPIO
WORD 0x00000000 // 33: check no interrupts pending after claim
WORD 0x00000000 // 34: check no interrupts pending
WORD 0x00000000 // 35: read empty MIP (1.3.0)
WORD 0x00000008 // 36: check GPIO interrupt pending on intPending0
WORD 0x00000003 // 37: Claim gives 3 for ID of GPIO
WORD 0x00000000 // 38: check no interrupts pending after claim
WORD 0x00000000 // 39: check no interrupts pending
WORD 0x00000800 // 40: MEIP set due to PLIC priority (1.3.1)
WORD 0x00000008 // 41: check GPIO interrupt pending on intPending0
WORD 0x00000003 // 42: claim gives 3 for ID of GPIO
WORD 0x00000000 // 43: check no interrupts pending after claim
WORD 0x00000000 // 44: check no interrupts pending
WORD 0x00000000 // 45: read empty MIP (1.4.0)
WORD 0x00000008 // 46: check GPIO interrupt pending on intPending0
WORD 0x00000003 // 47: Claim gives 3 for ID of GPIO
WORD 0x00000000 // 48: check no interrupts pending after claim
WORD 0x00000000 // 49: check no interrupts pending
WORD 0x00000800 // 50: MEIP set due to PLIC priority (1.4.1)
WORD 0x00000008 // 51: check GPIO interrupt pending on intPending0
WORD 0x00000003 // 52: claim gives 3 for ID of GPIO
WORD 0x00000000 // 53: check no interrupts pending after claim
WORD 0x00000000 // 54: check no interrupts pending
WORD 0x00000000 // 55: read empty MIP (1.5.0)
WORD 0x00000008 // 56: check GPIO interrupt pending on intPending0
WORD 0x00000003 // 57: Claim gives 3 for ID of GPIO
WORD 0x00000000 // 58: check no interrupts pending after claim
WORD 0x00000000 // 59: check no interrupts pending
WORD 0x00000800 // 60: MEIP set due to PLIC priority (1.5.1)
WORD 0x00000008 // 61: check GPIO interrupt pending on intPending0
WORD 0x00000003 // 62: claim gives 3 for ID of GPIO
WORD 0x00000000 // 63: check no interrupts pending after claim
WORD 0x00000000 // 64: check no interrupts pending
WORD 0x00000000 // 65: read empty MIP (1.6.0)
WORD 0x00000008 // 66: check GPIO interrupt pending on intPending0
WORD 0x00000003 // 67: Claim gives 3 for ID of GPIO
WORD 0x00000000 // 68: check no interrupts pending after claim
WORD 0x00000000 // 69: check no interrupts pending
WORD 0x00000800 // 70: MEIP set due to PLIC priority (1.6.1)
WORD 0x00000008 // 71: check GPIO interrupt pending on intPending0
WORD 0x00000003 // 72: claim gives 3 for ID of GPIO
WORD 0x00000000 // 73: check no interrupts pending after claim
WORD 0x00000000 // 74: check no interrupts pending
WORD 0x00000000 // 75: read empty MIP (1.7.0)
WORD 0x00000008 // 76: check GPIO interrupt pending on intPending0
WORD 0x00000003 // 77: Claim gives 3 for ID of GPIO
WORD 0x00000000 // 78: check no interrupts pending after claim
WORD 0x00000000 // 79: check no interrupts pending
WORD 0x00000800 // 80: MEIP set (2.0)
WORD 0x00000408 // 81: gpio and uart pending
WORD 0x00000003 // 82: claim gpio
WORD 0x00000400 // 83: gpio no longer pending
WORD 0x00000000 // 84: no interrupts pending
WORD 0x00000800 // 85: MEIP set (2.1)
WORD 0x00000408 // 86: gpio and uart pending
WORD 0x00000003 // 87: claim gpio
WORD 0x00000400 // 88: gpio no longer pending
WORD 0x00000000 // 89: no interrupts pending
WORD 0x00000800 // 90: MEIP set (2.2)
WORD 0x00000408 // 91: gpio and uart pending
WORD 0x0000000A // 92: claim uart
WORD 0x00000008 // 93: uart no longer pending
WORD 0x00000000 // 94: no interrupts pending
WORD 0x00000800 // 95: MEIP set (2.3)
WORD 0x00000408 // 96: gpio and uart pending
WORD 0x0000000A // 97: claim uart
WORD 0x00000008 // 98: uart no longer pending
WORD 0x00000000 // 99: no interrupts pending
WORD 0x00000000 // 100: MEIP empty (2.4)
WORD 0x00000408 // 101: gpio and uart pending
WORD 0x0000000A // 102: claim none
WORD 0x00000008 // 103: gpio and uart still pending
WORD 0x00000000 // 104: no interrupts pending
WORD 0x00000A00 // 105: MEIP and SEIP set (3.0)
WORD 0x00000408 // 106: check GPIO and UART interrupt pending on intPending0
WORD 0x00000003 // 107: claim gives 3 for ID of GPIO
WORD 0x00000400 // 108: check GPIO interrupt pending cleared after claim
WORD 0x00000000 // 109: check no interrupts pending
WORD 0x00000200 // 110: SEIP set (3.1)
WORD 0x00000408 // 111: check GPIO and UART interrupt pending on intPending0
WORD 0x00000003 // 112: claim gives 3 for ID of GPIO
WORD 0x00000400 // 113: check GPIO interrupt pending cleared after claim
WORD 0x00000000 // 114: check no interrupts pending
WORD 0x00000200 // 115: SEIP set (3.2)
WORD 0x00000408 // 116: check GPIO and UART interrupt pending on intPending0
WORD 0x0000000A // 117: claim UART
WORD 0x00000008 // 118: GPIO interrupt pending after UART claimcomp
WORD 0x00000000 // 119: check no interrupts pending
WORD 0x00000000 // 120: read empty MIP (3.3)
WORD 0x00000408 // 121: check GPIO and UART interrupt pending on intPending0
WORD 0x0000000A // 122: claim UART
WORD 0x00000008 // 123: check UART interrupt pending cleared after claim
WORD 0x00000000 // 124: check no interrupts pending
WORD 0x00000A00 // 125: MEIP and SEIP set (4.0)
WORD 0x00000400 // 126: UART interrupt pending
WORD 0x0000000A // 127: claim UART
WORD 0x00000000 // 128: check no interrupts pending
WORD 0x00000000 // 129: check no interrupts pending
WORD 0x00000200 // 130: SEIP set (4.1)
WORD 0x00000400 // 131: UART interrupt pending
WORD 0x00000000 // 132: nothing in claim register
WORD 0x00000400 // 133: UART interrupt pending
WORD 0x00000000 // 134: check no interrupts pending
WORD 0x00000A00 // 135: MEIP and SEIP set (4.2)
WORD 0x00000400 // 136: UART interrupt pending
WORD 0x0000000A // 137: claim UART
WORD 0x00000000 // 138: check no interrupts pending
WORD 0x00000000 // 139: check no interrupts pending
WORD 0x00000800 // 140: MEIP set (4.3)
WORD 0x00000400 // 141: UART interrupt pending
WORD 0x0000000A // 142: claim UART
WORD 0x00000000 // 143: check no interrupts pending
WORD 0x00000000 // 144: check no interrupts pending
WORD 0x00000800 // 145: MEIP set (4.4)
WORD 0x00000400 // 146: UART interrupt pending
WORD 0x0000000A // 147: claim UART
WORD 0x00000000 // 148: check no interrupts pending
WORD 0x00000000 // 149: check no interrupts pending
WORD 0x00000200 // 150: SEIP set (4.5)
WORD 0x00000400 // 151: UART interrupt pending
WORD 0x00000000 // 152: nothing in claim register
WORD 0x00000400 // 153: UART interrupt pending
WORD 0x00000000 // 154: check no interrupts pending
WORD 0x00000000 // 155: All disabled (4.6)
WORD 0x00000400 // 156: UART interrupt pending
WORD 0x00000000 // 157: nothing in claim register
WORD 0x00000400 // 158: UART interrupt pending
WORD 0x00000000 // 159: check no interrupts pending
WORD 0x00000200 // 160: SEIP set (5.0)
WORD 0x00000008 // 161: GPIO interrupt pending
WORD 0x00000000 // 162: nothing in claim register
WORD 0x00000008 // 163: GPIO interrupt pending
WORD 0x00000000 // 164: check no interrupts pending
WORD 0x00000A00 // 165: MEIP and SEIP set (5.1)
WORD 0x00000008 // 166: GPIO interrupt pending
WORD 0x00000003 // 167: claim gives 3 for ID of GPIO
WORD 0x00000000 // 168: check no interrupts pending
WORD 0x00000000 // 169: check no interrupts pending
WORD 0x00000800 // 170: MEIP set (5.2)
WORD 0x00000008 // 171: GPIO interrupt pending
WORD 0x00000003 // 172: claim gives 3 for ID of GPIO
WORD 0x00000000 // 173: check no interrupts pending
WORD 0x00000000 // 174: check no interrupts pending
WORD 0x00000A00 // 175: MEIP and SEIP set (5.3)
WORD 0x00000008 // 176: GPIO interrupt pending
WORD 0x00000003 // 177: claim gives 3 for ID of GPIO
WORD 0x00000000 // 178: check no interrupts pending
WORD 0x00000000 // 179: check no interrupts pending
WORD 0x00000800 // 180: MEIP set (5.4)
WORD 0x00000008 // 181: GPIO interrupt pending
WORD 0x00000003 // 182: claim gives 3 for ID of GPIO
WORD 0x00000000 // 183: check no interrupts pending
WORD 0x00000000 // 184: check no interrupts pending
WORD 0x00000200 // 185: SEIP set (5.5)
WORD 0x00000008 // 186: GPIO interrupt pending
WORD 0x00000000 // 187: nothing in claim register
WORD 0x00000008 // 188: GPIO interrupt pending
WORD 0x00000000 // 189: check no interrupts pending
WORD 0x00000000 // 190: read empty MIP (5.6)
WORD 0x00000008 // 191: GPIO interrupt pending
WORD 0x00000000 // 192: nothing in claim register
WORD 0x00000008 // 193: GPIO interrupt pending
WORD 0x00000000 // 194: check no interrupts pending
WORD 0x0000000B // 195: written due to goto_s_mode
WORD 0x00000200 // 196: read sip (7.0)
WORD 0x00000408 // 197: check GPIO and UART interrupt pending on intPending0
WORD 0x00000003 // 198: claim gives 3 for ID of GPIO
WORD 0x00000400 // 199: check GPIO interrupt pending cleared after claim
WORD 0x00000000 // 200: check no interrupts pending
WORD 0x00000200 // 201: read sip (7.1)
WORD 0x00000408 // 202: check GPIO and UART interrupt pending on intPending0
WORD 0x00000003 // 203: claim gives 3 for ID of GPIO
WORD 0x00000400 // 204: check GPIO interrupt pending cleared after claim
WORD 0x00000000 // 205: check no interrupts pending
WORD 0x00000200 // 206: read sip (7.2)
WORD 0x00000408 // 207: check GPIO and UART interrupt pending on intPending0
WORD 0x0000000A // 208: claim UART
WORD 0x00000008 // 209: GPIO interrupt pending after UART claimcomp
WORD 0x00000000 // 210: check no interrupts pending
WORD 0x00000200 // 211: read sip (7.3)
WORD 0x00000408 // 212: check GPIO and UART interrupt pending on intPending0
WORD 0x00000003 // 213: claim gives 3 for ID of GPIO
WORD 0x00000400 // 214: check GPIO interrupt pending cleared after claim
WORD 0x00000000 // 215: check no interrupts pending
WORD 0x00000000 // 216: read sip (7.4)
WORD 0x00000408 // 217: check GPIO and UART interrupt pending on intPending0
WORD 0x00000000 // 218: nothing in claim register
WORD 0x00000408 // 219: check GPIO and UART interrupt pending on intPending0
WORD 0x00000000 // 220: check no interrupts pending
WORD 0x00000200 // 221: read sip (7.5)
WORD 0x00000408 // 222: check GPIO and UART interrupt pending on intPending0
WORD 0x00000003 // 223: claim gives 3 for ID of GPIO
WORD 0x00000400 // 224: check GPIO interrupt pending cleared after claim
WORD 0x00000000 // 225: check no interrupts pending
WORD 0x00000000 // 226: read sip (7.6)
WORD 0x00000408 // 227: check GPIO and UART interrupt pending on intPending0
WORD 0x00000000 // 228: nothing in claim register
WORD 0x00000408 // 229: check GPIO and UART interrupt pending on intPending0
WORD 0x00000000 // 230: check no interrupts pending
WORD 0x00000009 // 231: output from ecall in supervisor mode
WORD 0x00000800 // 232: MEIP set (8.0)
WORD 0x00000408 // 233: check GPIO and UART interrupt pending on intPending0
WORD 0x0000000A // 234: claim UART
WORD 0x00000008 // 235: GPIO interrupt pending after UART claimcomp
WORD 0x00000003 // 236: claim gives 3 for ID of GPIO
WORD 0x00000000 // 237: read empty MIP                # no interrupts, meip is low
WORD 0x00000000 // 238: check no interrupts pending
WORD 0x00000800 // 239: MEIP set
WORD 0x00000008 // 240: GPIO interrupt pending after complete
WORD 0x00000003 // 241: claim gives 3 for ID of GPIO
WORD 0x00000000 // 242: read empty MIP                # meip is zeroed
WORD 0x00000000 // 243: check no interrupts pending
WORD 0x00000800 // 244: MEIP set
WORD 0x00000400 // 245: check GPIO interrupt pending cleared after claim
WORD 0x00000800 // 246: MEIP set
WORD 0x00000408 // 247: check GPIO and UART interrupt pending on intPending0
WORD 0x0000000A // 248: claim UART
WORD 0x0000000B // 249: ecall from test termination in M mode
expected_signature_end:
