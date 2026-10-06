#!/usr/bin/env perl

###########################################
## vclean.pl
##
## Written: David_Harris@hmc.edu
## Created: 7 December 2023
## Modified:
##
## Purpose: Identifies unused signals in Verilog files
##          verilator should do this, but it also reports partially used signals
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

for (my $i=0; $i<=$#ARGV; $i++) {
    my $fname = $ARGV[$i];
    &clean($fname);
}

sub clean {
    my $fname = shift;

#    printf ("Cleaning $fname\n");
    open(FILE, $fname) || die("Can't read $fname");
#    my $incomment = 0;
    my @allsigs;
    while (<FILE>) {
        if (/typedef/) { } # skip typedefs
        elsif (/logic (.*)/) { # found signal declarations
            my $siglist = $1;
            $siglist =~ s/\/\/.*//; # trim off everything after //
#            print ("Logic: $siglist\n");
            $siglist =~ s/\[[^\]]*\]//g; # trim off everything in brackets
            $siglist =~ s/\s//g; # trim off white space
#            print ("Logic Trimmed: $siglist\n");
            my @sigs = split(/[,;)]/, $siglist);
#            print ("Logic parsed: @sigs\n");
            push(@allsigs, @sigs);
        }
    }
#    print("Signals: @allsigs\n");
    foreach my $sig (@allsigs) {
        if ($sig eq "") { last }; # skip empty signals
#        print("Searching for '$sig'\n");
        my $hits = `grep -c $sig $fname`;
#        print("  Signal $sig appears $hits times\n");
        if ($hits < 2) {
            printf("$sig not used in $fname\n");
        }
    }
}
