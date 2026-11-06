///////////////////////////////////////////
//
// WALLY-pwm
//
// Author: Naiche Whyte-Aguayo naichewa@gmail.com>
//
// Created 2026-05-06
//
// Tests PWM peripheral by counting number of periods for a given configuration and comparing to expected reference number
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

.equ PWM, 0x10020000
.equ PWMConfig,  (PWM+0x00)
.equ PWMCount,   (PWM+0x08)
.equ PWMScaled,  (PWM+0x10)
.equ PWMCompare0, (PWM+0x020)
.equ PWMCompare1, (PWM+0x024)
.equ PWMCompare2, (PWM+0x028)
.equ PWMCompare3, (PWM+0x02C)

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


# =========== Verify correct registers reset to zero ===========

WORD PWMConfig, 0x00000000, read32_test       # PWMConfig register reset to all 0s
WORD PWMCount, 0x00000000, read32_test        # PWMCount register reset to all 0s
WORD PWMScaled, 0x00000000, read32_test       # PWMCount register reset to all 0s
WORD PWMCompare0, 0x0000FFFF, read32_test     # PWMCompare registers reset to all high to avoid high comps on reset
WORD PWMCompare1, 0x0000FFFF, read32_test
WORD PWMCompare2, 0x0000FFFF, read32_test
WORD PWMCompare3, 0x0000FFFF, read32_test

# =========== Setting up GPIO

WORD iof_en, 0x0000000F, write32_test         # turn on the iof_en for GPIO 0-3, selecting PWM outs
WORD input_en, 0x00000001, write32_test       # turn on gpio input pin 0
WORD output_en, 0x00000001, write32_test      # turn on gpio output pin 0

#============ Write PWMS test ==================
WORD PWMConfig, 0x00000206, write32_test
WORD PWMCompare0, 0x00000003, write32_test
WORD PWMConfig, 0x00001206, write32_test      # set PWMEnAlways to 1 to start cycle
WORD PWMScaled, 0x00000001, write32_test      # write PWMScaled, should also write to PWMCount
WORD 0x0, 0x00000000, pwm_cycle_wait

#============ ZeroCompare clear test ===========
WORD PWMConfig, 0x00000000, write32_test
WORD PWMCompare0, 0x00000800, write32_test
WORD PWMConfig, 0x00001000, write32_test
WORD 0x0, 0x00000000, pwm_cycle_wait_center   # use center wait function to wait FFFF, should be only high 1 time

#============ OneShot test =====================
WORD PWMCompare1, 0x0000FFFF, write32_test
WORD PWMCompare0, 0x00000001, write32_test
WORD PWMConfig, 0x00002206, write32_test      # enable one shot
WORD 0x0, 0x00000002, pwm_cycle_wait          # wait 4 cycles, should be high once

#============ Scale min tests ===
WORD PWMConfig, 0x00000200, write32_test      # initialize config register with ZeroCompare bit set
WORD PWMCompare0, 0x00000001, write32_test    # set Compare0 to 1
WORD PWMConfig, 0x00001206, write32_test      # set PWMEnAlways to 1 to start cycle
WORD 0x0, 0x00000002, pwm_cycle_wait          # wait 4 PWM cycles
WORD PWMCompare0, 0x0000EFFF, write32_test    # set Compare0 to half of full capacity
WORD PWMConfig, 0x00001200, write32_test      # set PWMEnAlways to 1 to start cycle
WORD 0x0, 0x00000000, pwm_cycle_wait          # wait 1 PWM cycle
WORD PWMCompare0, 0x0000FFFE, write32_test    # set Compare0 to max -1
WORD PWMConfig, 0x00001200, write32_test      # set PWMEnAlways to 1 to start cycle
WORD 0x0, 0x00000000, pwm_cycle_wait          # wait 1 PWM cycle
WORD PWMCompare0, 0x0000FFFF, write32_test    # set Compare0 to max
WORD PWMConfig, 0x00001200, write32_test      # set PWMEnAlways to 1 to start cycle
WORD 0x0, 0x00000000, pwm_cycle_wait          # wait 1 PWM cycle

# =========== Scale max tests ================

WORD PWMCompare0, 0x00000001, write32_test    # set Compare0 to 1
WORD PWMConfig, 0x0000120F, write32_test      # set PWMEnAlways to 1 to start cycle with scale set to FFFF
WORD 0x0, 0x00000000, pwm_cycle_wait          # wait 1 PWM cycle

# ========== Right Aligned  tests               # set of right aligned tests, compare to Section 14.9 figure 7 of reference manual
WORD input_en, 0x00000008, write32_test       # turn on gpio input pin 3
WORD output_en, 0x00000008, write32_test      # turn on gpio output pin 3
WORD PWMCompare1, 0x0000FFFF, write32_test
WORD PWMCompare0, 0x00000006, write32_test    # set cycle length to 6
WORD PWMConfig, 0x00000206, write32_test      # initialize config register with ZeroCompare set
WORD PWMCompare3, 0x00000001, write32_test    # Set compare3 to 1
WORD PWMConfig, 0x00001206, write32_test      # set PWMEnalways
WORD 0x0, 0x00000002, pwm_cycle_wait
WORD PWMConfig, 0x00000206, write32_test      # initialize config register with ZeroCompare set
WORD PWMCompare3, 0x00000002, write32_test    # set compare3 to 2
WORD PWMConfig, 0x00001206, write32_test      # set PWMEnalways
WORD 0x0, 0x00000002, pwm_cycle_wait
WORD PWMConfig, 0x00000206, write32_test      # initialize config register with ZeroCompare set
WORD PWMCompare3, 0x00000003, write32_test    # set compare3 to 3
WORD PWMConfig, 0x00001206, write32_test      # set PWMEnalways
WORD 0x0, 0x00000002, pwm_cycle_wait
WORD PWMConfig, 0x00000206, write32_test      # initialize config register with ZeroCompare set
WORD PWMCompare3, 0x00000004, write32_test    # set compare3 to 4
WORD PWMConfig, 0x00001206, write32_test      # set PWMEnalways
WORD 0x0, 0x00000002, pwm_cycle_wait
WORD PWMConfig, 0x00000206, write32_test      # initialize config register with ZeroCompare set
WORD PWMCompare3, 0x00000005, write32_test    # set compare3 to 5
WORD PWMConfig, 0x00001206, write32_test      # set PWMEnalways
WORD 0x0, 0x00000002, pwm_cycle_wait
WORD PWMConfig, 0x00000206, write32_test      # initialize config register with ZeroCompare set
WORD PWMCompare3, 0x00000006, write32_test    # set compare3 to 6
WORD PWMConfig, 0x00001206, write32_test      # set PWMEnalways
WORD 0x0, 0x00000002, pwm_cycle_wait

# ========== Arbitrary ganged tests===========
WORD input_en, 0x00000004, write32_test       # turn on gpio input pin 2
WORD output_en, 0x00000004, write32_test      # turn on gpio output pin 2
WORD PWMConfig, 0x04000206, write32_test      # initialize config register w cmp2 gang, zerocmp
WORD PWMCompare0, 0x00000006, write32_test    # set compare0 (base cycle) to 6
WORD PWMCompare2, 0x00000001, write32_test
WORD PWMCompare3, 0x00000002, write32_test    # compare2 = 1 ganged with compare3 = 2, high at 1 reset at 2
WORD PWMConfig, 0x04001206, write32_test      # set EnAlways
WORD 0x0, 0x00000002, pwm_cycle_wait          # wait 4 cycles
WORD PWMCompare2, 0x00000002, write32_test
WORD PWMCompare3, 0x00000003, write32_test    # high at 2 reset at 3
WORD PWMConfig, 0x04001206, write32_test      # set EnAlways
WORD 0x0, 0x00000002, pwm_cycle_wait          # wait 4 cycles
WORD PWMCompare2, 0x00000002, write32_test
WORD PWMCompare3, 0x00000004, write32_test    # high at 2 reset at 4
WORD PWMConfig, 0x04001206, write32_test      # set EnAlways
WORD 0x0, 0x00000002, pwm_cycle_wait          # wait 4 cycles

# =========== Center Aligned Tests ============
WORD input_en, 0x00000001, write32_test       # turn on gpio. input pin 0
WORD output_en, 0x00000001, write32_test      # turn on gpio output pin 0
WORD PWMConfig, 0x00010000, write32_test      # initialize config register with pwmcmp0center set
WORD PWMCompare0, 0x000000FF, write32_test    # set Compare0 register to FF
WORD PWMCompare1, 0x0000FFFF, write32_test
WORD PWMCompare2, 0x0000FFFF, write32_test
WORD PWMCompare3, 0x0000FFFF, write32_test
WORD PWMConfig, 0x00011000, write32_test      # set PWMEnAlways to 1 w ZeroCompare off - center compare functionality requires counter to reach max value
WORD 0x0, 0x0000000, pwm_cycle_wait_center    # wait 1 PWM cycle
WORD PWMCompare0, 0x00007FFF, write32_test    # set Compare0 to ((2^16)/2) - 1 for the minimum high time
WORD PWMConfig, 0x00011000, write32_test      # set PWMEnOneShot to 1 to start cycle
WORD 0x0, 0x0000000, pwm_cycle_wait_center    # wait 1 PWM cycle
WORD PWMCompare0, 0x00008000, write32_test    # set Compare0 to 8000 to 2^16, never goes high
WORD PWMConfig, 0x00011000, write32_test      # set PWMEnOneShot to 1 to start cycle
WORD 0x0, 0x0000000, pwm_cycle_wait_center    # wait 1 PWM cycle

SETUP_PLIC
# ========== Sticky/Deglitch circuit test ====
WORD PWMConfig, 0x00000300, write32_test      # initialize config register with sticky bit and zerocmp set
WORD PWMCompare0, 0x00000001, write32_test    # set PWMCompare0
WORD PWMConfig, 0x00001100, write32_test      # set PWMEnAlways, ip should insantly be high
WORD PWMCompare0, 0x0000FFFF, write32_test    # set compare register to max, comparator is 0 but sticky should prevent ip from falling
WORD 0x0, 0x00000800, readmip_test            # check that mip is high
WORD 0x0, 0x00000000, pwm_dumb_wait           # wait for 1 cycle
WORD 0x0, 0x00000000, claim_m_plic_interrupts # clear mip interrupt
WORD PWMConfig, 0x00000400, write32_test      # initialize config register with deglitch bit set
WORD PWMCompare0, 0x00000001, write32_test    # set PWMCompare0
WORD PWMConfig, 0x00001400, write32_test      # set PWMEnAlways, ip should insantly be high
WORD PWMCompare0, 0x0000FFFF, write32_test    # set compare register to max, comparator is 0 but deglitch should prevent ip from falling
WORD 0x0, 0x00000800, readmip_test            # check that mip is high
WORD 0x0, 0x00000000, pwm_dumb_wait           # wait for 1 cycle
WORD 0x0, 0x00000000, claim_m_plic_interrupts # clear mip interrupt


# =========== Register widths and readback (counter stopped) ===========
WORD PWMConfig, 0x00000000, write32_test    # stop the counter, pwmscale = 0
WORD PWMCount, 0xFFFFFFFF, write32_test    # pwmcount is 31 bits wide
WORD PWMCount, 0x7FFFFFFF, read32_test    # bit 31 reads as zero
WORD PWMScaled, 0x0000FFFF, read32_test    # pwms is the low 16 bits of pwmcount when pwmscale = 0
WORD PWMCount, 0x12345678, write32_test
WORD PWMCount, 0x12345678, read32_test
WORD PWMScaled, 0x00005678, read32_test
WORD PWMConfig, 0x00000004, write32_test    # pwmscale = 4
WORD PWMScaled, 0x00004567, read32_test    # pwms = pwmcount[19:4]
WORD PWMConfig, 0x0000000F, write32_test    # pwmscale = 15
WORD PWMScaled, 0x00002468, read32_test    # pwms = pwmcount[30:15]
WORD PWMScaled, 0x00001234, write32_test    # writing pwms sets pwmcount = pwms << pwmscale
WORD PWMCount, 0x091A0000, read32_test
WORD PWMScaled, 0x00001234, read32_test
WORD PWMCompare1, 0x00012345, write32_test    # compare registers are 16 bits wide
WORD PWMCompare1, 0x00002345, read32_test
WORD PWMCompare2, 0x0000ABCD, write32_test
WORD PWMCompare2, 0x0000ABCD, read32_test
WORD PWMConfig, 0x0F0F070F, write32_test    # gang, center, deglitch, zerocmp, sticky, and scale bits all set; enables clear
WORD PWMConfig, 0x0F0F070F, read32_test    # all read back
WORD PWMConfig, 0x00F0C8F0, write32_test    # only reserved bits set
WORD PWMConfig, 0x00000000, read32_test    # reserved bits read as zero
WORD PWMCount, 0x00000000, write32_test    # counter back to zero
WORD PWMCompare1, 0x0000FFFF, write32_test
WORD PWMCompare2, 0x0000FFFF, write32_test

# =========== Interrupt pending bits in pwmcfg (PLIC was set up above) ===========
WORD PWMCompare0, 0x00000010, write32_test    # period of 17 counts
WORD PWMCompare1, 0x00000008, write32_test
WORD PWMConfig, 0x00001300, write32_test    # enalways, zerocmp, sticky
WORD 0x0, 0x00000100, pwm_wait    # wait 256 cycles, several periods
WORD 0x0, 0x00000800, readmip_test    # PWM interrupt pending
WORD PWMConfig, 0x30001300, read32_test    # pwmcmp0ip and pwmcmp1ip are set
WORD PWMCompare0, 0x0000FFFF, write32_test    # stop the comparators from firing
WORD PWMCompare1, 0x0000FFFF, write32_test
WORD PWMConfig, 0x00000000, write32_test    # clear sticky, the enables, and the pending bits
WORD PWMConfig, 0x00000000, read32_test    # pending bits cleared
WORD 0x0, 0x00000000, claim_m_plic_interrupts
WORD 0x0, 0x00000000, readmip_test    # interrupt gone
WORD PWMCount, 0x00000000, write32_test

