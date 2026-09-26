# wally-run.do
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Runs a simulation against an already-compiled Questa work library
# produced by wally-compile.do.
#
# Usage: vsim -c -do "do wally-run.do <config> <testsuite> <testbench> <wkdir> [flags...] [--args \"...\"]"
# Flags: --ccov --fcov --lockstep --breker --gui
#
# James Stine, 2008; David Harris 2021; Jordan Carlin 2024, 2026

# lcheck - return 1 if value is in list and remove it from list
proc lcheck {listVariable value} {
    upvar 1 $listVariable list
    set index [lsearch -exact $list $value]
    if {$index >= 0} {
        set list [lreplace $list $index $index]
        return 1
    } else {
        return 0
    }
}

set DEBUG 1
onbreak {resume}
onerror {quit -f}

# Initialize variables
set CFG ${1}
set TESTSUITE ${2}
set TESTBENCH ${3}
set WKDIR ${4}
set WALLY $::env(WALLY)

# Shift off the first four arguments (config, testsuite, testbench, wkdir)
shift
shift
shift
shift

# Copy the remaining arguments into a list
set lst {}
while {$argc > 0} {
    lappend lst [expr "\$1"]
    shift
}

# Parse flags
set GUI 0
if {[lcheck lst "--gui"]} {
    set GUI 1
}

# VCD flag (currently unused in run but parsed for completeness)
if {[lcheck lst "--vcd"]} {
}

set ccov 0
set CoverageVsimArg ""
if {[lcheck lst "--ccov"]} {
    set ccov 1
    set CoverageVsimArg "-coverage"
}

set FunctCoverage 0
if {[lcheck lst "--fcov"]} {
    set FunctCoverage 1
}

set SVLib ""
if {[lcheck lst "--lockstep"]} {
    set IMPERAS_HOME $::env(IMPERAS_HOME)
    set SVLib " -sv_lib ${IMPERAS_HOME}/lib/Linux64/ImperasLib/imperas.com/verification/riscv/1.0/model "
}

if {[lcheck lst "--breker"]} {
    set BREKER_HOME $::env(BREKER_HOME)
    append SVLib " -sv_lib ${BREKER_HOME}/linux64/lib/libtrek "
}

# Parse --args flag (runtime plusargs)
set PlusArgs ""
set PlusArgsIndex [lsearch -exact $lst "--args"]
if {$PlusArgsIndex >= 0} {
    set PlusArgs [lindex $lst [expr {$PlusArgsIndex + 1}]]
    set lst [lreplace $lst $PlusArgsIndex [expr {$PlusArgsIndex + 1}]]
}

if {$DEBUG > 0} {
    echo "GUI = $GUI"
    echo "ccov = $ccov"
    echo "FunctCoverage = $FunctCoverage"
    echo "Extra +args = $PlusArgs"
}

# Run simulation against the pre-compiled design
vsim -lib ${WKDIR} testbenchopt +TEST=${TESTSUITE} {*}${PlusArgs} -fatal 7 {*}${SVLib} -suppress 3829 ${CoverageVsimArg}

# Add waveforms if GUI is enabled
if { ${GUI} } {
    add log -recursive /*
    if { ${TESTBENCH} eq "testbench_fp" } {
        do wave-fpu.do
    } else {
        do wave.do
    }
}

if {$FunctCoverage} {
    set UCDB ${WALLY}/sim/questa/fcov_ucdb/${CFG}_${TESTSUITE}.ucdb
    coverage save -onexit ${UCDB}
}

run -all

if {$ccov} {
    set UCDB ${WALLY}/sim/questa/ucdb/${CFG}_${TESTSUITE}.ucdb
    echo "Saving coverage to ${UCDB}"
    do coverage-exclusions-rv64gc.do
    coverage save -instance /testbench/dut/core ${UCDB}
}

# Terminate simulation unless we need to keep the GUI running
if { ${GUI} == 0} {
    quit
}
