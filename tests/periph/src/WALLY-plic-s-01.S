///////////////////////////////////////////
//
// WALLY-plic-s
//
// Author: David_Harris@hmc.edu and Nicholas Lucio <nlucio@hmc.edu>
// Test PLIC supervisor context interrupts and claim/complete
//
// Created 2022-07-29
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
.equ PLIC_INTPRI_UART, (PLIC+0x000028)      # UART is interrupt 10
.equ PLIC_INTPENDING0, (PLIC+0x001000)       # intPending0 register
.equ PLIC_INTPENDING1, (PLIC+0x001004)       # intPending0 register
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

# =========== Initialize  GPIO ===========

# GPIO Initialization
WORD input_en, 0x00000001, write32_test   # enable bit 0 of input_en
WORD output_en, 0x00000001, write32_test  # enable bit 0 of output_en
WORD output_val, 0x00000000, write32_test # make sure output_val is 0
WORD rise_ie, 0x00000001, write32_test    # enable rise interrupts

# =========== Initialize relevant PLIC registers ===========

WORD PLIC_INTPRI_UART, 0x00000000, write32_test   # set UART priority to 0 to never interrupt

# =========== Enter Supervisor Mode ===========

WORD 0x0, 0x222, write_mideleg                    # delegate supervisor interrupts to S mode
WORD 0x0, 0x0, goto_s_mode                        # Enter supervisor mode

# =========== Test interrupt enables and priorities ===========

# Case 1.1:
WORD PLIC_INTPRI_GPIO, 0x00000001, write32_test   # GPIOPriority = 1
WORD PLIC_INTEN00, 0x00000008, write32_test       # enable GPIO m-mode interrupts
WORD PLIC_INTEN10, 0x00000008, write32_test       # enable GPIO s-mode interrupts
WORD PLIC_THRESH0, 0x00000000, write32_test       # set m-mode threshold to 0
WORD PLIC_THRESH1, 0x00000000, write32_test       # set s-mode threshold to 0
WORD output_val, 0x00000001, write32_test         # cause rise_ip to go high
WORD 0x0, 0x00000200, readsip_test                # read sip
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # interrupt pending for GPIO
WORD PLIC_CLAIM1, 0x00000003, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD PLIC_CLAIM1, 0x00000003, write32_test        # complete claim made earlier
WORD 0x0, 0x0, claim_s_plic_interrupts            # clear interrupt from PLIC
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # no interrupts pending

# Case 1.2:
WORD PLIC_INTPRI_GPIO, 0x00000001, write32_test   # GPIOPriority = 1
WORD PLIC_INTEN00, 0x00000000, write32_test       # enable GPIO m-mode interrupts
WORD PLIC_INTEN10, 0x00000008, write32_test       # enable GPIO s-mode interrupts
WORD PLIC_THRESH0, 0x00000000, write32_test       # set m-mode threshold to 0
WORD PLIC_THRESH1, 0x00000000, write32_test       # set s-mode threshold to 0
WORD output_val, 0x00000001, write32_test         # cause rise_ip to go high
WORD 0x0, 0x00000200, readsip_test                # read sip
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # interrupt pending for GPIO
WORD PLIC_CLAIM1, 0x00000003, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD PLIC_CLAIM1, 0x00000003, write32_test        # complete claim made earlier
WORD 0x0, 0x0, claim_s_plic_interrupts            # clear interrupt from PLIC
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # no interrupts pending

# Case 1.3:
WORD PLIC_INTPRI_GPIO, 0x00000001, write32_test   # GPIOPriority = 1
WORD PLIC_INTEN00, 0x00000008, write32_test       # enable GPIO m-mode interrupts
WORD PLIC_INTEN10, 0x00000000, write32_test       # enable GPIO s-mode interrupts
WORD PLIC_THRESH0, 0x00000000, write32_test       # set m-mode threshold to 0
WORD PLIC_THRESH1, 0x00000000, write32_test       # set s-mode threshold to 0
WORD output_val, 0x00000001, write32_test         # cause rise_ip to go high
WORD 0x0, 0x00000000, readsip_test                # read sip
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # interrupt pending for GPIO
WORD PLIC_CLAIM1, 0x00000000, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD PLIC_CLAIM1, 0x00000003, write32_test        # complete claim made earlier
WORD 0x0, 0x0, claim_s_plic_interrupts            # clear interrupt from PLIC
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # no interrupts pending

