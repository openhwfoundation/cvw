#!/bin/bash

######################
## extractFunctionRadix.sh
##
## Written: Rose Thompson
## email: rose@rosethompson.net
## Created: March 1, 2021
## Modified: March 10, 2021
##
## Purpose: Processes all compiled object files into 2 types of files which assist in debugging applications.
##          File 1: .addr: A sorted list of function starting addresses.
##                  When a the PCE is greater than or equal to the function's starting address, the label will be associated with this address.
##          File 2: .lab: A sorted list of function labels. The names of functions.  Modelsim will display these names rather than the function address.
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


function processProgram {
    local objDumpFile=$1
    local numBits=$2
    local size=$(($numBits/4))
    local index=$3

    # when size = 16 => 64 bit
    # when size = 8 => 32 bit
    local listOfAddr=$(grep -E -i "^[0-9a-f]{$size} <[0-9a-zA-Z_]+>" $objDumpFile)

    # skip if the wrong bit width.
    if [ -z "$listOfAddr" ]; then
        return 0
    fi

    # parse out the addresses and the labels
    local addresses=$(echo "$listOfAddr" | awk '{print $1}')
    local labels=$(echo "$listOfAddr" | awk '{print  "\""$2"\"", "-color \"SpringGreen\","}' | tr -d '<>:')
    local labelsName=$(echo "$listOfAddr" | awk '{print  ""$2""}' | tr -d '<>:')

    # output per program function address list
    echo "$addresses" > $objDumpFile.addr
    echo "$labelsName" > $objDumpFile.lab

    # need to add some formatting to each line
    local numLines=$(echo "$listOfAddr" | wc -l)

    return 0
}


index=0

for objDumpFile in "$@";
do

    processProgram "$objDumpFile" 32 "$index"
    processProgram "$objDumpFile" 64 "$index"

    index=$(($index+1))

done

exit 0
