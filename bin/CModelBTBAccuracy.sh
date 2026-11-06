#!/bin/bash

###########################################
## Written: rose@rosethompson.net
## Created: 23 October 2023
## Modified:
##
## Purpose: Takes a directory of branch outcomes organized as 1 files per benchmark.
##          Computes the geometric mean for btb accuracy
##
## A component of the CORE-V-WALLY configurable RISC-V project.
## https://github.com/openhwfoundation/cvw
##
## Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
##
## SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
##
################################################################################################


Directory="$1"
Files="$1/*.log"

for Size in $(seq 6 2 16)
do
    Product=1.0
    Count=0
    BMDRArray=()
    for File in $Files
    do
    lines=`sim_bp gshare 16 16 $Size 1  $File | tail -5`
        Total=`echo "$lines" | head -1 | awk '{print $5}'`
        Miss=`echo "$lines" | tail -2 | head -1 | awk '{print $8}'`
        BMDR=`echo "100.0 * $Miss / $Total" | bc -l`
        BMDRArray+=("$BMDR")
        if [ $Miss -eq 0 ]; then
        Product=`echo "scale=200; $Product * 100 / $Total" | bc -l`
        else
            Product=`echo "scale=200; $Product * $BMDR" | bc -l`
        fi
    Count=$((Count+1))
    done
    # with such long precision bc outputs onto multiple lines
    # must remove \n and \ from string
    Product=`echo "$Product" | tr -d '\n' | tr -d '\\\'`
    GeoMean=`perl -E "say $Product**(1/$Count)"`
    echo "$Pred$Size $GeoMean"
done
