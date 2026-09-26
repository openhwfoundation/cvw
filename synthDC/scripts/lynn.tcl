#
# Synthesis Synopsys Flow
# james.stine@okstate.edu 27 Sep 2015
#

# start run clock
set t1 [clock seconds]

# Ignore unnecessary warnings:
# intraassignment delays for nonblocking assignments are ignored
suppress_message {VER-130}
# statements in initial blocks are ignored
suppress_message {VER-281}
suppress_message {VER-173}
# Unsupported system task '$warn'
suppress_message {VER-274}
# Disable Warning:  Little argument or return value checking implemented for system task or function '$readmemh'. (VER-209)
suppress_message {VER-209}

# Enable Multicore
set_host_options -max_cores $::env(MAXCORES)

# get outputDir and configDir from environment (Makefile)
set outputDir $::env(OUTPUTDIR)
set cfg $::env(CONFIGDIR)
set hdl_src $::env(HDLDIR)
set saifpower $::env(SAIFPOWER)
set maxopt $::env(MAXOPT)
set drive $::env(DRIVE)
set width $::env(WIDTH)

set search_path "$search_path $outputDir/hdl"

# Build include-dir list from env var (allow space-separated dirs)
set incdirs {}
if {[info exists ::env(INCDIR)] && $::env(INCDIR) ne ""} {
    foreach d [split $::env(INCDIR)] { lappend incdirs $d }
}

set processortop ""
if {[info exists ::env(PROCESSORTOP)] && $::env(PROCESSORTOP) ne ""} {
    set processortop $::env(PROCESSORTOP)
}

# Presto uses search_path to find `include files (and also other source/library files)
set sp [get_app_var search_path]
set sp [concat [list . $outputDir/hdl $cfg] $incdirs $sp]
set_app_var search_path $sp

puts "DC search_path = $sp"

# Check if a wrapper is needed and create it (to pass parameters when cvw_t parameters are used)
set wrapper 0
if {[catch {exec grep "cvw_t" "$outputDir/hdl/$::env(DESIGN).sv"}] == 0} {
    echo "Creating wrapper"
    set wrapper 1
    # make the wrapper
    exec python3 $::env(WALLY)/synthDC/scripts/wrapperGen.py $::env(DESIGN) $outputDir/hdl
}

# Enables name mapping
if { $saifpower == 1 } {
    saif_map -start
}

# Set toplevel
if { $wrapper == 1 } {
    set my_toplevel $::env(DESIGN)wrapper
} else {
    set my_toplevel $::env(DESIGN)
}
set my_design $::env(DESIGN)

# Set number of significant digits
set report_default_significant_digits 6

# V(HDL) Unconnectoed Pins Output
set verilogout_show_unconnected_pins "true"
set vhdlout_show_unconnected_pins "true"

#  Set up MW List
set MY_LIB_NAME $my_toplevel
# Create MW
if { [shell_is_in_topographical_mode] } {
    echo "In Topographical Mode...processing\n"
    create_mw_lib  -technology $MW_REFERENCE_LIBRARY/$MW_TECH_FILE.tf \
        -mw_reference_library $mw_reference_library $outputDir/$MY_LIB_NAME
    # Open MW
    open_mw_lib $outputDir/$MY_LIB_NAME

    # TLU+
    set_tlu_plus_files -max_tluplus $MAX_TLU_FILE -min_tluplus $MIN_TLU_FILE \
    -tech2itf_map $PRS_MAP_FILE

} else {
    echo "In normal DC mode...processing\n"
}

# Due to parameterized Verilog must use analyze/elaborate and not
# read_verilog/vhdl (change to pull in Verilog and/or VHDL)
#
#set alib_library_analysis_path ./$outputDir
define_design_lib WORK -path ./$outputDir/WORK

set pkg_files  [glob -nocomplain $outputDir/hdl/*.pkg $outputDir/hdl/*pkg*.sv $outputDir/hdl/*Type*.sv $outputDir/hdl/*Package*.sv]
set sv_files   [glob -nocomplain $outputDir/hdl/*.sv]

# If you know exact package naming patterns, add them above.
# Analyze packages first (DC uses -define, not +define+...)
set analyze_defs {}
if {$processortop ne ""} {
    lappend analyze_defs -define "PROCESSORTOP=$processortop"
}

if {[llength $pkg_files] > 0} {
    foreach f $pkg_files {
        analyze -format sverilog -lib WORK {*}$analyze_defs $f
    }
}

# Then analyze the rest
foreach f $sv_files {
    analyze -format sverilog -lib WORK {*}$analyze_defs $f
}

# If wrapper=0, we want to run against a specific module and pass
# width to DC
if { $wrapper == 1 } {
    elaborate $my_toplevel -lib WORK
} else {
    elaborate $my_toplevel -lib WORK
}

# Set the current_design
current_design $my_toplevel
link

# Reset all constraints
reset_design

# Power Dissipation Analysis
######### OPTIONAL !!!!!!!!!!!!!!!!
if { $saifpower == 1 } {
    read_saif -input power.saif -instance_name testbench/dut/core -auto_map_names -verbose
}

# Set reset false path
if {$drive != "INV"} {
    set_false_path -from [get_ports reset]
}
# for PPA multiplexer synthesis
if {(($::env(DESIGN) == "ppa_mux2d_1") || ($::env(DESIGN) == "ppa_mux4d_1") || ($::env(DESIGN) == "ppa_mux8d_1"))} {
    set_false_path -from {s}
}

# Set Frequency in [MHz] or period in [ns]
set my_clock_pin clk
set my_uncertainty 0.0
set my_clk_freq_MHz $::env(FREQ)
set my_period [expr 1000.0 / $my_clk_freq_MHz]

# Create clock object
set find_clock [ find port [list $my_clock_pin] ]
if {  $find_clock != [list] } {
    echo "Found clock!"
    set my_clk $my_clock_pin
    create_clock -period $my_period $my_clk
    set_clock_uncertainty $my_uncertainty [get_clocks $my_clk]
} else {
    echo "Did not find clock! Design is probably combinational!"
    set my_clk vclk
    create_clock -period $my_period -name $my_clk
}


# Optimize paths that are close to critical
set_critical_range 0.05 $current_design

# Partitioning - flatten or hierarchically synthesize
if { $maxopt == 1 } {
    ungroup -all -simple_names -flatten
}

# Set input pins except clock
set all_in_ex_clk [remove_from_collection [all_inputs] [get_ports $my_clk]]

# Specifies delays be propagated through the clock network
# This is getting optimized poorly in the current flow, causing a lot of clock skew
# and unrealistic bad timing results.
# set_propagated_clock [get_clocks $my_clk]

# Setting constraints on input ports
if {$tech == "sky130"} {
    if {$drive == "INV"} {
        set_driving_cell -lib_cell inv -pin Y $all_in_ex_clk
    } elseif {$drive == "FLOP"} {
        set_driving_cell  -lib_cell sky130_osu_sc_12T_ms__dff_1 -pin Q $all_in_ex_clk
    }
} elseif {$tech == "sky90"} {
    if {$drive == "INV"} {
        set_driving_cell -lib_cell scc9gena_inv_1 -pin Y $all_in_ex_clk
    } elseif {$drive == "FLOP"} {
        set_driving_cell  -lib_cell scc9gena_dfxbp_1 -pin Q $all_in_ex_clk
    }
} elseif {$tech == "tsmc28" || $tech=="tsmc28psyn"} {
    if {$drive == "INV"} {
        set_driving_cell -lib_cell INVD1BWP30P140 -pin ZN $all_in_ex_clk
    } elseif {$drive == "FLOP"} {
        set_driving_cell -lib_cell DFQD1BWP30P140 -pin Q $all_in_ex_clk
    }
}

# Set input/output delay
if {$drive == "FLOP"} {
    set_input_delay 0.0 -max -clock $my_clk $all_in_ex_clk
    set_output_delay 0.0 -max -clock $my_clk [all_outputs]
} else {
    set_input_delay 0.0 -max -clock $my_clk $all_in_ex_clk
    set_output_delay 0.0 -max -clock $my_clk [all_outputs]
}

#####################################################################
# External memory interface timing model
# Goal: model SRAM read-data arriving 2ns after clk edge at our inputs
#####################################################################

# Instruction memory read data (coming INTO chip)
set_input_delay 3.0 -clock $my_clk -max [get_ports {Instr[*]}]
set_input_delay 0.2 -clock $my_clk -min [get_ports {Instr[*]}]

# Instruction memory address (going OUT of chip)
set_output_delay [expr $my_period - 0.5] -clock $my_clk -max [get_ports {PC[*]}]
set_output_delay 0.0 -clock $my_clk -min [get_ports {PC[*]}]

# Data memory read data (coming INTO chip)
set_input_delay 3.0 -clock $my_clk -max [get_ports {MemReadData[*]}]
set_input_delay 0.2 -clock $my_clk -min [get_ports {MemReadData[*]}]

# Data memory control/address/write data (going OUT of chip)
set_output_delay [expr $my_period - 0.5] -clock $my_clk -max \
    [get_ports {MemEn WriteEn WriteByteEn[*] DataAdr[*] WriteData[*]}]

set_output_delay 0.0 -clock $my_clk -min \
    [get_ports {MemEn WriteEn WriteByteEn[*] DataAdr[*] WriteData[*]}]

# Setting load constraint on output ports
if {$tech == "sky130"} {
    if {$drive == "INV"} {
        set_load [expr [load_of sky130_osu_sc_12T_ms_TT_1P8_25C.ccs/sky130_osu_sc_12T_ms__inv_4/A] * 1] [all_outputs]
    } elseif {$drive == "FLOP"} {
        set_load [expr [load_of sky130_osu_sc_12T_ms_TT_1P8_25C.ccs/sky130_osu_sc_12T_ms__dff_1/D] * 1] [all_outputs]
    }
} elseif {$tech == "sky90"} {
    if {$drive == "INV"} {
        set_load [expr [load_of scc9gena_tt_1.2v_25C/scc9gena_inv_4/A] * 1] [all_outputs]
    } elseif {$drive == "FLOP"} {
        set_load [expr [load_of scc9gena_tt_1.2v_25C/scc9gena_dfxbp_1/D] * 1] [all_outputs]
    }
} elseif {$tech == "tsmc28" || $tech == "tsmc28psyn"} {
    if {$drive == "INV"} {
        set_load [expr [load_of tcbn28hpcplusbwp30p140tt0p9v25c/INVD4BWP30P140/I] * 1] [all_outputs]
    } elseif {$drive == "FLOP"} {
        set_load [expr [load_of tcbn28hpcplusbwp30p140tt0p9v25c/DFQD1BWP30P140/D] * 1] [all_outputs]
    }
}

if {$tech != "tsmc28psyn"} {
    # Set the wire load model
    set_wire_load_mode "top"
}

# Set switching activities
# default activity factors are 1 for clocks, 0.1 for others
# static probability of 0.5 is used for leakage

# Attempt Area Recovery - if looking for minimal area
# set_max_area 2000

# Set fanout
set_max_fanout 6 $all_in_ex_clk

# Fix hold time violations (DH: this doesn't seem to be working right now)
#set_fix_hold [all_clocks]

# Deal with constants and buffers to isolate ports
set_fix_multiple_port_nets -all -buffer_constants

# setting up the group paths to find out the required timings
# group_path -name OUTPUTS -to [all_outputs]
# group_path -name INPUTS -from [all_inputs]
# group_path -name COMBO -from [all_inputs] -to [all_outputs]

# Save Unmapped Design
# set filename [format "%s%s%s%s" $outputDir "/unmapped/" $my_toplevel ".ddc"]
# write_file -format ddc -hierarchy -o $filename

# Compile statements
if { $maxopt == 1 } {
    compile_ultra -retime
    optimize_registers
} else {
    compile_ultra -no_seq_output_inversion -no_boundary_optimization
}

# Eliminate need for assign statements (yuck!)
set verilogout_no_tri true
set verilogout_equation false

# setting to generate output files
set write_v    1        ;# generates structural netlist
set write_sdc  1        ;# generates synopsys design constraint file for p&r
set write_ddc  1        ;# compiler file in ddc format
set write_sdf  1        ;# sdf file for backannotated timing sim
set write_pow  1        ;# generates estimated power report
set write_rep  1        ;# generates estimated area and timing report
set write_cst  1        ;# generate report of constraints
set write_hier 1        ;# generate hierarchy report

# Report on DESIGN, not wrapper.  However, design has a suffix for the parameters.
if { $wrapper == 1 } {
    set designname [format "%s%s" $my_design "__*"]
    current_design $designname

    # recreate clock below wrapper level or reporting doesn't work properly
    set find_clock [ find port [list $my_clock_pin] ]
    if {  $find_clock != [list] } {
        echo "Found clock!"
        set my_clk $my_clock_pin
        create_clock -period $my_period $my_clk
        set_clock_uncertainty $my_uncertainty [get_clocks $my_clk]
    } else {
        echo "Did not find clock! Design is probably combinational!"
        set my_clk vclk
        create_clock -period $my_period -name $my_clk
    }
}

# Report Constraint Violators
set filename [format "%s%s" $outputDir "/reports/constraint_all_violators.rpt"]
redirect $filename {report_constraint -all_violators}

# Check design
redirect $outputDir/reports/check_design.rpt { check_design }

# Report Final Netlist (Hierarchical)
set filename [format "%s%s%s%s" $outputDir "/mapped/" $my_design ".sv"]
write_file -f verilog -hierarchy -output $filename

set filename [format "%s%s%s%s" $outputDir "/mapped/" $my_design ".sdc"]
write_sdc $filename

set filename [format "%s%s%s%s" $outputDir  "/mapped/" $my_design ".ddc"]
write_file -format ddc -hierarchy -o $filename

set filename [format "%s%s%s%s" $outputDir "/mapped/" $my_design ".sdf"]
write_sdf $filename

# Write SPEF file in case need more precision power exploration for TSMC28psyn
if {$tech == "tsmc28psyn"} {
    set filename [format "%s%s%s%s" $outputDir "/mapped/" $my_toplevel ".spef"]
    redirect $filename { write_parasitics }
}

# QoR
set filename [format "%s%s"  $outputDir "/reports/qor.rep"]
redirect $filename { report_qor }

# Report Timing
set filename [format "%s%s" $outputDir "/reports/reportpath.rep"]
#redirect $filename { report_path_group }

set filename [format "%s%s" $outputDir "/reports/report_clock.rep"]
# redirect $filename { report_clock }

set filename [format "%s%s" $outputDir  "/reports/timing.rep"]
redirect $filename { report_timing -capacitance -transition_time -nets -nworst 1 }

set filename [format "%s%s" $outputDir  "/reports/mindelay.rep"]
redirect $filename { report_timing -capacitance -transition_time -nets -delay_type min -nworst 1 }

set filename [format "%s%s" $outputDir  "/reports/per_module_timing.rep"]
redirect -append $filename { echo "\n\n\n//// Critical paths through Stall ////\n\n\n" }
redirect -append $filename { report_timing -capacitance -transition_time -nets -through {Stall*} -nworst 1 }
redirect -append $filename { echo "\n\n\n//// Critical paths through ifu ////\n\n\n" }
redirect -append $filename { report_timing -capacitance -transition_time -nets -through {ifu/*} -nworst 1 }
redirect -append $filename { echo "\n\n\n//// Critical paths through ieu ////\n\n\n" }
redirect -append $filename { report_timing -capacitance -transition_time -nets -through {ieu/*} -nworst 1 }
redirect -append $filename { echo "\n\n\n//// Critical paths through lsu ////\n\n\n" }
redirect -append $filename { report_timing -capacitance -transition_time -nets -through {lsu/*} -nworst 1 }
redirect -append $filename { echo "\n\n\n//// Critical paths through ebu (ahblite) ////\n\n\n" }
redirect -append $filename { report_timing -capacitance -transition_time -nets -through {ebu/*} -nworst 1 }
redirect -append $filename { echo "\n\n\n//// Critical paths through mdu ////\n\n\n" }
redirect -append $filename { report_timing -capacitance -transition_time -nets -through {mdu.mdu/*} -nworst 1 }
redirect -append $filename { echo "\n\n\n//// Critical paths through hzu ////\n\n\n" }
redirect -append $filename { report_timing -capacitance -transition_time -nets -through {hzu/*} -nworst 1 }
redirect -append $filename { echo "\n\n\n//// Critical paths through priv ////\n\n\n" }
redirect -append $filename { report_timing -capacitance -transition_time -nets -through {priv/*} -nworst 1 }
redirect -append $filename { echo "\n\n\n//// Critical paths through fpu ////\n\n\n" }
redirect -append $filename { report_timing -capacitance -transition_time -nets -through {fpu/*} -nworst 1 }

set filename [format "%s%s" $outputDir  "/reports/mdu_timing.rep"]
redirect -append $filename { echo "\n\n\n//// Critical paths through entire mdu ////\n\n\n" }
redirect -append $filename { report_timing -capacitance -transition_time -nets -through {mdu.mdu/*} -nworst 1 }
redirect -append $filename { echo "\n\n\n//// Critical paths through multiply unit ////\n\n\n" }
redirect -append $filename { report_timing -capacitance -transition_time -nets -through {mdu.mdu/genblk1.mul/*} -nworst 1 }
redirect -append $filename { echo "\n\n\n//// Critical paths through redundant multiplier ////\n\n\n" }
redirect -append $filename { report_timing -capacitance -transition_time -nets -through {mdu.mdu/genblk1.mul/bigmul/*} -nworst 1 }
redirect -append $filename { echo "\n\n\n//// Critical path through ProdM (mul output) ////\n\n\n" }
redirect -append $filename { report_timing -capacitance -transition_time -nets -through {mdu.mdu/genblk1.ProdM} -nworst 1 }
redirect -append $filename { echo "\n\n\n//// Critical path through PP0E (mul partial product) ////\n\n\n" }
redirect -append $filename { report_timing -capacitance -transition_time -nets -through {mdu.mdu/genblk1.mul/PP0E} -nworst 1 }
redirect -append $filename { echo "\n\n\n//// Critical paths through divide unit ////\n\n\n" }
redirect -append $filename { report_timing -capacitance -transition_time -nets -through {mdu.mdu/genblk1.div/*} -nworst 1 }
redirect -append $filename { echo "\n\n\n//// Critical path through QuotM (div output) ////\n\n\n" }
redirect -append $filename { report_timing -capacitance -transition_time -nets -through {mdu.mdu/genblk1.QuotM} -nworst 1 }
redirect -append $filename { echo "\n\n\n//// Critical path through RemM (div output) ////\n\n\n" }
redirect -append $filename { report_timing -capacitance -transition_time -nets -through {mdu.mdu/genblk1.RemM} -nworst 1 }
redirect -append $filename { echo "\n\n\n//// Critical path through div/WNextE ////\n\n\n" }
redirect -append $filename { report_timing -capacitance -transition_time -nets -through {mdu.mdu/genblk1.div/WNextE} -nworst 1 }
redirect -append $filename { echo "\n\n\n//// Critical path through div/XQNextE ////\n\n\n" }
redirect -append $filename { report_timing -capacitance -transition_time -nets -through {mdu.mdu/genblk1.div/XQNextE} -nworst 1 }
redirect -append $filename { echo "\n\n\n//// Critical path through div/DAbsBE ////\n\n\n" }
redirect -append $filename { report_timing -capacitance -transition_time -nets -through {mdu.mdu/genblk1.div/DAbsBE} -nworst 1 }

# set filename [format "%s%s%s%s" $outputDir  "/reports/fpu_timing.rep"]
# redirect $filename { echo "\n\n\n//// Critical paths through fma ////\n\n\n" }
# redirect -append $filename { report_timing -capacitance -transition_time -nets -through {fpu/fpu.fma/*} -nworst 1 }
# redirect -append $filename { echo "\n\n\n//// Critical paths through fpdiv ////\n\n\n" }
# redirect -append $filename { report_timing -capacitance -transition_time -nets -through {fpu/fpu.fdivsqrt/*} -nworst 1 }
# redirect -append $filename { echo "\n\n\n//// Critical paths through faddcvt ////\n\n\n" }
# redirect -append $filename { report_timing -capacitance -transition_time -nets -through {fpu/fpu.faddcvt/*} -nworst 1 }

# set filename [format "%s%s%s%s" $outputDir  "/reports/ifu_timing.rep"]
# redirect -append $filename { echo "\n\n\n//// Critical path through PCF ////\n\n\n" }
# redirect -append $filename { report_timing -capacitance -transition_time -nets -through {ifu/PCF} -nworst 1 }
# redirect -append $filename { echo "\n\n\n//// Critical path through PCNextF ////\n\n\n" }
# redirect -append $filename { report_timing -capacitance -transition_time -nets -through {ifu/PCNextF} -nworst 1 }
# redirect -append $filename { echo "\n\n\n//// Critical path through FinalInstrRawF ////\n\n\n" }
# redirect -append $filename { report_timing -capacitance -transition_time -nets -through {ifu/FinalInstrRawF} -nworst 1 }
# redirect -append $filename { echo "\n\n\n//// Critical path through InstrD ////\n\n\n" }
# redirect -append $filename { report_timing -capacitance -transition_time -nets -through {ifu/decomp/InstrD} -nworst 1 }

# set filename [format "%s%s%s%s" $outputDir  "/reports/stall_flush_timing.rep"]
# redirect -append $filename { echo "\n\n\n//// Critical path through StallD ////\n\n\n" }
# redirect -append $filename { report_timing -capacitance -transition_time -nets -through {ieu/StallD} -nworst 1 }
# redirect -append $filename { echo "\n\n\n//// Critical path through StallE ////\n\n\n" }
# redirect -append $filename { report_timing -capacitance -transition_time -nets -through {ieu/StallE} -nworst 1 }
# redirect -append $filename { echo "\n\n\n//// Critical path through StallM ////\n\n\n" }
# redirect -append $filename { report_timing -capacitance -transition_time -nets -through {ieu/StallM} -nworst 1 }
# redirect -append $filename { echo "\n\n\n//// Critical path through StallW ////\n\n\n" }
# redirect -append $filename { report_timing -capacitance -transition_time -nets -through {ieu/StallW} -nworst 1 }
# redirect -append $filename { echo "\n\n\n//// Critical path through FlushD ////\n\n\n" }
# redirect -append $filename { report_timing -capacitance -transition_time -nets -through {ieu/FlushD} -nworst 1 }
# redirect -append $filename { echo "\n\n\n//// Critical path through FlushE ////\n\n\n" }
# redirect -append $filename { report_timing -capacitance -transition_time -nets -through {ieu/FlushE} -nworst 1 }
# redirect -append $filename { echo "\n\n\n//// Critical path through FlushM ////\n\n\n" }
# redirect -append $filename { report_timing -capacitance -transition_time -nets -through {ieu/FlushM} -nworst 1 }
# redirect -append $filename { echo "\n\n\n//// Critical path through FlushW ////\n\n\n" }
# redirect -append $filename { report_timing -capacitance -transition_time -nets -through {ieu/FlushW} -nworst 1 }

# set filename [format "%s%s%s%s" $outputDir  "/reports/ieu_timing.rep"]
# redirect -append $filename { echo "\n\n\n//// Critical path through datapath/R1D ////\n\n\n" }
# redirect -append $filename { report_timing -capacitance -transition_time -nets -through {ieu/dp/R1D} -nworst 1 }
# redirect -append $filename { echo "\n\n\n//// Critical path through datapath/R2D ////\n\n\n" }
# redirect -append $filename { report_timing -capacitance -transition_time -nets -through {ieu/dp/R2D} -nworst 1 }
# redirect -append $filename { echo "\n\n\n//// Critical path through datapath/SrcAE ////\n\n\n" }
# redirect -append $filename { report_timing -capacitance -transition_time -nets -through {ieu/dp/SrcAE} -nworst 1 }
# redirect -append $filename { echo "\n\n\n//// Critical path through datapath/ALUResultE ////\n\n\n" }
# redirect -append $filename { report_timing -capacitance -transition_time -nets -through {ieu/dp/ALUResultE} -nworst 1 }
# redirect -append $filename { echo "\n\n\n//// Critical path through datapath/WriteDataW ////\n\n\n" }
# redirect -append $filename { report_timing -capacitance -transition_time -nets -through {ieu/dp/WriteDataW} -nworst 1 }
# redirect -append $filename { echo "\n\n\n//// Critical path through datapath/ReadDataM ////\n\n\n" }
# redirect -append $filename { report_timing -capacitance -transition_time -nets -through {ieu/dp/ReadDataM} -nworst 1 }

# set filename [format "%s%s%s%s" $outputDir  "/reports/fpu_timing.rep"]
# redirect -append $filename { echo "\n\n\n//// Critical paths through fma ////\n\n\n" }
# redirect -append $filename { report_timing -capacitance -transition_time -nets -through {fma/*} -nworst 1 }
# redirect -append $filename { echo "\n\n\n//// Critical paths through fma1 ////\n\n\n" }
# redirect -append $filename { report_timing -capacitance -transition_time -nets -through {fma/fma1/*} -nworst 1 }
# redirect -append $filename { echo "\n\n\n//// Critical paths through fma2 ////\n\n\n" }
# redirect -append $filename { report_timing -capacitance -transition_time -nets -through {postprocess/*} -nworst 1 }
# redirect -append $filename { echo "\n\n\n//// Critical paths through fpdiv ////\n\n\n" }
# redirect -append $filename { report_timing -capacitance -transition_time -nets -through {divsqrt/*} -nworst 1 }
# redirect -append $filename { echo "\n\n\n//// Critical paths through fcvt ////\n\n\n" }
# redirect -append $filename { report_timing -capacitance -transition_time -nets -through {fcvt/*} -nworst 1 }

# set filename [format "%s%s%s%s" $outputDir  "/reports/mmu_timing.rep"]
# redirect -append $filename { echo "\n\n\n//// Critical paths through immu/physicaladdress ////\n\n\n" }
# redirect -append $filename { report_timing -capacitance -transition_time -nets -through {ifu/immu/PhysicalAddress} -nworst 1 }
# redirect -append $filename { echo "\n\n\n//// Critical paths through dmmu/physicaladdress ////\n\n\n" }
# redirect -append $filename { report_timing -capacitance -transition_time -nets -through {lsu/dmmu/PhysicalAddress} -nworst 1 }

# set filename [format "%s%s%s%s" $outputDir  "/reports/priv_timing.rep"]
# redirect -append $filename { echo "\n\n\n//// Critical paths through priv/TrapM ////\n\n\n" }
# redirect -append $filename { report_timing -capacitance -transition_time -nets -through {priv/TrapM} -nworst 1 }
# redirect -append $filename { echo "\n\n\n//// Critical paths through priv/CSRReadValM ////\n\n\n" }
# redirect -append $filename { report_timing -capacitance -transition_time -nets -through {priv/csr/CSRReadValM} -nworst 1 }
# redirect -append $filename { echo "\n\n\n//// Critical paths through priv/CSRReadValW ////\n\n\n" }
# redirect -append $filename { report_timing -capacitance -transition_time -nets -through {priv/CSRReadValW} -nworst 1 }

set filename [format "%s%s" $outputDir  "/reports/area.rep"]
redirect $filename { report_area -hierarchy -nosplit -physical -designware}

set filename [format "%s%s" $outputDir  "/reports/cell.rep"]
#redirect $filename { report_cell [get_cells -hier *] }  # not too useful

set filename [format "%s%s" $outputDir  "/reports/power.rep"]
redirect $filename { report_power -hierarchy -levels 1 }

set filename [format "%s%s" $outputDir  "/reports/constraint.rep"]
redirect $filename { report_constraint }

set filename [format "%s%s" $outputDir  "/reports/hier.rep"]
# redirect $filename { report_hierarchy }

# end run clock and echo run time in minutes
set t2 [clock seconds]
set t [expr $t2 - $t1]
echo [expr $t/60]

quit
