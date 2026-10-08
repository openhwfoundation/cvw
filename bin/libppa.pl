#!/usr/bin/env perl

###########################################
## libppa.pl
##
## Written: David_Harris@hmc.edu
## Created: 28 January 2023
##
## Purpose: Extract PPA information from Liberty files
##          presently characterizes Skywater 90 and TSMC28hpc+
##
## The user will need to change $libpath to point to the desired library in your local installation
## and for TSMC change the $cellname to the actual name of the inverter.
##
## A component of the CORE-V-WALLY configurable RISC-V project.
## https://github.com/openhwfoundation/cvw
##
## Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
##
## SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
##
## Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
## except in compliance with the License, or, at your option, the Apache License version 2.0. You
## may obtain a copy of the License at
##
## https://solderpad.org/licenses/SHL-2.1/
##
## Unless required by applicable law or agreed to in writing, any work distributed under the
## License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
## either express or implied. See the License for the specific language governing permissions
## and limitations under the License.
################################################################################################

use strict;
use warnings;

# global variables for simplicity
my @index1; my @index2;
my @values;
my @cr; my @cf; my @rt; my @ft;

# cell and corners to analyze
my $libpath; my $libbase; my $cellname; my @corners;

# Sky130
$libpath ="$ENV{RISCV}/cad/lib/sky130_osu_sc_t12/12T_ms/lib";
$libbase = "sky130_osu_sc_12T_ms_";
$cellname = "sky130_osu_sc_12T_ms__inv_1";
@corners = ("TT_1P8_25C.ccs", "tt_1P80_25C.ccs", "tt_1P62_25C.ccs", "tt_1P89_25C.ccs", "ss_1P60_-40C.ccs", "ss_1P60_100C.ccs", "ss_1P60_150C.ccs", "ff_1P95_-40C.ccs", "ff_1P95_100C.ccs", "ff_1P95_150C.ccs");
printf("Library $libbase Cell $cellname\n");
foreach my $corner (@corners) {
    &analyzeCell($corner);
}

# Sky90
$libpath ="$ENV{RISCV}/cad/lib/sky90/sky90_sc/V1.7.4/lib";
$libbase = "scc9gena_";
$cellname = "scc9gena_inv_1";
@corners = ("tt_1.2v_25C", "tt_1.08v_25C", "tt_1.32v_25C", "tt_1.2v_-40C", "tt_1.2v_85C", "tt_1.2v_125C", "ss_1.2v_25C", "ss_1.08v_-40C", "ss_1.08v_25C", "ss_1.08v_125C", "ff_1.2v_25C", "ff_1.32v_-40C", "ff_1.32v_25C", "ff_1.32v_125C");
printf("Library $libbase Cell $cellname\n");
foreach my $corner (@corners) {
    &analyzeCell($corner);
}

# TSMC
$libpath = "/proj/models/tsmc28/libraries/28nmtsmc/tcbn28hpcplusbwp30p140_190a/TSMCHOME/digital/Front_End/timing_power_noise/NLDM/tcbn28hpcplusbwp30p140_180a";
$libbase = "tcbn28hpcplusbwp30p140";
$cellname = "INVD1..."; # replace this with the full name of the library cell
@corners = ("tt0p9v25c", "tt0p8v25c", "tt1v25c", "tt0p9v85c", "ssg0p9vm40c", "ssg0p9v125c", "ssg0p81vm40c", "ssg0p81v125c", "ffg0p88vm40c", "ffg0p88v125c", "ffg0p99vm40c", "ffg0p99v125c");
printf("\nLibrary $libbase Cell $cellname\n");
foreach my $corner (@corners) {
    &analyzeCell($corner);
}

#############
# subroutines
#############

