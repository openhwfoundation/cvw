# Copyright 1991-2016 Mentor Graphics Corporation
#
# Modification by Oklahoma State University
# Use with Testbench
# James Stine, 2008
# Go Cowboys!!!!!!
#
# All Rights Reserved.
#
# THIS WORK CONTAINS TRADE SECRET AND PROPRIETARY INFORMATION
# WHICH IS THE PROPERTY OF MENTOR GRAPHICS CORPORATION
# OR ITS LICENSORS AND IS SUBJECT TO LICENSE TERMS.

# Use this run.do file to run this example.
# Either bring up ModelSim and type the following at the "ModelSim>" prompt:
#     do run.do
# or, to run from a shell, type the following at the shell prompt:
#     vsim -do fma.do -c
# (omit the "-c" to see the GUI while running from the shell)

onbreak {resume}

# create library
if [file exists work] {
    vdel -all
}
vlib work

if {![info exists env(WALLY)]} {
  puts "ERROR: Environment variable WALLY is not set."
  quit -f
}
set WALLY $env(WALLY)
set VECROOT $WALLY/tests/fp/vectors
puts "Using WALLY=$WALLY"

# compile source files
vlog $WALLY/src/cvw.sv $WALLY/src/fpu/fma/*.sv tb_fma_wally.sv +incdir+$WALLY/config/rv32gc +incdir+$WALLY/config/shared
vlog $WALLY/src/generic/lzc.sv $WALLY/src/generic/mux.sv
vlog $WALLY/src/fpu/postproc/*.sv
vlog $WALLY/src/fpu/unpack.sv $WALLY/src/fpu/unpackinput.sv $WALLY/src/fpu/fmtparams.sv

# Start and run simulation (change to vector you wish to test)
# Remember to set the rounding mode and format in the tb too
vsim -voptargs=+acc -gVEC_FILE=$VECROOT/f16_mulAdd_rne.tv work.stimulus

view list
view wave

-- display input and output signals as hexidecimal values
# Diplays All Signals recursively
# add wave -hex -r /stimulus/*

# Inputs
add wave -noupdate -divider -height 32 "Inputs"
add wave -hex /stimulus/Xs
add wave -hex /stimulus/Ys
add wave -hex /stimulus/Zs
add wave -hex /stimulus/Xe
add wave -hex /stimulus/Ye
add wave -hex /stimulus/Ze
add wave -hex /stimulus/Xm
add wave -hex /stimulus/Ym
add wave -hex /stimulus/Zm
add wave -hex /stimulus/XZero
add wave -hex /stimulus/YZero
add wave -hex /stimulus/ZZero
add wave -hex /stimulus/OpCtrl
add wave -hex /stimulus/PostProcRes

add wave -noupdate -divider -height 32 "unpack"
add wave -hex -r /stimulus/unpack/*
add wave -noupdate -divider -height 32 "fma"
add wave -hex -r /stimulus/dut/*
add wave -noupdate -divider -height 32 "postprocess"
add wave -hex -r /stimulus/postprocess/*

# Output
add wave -noupdate -divider -height 32 "Outputs"
add wave -hex /stimulus/ASticky
add wave -hex /stimulus/Sm
add wave -hex /stimulus/InvA
add wave -hex /stimulus/As
add wave -hex /stimulus/Ps
add wave -hex /stimulus/Ss
add wave -hex /stimulus/Se
add wave -hex /stimulus/SCnt

# PostProc
add wave -noupdate -divider -height 32 "PostProc"
add wave -hex /stimulus/postprocess/*

# Shift Correction
add wave -noupdate -divider -height 32 "PostProc"
add wave -hex /stimulus/postprocess/shiftcorrection/*

# add list -hex -r /tb/*
# add log -r /*

-- Set Wave Output Items
TreeUpdate [SetDefaultTree]
WaveRestoreZoom {0 ps} {75 ns}
#configure wave -namecolwidth 150
#configure wave -valuecolwidth 100
#configure wave -justifyvalue left
#configure wave -signalnamewidth 1
#configure wave -snapdistance 10
#configure wave -datasetprefix 0
#configure wave -rowmargin 4
#configure wave -childrowmargin 2

-- Run the Simulation
run -all