# Case 1.4:
WORD PLIC_INTPRI_GPIO, 0x00000001, write32_test   # GPIOPriority = 1
WORD PLIC_INTEN00, 0x00000000, write32_test       # enable GPIO m-mode interrupts
WORD PLIC_INTEN10, 0x00000000, write32_test       # enable GPIO s-mode interrupts
WORD PLIC_THRESH0, 0x00000000, write32_test       # set m-mode threshold to 0
WORD PLIC_THRESH1, 0x00000000, write32_test       # set s-mode threshold to 0
WORD output_val, 0x00000001, write32_test         # cause rise_ip to go high
WORD 0x0, 0x00000000, readsip_test                # read sip
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # interrupt pending for GPIO
WORD PLIC_CLAIM1, 0x00000000, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD PLIC_CLAIM1, 0x00000003, write32_test        # complete claim made earlier
WORD 0x0, 0x0, claim_s_plic_interrupts            # clear interrupt from PLIC
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # no interrupts pending

# Case 1.5:
WORD PLIC_INTPRI_GPIO, 0x00000001, write32_test   # GPIOPriority = 1
WORD PLIC_INTEN00, 0x00000008, write32_test       # enable GPIO m-mode interrupts
WORD PLIC_INTEN10, 0x00000008, write32_test       # enable GPIO s-mode interrupts
WORD PLIC_THRESH0, 0x00000000, write32_test       # set m-mode threshold to 0
WORD PLIC_THRESH1, 0x00000005, write32_test       # set s-mode threshold to 5
WORD output_val, 0x00000001, write32_test         # cause rise_ip to go high
WORD 0x0, 0x00000000, readsip_test                # read sip
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # interrupt pending for GPIO
WORD PLIC_CLAIM1, 0x00000003, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD PLIC_CLAIM1, 0x00000003, write32_test        # complete claim made earlier
WORD 0x0, 0x0, claim_s_plic_interrupts            # clear interrupt from PLIC
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # no interrupts pending

# Case 1.6:
WORD PLIC_INTPRI_GPIO, 0x00000001, write32_test   # GPIOPriority = 1
WORD PLIC_INTEN00, 0x00000008, write32_test       # enable GPIO m-mode interrupts
WORD PLIC_INTEN10, 0x00000008, write32_test       # enable GPIO s-mode interrupts
WORD PLIC_THRESH0, 0x00000005, write32_test       # set m-mode threshold to 5
WORD PLIC_THRESH1, 0x00000000, write32_test       # set s-mode threshold to 0
WORD output_val, 0x00000001, write32_test         # cause rise_ip to go high
WORD 0x0, 0x00000200, readsip_test                # read sip
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # interrupt pending for GPIO
WORD PLIC_CLAIM1, 0x00000003, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD PLIC_CLAIM1, 0x00000003, write32_test        # complete claim made earlier
WORD 0x0, 0x0, claim_s_plic_interrupts            # clear interrupt from PLIC
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # no interrupts pending

