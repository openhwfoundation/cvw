# tb_fma_wally.do
#
# Written: James E. Stine james.stine@okstate.edu
#
# Purpose: Simulate Wally's FMA unit on half-precision TestFloat vectors with Questa.
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
# Run from this directory, after sourcing setup.sh and building the TestFloat vectors, with
#     vsim -do tb_fma_wally.do        (GUI)
#     vsim -c -do tb_fma_wally.do     (batch)
# To test another vector file, change VEC_FILE below, and set the rounding mode and format in
# tb_fma_wally.sv to match.

onbreak {resume}

if {![info exists env(WALLY)]} {
  puts "ERROR: Environment variable WALLY is not set; source setup.sh first."
  quit -f
}
set WALLY $env(WALLY)
set VEC_FILE $WALLY/tests/fp/vectors/f16_mulAdd_rne.tv
puts "Using WALLY=$WALLY"

# Start from an empty work library
if {[file exists work]} {
  vdel -all
}
vlib work

# Wally's FMA, unpacker, and postprocessor, with the rv32gc configuration
vlog +incdir+$WALLY/config/rv32gc +incdir+$WALLY/config/shared \
     $WALLY/src/cvw.sv $WALLY/src/fpu/fma/*.sv tb_fma_wally.sv
vlog $WALLY/src/generic/lzc.sv $WALLY/src/generic/mux.sv
vlog $WALLY/src/fpu/postproc/*.sv
vlog $WALLY/src/fpu/unpack.sv $WALLY/src/fpu/unpackinput.sv $WALLY/src/fpu/fmtparams.sv

vsim -voptargs=+acc -gVEC_FILE=$VEC_FILE work.stimulus

view wave

add wave -noupdate -divider -height 32 "Inputs"
foreach sig {Xs Ys Zs Xe Ye Ze Xm Ym Zm XZero YZero ZZero OpCtrl PostProcRes} {
  add wave -hex /stimulus/$sig
}

add wave -noupdate -divider -height 32 "Unpack"
add wave -hex -r /stimulus/unpack/*
add wave -noupdate -divider -height 32 "FMA"
add wave -hex -r /stimulus/dut/*

add wave -noupdate -divider -height 32 "FMA outputs"
foreach sig {ASticky Sm InvA As Ps Ss Se SCnt} {
  add wave -hex /stimulus/$sig
}

add wave -noupdate -divider -height 32 "Postprocessor"
add wave -hex -r /stimulus/postprocess/*

WaveRestoreZoom {0 ps} {75 ns}

run -all
