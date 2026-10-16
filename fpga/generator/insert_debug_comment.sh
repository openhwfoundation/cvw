#!/bin/bash
###########################################
## insert_debug_comment.sh
##
## Written: Rose Thompson ross1728@gmail.com
## Created: 20 January 2023
## Modified: 22 April 2024
##
## A component of the CORE-V-WALLY configurable RISC-V project.
## https://github.com/openhwfoundation/cvw
##
## Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
##
## SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
##
################################################################################################

# This script copies wally's pipelined#src to fpga#src#CopiedFiles_do_not_add_to_repo
# Then it processes them to add mark_debug on signals needed by the FPGA's ILA.
copiedDir="../src/CopiedFiles_do_not_add_to_repo"
while read line; do
    readarray -d ":" -t StrArray <<< "$line"
    file="${copiedDir}/${StrArray[0]}"
    signal=`echo "${StrArray[1]}" | awk '{$1=$1};1'`
    readarray -d " " -t SigArray <<< $signal
    sigType=`echo "${SigArray[0]}" | awk '{$1=$1};1'`
    sigName=`echo "${SigArray[1]}" | awk '{$1=$1};1' | tr -d "\015"`
    filepath=`find $copiedDir -wholename $file`
    sed -i "s/\(.*${sigType}.*${sigName}.*\)/(\* mark_debug = \"true\" \*)\1/g" $filepath
done < ../constraints/marked_debug.txt