# Case 1.7:
WORD PLIC_INTPRI_GPIO, 0x00000001, write32_test   # GPIOPriority = 1
WORD PLIC_INTEN00, 0x00000008, write32_test       # enable GPIO m-mode interrupts
WORD PLIC_INTEN10, 0x00000008, write32_test       # enable GPIO s-mode interrupts
WORD PLIC_THRESH0, 0x00000005, write32_test       # set m-mode threshold to 5
WORD PLIC_THRESH1, 0x00000005, write32_test       # set s-mode threshold to 5
WORD output_val, 0x00000001, write32_test         # cause rise_ip to go high
WORD 0x0, 0x00000000, readsip_test                # read sip
WORD PLIC_INTPENDING0, 0x00000008, read32_test    # interrupt pending for GPIO
WORD PLIC_CLAIM1, 0x00000003, read32_test         # read claim register
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # interrupt pending cleared for GPIO
WORD output_val, 0x00000000, write32_test         # clear output_val
WORD rise_ip, 0x00000001, write32_test            # clear GPIO interrupt
WORD PLIC_CLAIM1, 0x00000003, write32_test        # complete claim made earlier
WORD 0x0, 0x0, claim_s_plic_interrupts            # clear interrupt from PLIC
WORD PLIC_INTPENDING0, 0x00000000, read32_test    # no interrupts pending

# All done

WORD 0x0, 0x0, terminate_test # terminate tests

// ---------------------------------------------------------------------------------------------
// Expected signature
//
//   One entry per signature write, in order (XLEN bits each; SEXT32 marks values that are sign extended on RV64).  SIG_NEXT in WALLY-TEST-LIB.h checks each
//   entry as soon as it is written; a mismatch halts the test and reports the entry index below.
// ---------------------------------------------------------------------------------------------

.align REGSHIFT
expected_signature:
WORD 0x0000000B // 0: ecall for change to supervisor mode
WORD 0x00000200 // 1: 1.1: read SIP with supervisor interrupt
WORD 0x00000008 // 2: check GPIO interrupt pending on intPending0
WORD 0x00000003 // 3: Claim GPIO in supervisor context
WORD 0x00000000 // 4: No interrupts pending
WORD 0x00000000 // 5: No interrupts pending
WORD 0x00000200 // 6: 1.2: read SIP with supervisor interrupt
WORD 0x00000008 // 7: check GPIO interrupt pending on intPending0
WORD 0x00000003 // 8: Claim GPIO in supervisor context
WORD 0x00000000 // 9: No interrupts pending
WORD 0x00000000 // 10: No interrupts pending
WORD 0x00000000 // 11: 1.3: read SIP with supervisor interrupt
WORD 0x00000008 // 12: check GPIO interrupt pending on intPending0
WORD 0x00000000 // 13: No claim
WORD 0x00000008 // 14: Interrupt unclaimed and still pending
WORD 0x00000000 // 15: No interrupts pending
WORD 0x00000000 // 16: 1.4: read SIP with supervisor interrupt
WORD 0x00000008 // 17: check GPIO interrupt pending on intPending0
WORD 0x00000000 // 18: No claim
WORD 0x00000008 // 19: Interrupt unclaimed and still pending
WORD 0x00000000 // 20: No interrupts pending
WORD 0x00000000 // 21: 1.5: read SIP with supervisor interrupt
WORD 0x00000008 // 22: check GPIO interrupt pending on intPending0
WORD 0x00000003 // 23: Claim GPIO in supervisor context even though it is masked by priority
WORD 0x00000000 // 24: No interrupts pending
WORD 0x00000000 // 25: No interrupts pending
WORD 0x00000200 // 26: 1.6: read SIP with supervisor interrupt
WORD 0x00000008 // 27: check GPIO interrupt pending on intPending0
WORD 0x00000003 // 28: Claim GPIO in supervisor context
WORD 0x00000000 // 29: No interrupts pending
WORD 0x00000000 // 30: No interrupts pending
WORD 0x00000000 // 31: 1.7: read SIP with supervisor interrupt
WORD 0x00000008 // 32: check GPIO interrupt pending on intPending0
WORD 0x00000003 // 33: Glaim GPIO in supervisor conxtex even though it is masked by priority
WORD 0x00000000 // 34: No interrupts pending
WORD 0x00000000 // 35: No interrupts pending
WORD 0x00000009 // 36: ecall from test termination in S mode
expected_signature_end:
