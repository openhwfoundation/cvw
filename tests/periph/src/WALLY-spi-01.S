///////////////////////////////////////////
//
// WALLY-spi
//
// Author: David_Harris@hmc.edu and Naiche Whyte-Aguayo
//
// Created 2023-02-01
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
# ---------------------------------------------------------------------------------------------

.equ SPI, 0x10040000
.equ sck_div, (SPI+0x00)
.equ sck_mode, (SPI+0x04)
.equ cs_id, (SPI+0x10)
.equ cs_def, (SPI+0x14)
.equ cs_mode, (SPI+0x18)
.equ delay0, (SPI+0x28)
.equ delay1, (SPI+0x2C)
.equ fmt, (SPI+0x40)
.equ tx_data, (SPI+0x48)
.equ rx_data, (SPI+0x4C)
.equ tx_mark, (SPI+0x50)
.equ rx_mark, (SPI+0x54)
.equ ie, (SPI+0x70)
.equ ip, (SPI+0x74)

# =========== Verify all registers reset to correct values ===========

WORD sck_div, 0x00000003, read32_test     # sck_div reset to 0x3
WORD sck_mode, 0x00000000, read32_test    # sck_mode reset to 0x0
WORD cs_id, 0x00000000, read32_test       # cs_id reset to 0x0
WORD cs_def, 0x0000000F, read32_test      # cs_def reset to 0x1
WORD cs_mode, 0x00000000, read32_test     # cs_mode reset to 0x0
WORD delay0, 0x00010001, read32_test      # delay0 reset to [31:24] 0x0, [23:16] 0x1, [15:8] 0x0, [7:0] 0x1
WORD delay1, 0x00000001, read32_test      # delay1 reset to 0x1
WORD fmt, 0x00080000, read32_test         # fmt reset to [31:20] 0x0, [19:16] 0x8, [15:0] 0x0 for non-flash enabled SPI controllers
WORD tx_data, 0x00000000, read32_test     # tx_data [30:0] reset to 0x0, [31] read only
WORD tx_mark, 0x00000000, read32_test     # tx_mark reset to 0x0 for non-flash enabled controllers
WORD rx_mark, 0x00000000, read32_test     # rx_mark reset to 0x0
WORD ie, 0x00000000, read32_test          # ie reset to 0x0
WORD ip, 0x00000000, read32_test          # ip reset to 0x0

# =========== watermark interrupts ===============

#test watermark interrupts at beginning where fifo read/write pointers are known b/c reset
# txwmp raised when # of entries in txfifo < txmark, rxwm raised when # of entries in rxfifo > rxmark

WORD ip, 0x00000000, read32_test          # txfifo entries not < 0, rxfifo entries not > 0;
WORD tx_mark, 0x00000004, write32_test    # set tx_mark to 4
WORD rx_mark, 0x00000003, write32_test    # set rx_mark to 3
WORD ip, 0x00000001, read32_test          # tx entries < 4, rx entries ! > 3
WORD tx_data, 0x41526374, spi_burst_send
WORD 0x0, 0x00000003, spi_data_wait
WORD ip, 0x00000003, read32_test          # tx entries < 4, rx entries > 3, visual inspection should see tx TransmitFIFOReadIncrement

# txfifo wptr now at 0011, rxfifo wptr at 0000

WORD rx_mark, 0x00000007, write32_test    # set rx_mark to 7
WORD tx_data, 0xD4C3B2A1, spi_burst_send
WORD 0x0, 0x00000007, spi_data_wait       # rxfifo full, txfifo wptr at 1000, rxfifo wptr at 0000
WORD ip, 0x00000003, read32_test
WORD rx_data, 0x00000074, read32_test
WORD rx_data, 0x00000063, read32_test     # clear 2 entries, txfifo wptr at 1000, rxfifo wptr at 0010


WORD tx_data, 0x000000A4, write32_test
WORD tx_data, 0x000000B4, write32_test    # tx 1010, rx 0010
WORD 0x0, 0x00000007, spi_data_wait       # 8 tx 1010, rx 0010
WORD rx_mark, 0x00000004, write32_test
WORD rx_data, 0x00000052, read32_test     # 7 rx 0011
WORD rx_data, 0x00000041, read32_test     # 6 rx 0100
WORD rx_data, 0x000000A1, read32_test     # 5 rx 0101
WORD ip, 0x00000003, read32_test          # 5 things in rx fifo
WORD rx_data, 0x000000B2, read32_test     # 4 tx 1010, rx 0110
WORD ip, 0x00000001, read32_test          # 4 entries in rxfifo, not strictly greater than 4

WORD rx_mark, 0x00000007, write32_test
WORD tx_data, 0xD5C5B5A5, spi_burst_send  # 8 tx1110, rx 0110
WORD 0x0, 0x00000007, spi_data_wait

WORD rx_mark, 0x00000005, write32_test
WORD rx_data, 0x000000C3, read32_test     # tx 1110, rx 0111
WORD rx_data, 0x000000D4, read32_test     # tx 1110, rx 1000
WORD ip, 0x00000003, read32_test          # 6 entries
WORD rx_data, 0x000000A4, read32_test     # tx 1110, rx 1001
WORD ip, 0x00000001, read32_test          # 5 entries
WORD rx_data, 0x000000B4, read32_test     # tx 1110, rx 1010
WORD rx_data, 0x000000A5, read32_test     # tx 1110, rx 1011

WORD rx_mark, 0x00000006, write32_test
WORD tx_data, 0xD7C7B7A7, spi_burst_send
WORD 0x0, 0x00000006, spi_data_wait       # tx 0010, rx 1011
WORD tx_mark, 0x00000000, write32_test
WORD rx_mark, 0x00000000, write32_test
WORD rx_data, 0x000000B5, read32_test     # tx 0010, rx 1100
WORD rx_data, 0x000000C5, read32_test     # tx 0010, rx 1101
WORD rx_data, 0x000000D5, read32_test     # tx 0010, rx 1110
WORD rx_data, 0x000000A7, read32_test     # tx 0010, rx 1111
WORD rx_data, 0x000000B7, read32_test     # tx 0010, rx 0000
WORD rx_data, 0x000000C7, read32_test     # tx 0010, rx 0001
WORD ip, 0x00000002, read32_test
WORD rx_data, 0x000000D7, read32_test     # tx 0010, rx 1010
WORD ip, 0x00000000, read32_test
WORD tx_mark, 0x00000000, write32_test
WORD rx_mark, 0x00000000, write32_test    # reset watermark registers

# =========== Basic read-write ===========

WORD tx_data, 0x000000011, write32_test   # place 8'h11 into tx_data
WORD 0x0, 0x00000000, spi_data_wait           # wait for transmission to end
WORD rx_data, 0x00000011, read32_test     # read rx_data

# =========== Different cs_mode, sck_mode, cs_def, sck_div ===========

# Test sck_div

WORD sck_div, 0x00000101, write32_test    # set sck_div to 0x101
WORD tx_data, 0x000000FF, write32_test   # place 8'h11 into tx_data
WORD 0x0, 0x00000000, spi_data_wait           # wait for transmission to end
WORD rx_data, 0x000000FF, read32_test     # read rx_data

# Test min sck_div

WORD sck_div, 0x000000000, write32_test   #set sck_div to 0
WORD tx_data, 0xABACADAE, spi_burst_send
WORD 0x0, 0x00000003, spi_data_wait
WORD rx_data, 0x000000AE, read32_test
WORD rx_data, 0x000000AD, read32_test
WORD rx_data, 0x000000AC, read32_test
WORD rx_data, 0x000000AB, read32_test

# min sck_div, sckmode 01

WORD sck_mode, 0x00000001, write32_test
WORD tx_data, 0xABACADAE, spi_burst_send
WORD 0x0, 0x00000003, spi_data_wait
WORD rx_data, 0x000000AE, read32_test
WORD rx_data, 0x000000AD, read32_test
WORD rx_data, 0x000000AC, read32_test
WORD rx_data, 0x000000AB, read32_test

#min sck_div, sckmode 10
WORD sck_mode, 0x00000002, write32_test
WORD tx_data, 0xABACADAE, spi_burst_send
WORD 0x0, 0x00000003, spi_data_wait
WORD rx_data, 0x000000AE, read32_test
WORD rx_data, 0x000000AD, read32_test
WORD rx_data, 0x000000AC, read32_test
WORD rx_data, 0x000000AB, read32_test

#min sck_div, sckmode 11
WORD sck_mode, 0x00000003, write32_test
WORD tx_data, 0xABACADAE, spi_burst_send
WORD 0x0, 0x00000003, spi_data_wait
WORD rx_data, 0x000000AE, read32_test
WORD rx_data, 0x000000AD, read32_test
WORD rx_data, 0x000000AC, read32_test
WORD rx_data, 0x000000AB, read32_test




# Test phase

WORD sck_div, 0x00000003, write32_test    # reset sck_div to 0x03 so only sck_mode is different
WORD sck_mode, 0x00000001, write32_test   # change phase to falling edge
WORD tx_data, 0x000000A0, write32_test   # place 8'h11 into tx_data
WORD 0x0, 0x00000000, spi_data_wait           # wait for transmission to end
WORD rx_data, 0x000000A0, read32_test     # read rx_data

# Test polarity

WORD sck_mode, 0x00000000, write32_test   # reset sck phase to rising edge
WORD sck_mode, 0x00000002, write32_test   # set sck polarity active low
WORD tx_data, 0x0000000B, write32_test   # place 8'h11 into tx_data
WORD 0x0, 0x00000000, spi_data_wait           # wait for transmission to end
WORD rx_data, 0x0000000B, read32_test     # read rx_data

# Test phase polarity
WORD sck_mode, 0x00000003, write32_test   # set sck mode to 11
WORD tx_data, 0x000000F3, write32_test    # place f3 into tx_data
WORD 0x0, 0x00000000, spi_data_wait       # wait for transmission to end
WORD rx_data, 0x000000F3, read32_test     # read rx_data

# Test chip select polarity

WORD sck_mode, 0x00000000, write32_test   # reset sck polarity to active high
WORD cs_def, 0x0000000E, write32_test     # set cs[0] to inactive low
WORD tx_data, 0x00000079, write32_test   # place 8'h11 into tx_data
WORD 0x0, 0x00000000, spi_data_wait           # wait for transmission to end
WORD rx_data, 0x00000079, read32_test     # read rx_data

# Test chip id

WORD cs_def, 0x0000000F, write32_test     # reset all cs to active low
WORD cs_id, 0x00000001, write32_test      # select cs[1]
WORD tx_data, 0x00000000, write32_test   # place 8'h11 into tx_data
WORD 0x0, 0x00000000, spi_data_wait           # wait for transmission to end
WORD rx_data, 0x00000000, read32_test     # read rx_data

# Test cs hold mode

WORD cs_id, 0x00000000, write32_test      # select cs[0]
WORD cs_mode, 0x00000002, write32_test    # set cs_mode to HOLD
WORD tx_data, 0x000000C0, write32_test   # place 8'h11 into tx_data
WORD 0x0, 0x00000000, spi_data_wait           # wait for transmission to end
WORD rx_data, 0x000000C0, read32_test     # read rx_data

# Test cs OFF mode

WORD cs_mode, 0x00000003, write32_test    # set cs_mode to OFF
WORD tx_data, 0x00000011, write32_test   # place 8'h11 into tx_data
WORD 0x0, 0x00000000, spi_data_wait           # wait for transmission to end
WORD rx_data, 0x00000011, read32_test     # read rx_data

# =========== Test delay0 register (mode auto)===========

# Test cs-sck delay of 0 with sck phase = 0 (implicit half cycle delay)

WORD cs_mode, 0x00000000, write32_test    # reset cs_mode to auto, all cs and sck mode settings should be default
WORD delay0, 0x00010000, write32_test     # set cs-sck delay to 0
WORD tx_data, 0x00000020, write32_test   # place 8'h11 into tx_data
WORD 0x0, 0x00000000, spi_data_wait           # wait for transmission to end
WORD rx_data, 0x00000020, read32_test     # read rx_data

# Test cs-sck delay of 0 with sck phase 1 (no delay)

WORD sck_mode, 0x00000001, write32_test   # set sck_mode[0] to 1 (sck phase = 1)
WORD tx_data, 0x00000032, write32_test   # place 8'h11 into tx_data
WORD 0x0, 0x00000000, spi_data_wait           # wait for transmission to end
WORD rx_data, 0x00000032, read32_test     # read rx_data

# Test arbitrary cs-sck delay (sck phase 1)

WORD delay0, 0x00010005, write32_test     # set cs-sck delay to 5 cycles
WORD tx_data, 0x00000048, write32_test   # place 8'h11 into tx_data
WORD 0x0, 0x00000000, spi_data_wait           # wait for transmission to end
WORD rx_data, 0x00000048, read32_test     # read rx_data

# Test arbitrary cs-sck delay (sck phase 0)

WORD sck_mode, 0x00000000, write32_test   # set sck phase to 0
WORD delay0, 0x00010005, write32_test     # set cs-sck delay to AF cycles
WORD tx_data, 0x000000AF, write32_test   # place 8'h11 into tx_data
WORD 0x0, 0x00000000, spi_data_wait           # wait for transmission to end
WORD rx_data, 0x000000AF, read32_test     # read rx_data


# Test sck-cs delay of 0 with sck phase = 0 (no delay)

WORD delay0, 0x00000001, write32_test     # set cs-sck delay to 0
WORD tx_data, 0x00000050, write32_test   # place 8'h11 into tx_data
WORD 0x0, 0x00000000, spi_data_wait           # wait for transmission to end
WORD rx_data, 0x00000050, read32_test     # read rx_data

# Test sck-cs delay of 0 with sck phase 1 (implicit half cycle delay)

WORD sck_mode, 0x00000001, write32_test   # set sck_mode[0] to 1 (sck phase = 1)
WORD tx_data, 0x0000006B, write32_test   # place 8'h11 into tx_data
WORD 0x0, 0x00000000, spi_data_wait           # wait for transmission to end
WORD rx_data, 0x0000006B, read32_test     # read rx_data

# Test arbitrary sck-cs delay (sck phase 1)

WORD delay0, 0x00050001, write32_test     # set cs-sck delay to A5 cycles
WORD tx_data, 0x00000011, write32_test   # place 8'h11 into tx_data
WORD 0x0, 0x00000000, spi_data_wait           # wait for transmission to end
WORD rx_data, 0x00000011, read32_test     # read rx_data

# Test arbitrary sck-cs delay (sck phase 0)

WORD sck_mode, 0x00000000, write32_test   # set sck phase to 0
WORD delay0, 0x00050001, write32_test     # set cs-sck delay to 5 cycles
WORD tx_data, 0x00000015, write32_test   # place 8'h11 into tx_data
WORD 0x0, 0x00000000, spi_data_wait           # wait for transmission to end
WORD rx_data, 0x00000015, read32_test     # read rx_data

# SCKCS Delay of 0, SCKMODE 10
WORD sck_mode, 0x00000002, write32_test    #set sckmode to 10
WORD delay0, 0x00000001, write32_test    # set sckcs delay to 0
WORD tx_data, 0x00000010, write32_test    # place 10 into tx_data
WORD 0x0, 0x00000000, spi_data_wait       #wait for transmission
WORD rx_data, 0x00000010, read32_test     # reade rx_data

# Arbitrary SCKCS delay, SCKMODE 10
WORD delay0, 0x00050001, write32_test    # set sckcs delay to 5
WORD tx_data, 0x00000010, write32_test    # place 10 into tx_data
WORD 0x0, 0x00000000, spi_data_wait       #wait for transmission
WORD rx_data, 0x00000010, read32_test     # reade rx_data

