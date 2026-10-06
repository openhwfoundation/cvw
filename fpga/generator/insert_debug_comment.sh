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
