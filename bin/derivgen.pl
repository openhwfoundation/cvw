#!/usr/bin/env perl

###########################################
## derivgen.pl
##
## Written: David_Harris@hmc.edu
## Created: 29 January 2024
## Modified:
##
## Purpose: Read config/derivlist.txt and generate config/deriv/*/config.vh
##          derivative configurations from the base configurations
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
use Data::Dumper;

my $curderiv = "";
my @derivlist = ();
my %derivs;
my %basederiv;
my @derivnames = ();

if ($#ARGV != -1) {
    die("Usage: $0")
}
my $derivlist = "$ENV{WALLY}/config/derivlist.txt";
open(my $fh, $derivlist) or die "Could not open file '$derivlist' $!";
foreach my $line (<$fh>) {
    chomp $line;
    my @tokens = split('\s+', $line);
    if ($#tokens < 0 || $tokens[0] =~ /^#/) {   # skip blank lines and comments
        next;
    }
    if ($tokens[0] =~ /deriv/) {   # start of a new derivative
        &terminateDeriv();
        $curderiv = $tokens[1];
        $basederiv{$curderiv} = $tokens[2];
        @derivlist = ();
        if ($#tokens > 2) {
            my $inherits = $derivs{$tokens[3]};
            @derivlist = @{$inherits};
        }
    } else {   # add to the current derivative
        $line =~ /\s*(\S+)\s*(.*)/;
        my @entry = ($1, $2);
        push(@derivlist, \@entry);
    }
}
&terminateDeriv();
close($fh);
system("rm -rf $ENV{WALLY}/config/deriv");
#foreach my $key (keys %derivs) {
foreach my $key (@derivnames) {
    my $dir = "$ENV{WALLY}/config/deriv/$key";
    system("mkdir -p $dir");
    my $configunmod = "$dir/config_unmod.vh";
    my $config = "$dir/config.vh";
    my $base = "$ENV{WALLY}/config/$basederiv{$key}/config.vh";
    if (! -e $base) {
        $base = "$ENV{WALLY}/config/deriv/$basederiv{$key}/config.vh";
        #if (! -e $base) {
        #    die("Unable to find base config $base for $key\n");
        #}
    }
    system("cp $base $configunmod");
    open(my $unmod, $configunmod) or die "Could not open file '$configunmod' $!";
    open(my $fh, '>>', $config) or die "Could not open file '$config' $!";

    # Create symlink to imperas.ic for deriv buildroot
    if ($key eq "buildroot") {
        my $baseimperas_ic = "$ENV{WALLY}/config/$basederiv{$key}/imperas.ic";
        if (! -e $baseimperas_ic) {
            my $baseimperas_ic = "$ENV{WALLY}/config/deriv/$basederiv{$key}/config.vh";
        }
        if (-e $baseimperas_ic) { # If imperas.ic exists for base derivative, create hardlink to it
            my $imperas_ic = "$dir/imperas.ic";
            system("ln -T $baseimperas_ic $imperas_ic");
        }
    }

    # Create symlink to coverage.svh for deriv breker
    if ($key eq "breker") {
        my $basecoverage_svh = "$ENV{WALLY}/config/$basederiv{$key}/coverage.svh";
        if (! -e $basecoverage_svh) {
            my $basecoverage_svh = "$ENV{WALLY}/config/deriv/$basederiv{$key}/coverage.svh";
        }
        if (-e $basecoverage_svh) { # If imperas.ic exists for base derivative, create hardlink to it
            my $coverage_svh = "$dir/coverage.svh";
            system("ln -T $basecoverage_svh $coverage_svh");
        }
    }

    my $datestring = localtime();
    my %hit = ();
    print $fh "// Config $key automatically derived from $basederiv{$key} on $datestring using derivgen.pl\n";
    foreach my $line (<$unmod>) {
        foreach my $entry (@{$derivs{$key}}) {
            my @ent = @{$entry};
            my $param = $ent[0];
            my $value = $ent[1];
            if ($line =~ s/\b$param\s*=\s*.*;/$param = $value;/) {
                $hit{$param} = 1;
#               print("Hit: new line in $config for $param is $line");
            }
        }
        print $fh $line;
    }
    close($fh);
    close($unmod);
    foreach my $entry (@{$derivs{$key}}) {
        my @ent = @{$entry};
        my $param = $ent[0];
        if (!exists($hit{$param})) {
            print("Unable to find $param in $key\n");
        }
    }
    system("rm -f $dir/config_unmod.vh");
}

sub terminateDeriv {
    if ($curderiv ne "") { # close out the previous derivative
        my @dl = @derivlist;
        $derivs{$curderiv} = \@dl;
        push(@derivnames, $curderiv);
    }
};

sub printref {
    my $ref = shift;
    my @array = @{$ref};
    foreach my $entry (@array) {
        print join('_', @{$entry}), ', ';
    }
    print("\n");
}
