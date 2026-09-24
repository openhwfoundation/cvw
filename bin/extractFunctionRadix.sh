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
    # labels from the disassembly: "<addr> <label>:"
    local disasmLabels=$(grep -E -i "^[0-9a-f]{$size} <[0-9a-zA-Z_]+>" $objDumpFile | awk '{print $1, $2}' | tr -d '<>:')
    # skip if the wrong bit width.
    if [ -z "$disasmLabels" ]; then
        return 0
    fi
    # Data labels the testbench looks for (tohost, begin_signature, selfcheck_record, ...) live in
    # sections that objdump may not disassemble, so also take symbols from the symbol table, if present:
    # "<addr> <flags> <section> <size> <name>", keeping only plain names (not section or file symbols)
    local symbolLabels=$(awk -v size=$size 'length($1)==size && $1 ~ /^[0-9a-f]+$/ && NF>=5 && $2 !~ /^[0-9a-f]+$/ && $(NF-1) ~ /^[0-9a-f]+$/ && $NF ~ /^[0-9a-zA-Z_]+$/ {print $1, $NF}' $objDumpFile)
    # merge, sorted by address so the testbench can binary search
    local listOfAddr=$(printf "%s\n%s\n" "$disasmLabels" "$symbolLabels" | grep -v "^$" | sort -u)
    # output per program address and label lists
    echo "$listOfAddr" | awk '{print $1}' > $objDumpFile.addr
    echo "$listOfAddr" | awk '{print $2}' > $objDumpFile.lab
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
