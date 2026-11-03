#!/bin/bash

###########################################
## testcount.pl
##
## Written: David_Harris@hmc.edu
## Created: 25 December 2022
## Modified: Read the riscv-test-suite directories from riscv-arch-test
## and count how many tests are in each
##
## Purpose: Read the riscv-test-suite directories from riscv-arch-test
##          and count how many tests are in each
##
## A component of the CORE-V-WALLY configurable RISC-V project.
## https://github.com/openhwfoundation/cvw
##
## Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
##
## SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
##
################################################################################################

for dir in `ls ${WALLY}/addins/riscv-arch-test/riscv-test-suite/rv*/*`
do
    dir=$(echo $dir | cut -d':' -f1)
    echo $dir
    if [ $dir == "src" ]
    then
        continue
    fi
    for fn in `ls $dir/src/*.S`
    do
        result=`grep 'inst_' $fn | tail -n 1`
        num=$(echo $result| cut -d'_' -f 2 | cut -d':' -f 1)
        ((num++))
        fnbase=`basename $fn`
        echo "$fnbase: $num"
    done
done