sub analyzeCell {
    my $corner = shift;
    my $fname = $libpath."/".$libbase.$corner.".lib";
    open (FILE, $fname) || die("Can't read $fname");
    my $incell = 0;
    my $inleakage = 0;
    my $inpin = 0;
    my $incellrise = 0;
    my $incellfall = 0;
    my $inrisetrans = 0;
    my $infalltrans = 0;
    my $inindex = 0;
    my $invalues = 0;
    my $searchstring = "cell (".$cellname.")";
    my $area; my $leakage; my $cap;
     while (<FILE>) {
    if (index($_, $searchstring) != -1) { $incell = 1;}
    elsif ($incell) {
        if (/cell \(/) {
        $incell = 0;
        close(FILE);
        last;
        }
        if (/area\s*:\s*(.*);/) { $area = $1; }
        if (/cell_leakage_power\s*:\s*(.*);/) { $leakage = $1; $inleakage = 2; }
        if ($inleakage == 0 && /leakage_power/) { $inleakage = 1; }
        if ($inleakage == 1 && /value\s*:\s*(.*);/) {
        $leakage = $1;
        $inleakage = 2;
        }
        if ($inpin == 0 && /pin/) { $inpin = 1; }
        if ($inpin == 1 && /\s+capacitance\s*:\s*(.*);/) {
        $cap = $1;
        $inpin = 2;
        }
        if ($inindex == 0 && /index_1/) { $inindex = 1; }
        if ($inindex == 1) {
        if (/index_1\s*\(\"(.*)\"\);/) { @index1 = split(/, /, $1); }
        if (/index_2\s*\(\"(.*)\"\);/) { @index2 = split(/, /, $1); $inindex = 2; }
        }
        if ($incellrise == 0 && /cell_rise/) { $incellrise = 1; $invalues = 0;}
        if ($incellfall == 0 && /cell_fall/) { $incellfall = 1; $invalues = 0; }
        if ($inrisetrans == 0 && /rise_trans/) { $inrisetrans = 1; $invalues = 0; }
        if ($infalltrans == 0 && /fall_trans/) { $infalltrans = 1; $invalues = 0; }
        if ($incellrise == 1 || $incellfall == 1 || $inrisetrans == 1 || $infalltrans == 1) {
        if (/values/) { $invalues = 1; @values = (); }
        elsif ($invalues == 1) {
            if (/\);/) {
            $invalues = 2;
            if ($incellrise == 1) { @cr = &parseVals(); $incellrise = 2; }
            if ($incellfall == 1) { @cf = &parseVals(); $incellfall = 2; }
            if ($inrisetrans == 1) { @rt = &parseVals(); $inrisetrans = 2; }
            if ($infalltrans == 1) { @ft = &parseVals(); $infalltrans = 2; }
            }
            elsif (/\"(.*)\"/) { push(@values, $1); }
        }
        }
#       print $_;
    }
    }

    my $delay = &computeDelay($cap);
    my $cornerr = sprintf("%20s", $corner);
    my $delayr = sprintf("%2.1f", $delay*1000);
    my $leakager = sprintf("%3.3f", $leakage);

    print("$cornerr: Delay $delayr Leakage: $leakager capacitance: $cap\n");
    #print("$cellname $corner: Area $area Leakage: $leakage capacitance: $cap delay $delay\n");
    #print(" index1: @index1\n");
    #print(" index2: @index2\n");
    #print("Cell Rise\n"); printMatrix(\@cr);
    #print("Cell Fall\n"); printMatrix(\@cf);
    #print("Rise Trans\n"); printMatrix(\@rt);
    #print("Fall Trans\n"); printMatrix(\@ft);
}

sub computeDelay {
    # relies on cr, cf, rt, ft, index1, index2
    # index1 for rows of matrix (different trans times, units of ns)
    # index2 for cols of matrix (different load capacitances, units of pF)

    # first, given true load, create a rise/fall delay and transition
    # as a function of trans time, interpolated
    my $cap = shift;
    my $fo4cap = 4*$cap;
    my @cri = &interp2(\@cr, $fo4cap);
    my @cfi = &interp2(\@cf, $fo4cap);
    my @rti = &interp2(\@rt, $fo4cap);
    my @fti = &interp2(\@ft, $fo4cap);

    # initially guess second smallest transition time
    my $tt = $index1[1];
    # assume falling input with this transition, compute rise delay & trans
    my $cr0 = &interp1(\@cri, \@index1, $tt);
    my $rt0 = &interp1(\@rti, \@index1, $tt);
    # now assuming rising input with rt0, compute fall delay & trans
    my $cf1 = &interp1(\@cfi, \@index1, $rt0);
    my $ft1 = &interp1(\@fti, \@index1, $rt0);
    # now assuming falling input with ft1, compute rise delay & trans
    my $cr2 = &interp1(\@cri, \@index1, $ft1);
    my $rt2 = &interp1(\@rti, \@index1, $ft1);
    # now assuming rising input with rt2, compute fall delay & trans
    my $cf3 = &interp1(\@cfi, \@index1, $rt2);
    my $ft3 = &interp1(\@fti, \@index1, $rt2);

    # delay is average of rising and falling
    my $delay = ($cr2 + $cf3)/2;
    return $delay;

#    print("tt $tt cr0 $cr0 rt0 $rt0\n");
#    print("cf1 $cf1 ft1 $ft1 cr2 $cr2 rt2 $rt2 cf3 $cf3 ft3 $ft3 delay $delay\n");
}

sub interp2 {
    my $matref = shift;
    my @matrix = @$matref;
    my $fo4cap = shift;
    my @interp = ();

    my $i;
    # interpolate row by row
    for ($i=0; $i <= $#index1; $i++) {
    my @row = @{$matrix[$i]};
    #print ("Extracted row $i = @row\n");
    $interp[$i] = &interp1(\@row, \@index2, $fo4cap);
    }
    return @interp;
}

sub interp1 {
    my $vecref = shift;
    my @vec = @$vecref;
    my $indexref = shift;
    my @index = @$indexref;
    my $x = shift;

    # find entry i containing the first index greater than x
    my $i = 0;
    while ($index[$i] < $x) {$i++}
    my $start = $index[$i-1];
    my $end = $index[$i];
    my $fract = ($x-$start)/($end-$start);
    my $interp = $vec[$i-1] + ($vec[$i] - $vec[$i-1])*$fract;

#    print ("Interpolating $x as $interp from i $i start $start end $end based on index @index and vec @vec\n");

    return $interp;
}

sub parseVals {
    # relies on global variables @values, @index1, @index2
    my @vals;
    my $i; my $j;
    for ($i=0; $i <= $#index1; $i++) {
    my @row = split(/, /,$values[$i]);
    for ($j = 0; $j <= $#index2; $j++) {
        $vals[$i][$j] = $row[$j];
    }
    }
    return @vals;
}

sub printMatrix {
    my $mat = shift;
    my @matrix = @$mat;
    my $i; my $j;
    for ($i=0; $i <= $#index1; $i++) {
    for ($j = 0; $j <= $#index2; $j++) {
        print($matrix[$i][$j]." ");
    }
    print("\n");
    }
}