# Long SCKCS delay, SCKMODE 10
WORD delay0, 0x00A50001, write32_test    # set sckcs delay to 0
WORD tx_data, 0x00000010, write32_test    # place 10 into tx_data
WORD 0x0, 0x00000000, spi_data_wait       #wait for transmission
WORD rx_data, 0x00000010, read32_test     # reade rx_data

# CSSCK Delay 0, SCKMODE 10
WORD delay0, 0x00010000, write32_test    # set sckcs delay to 0
WORD tx_data, 0x00000010, write32_test    # place 10 into tx_data
WORD 0x0, 0x00000000, spi_data_wait       #wait for transmission
WORD rx_data, 0x00000010, read32_test     # reade rx_data

# Arbitrary CSSCK delay, SCKMODE 10
WORD delay0, 0x00010005, write32_test    # set sckcs delay to 0
WORD tx_data, 0x00000010, write32_test    # place 10 into tx_data
WORD 0x0, 0x00000000, spi_data_wait       #wait for transmission
WORD rx_data, 0x00000010, read32_test     # reade rx_data

# Long CSSCK delay, SCKMODE 10
WORD delay0, 0x000100A5, write32_test    # set sckcs delay to 0
WORD tx_data, 0x00000010, write32_test    # place 10 into tx_data
WORD 0x0, 0x00000000, spi_data_wait       #wait for transmission
WORD rx_data, 0x00000010, read32_test     # reade rx_data



# SCKCS Delay of 0, SCKMODE 11
WORD sck_mode, 0x00000003, write32_test
WORD delay0, 0x00000001, write32_test    # set sckcs delay to 0
WORD tx_data, 0x00000011, write32_test    # place 10 into tx_data
WORD 0x0, 0x00000000, spi_data_wait       #wait for transmission
WORD rx_data, 0x00000011, read32_test     # reade rx_data

# Arbitrary SCKCS delay, SCKMODE 11
WORD delay0, 0x00050001, write32_test    # set sckcs delay to 0
WORD tx_data, 0x00000011, write32_test    # place 10 into tx_data
WORD 0x0, 0x00000000, spi_data_wait       #wait for transmission
WORD rx_data, 0x00000011, read32_test     # reade rx_data

# Long SCKCS delay, SCKMODE 11
WORD delay0, 0x00A50001, write32_test    # set sckcs delay to 0
WORD tx_data, 0x00000011, write32_test    # place 10 into tx_data
WORD 0x0, 0x00000000, spi_data_wait       #wait for transmission
WORD rx_data, 0x00000011, read32_test     # reade rx_data

# CSSCK Delay 0, SCKMODE 11
WORD delay0, 0x00010000, write32_test    # set sckcs delay to 0
WORD tx_data, 0x00000011, write32_test    # place 10 into tx_data
WORD 0x0, 0x00000000, spi_data_wait       #wait for transmission
WORD rx_data, 0x00000011, read32_test     # reade rx_data

# Arbitrary CSSCK delay, SCKMODE 11
WORD delay0, 0x00010005, write32_test    # set sckcs delay to 0
WORD tx_data, 0x00000011, write32_test    # place 10 into tx_data
WORD 0x0, 0x00000000, spi_data_wait       #wait for transmission
WORD rx_data, 0x00000011, read32_test     # reade rx_data

# Long CSSCK delay, SCKMODE 11
WORD delay0, 0x000100A5, write32_test    # set sckcs delay to 0
WORD tx_data, 0x00000011, write32_test    # place 10 into tx_data
WORD 0x0, 0x00000000, spi_data_wait       #wait for transmission
WORD rx_data, 0x00000011, read32_test     # reade rx_data

# =========== Test delay1 register ===========

# Test inter cs delay

WORD sck_mode, 0x00000000, write32_test   #reset sck_mode
WORD delay0, 0x00010001, write32_test     # reset delay0 register
WORD delay1, 0x00000005, write32_test     # set inter_cs delay to 5
WORD rx_mark, 0x0000003, write32_test     # preset rx watermark b/c of hardware interlock
WORD tx_data, 0x44332211, spi_burst_send
WORD 0x0, 0x00000003, spi_data_wait           # wait for transmission to end
WORD rx_data, 0x00000011, read32_test
WORD rx_data, 0x00000022, read32_test
WORD rx_data, 0x00000033, read32_test
WORD rx_data, 0x00000044, read32_test

#test long inter_cs delay

WORD delay1, 0x000000A5, write32_test
WORD rx_mark, 0x0000000, write32_test     # preset rx watermark b/c of hardware interlock
WORD tx_data, 0x0000007B, write32_test
WORD 0x0, 0x00000000, spi_data_wait
WORD rx_data, 0x0000007B, read32_test


# Test inter_cs delay set to 0

WORD delay1, 0x00000000, write32_test     # set inter_cs delay to 5
WORD rx_mark, 0x0000003, write32_test     # preset rx watermark b/c of hardware interlock
WORD tx_data, 0x54433221, spi_burst_send
WORD 0x0, 0x00000003, spi_data_wait           # wait for transmission to end
WORD rx_data, 0x00000021, read32_test
WORD rx_data, 0x00000032, read32_test
WORD rx_data, 0x00000043, read32_test
WORD rx_data, 0x00000054, read32_test