# =========== Timer mode (no pwmzerocmp): interrupt from comparator 1 ===========
WORD PWMCompare1, 0x00000020, write32_test    # pwmcmp1 fires at count 0x20; the counter wraps at 0x10000
WORD PWMConfig, 0x00001100, write32_test    # enalways, sticky
WORD 0x0, 0x00000100, pwm_wait    # wait 256 cycles
WORD 0x0, 0x00000800, readmip_test    # PWM interrupt pending
WORD PWMConfig, 0x20001100, read32_test    # only pwmcmp1ip is set
WORD PWMCompare1, 0x0000FFFF, write32_test
WORD PWMConfig, 0x00000000, write32_test    # clear sticky, the enable, and the pending bit
WORD 0x0, 0x00000000, claim_m_plic_interrupts
WORD 0x0, 0x00000000, readmip_test    # interrupt gone
WORD PWMCount, 0x00000000, write32_test

# =========== Timer mode (no pwmzerocmp): interrupt from comparator 2 ===========
WORD PWMCompare2, 0x00000020, write32_test    # pwmcmp2 fires at count 0x20; the counter wraps at 0x10000
WORD PWMConfig, 0x00001100, write32_test    # enalways, sticky
WORD 0x0, 0x00000100, pwm_wait    # wait 256 cycles
WORD 0x0, 0x00000800, readmip_test    # PWM interrupt pending
WORD PWMConfig, 0x40001100, read32_test    # only pwmcmp2ip is set
WORD PWMCompare2, 0x0000FFFF, write32_test
WORD PWMConfig, 0x00000000, write32_test    # clear sticky, the enable, and the pending bit
WORD 0x0, 0x00000000, claim_m_plic_interrupts
WORD 0x0, 0x00000000, readmip_test    # interrupt gone
WORD PWMCount, 0x00000000, write32_test

# =========== Timer mode (no pwmzerocmp): interrupt from comparator 3 ===========
WORD PWMCompare3, 0x00000020, write32_test    # pwmcmp3 fires at count 0x20; the counter wraps at 0x10000
WORD PWMConfig, 0x00001100, write32_test    # enalways, sticky
WORD 0x0, 0x00000100, pwm_wait    # wait 256 cycles
WORD 0x0, 0x00000800, readmip_test    # PWM interrupt pending
WORD PWMConfig, 0x80001100, read32_test    # only pwmcmp3ip is set
WORD PWMCompare3, 0x0000FFFF, write32_test
WORD PWMConfig, 0x00000000, write32_test    # clear sticky, the enable, and the pending bit
WORD 0x0, 0x00000000, claim_m_plic_interrupts
WORD 0x0, 0x00000000, readmip_test    # interrupt gone
WORD PWMCount, 0x00000000, write32_test

# =========== Deglitch with pwmzerocmp clear: output held until the counter wraps ===========
WORD input_en, 0x00000002, write32_test    # observe pin 1
WORD output_en, 0x00000002, write32_test    # loop the pin back to its input
WORD PWMCompare1, 0x00000010, write32_test    # pwmcmp1 fires at count 0x10
WORD PWMConfig, 0x00001400, write32_test    # enalways, deglitch
WORD 0x0, 0x00000100, pwm_wait    # count is now about 0x100
WORD input_val, 0x00000002, read32_test    # pin 1 high
WORD PWMCompare1, 0x00008000, write32_test    # raise the compare value above the current count
WORD input_val, 0x00000002, read32_test    # deglitch holds the output high
WORD 0x0, 0x00010000, pwm_wait    # past the wrap; the count is again far below 0x8000
WORD input_val, 0x00000000, read32_test    # output released when the counter wrapped
WORD PWMConfig, 0x00000000, write32_test
WORD PWMCount, 0x00000000, write32_test
WORD PWMCompare1, 0x00000010, write32_test    # same sequence without deglitch
WORD PWMConfig, 0x00001000, write32_test    # enalways only
WORD 0x0, 0x00000100, pwm_wait
WORD input_val, 0x00000002, read32_test    # pin 1 high
WORD PWMCompare1, 0x00008000, write32_test
WORD input_val, 0x00000000, read32_test    # without deglitch the output drops immediately
WORD PWMConfig, 0x00000000, write32_test
WORD PWMCompare1, 0x0000FFFF, write32_test
WORD 0x0, 0x00000000, claim_m_plic_interrupts    # clear the interrupt these pulses raised
WORD PWMCount, 0x00000000, write32_test

