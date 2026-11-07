# sha512.do
#
# Written: James E. Stine james.stine@okstate.edu
#
# Purpose: Compile and simulate the SHA-512 example with Questa and show its signals.
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
#     vsim -do sha512.do        (GUI)
#     vsim -c -do sha512.do     (batch)

onbreak {resume}

# Start from an empty work library
if {[file exists work]} {
  vdel -all
}
vlib work

vlog sha512.sv tb_sha512.sv
vsim -voptargs=+acc work.stimulus

view wave

# Testbench
add wave -noupdate -divider -height 64 "Testbench"
foreach sig {hashed message result errors} {
  add wave -noupdate -expand -group tb /stimulus/$sig
}

# Message padding
add wave -noupdate -divider -height 64 "Padder"
add wave -noupdate -expand -group padder /stimulus/dut/padder/*

# Working variables of the main loop
add wave -noupdate -divider -height 64 "Main loop"
foreach v {a b c d e f g} {
  add wave -noupdate -expand -group main /stimulus/dut/main/$v
}

# Message schedule
add wave -noupdate -divider -height 64 "Message schedule"
add wave -noupdate -expand -group prepare /stimulus/dut/main/p1/*

# Outputs of selected rounds of the compression function
foreach round {mc01 mc02 mc03 mc04 mc15 mc61 mc62 mc63 mc64} {
  add wave -noupdate -divider -height 64 "Round $round"
  foreach v {a b c d e f g h} {
    add wave -noupdate -expand -group $round /stimulus/dut/main/$round/${v}_out
  }
}

# Intermediate hash
add wave -noupdate -divider -height 64 "Intermediate hash"
add wave -noupdate -expand -group ih1 /stimulus/dut/main/ih1/*

configure wave -namecolwidth 350
configure wave -valuecolwidth 200
configure wave -justifyvalue left
configure wave -signalnamewidth 1
WaveRestoreZoom {0 ps} {75 ns}

run 25 ns
quit
