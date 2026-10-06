#!/usr/bin/env perl

###########################################
## testlist.pl
##
## Written: David_Harris@hmc.edu
## Created: 25 December 2021
## Modified:
##
## Purpose: Read the work directories from riscv-arch-test or imperas-riscv-tests
##          and generate a list of tests and signature addresses for tests.vh
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

if ($#ARGV != 0) {
    die("Usage: $0 workpath [e.g. $0 \$WALLY/addins/riscv-arch-test/work")
}
my $mypath = $ARGV[0];
my @dirs = glob($mypath.'/*/*');
foreach my $dir (@dirs) {
    $dir =~ /.*\/(.*)\/(.*)/;
    my $arch = $1;
    my $ext = $2;
    my $contents = `grep --with-filename "<begin_signature>:" $dir/*.objdump`;
    my @lines = split('\n', $contents);
    print "$arch/$ext";
    foreach my $line (@lines) {
        $line =~ /.*\/(.*)\.elf.objdump:(\S*)/;
        my $fname = $1;
        my $adr = $2;
        my $partialaddress = substr($adr, -6);
        print ",\n\t\t\"$arch/$ext/$fname\", \"$partialaddress\"";
    }
    print("\n\n");
}