# =========== Center-aligned mode on comparators 1-3, and with deglitch ===========
WORD input_en, 0x00000002, write32_test    # observe pin 1
WORD output_en, 0x00000002, write32_test    # loop the pin back to its input
WORD PWMCompare1, 0x00007000, write32_test
WORD PWMConfig, 0x00020000, write32_test    # pwmcmp1center
WORD PWMConfig, 0x00021000, write32_test    # enalways
WORD 0x0, 0x00000001, pwm_cycle_wait_center    # two periods: one high interval each
WORD PWMCompare1, 0x0000FFFF, write32_test
WORD input_en, 0x00000004, write32_test    # observe pin 2
WORD output_en, 0x00000004, write32_test    # loop the pin back to its input
WORD PWMCompare2, 0x00007000, write32_test
WORD PWMConfig, 0x00040000, write32_test    # pwmcmp2center
WORD PWMConfig, 0x00041000, write32_test    # enalways
WORD 0x0, 0x00000001, pwm_cycle_wait_center    # two periods: one high interval each
WORD PWMCompare2, 0x0000FFFF, write32_test
WORD input_en, 0x00000008, write32_test    # observe pin 3
WORD output_en, 0x00000008, write32_test    # loop the pin back to its input
WORD PWMCompare3, 0x00007000, write32_test
WORD PWMConfig, 0x00080000, write32_test    # pwmcmp3center
WORD PWMConfig, 0x00081000, write32_test    # enalways
WORD 0x0, 0x00000001, pwm_cycle_wait_center    # two periods: one high interval each
WORD PWMCompare3, 0x0000FFFF, write32_test
WORD input_en, 0x00000001, write32_test    # observe pin 0
WORD output_en, 0x00000001, write32_test    # loop the pin back to its input
WORD PWMCompare0, 0x00007000, write32_test
WORD PWMConfig, 0x00010400, write32_test    # pwmcmp0center, deglitch
WORD PWMConfig, 0x00011400, write32_test    # enalways
WORD 0x0, 0x00000001, pwm_cycle_wait_center    # deglitch in center mode still allows one rise and one fall per period
WORD PWMCompare0, 0x0000FFFF, write32_test
WORD 0x0, 0x00000000, claim_m_plic_interrupts

# =========== Ganging: output levels after the partner comparator has fired (counter wrapping, all pins observed) ===========
WORD input_en, 0x0000000F, write32_test    # observe all four pins
WORD output_en, 0x0000000F, write32_test    # loop the pin back to its input
WORD PWMCompare0, 0x00000020, write32_test
WORD PWMCompare1, 0x00000040, write32_test
WORD PWMCompare2, 0x00000060, write32_test
WORD PWMCompare3, 0x00000080, write32_test
WORD PWMConfig, 0x00001000, write32_test    # enalways, no ganging
WORD 0x0, 0x00000100, pwm_wait    # all four comparators have fired
WORD input_val, 0x0000000F, read32_test    # all four outputs high
WORD PWMConfig, 0x01001000, write32_test    # pwmcmp0gang: pin 0 reset when comparator 1 fires
WORD input_val, 0x0000000E, read32_test
WORD PWMConfig, 0x02001000, write32_test    # pwmcmp1gang
WORD input_val, 0x0000000D, read32_test
WORD PWMConfig, 0x04001000, write32_test    # pwmcmp2gang
WORD input_val, 0x0000000B, read32_test
WORD PWMConfig, 0x08001000, write32_test    # pwmcmp3gang: pin 3 reset when comparator 0 fires
WORD input_val, 0x00000007, read32_test
WORD PWMConfig, 0x0F001000, write32_test    # all ganged
WORD input_val, 0x00000000, read32_test
WORD PWMConfig, 0x00000000, write32_test
WORD PWMCompare0, 0x0000FFFF, write32_test
WORD PWMCompare1, 0x0000FFFF, write32_test
WORD PWMCompare2, 0x0000FFFF, write32_test
WORD PWMCompare3, 0x0000FFFF, write32_test
WORD 0x0, 0x00000000, claim_m_plic_interrupts
WORD PWMCount, 0x00000000, write32_test

