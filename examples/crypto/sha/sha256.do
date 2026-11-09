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
#     vsim -do run.do -c
# (omit the "-c" to see the GUI while running from the shell)
onbreak {resume}
# create library
if [file exists work] {
    vdel -all
}
vlib work
# compile source files
vlog sha256.sv tb_sha256.sv

# start and run simulation
vsim -voptargs=+acc work.stimulus
view wave

-- display input and output signals as hexidecimal values
# Diplays All Signals recursively
add wave -hex -r /stimulus/*
#add wave -noupdate -divider -height 32 "Main tb"
#add wave -noupdate -expand -group tb /stimulus/message
#add wave -noupdate -expand -group tb /stimulus/hashed
#add wave -noupdate -divider -height 32 "padded"
#add wave -noupdate -expand -group padded /stimulus/dut/padder/*
#add wave -noupdate -divider -height 32 "sha256 main module"
#add wave -noupdate -expand -group main /stimulus/dut/main/a
#add wave -noupdate -expand -group main /stimulus/dut/main/b
#add wave -noupdate -expand -group main /stimulus/dut/main/c
#add wave -noupdate -expand -group main /stimulus/dut/main/d
#add wave -noupdate -expand -group main /stimulus/dut/main/e
#add wave -noupdate -expand -group main /stimulus/dut/main/f
#add wave -noupdate -expand -group main /stimulus/dut/main/g
#add wave -noupdate -divider -height 32 "sha256 prepare"
#add wave -noupdate -expand -group prepare /stimulus/dut/main/p1/*
#add wave -noupdate -divider -height 32 "sha256 mc01"
#add wave -noupdate -expand -group mc01 /stimulus/dut/main/mc01/a_out
#add wave -noupdate -expand -group mc01 /stimulus/dut/main/mc01/b_out
#add wave -noupdate -expand -group mc01 /stimulus/dut/main/mc01/c_out
#add wave -noupdate -expand -group mc01 /stimulus/dut/main/mc01/d_out
#add wave -noupdate -expand -group mc01 /stimulus/dut/main/mc01/e_out
#add wave -noupdate -expand -group mc01 /stimulus/dut/main/mc01/f_out
#add wave -noupdate -expand -group mc01 /stimulus/dut/main/mc01/g_out
#add wave -noupdate -expand -group mc01 /stimulus/dut/main/mc01/h_out
#add wave -noupdate -divider -height 32 "sha256 mc02"
#add wave -noupdate -expand -group mc02 /stimulus/dut/main/mc02/a_out
#add wave -noupdate -expand -group mc02 /stimulus/dut/main/mc02/b_out
#add wave -noupdate -expand -group mc02 /stimulus/dut/main/mc02/c_out
#add wave -noupdate -expand -group mc02 /stimulus/dut/main/mc02/d_out
#add wave -noupdate -expand -group mc02 /stimulus/dut/main/mc02/e_out
#add wave -noupdate -expand -group mc02 /stimulus/dut/main/mc02/f_out
#add wave -noupdate -expand -group mc02 /stimulus/dut/main/mc02/g_out
#add wave -noupdate -expand -group mc02 /stimulus/dut/main/mc02/h_out
#add wave -noupdate -divider -height 32 "sha256 mc03"
#add wave -noupdate -expand -group mc03 /stimulus/dut/main/mc03/a_out
#add wave -noupdate -expand -group mc03 /stimulus/dut/main/mc03/b_out
#add wave -noupdate -expand -group mc03 /stimulus/dut/main/mc03/c_out
#add wave -noupdate -expand -group mc03 /stimulus/dut/main/mc03/d_out
#add wave -noupdate -expand -group mc03 /stimulus/dut/main/mc03/e_out
#add wave -noupdate -expand -group mc03 /stimulus/dut/main/mc03/f_out
#add wave -noupdate -expand -group mc03 /stimulus/dut/main/mc03/g_out
#add wave -noupdate -expand -group mc03 /stimulus/dut/main/mc03/h_out
#add wave -noupdate -divider -height 32 "sha256 mc63"
#add wave -noupdate -expand -group mc63 /stimulus/dut/main/mc63/a_out
#add wave -noupdate -expand -group mc63 /stimulus/dut/main/mc63/b_out
#add wave -noupdate -expand -group mc63 /stimulus/dut/main/mc63/c_out
#add wave -noupdate -expand -group mc63 /stimulus/dut/main/mc63/d_out
#add wave -noupdate -expand -group mc63 /stimulus/dut/main/mc63/e_out
#add wave -noupdate -expand -group mc63 /stimulus/dut/main/mc63/f_out
#add wave -noupdate -expand -group mc63 /stimulus/dut/main/mc63/g_out
#add wave -noupdate -expand -group mc63 /stimulus/dut/main/mc63/h_out
#add wave -noupdate -divider -height 32 "sha256 mc64"
#add wave -noupdate -expand -group mc64 /stimulus/dut/main/mc64/a_out
#add wave -noupdate -expand -group mc64 /stimulus/dut/main/mc64/b_out
#add wave -noupdate -expand -group mc64 /stimulus/dut/main/mc64/c_out
#add wave -noupdate -expand -group mc64 /stimulus/dut/main/mc64/d_out
#add wave -noupdate -expand -group mc64 /stimulus/dut/main/mc64/e_out
#add wave -noupdate -expand -group mc64 /stimulus/dut/main/mc64/f_out
#add wave -noupdate -expand -group mc64 /stimulus/dut/main/mc64/g_out
#add wave -noupdate -expand -group mc64 /stimulus/dut/main/mc64/h_out
#add wave -noupdate -divider -height 32 "sha256 intermediate hash"
#add wave -noupdate -expand -group ih1 /stimulus/dut/main/ih1/*





-- Set Wave Output Items
TreeUpdate [SetDefaultTree]
WaveRestoreZoom {0 ps} {75 ns}
configure wave -namecolwidth 350
configure wave -valuecolwidth 200
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2

-- Run the Simulation
run 25 ns
quit
