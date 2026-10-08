#!/bin/bash

###########################################
## Written: rose@rosethompson.net
## Created: 12 March 2023
## Modified:
##
## Purpose: Takes a directory of branch outcomes organized as 1 files per benchmark.
##          Computes the geometric mean.
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


Directory="$1"
Files="$1/*.log"

for Pred in "bimodal" "gshare" "local4" "local8" "local10"
do
    for Size in $(seq 6 2 16)
    do
  if [ $Pred = "gshare" ]; then
      SizeString="$Size $Size 18 1"
  elif [ $Pred = "bimodal" ]; then
      SizeString="$Size 18 1"
  elif [ $Pred = "local4" ]; then
      SizeString="$Size 4 18 1"
      Pred="yehpatt"
  elif [ $Pred = "local8" ]; then
      SizeString="$Size 8 18 1"
      Pred="yehpatt"
  elif [ $Pred = "local10" ]; then
      SizeString="$Size 10 18 1"
      Pred="yehpatt"
  fi

  Product=1.0
  Count=0
  for File in $Files
  do
      #echo "sim_bp $Pred $Size $Size 18 1 $File | tail -1 | awk '{print $4}'"
      #echo "sim_bp $Pred $SizeString $File | tail -1 | awk '{print $4}'"
      BMDR=`sim_bp -c $Pred $SizeString $File | tail -1 | awk '{print $4}'`
      Product=`echo "$Product * $BMDR" | bc`
      Count=$((Count+1))
  done

  GeoMean=`perl -E "say $Product**(1/$Count)"`
  echo "$Pred$Size $GeoMean"
    done
done
