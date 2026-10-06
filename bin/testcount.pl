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