# =========== One-shot: pwmenoneshot clears itself, can be replayed, and pwmenalways keeps counting ===========
WORD input_en, 0x00000001, write32_test    # observe pin 0
WORD output_en, 0x00000001, write32_test    # loop the pin back to its input
WORD high_ip, 0xFFFFFFFF, write32_test    # clear high_ip
WORD PWMCompare0, 0x00000100, write32_test    # one cycle is 0x101 counts
WORD PWMConfig, 0x00002200, write32_test    # enoneshot, zerocmp
WORD 0x0, 0x00000400, pwm_wait    # the single cycle completes
WORD PWMConfig, 0x00000200, read32_test    # pwmenoneshot cleared by hardware
WORD PWMCount, 0x00000000, read32_test    # counter reset and stopped
WORD high_ip, 0x00000001, read32_test    # pin 0 pulsed once
WORD high_ip, 0xFFFFFFFF, write32_test    # clear high_ip
WORD PWMConfig, 0x00002200, write32_test    # replay the one-shot
WORD 0x0, 0x00000400, pwm_wait
WORD PWMConfig, 0x00000200, read32_test    # cleared again
WORD high_ip, 0x00000001, read32_test    # pin 0 pulsed again
WORD high_ip, 0xFFFFFFFF, write32_test
WORD PWMConfig, 0x00003200, write32_test    # enalways and enoneshot together
WORD 0x0, 0x00000400, pwm_wait
WORD PWMConfig, 0x00001200, read32_test    # enoneshot cleared, enalways still set
WORD high_ip, 0x00000001, read32_test    # pin 0 pulsing
WORD PWMConfig, 0x00000000, write32_test
WORD PWMCompare0, 0x0000FFFF, write32_test
WORD high_ip, 0xFFFFFFFF, write32_test
WORD 0x0, 0x00000000, claim_m_plic_interrupts
WORD PWMCount, 0x00000000, write32_test

# =========== 100% duty cycle: pwmcmp3 = 0 keeps the output high ===========
WORD input_en, 0x00000008, write32_test    # observe pin 3
WORD output_en, 0x00000008, write32_test    # loop the pin back to its input
WORD PWMCompare0, 0x00000006, write32_test
WORD PWMCompare3, 0x00000000, write32_test
WORD PWMConfig, 0x00000206, write32_test    # zerocmp, scale 6
WORD PWMConfig, 0x00001206, write32_test    # enalways
WORD 0x0, 0x00000002, pwm_cycle_wait    # four periods, but the output never falls: no completed pulse
WORD PWMCompare3, 0x0000FFFF, write32_test

# =========== Timer mode: the pwms carry out resets the counter and ends a one-shot ===========
WORD PWMCount, 0x0000FFF0, write32_test    # start just below the pwms carry out
WORD PWMConfig, 0x00002000, write32_test    # enoneshot, no zerocmp
WORD 0x0, 0x00000100, pwm_wait
WORD PWMCount, 0x00000000, read32_test    # reset by the carry out, and the one-shot stopped it there
WORD PWMConfig, 0x00000000, read32_test    # pwmenoneshot cleared by the carry out
WORD PWMCount, 0x00000000, write32_test

# =========== Pending bits set and cleared by software through pwmcfg, with pwmsticky set ===========
WORD PWMConfig, 0x00000100, write32_test    # sticky, counter stopped
WORD PWMConfig, 0x10000100, write32_test    # set pwmcmp0ip
WORD 0x0, 0x00000800, readmip_test    # interrupt pending
WORD PWMConfig, 0x10000100, read32_test    # pwmcmp0ip reads back
WORD PWMConfig, 0x00000100, write32_test    # clear pwmcmp0ip; sticky only stops the hardware from clearing it
WORD PWMConfig, 0x00000100, read32_test    # cleared
WORD 0x0, 0x00000000, claim_m_plic_interrupts
WORD 0x0, 0x00000000, readmip_test    # interrupt gone
WORD PWMConfig, 0x00000000, write32_test

# =========== Each comparator drives its own PLIC source (FU540 numbering) ===========
# pwmcmp0ip through pwmcmp3ip are PLIC sources 11 through 14.  The claim ID is the only thing that
# distinguishes the four outputs: mip has a single external interrupt bit, and pwmcfg[31:28] reads the
# pending flops inside the PWM, upstream of the PLIC.  Each pending bit is set by software, then cleared
# before the claim so the source does not immediately re-assert.
WORD PWMConfig, 0x00000100, write32_test    # sticky, counter stopped, no pending bits
WORD PWMConfig, 0x10000100, write32_test    # set pwmcmp0ip
WORD PWMConfig, 0x00000100, write32_test    # clear it; the PLIC keeps the source latched
WORD 0x0, 0x0000000B, claim_m_plic_id_test    # comparator 0 is PLIC source 11
WORD 0x0, 0x00000000, readmip_test    # interrupt gone
WORD PWMConfig, 0x20000100, write32_test    # set pwmcmp1ip
WORD PWMConfig, 0x00000100, write32_test
WORD 0x0, 0x0000000C, claim_m_plic_id_test    # comparator 1 is PLIC source 12
WORD 0x0, 0x00000000, readmip_test
WORD PWMConfig, 0x40000100, write32_test    # set pwmcmp2ip
WORD PWMConfig, 0x00000100, write32_test
WORD 0x0, 0x0000000D, claim_m_plic_id_test    # comparator 2 is PLIC source 13
WORD 0x0, 0x00000000, readmip_test
WORD PWMConfig, 0x80000100, write32_test    # set pwmcmp3ip
WORD PWMConfig, 0x00000100, write32_test
WORD 0x0, 0x0000000E, claim_m_plic_id_test    # comparator 3 is PLIC source 14
WORD 0x0, 0x00000000, readmip_test

