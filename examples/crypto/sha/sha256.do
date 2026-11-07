# sha256.do
#
# Written: James E. Stine james.stine@okstate.edu
#
# Purpose: Compile and simulate the SHA-256 example with Questa and show its signals.
#
# Documentation: RISC-V System on Chip Design
#
# A component of the CORE-V-WALLY configurable RISC-V project.
# https://github.com/openhwfoundation/cvw
#
# Copyright (C) 2025-26 Harvey Mudd College & Oklahoma State University
#
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Run from this directory with
#     vsim -do sha256.do        (GUI)
#     vsim -c -do sha256.do     (batch)

onbreak {resume}

# Start from an empty work library
if {[file exists work]} {
  vdel -all
}
vlib work

vlog sha256.sv tb_sha256.sv
vsim -voptargs=+acc work.stimulus

# Every signal in the testbench and the design, in hexadecimal
view wave
add wave -hex -r /stimulus/*

configure wave -namecolwidth 350
configure wave -valuecolwidth 200
configure wave -justifyvalue left
configure wave -signalnamewidth 1
WaveRestoreZoom {0 ps} {75 ns}

run 25 ns
quit
