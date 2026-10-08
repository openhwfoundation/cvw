#!/usr/bin/env perl

###########################################
## extractArea.pl
##
## Written: David_Harris@hmc.edu
## Created: 19 Feb 2023
## Modified:
##
## Purpose: Pull area statistics from run directory
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
import os;

my %configResults;
my $dir = "runs";
my $macro = "Macro/Black Box area:";
my $seq = "Noncombinational area:";
my $buf = "Buf/Inv area:";
my $comb = "Combinational area:";
my $macroC = "Number of macros/black boxes:";
my $seqC = "Number of sequential cells:";
my $bufC = "Number of buf/inv:";
my $combC = "Number of combinational cells:";
my @keywords = ("ifu", "ieu", "lsu", "hzu", "ebu.ebu", "priv.priv", "mdu.mdu", "fpu.fpu", "wallypipelinedcore", $macro, $seq, $buf, $comb, $macroC, $seqC, $bufC, $combC);
my @keywordsp = ("ifu", "ieu", "lsu", "hzu", "ebu.ebu", "priv.priv", "mdu.mdu", "fpu.fpu", "wallypipelinedcore",
                 "RAMs", "Flip-flops", "Inv/Buf", "Logic", "RAMs Cnt", "Flip-flops Cnt", "Inv/Buf Cnt", "Logic Cnt", "Total Cnt");
my @configs = ("rv32e", "rv32i", "rv32imc", "rv32gc", "rv64i", "rv64gc");

opendir(DIR, $dir) or die "Could not open $dir";

while (my $filename = readdir(DIR)) {
    if ($filename =~ /orig_tsmc28psyn/) {
#    if ($filename =~ /orig_sky90/) {
        &processRun("$dir/$filename");
    }
}
closedir(DIR);

# print table of results
printf("%20s\t", "");
foreach my $config (@configs) {
    printf("%s\t", $config);
}
print ("\n");
foreach my $kw (@keywordsp) {
    my $kws = substr($kw, 0, 3);
    printf("%20s\t", $kw);
    foreach my $config (@configs) {
        my $r = $configResults{$config};
        if (exists ${$r}{$kw}) {
            my $area = ${$r}{$kw};
            while ($area =~ s/(\d+)(\d\d\d)/$1\,$2/){};
            #print "${$r}{$kw}\t";
            print "$area\t";
        } else {
            print("\t");
        }
    }
    print("\n");
}

sub processRun {
    my $fname = shift;
    my $ffname = "$fname/reports/area.rep";
    open(FILE, "$ffname") or die ("Could not read $ffname");

    # Extract configuration from fname;
    $fname =~ /_([^_]*)_orig/;
    my $config = $1;
    #print("Reading $config from $ffname\n");

    # Search for results
    my %results;
    while (my $line = <FILE>) {
        foreach my $kw (@keywords) {
           # print "$kw $line\n";
            if ($line =~ /^${kw}\s+(\S*)/) {
                $results{$kw} = int($1);
            } elsif ($line =~ /^${kw}__\S*\s+(\S*)/) {
                $results{$kw} = int($1);
            }
         }
    }
    foreach my $kw (@keywords) {
        #print "$kw\t$results{$kw}\n";
    }
    $results{"Logic"} = $results{$comb} - $results{$buf};
    $results{"Inv/Buf"} = $results{$buf};
    $results{"Flip-flops"} = $results{$seq};
    $results{"RAMs"} = $results{$macro};
    $results{"Logic Cnt"} = $results{$combC} - $results{$bufC};
    $results{"Inv/Buf Cnt"} = $results{$bufC};
    $results{"Flip-flops Cnt"} = $results{$seqC};
    $results{"RAMs Cnt"} = $results{$macroC};
    $results{"Total Cnt"} = $results{$macroC} + $results{$seqC} +  $results{$combC};
    close(FILE);
    $configResults{$config} = \%results;
}