# =========== Several comparators pending at once ===========
WORD PWMConfig, 0x50000100, write32_test    # set pwmcmp0ip and pwmcmp2ip together
WORD PWMConfig, 0x00000100, write32_test    # clear both; two PLIC sources stay latched
WORD 0x0, 0x00000800, readmip_test    # interrupt pending
WORD 0x0, 0x0000000B, claim_m_plic_id_test    # the lowest numbered source is claimed first
WORD 0x0, 0x00000800, readmip_test    # comparator 2 is still pending
WORD 0x0, 0x0000000D, claim_m_plic_id_test
WORD 0x0, 0x00000000, readmip_test    # both serviced
WORD PWMConfig, 0xF0000100, write32_test    # all four at once
WORD PWMConfig, 0x00000100, write32_test
WORD 0x0, 0x0000000B, claim_m_plic_id_test
WORD 0x0, 0x0000000C, claim_m_plic_id_test
WORD 0x0, 0x0000000D, claim_m_plic_id_test
WORD 0x0, 0x0000000E, claim_m_plic_id_test
WORD 0x0, 0x00000000, readmip_test    # all four serviced, one claim each
WORD PWMConfig, 0x00000000, write32_test

# =========== A centered comparator low at the wrap raises no source of its own ===========
# Comparators 0, 2 and 3 are centered, so they are low when pwms is all ones; comparator 1 is at the
# maximum and fires at the wrap.  A single ORed source reported the PWM interrupt here without saying
# which comparator caused it, so a handler for comparator 0 ran although comparator 0 was low.
WORD PWMCount, 0x00000000, write32_test
WORD PWMCompare0, 0x00004000, write32_test
WORD PWMCompare1, 0x0000FFFF, write32_test    # fires at the wrap
WORD PWMCompare2, 0x00004000, write32_test
WORD PWMCompare3, 0x00004000, write32_test
WORD PWMConfig, 0x000D0000, write32_test    # center on comparators 0, 2 and 3 before the counter is loaded,
                                            # otherwise they are briefly in wrap mode at 0xFFF0 and latch their pending bits
WORD PWMCount, 0x0000FFF0, write32_test    # start just below the pwms carry out
WORD PWMConfig, 0x000D1000, write32_test    # add enalways, no zerocmp
WORD 0x0, 0x00000100, pwm_wait    # run past the wrap
WORD 0x0, 0x00000800, readmip_test    # an interrupt is pending
WORD 0x0, 0x0000000C, claim_m_plic_id_test    # comparator 1 raised it, not the centered comparators
WORD 0x0, 0x00000000, readmip_test    # sources 11, 13 and 14 never fired
WORD PWMConfig, 0x00000000, write32_test

WORD 0x0, 0x0, terminate_test

// ---------------------------------------------------------------------------------------------
// Expected signature
//
//   One entry per signature write, in order (XLEN bits each).  SIG_NEXT in WALLY-TEST-LIB.h checks each
//   entry as soon as it is written; a mismatch halts the test and reports the entry index below.
// ---------------------------------------------------------------------------------------------