# Test inter_xfr delay of 0 (maybe change behavior to half-period instead of period)

WORD delay1, 0x00000001, write32_test     # reset inter_cs delay to 1
WORD cs_mode, 0x00000002, write32_test    # set cs_mode to HOLD
WORD tx_data, 0x99887766, spi_burst_send
WORD 0x0, 0x00000003, spi_data_wait           # wait for transmission to end
WORD rx_data, 0x00000066, read32_test
WORD rx_data, 0x00000077, read32_test
WORD rx_data, 0x00000088, read32_test
WORD rx_data, 0x00000099, read32_test

# Test inter_xfr delay 0 with phase = 1
WORD sck_mode, 0x00000001, write32_test
WORD tx_data, 0x99887766, spi_burst_send
WORD 0x0, 0x00000003, spi_data_wait
WORD rx_data, 0x00000066, read32_test
WORD rx_data, 0x00000077, read32_test
WORD rx_data, 0x00000088, read32_test
WORD rx_data, 0x00000099, read32_test


# Test arbitrary inter_xfr delay

WORD delay1, 0x00050001, write32_test     # set inter_xfr delay to 5
WORD sck_mode, 0x00000001, write32_test
WORD tx_data, 0x98877665, spi_burst_send
WORD 0x0, 0x00000003, spi_data_wait           # wait for transmission to end
WORD rx_data, 0x00000065, read32_test
WORD rx_data, 0x00000076, read32_test
WORD rx_data, 0x00000087, read32_test
WORD rx_data, 0x00000098, read32_test

# test long inter_xfr delay
WORD delay1, 0x00A50001, write32_test
WORD rx_mark, 0x0000000, write32_test     # preset rx watermark b/c of hardware interlock
WORD tx_data, 0x00000048, write32_test
WORD 0x0, 0x00000000, spi_data_wait
WORD rx_data, 0x00000048, read32_test

# Test cs-sck delay with cs_mode = HOLD

WORD delay1, 0x00000001, write32_test     # set inter_xfr delay to 0
WORD delay0, 0x00010005, write32_test     # set cs-sck delay to 5 (should have no effect because cs is never inactive)
WORD rx_mark, 0x0000003, write32_test     # preset rx watermark b/c of hardware interlock
WORD tx_data, 0xAABBCCDD, spi_burst_send
WORD 0x0, 0x00000003, spi_data_wait           # wait for transmission to end
WORD rx_data, 0x000000DD, read32_test     # read rx_data
WORD rx_data, 0x000000CC, read32_test
WORD rx_data, 0x000000BB, read32_test
WORD rx_data, 0x000000AA, read32_test

# Test sck-cs delay cs_mode = HOLD

WORD delay0, 0x00000501, write32_test     # set sck-cs delay to 5 (should have no effect because cs is never inactive)
WORD tx_data, 0xABBCCDDE, spi_burst_send   # place 8'h11 into tx_data
WORD 0x0, 0x00000003, spi_data_wait           # wait for transmission to end
WORD rx_data, 0x000000DE, read32_test     # read rx_data
WORD rx_data, 0x000000CD, read32_test
WORD rx_data, 0x000000BC, read32_test
WORD rx_data, 0x000000AB, read32_test

# Test hold mode deassert conditions

WORD delay1, 0x00000001, write32_test     # reset delay1 register
WORD delay0, 0x00010001, write32_test     # reset delay0 register
WORD cs_mode, 0x00000002, write32_test    # set cs_mode to hold
WORD tx_data, 0x000000CE, write32_test    # place data into tx_data
WORD cs_id, 0x00000001, write32_test      #change selected cs pin. should deassert cs[0] in hold mode
WORD cs_def, 0x0000000D, write32_test     # change selected cs pins def value. should deassert cs[1]
WORD cs_mode, 0x00000000, write32_test    # change cs_mode to auto, should deassert cs[1], have now gone through all deassertion conditions
WORD cs_def, 0x0000000F, write32_test     # reset cs_def
WORD cs_id, 0x00000000, write32_test      # reset cs_id
WORD rx_data, 0x000000CE, read32_test     # clear rx_fifo

# =========== Test frame format (fmt) register ===========

# Test frame length of 4

WORD delay1, 0x00000001, write32_test     # reset delay1 register
WORD delay0, 0x00010001, write32_test     # reset delay0 register
WORD sck_mode, 0x00000000, write32_test   #reset sckmode register
WORD cs_mode, 0x00000000, write32_test    # set cs_mode to AUTO
WORD fmt, 0x00040000, write32_test        # set frame length to 4
WORD rx_mark, 0x0000000, write32_test     # preset rx watermark b/c of hardware interlock
WORD tx_data, 0x000000F0, write32_test   # place 8'h11 into tx_data
WORD 0x0, 0x00000000, spi_data_wait           # wait for transmission to end
WORD rx_data, 0x000000F0, read32_test     # read rx_data

# Test frame length of 0

#WORD fmt, 0x00000000, write32_test        # set frame length to 4
#WORD tx_data, 0x00000077, write32_test   # place 8'h11 into tx_data
#WORD 0x0, 0x0101, spi_data_wait           # wait for transmission to end
#WORD rx_data, 0x00000077, read32_test     # read rx_data

# test frame length 1 burst
WORD fmt, 0x00010000, write32_test
WORD rx_mark, 0x0000003, write32_test     # preset rx watermark b/c of hardware interlock
WORD tx_data, 0x80008000, spi_burst_send
WORD 0x0, 0x00000003, spi_data_wait
WORD rx_data, 0x00000000, read32_test
WORD rx_data, 0x00000080, read32_test
WORD rx_data, 0x00000000, read32_test
WORD rx_data, 0x00000080, read32_test


# Test big endian with frame length = 5

WORD fmt, 0x00050000, write32_test        # set frame length to 5, big endian
WORD rx_mark, 0x0000000, write32_test     # preset rx watermark b/c of hardware interlock
WORD tx_data, 0x000000A8, write32_test   # place 8'h11 into tx_data
WORD 0x0, 0x00000000, spi_data_wait           # wait for transmission to end
WORD rx_data, 0x000000A8, read32_test     # read rx_data

# Test big endian burst with frame length = 5

WORD rx_mark, 0x0000003, write32_test     # preset rx watermark b/c of hardware interlock
WORD tx_data, 0x03774FFF, spi_burst_send
WORD 0x0, 0x00000003, spi_data_wait
WORD rx_data, 0x000000F8, read32_test
WORD rx_data, 0x00000048, read32_test
WORD rx_data, 0x00000070, read32_test
WORD rx_data, 0x00000000, read32_test




# Test little endian with frame length = 5

WORD fmt, 0x00050004, write32_test        # set frame length to 5, little-endian
WORD rx_mark, 0x0000000, write32_test     # preset rx watermark b/c of hardware interlock
WORD tx_data, 0x000000A8, write32_test   # place 8'h11 into tx_data
WORD 0x0, 0x00000000, spi_data_wait           # wait for transmission to end
WORD rx_data, 0x00000008, read32_test     # read rx_data -> 08

#test little endian burst with frame length = 5

WORD rx_mark, 0x0000003, write32_test     # preset rx watermark b/c of hardware interlock
WORD tx_data, 0xFF4F7703, spi_burst_send
WORD 0x0, 0x00000003, spi_data_wait
WORD rx_data, 0x00000003, read32_test     #03
WORD rx_data, 0x00000017, read32_test     #17
WORD rx_data, 0x0000000F, read32_test     #0F
WORD rx_data, 0x0000001F, read32_test     #1F

# Test dual SPI protocol, frame length = 8, big endian

#WORD fmt, 0x00080001, write32_test        # set frame length to 8, big-endian, dual SPI
#WORD tx_data, 0x000000C8, write32_test   # place 8'h11 into tx_data
#WORD 0x0, 0x00000000, spi_data_wait           # wait for transmission to end
#WORD rx_data, 0x00000000, read32_test     # read rx_data

# Test dual SPI protocol, frame length = 4

#WORD fmt, 0x00040001, write32_test        # set frame length to 8, big-endian, dual SPI
#WORD tx_data, 0x000000A2, write32_test   # place 8'h11 into tx_data
#WORD 0x0, 0x00000000, spi_data_wait           # wait for transmission to end
#WORD rx_data, 0x000000A0, read32_test     # read rx_data

# Test dual SPI protocol, frame length = 5

#WORD fmt, 0x00050001, write32_test        # set frame length to 8, big-endian, dual SPI
#WORD tx_data, 0x00000075, write32_test   # place 8'h11 into tx_data
#WORD 0x0, 0x00000000, spi_data_wait           # wait for transmission to end
#WORD rx_data, 0x00000074, read32_test     # read rx_data

# Test dual SPI protocol burst, frame length = 5
#WORD tx_data, 0x30733FFF, spi_burst_send
#WORD 0x0, 0x00000003, spi_data_wait
#WORD rx_data, 0x000000FC, read32_test
#WORD rx_data, 0x0000003C, read32_test
#WORD rx_data, 0x00000070, read32_test
#WORD rx_data, 0x00000030, read32_test

# Test quad SPI protocol, frame length = 5

#WORD fmt, 0x00050002, write32_test        # set frame length to 8, big-endian, dual SPI
#WORD tx_data, 0x0000003F, write32_test   # place 8'h11 into tx_data
#WORD 0x0, 0x00000000, spi_data_wait           # wait for transmission to end
#WORD rx_data, 0x0000003F, read32_test     # read rx_data

# Test quad SPI protocol, frame length = 4

#WORD fmt, 0x00040002, write32_test        # set frame length to 8, big-endian, dual SPI
#WORD tx_data, 0x0000000F, write32_test   # place 8'h11 into tx_data
#WORD 0x0, 0x00000000, spi_data_wait           # wait for transmission to end
#WORD rx_data, 0x00000000, read32_test     # read rx_data

# Test quad SPI protocol, frame length = 8

#WORD fmt, 0x00080002, write32_test        # set frame length to 8, big-endian, dual SPI
#WORD tx_data, 0x000000F0, write32_test   # place 8'h11 into tx_data
#WORD 0x0, 0x00000000, spi_data_wait           # wait for transmission to end
#WORD rx_data, 0x000000F0, read32_test     # read rx_data









# =========== Test watermark interrupts ===========

# Test transmit watermark interrupt (triggers when entries in tx FIFO < tx watermark) without external enables

SETUP_PLIC
WORD fmt, 0x00080000, write32_test        # reset format register
WORD delay1, 0x0000001, write32_test      # reset delay1 register
WORD cs_mode, 0x00000000, write32_test    # reset cs_mode
WORD sck_div, 0x00000100, write32_test    # lower SPI clock rate so reads are done at correct time when ICACHE not supported
WORD tx_mark, 0x00000001, write32_test    # set transmit watermark to 1 (any entry turns mark off)
#WORD ie, 0x00000000, write32_test         # enable transmit interrupt
WORD ip, 0x00000001, read32_test          # tx watermark interrupt should be pending
WORD 0x0, 0x00000000, readmip_test
WORD tx_data, 0x55443322, spi_burst_send    # place 4 entries in transmit fifo
WORD ip, 0x00000000, read32_test          # tx watermark interrupt should be off 125
WORD 0x0, 0x00000003, spi_data_wait           # wait for transmission to end

# test receive watermark interrupt (triggers when entries in rx FIFO > rx watermark)

WORD tx_mark, 0x00000000, write32_test      # set tx_mark to 0
WORD rx_data, 0x00000022, read32_test       # clear one entry from rx FIFO
WORD rx_mark, 0x00000003, write32_test      # set receive watermark to 3
#WORD ie, 0x0000002, write32_test          # enable receive interrupts
WORD ip, 0x00000000, read32_test          # rx interrupts should be low (rx FIFO has 3 entries)
WORD rx_mark, 0x00000002, write32_test    # set receive watermark to 2
WORD ip, 0x00000002, read32_test          # receive interrupt should be high
WORD 0x0, 0x00000000, readmip_test
WORD rx_data, 0x00000033, read32_test     # clear one more entry from receive FIFO (2 entries)
WORD ip, 0x00000000, read32_test          # receive interrupt should be low
WORD rx_data, 0x00000044, read32_test
WORD rx_data, 0x00000055, read32_test     # clear rx fifo


WORD tx_mark, 0x00000001, write32_test    # set transmit watermark to 0
WORD ie, 0x00000001, write32_test         # enable transmit interrupt
WORD ip, 0x00000001, read32_test          # tx watermark interrupt should be pending
WORD 0x0, 0x00000800, readmip_test
WORD ie, 0x00000000, write32_test      # disable tx intr
WORD tx_data, 0x55443322, spi_burst_send    # place 4 entries in transmit fifo
WORD 0x0, 0x00000003, spi_data_wait           # wait for transmission to end

# test receive watermark interrupt (triggers when entries in rx FIFO > rx watermark)

WORD tx_mark, 0x00000000, write32_test
WORD 0x0, 0x00000000, claim_m_plic_interrupts
WORD rx_data, 0x00000022, read32_test       # clear one entry from rx FIFO
WORD rx_mark, 0x00000003, write32_test      # set receive watermark to 3
WORD ie, 0x0000002, write32_test          # enable receive interrupts
WORD ip, 0x00000000, read32_test          # rx interrupts should be low (rx FIFO has 3 entries)
WORD 0x0, 0x00000000, readmip_test
WORD rx_mark, 0x00000002, write32_test    # set receive watermark to 2
WORD ip, 0x00000002, read32_test          # receive interrupt should be high
WORD 0x0, 0x00000800, readmip_test
WORD rx_data, 0x00000033, read32_test     # clear one more entry from receive FIFO (2 entries)
WORD 0x0, 0x00000000, claim_m_plic_interrupts
WORD ip, 0x00000000, read32_test          # receive interrupt should be low
WORD 0x0, 0x00000000, readmip_test



WORD 0x0, 0x0, terminate_test

// ---------------------------------------------------------------------------------------------
// Expected signature
//
//   One entry per signature write, in order (XLEN bits each; SEXT32 marks values that are sign extended on RV64).  SIG_NEXT in WALLY-TEST-LIB.h checks each
//   entry as soon as it is written; a mismatch halts the test and reports the entry index below.
// ---------------------------------------------------------------------------------------------

.align REGSHIFT
expected_signature:
WORD 0x00000003 // 0: reset tests sck_div
WORD 0x00000000 // 1: sck_mode
WORD 0x00000000 // 2: cs_id
WORD 0x0000000F // 3: cs_def
WORD 0x00000000 // 4: cs_mode
WORD 0x00010001 // 5: delay 0
WORD 0x00000001 // 6: delay 1
WORD 0x00080000 // 7: fmt
WORD 0x00000000 // 8: tx_data
WORD 0x00000000 // 9: tx_mark
WORD 0x00000000 // 10: rx_mark
WORD 0x00000000 // 11: ie reset
WORD 0x00000000 // 12: ip reset
WORD 0x00000000 // 13: fifo watermark and edge case tests
WORD 0x00000001 // 14
WORD 0x00000003 // 15
WORD 0x00000003 // 16
WORD 0x00000074 // 17: spi_burst_send
WORD 0x00000063 // 18: spi_burst_send
WORD 0x00000052 // 19: spi_burst_send
WORD 0x00000041 // 20: spi_burst_send
WORD 0x000000A1 // 21: spi_burst_send
WORD 0x00000003 // 22
WORD 0x000000B2 // 23: spi_burst_send
WORD 0x00000001 // 24
WORD 0x000000C3 // 25: spi_burst_send
WORD 0x000000D4 // 26: spi_burst_send
WORD 0x00000003 // 27
WORD 0x000000A4 // 28: tx_data write test
WORD 0x00000001 // 29
WORD 0x000000B4 // 30: tx_data write test
WORD 0x000000A5 // 31: spi_burst_send
WORD 0x000000B5 // 32: spi_burst_send
WORD 0x000000C5 // 33: spi_burst_send
WORD 0x000000D5 // 34: spi_burst_send
WORD 0x000000A7 // 35: spi_burst_send
WORD 0x000000B7 // 36: spi_burst_send
WORD 0x000000C7 // 37: spi_burst_send
WORD 0x00000002 // 38
WORD 0x000000D7 // 39: spi_burst_send
WORD 0x00000000 // 40
WORD 0x00000011 // 41: basic read write
WORD 0x000000FF // 42: first test sck_div
WORD 0x000000AE // 43: min sck_div first spi_burst_send
WORD 0x000000AD // 44
WORD 0x000000AC // 45
WORD 0x000000AB // 46
WORD 0x000000AE // 47
WORD 0x000000AD // 48
WORD 0x000000AC // 49
WORD 0x000000AB // 50
WORD 0x000000AE // 51
WORD 0x000000AD // 52
WORD 0x000000AC // 53
WORD 0x000000AB // 54
WORD 0x000000AE // 55
WORD 0x000000AD // 56
WORD 0x000000AC // 57
WORD 0x000000AB // 58
WORD 0x000000A0 // 59
WORD 0x0000000B // 60
WORD 0x000000F3 // 61
WORD 0x00000079 // 62
WORD 0x00000000 // 63
WORD 0x000000C0 // 64
WORD 0x00000011 // 65
WORD 0x00000020 // 66: delay registers
WORD 0x00000032 // 67
WORD 0x00000048 // 68
WORD 0x000000AF // 69
WORD 0x00000050 // 70
WORD 0x0000006B // 71
WORD 0x00000011 // 72
WORD 0x00000015 // 73
WORD 0x00000010 // 74
WORD 0x00000010 // 75
WORD 0x00000010 // 76
WORD 0x00000010 // 77
WORD 0x00000010 // 78
WORD 0x00000010 // 79
WORD 0x00000011 // 80
WORD 0x00000011 // 81
WORD 0x00000011 // 82
WORD 0x00000011 // 83
WORD 0x00000011 // 84
WORD 0x00000011 // 85
WORD 0x00000011 // 86: delay1
WORD 0x00000022 // 87
WORD 0x00000033 // 88
WORD 0x00000044 // 89
WORD 0x0000007B // 90
WORD 0x00000021 // 91
WORD 0x00000032 // 92
WORD 0x00000043 // 93
WORD 0x00000054 // 94
WORD 0x00000066 // 95
WORD 0x00000077 // 96
WORD 0x00000088 // 97
WORD 0x00000099 // 98
WORD 0x00000066 // 99
WORD 0x00000077 // 100
WORD 0x00000088 // 101
WORD 0x00000099 // 102
WORD 0x00000065 // 103
WORD 0x00000076 // 104
WORD 0x00000087 // 105
WORD 0x00000098 // 106
WORD 0x00000048 // 107
WORD 0x000000DD // 108
WORD 0x000000CC // 109
WORD 0x000000BB // 110
WORD 0x000000AA // 111
WORD 0x000000DE // 112
WORD 0x000000CD // 113
WORD 0x000000BC // 114
WORD 0x000000AB // 115
WORD 0x000000CE // 116: hold mode deassert
WORD 0x000000F0 // 117: fmt register
WORD 0x00000000 // 118
WORD 0x00000080 // 119
WORD 0x00000000 // 120
WORD 0x00000080 // 121
WORD 0x000000A8 // 122
WORD 0x000000F8 // 123
WORD 0x00000048 // 124
WORD 0x00000070 // 125
WORD 0x00000000 // 126
WORD 0x00000008 // 127
WORD 0x00000003 // 128
WORD 0x00000017 // 129
WORD 0x0000000F // 130
WORD 0x0000001F // 131
WORD 0x00000001 // 132: watermark interrupts
WORD 0x00000000 // 133: read mip
WORD 0x00000000 // 134: read tx ip
WORD 0x00000022 // 135: clear 1 frame from rx fifo
WORD 0x00000000 // 136: read receive ip
WORD 0x00000002 // 137: read receive ip
WORD 0x00000000 // 138: read mip
WORD 0x00000033 // 139: clear frame
WORD 0x00000000 // 140: read receive ip
WORD 0x00000044 // 141: clear frame
WORD 0x00000055 // 142: clear frame
WORD 0x00000001 // 143: read tx ip
WORD 0x00000800 // 144: read mip
WORD 0x00000022 // 145: clear frame
WORD 0x00000000 // 146: read rx ip
WORD 0x00000000 // 147: read mip 94
WORD 0x00000002 // 148: read rx ip
WORD 0x00000800 // 149: read mip
WORD 0x00000033 // 150: clear frame
WORD 0x00000000 // 151: read rx wm
WORD 0x00000000 // 152: read mip 99
WORD 0x0000000B // 153: ecall from test termination in M mode
expected_signature_end:
