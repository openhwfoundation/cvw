# wally-compile.do
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Compiles and elaborates the Wally design for Questa simulation.
# Produces an optimized design (testbenchopt) in a shared work library
# that can be reused across multiple test runs with wally-run.do.
# Called by wally-compile.sh which handles flock serialization.
#
# Usage: vsim -c -do "do wally-compile.do <config> <testbench> <wkdir> [flags...] [--params \"...\"] [--define \"...\"]"
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

onerror {quit -f}

# Initialize variables
set CFG ${1}
set TESTBENCH ${2}
set WKDIR ${3}
set WALLY $::env(WALLY)
set CONFIG ${WALLY}/config
set SRC ${WALLY}/src
set TB ${WALLY}/testbench
set FCRVVI ${WALLY}/addins/cvw-arch-verif/fcov

# Shift off the first three arguments (config, testbench, wkdir)
shift
shift
shift

# Copy the remaining arguments into a list
set lst {}
while {$argc > 0} {
    lappend lst [expr "\$1"]
    shift
}

# Parse compile-time flags
set CoverageVoptArg ""
if {[lcheck lst "--ccov"]} {
    set CoverageVoptArg "+cover=sbecf"
}

set FCvlog ""
if {[lcheck lst "--fcov"]} {
    set FCvlog "-f ${FCRVVI}/cvw-arch-verif.f"
}

set lockstepvlog ""
set lockstep 0
if {[lcheck lst "--lockstep"]} {
    set IMPERAS_HOME $::env(IMPERAS_HOME)
    set lockstep 1
    set lockstepvlog "+incdir+${IMPERAS_HOME}/ImpPublic/include/host \
                      +incdir+${IMPERAS_HOME}/ImpPublic/include/host/rvvi \
                      +incdir+${IMPERAS_HOME}/ImpProprietary/include/host \
                      +incdir+${IMPERAS_HOME}/ImpProprietary/include/host/idv \
                      ${IMPERAS_HOME}/ImpPublic/source/host/rvvi/rvviApiPkg.sv \
                      ${IMPERAS_HOME}/ImpProprietary/source/host/idv/*.sv"
    if {$FCvlog eq ""} {append lockstepvlog " ${IMPERAS_HOME}/ImpPublic/source/host/rvvi/rvviTrace.sv"}
}

set brekervlog ""
set brekervopt ""
if {[lcheck lst "--breker"]} {
    set brekervlog "+incdir+${WALLY}/testbench/trek_files \
                    $::env(WALLY_UVM_PKG)"
    set brekervopt "${WKDIR}.trek_uvm"
}

set accFlag ""
if {[lcheck lst "--gui"]} {
    set accFlag "+acc"
}

# Parse --params flag
set ExpandedParamArgs {}
set ParamArgsIndex [lsearch -exact $lst "--params"]
if {$ParamArgsIndex >= 0} {
    set ParamArgs [lindex $lst [expr {$ParamArgsIndex + 1}]]
    set ParamArgs [regexp -all -inline {\S+} $ParamArgs]
    foreach param $ParamArgs {
        lappend ExpandedParamArgs -G$param
    }
    set lst [lreplace $lst $ParamArgsIndex [expr {$ParamArgsIndex + 1}]]
}

# Parse --define flag
set DefineArgs ""
set DefineArgsIndex [lsearch -exact $lst "--define"]
if {$DefineArgsIndex >= 0} {
    set DefineArgs [lindex $lst [expr {$DefineArgsIndex + 1}]]
    set lst [lreplace $lst $DefineArgsIndex [expr {$DefineArgsIndex + 1}]]
}

# Create work library
if [file exists ${WKDIR}] {
    vdel -lib ${WKDIR} -all
}
vlib ${WKDIR}

# Compile source files
# suppress spurious warnings about
# "Extra checking for conflicts with always_comb done at vopt time"
# because vsim will run vopt
set INC_DIRS "+incdir+${CONFIG}/${CFG} +incdir+${CONFIG}/deriv/${CFG} +incdir+${CONFIG}/shared"
set SOURCES "${SRC}/cvw.sv ${TB}/${TESTBENCH}.sv ${TB}/common/*.sv ${SRC}/*/*.sv ${SRC}/*/*/*.sv ${WALLY}/addins/verilog-ethernet/*/*.sv ${WALLY}/addins/verilog-ethernet/*/*/*/*.sv"
vlog -permissive -lint -work ${WKDIR} {*}${INC_DIRS} {*}${DefineArgs} {*}${lockstepvlog} {*}${FCvlog} {*}${brekervlog} {*}${SOURCES} -suppress 2282,2583,7053,7063,2596,13286,2605,2250

# Elaborate the design
vopt $accFlag ${WKDIR}.${TESTBENCH} ${brekervopt} -work ${WKDIR} {*}${ExpandedParamArgs} -o testbenchopt ${CoverageVoptArg}

quit