.align REGSHIFT
expected_signature:
WORD 0x00000000 // 0: reset tests
WORD 0x00000000 // 1
WORD 0x00000000 // 2
WORD 0x0000FFFF // 3
WORD 0x0000FFFF // 4
WORD 0x0000FFFF // 5
WORD 0x0000FFFF // 6
WORD 0x00000001 // 7: PWMScaled write
WORD 0x00000001 // 8: zerocompare clear
WORD 0x00000001 // 9: one shot en
WORD 0x00000004 // 10: minimmum scale tests
WORD 0x00000001 // 11
WORD 0x00000001 // 12
WORD 0x00000001 // 13
WORD 0x00000001 // 14: max scale tests
WORD 0x00000004 // 15: right aligned tests
WORD 0x00000004 // 16
WORD 0x00000004 // 17
WORD 0x00000004 // 18
WORD 0x00000004 // 19
WORD 0x00000004 // 20
WORD 0x00000004 // 21: arbitrarily ganged tests
WORD 0x00000004 // 22
WORD 0x00000004 // 23
WORD 0x00000001 // 24: centered tests
WORD 0x00000001 // 25
WORD 0x00000000 // 26
WORD 0x00000800 // 27: sticky and deglitch tests
WORD 0x00000800 // 28
WORD 0x7FFFFFFF // 29: bit 31 reads as zero
WORD 0x0000FFFF // 30: pwms is the low 16 bits of pwmcount when pwmscale = 0
WORD 0x12345678 // 31
WORD 0x00005678 // 32
WORD 0x00004567 // 33: pwms = pwmcount[19:4]
WORD 0x00002468 // 34: pwms = pwmcount[30:15]
WORD 0x091A0000 // 35
WORD 0x00001234 // 36
WORD 0x00002345 // 37
WORD 0x0000ABCD // 38
WORD 0x0F0F070F // 39: all read back
WORD 0x00000000 // 40: reserved bits read as zero
WORD 0x00000800 // 41: PWM interrupt pending
WORD 0x30001300 // 42: pwmcmp0ip and pwmcmp1ip are set
WORD 0x00000000 // 43: pending bits cleared
WORD 0x00000000 // 44: interrupt gone
WORD 0x00000800 // 45: PWM interrupt pending
WORD 0x20001100 // 46: only pwmcmp1ip is set
WORD 0x00000000 // 47: interrupt gone
WORD 0x00000800 // 48: PWM interrupt pending
WORD 0x40001100 // 49: only pwmcmp2ip is set
WORD 0x00000000 // 50: interrupt gone
WORD 0x00000800 // 51: PWM interrupt pending
WORD SEXT32(0x80001100) // 52: only pwmcmp3ip is set
WORD 0x00000000 // 53: interrupt gone
WORD 0x00000002 // 54: pin 1 high
WORD 0x00000002 // 55: deglitch holds the output high
WORD 0x00000000 // 56: output released when the counter wrapped
WORD 0x00000002 // 57: pin 1 high
WORD 0x00000000 // 58: without deglitch the output drops immediately
WORD 0x00000002 // 59: two periods: one high interval each
WORD 0x00000002 // 60: two periods: one high interval each
WORD 0x00000002 // 61: two periods: one high interval each
WORD 0x00000002 // 62: deglitch in center mode still allows one rise and one fall per period
WORD 0x0000000F // 63: all four outputs high
WORD 0x0000000E // 64
WORD 0x0000000D // 65
WORD 0x0000000B // 66
WORD 0x00000007 // 67
WORD 0x00000000 // 68
WORD 0x00000200 // 69: pwmenoneshot cleared by hardware
WORD 0x00000000 // 70: counter reset and stopped
WORD 0x00000001 // 71: pin 0 pulsed once
WORD 0x00000200 // 72: cleared again
WORD 0x00000001 // 73: pin 0 pulsed again
WORD 0x00001200 // 74: enoneshot cleared, enalways still set
WORD 0x00000001 // 75: pin 0 pulsing
WORD PWM_STUCK_HIGH // 76: four periods, but the output never falls: no completed pulse
WORD 0x00000000 // 77: counter reset by the pwms carry out, and the one-shot stops it there
WORD 0x00000000 // 78: pwmenoneshot cleared by the carry out
WORD 0x00000800 // 79: interrupt pending from a software-set pwmcmp0ip
WORD 0x10000100 // 80: pwmcmp0ip set by software reads back
WORD 0x00000100 // 81: pwmcmp0ip cleared by software with pwmsticky set
WORD 0x00000000 // 82: interrupt gone
WORD 0x0000000B // 83: comparator 0 is PLIC source 11
WORD 0x00000000 // 84: interrupt gone
WORD 0x0000000C // 85: comparator 1 is PLIC source 12
WORD 0x00000000 // 86
WORD 0x0000000D // 87: comparator 2 is PLIC source 13
WORD 0x00000000 // 88
WORD 0x0000000E // 89: comparator 3 is PLIC source 14
WORD 0x00000000 // 90
WORD 0x00000800 // 91: comparators 0 and 2 pending together
WORD 0x0000000B // 92: lowest numbered source claimed first
WORD 0x00000800 // 93: comparator 2 still pending after the first claim
WORD 0x0000000D // 94: comparator 2
WORD 0x00000000 // 95: both serviced
WORD 0x0000000B // 96: all four pending, one claim each
WORD 0x0000000C // 97
WORD 0x0000000D // 98
WORD 0x0000000E // 99
WORD 0x00000000 // 100: all four serviced
WORD 0x00000800 // 101: the wrap raised an interrupt
WORD 0x0000000C // 102: comparator 1 raised it, not the centered comparators
WORD 0x00000000 // 103: sources 11, 13 and 14 never fired
WORD 0x0000000B // 104: ecall from test termination in M mode
expected_signature_end:
