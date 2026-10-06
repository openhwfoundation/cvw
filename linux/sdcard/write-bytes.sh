#!/bin/bash
###########################################
## write-bytes.sh
##
## Written: Jacob Pease jacobpease@protonmail.com
## Created: November 2nd, 2024
## Modified:
##
## Purpose: Write a sequence of bytes from text file to an output file and a flash card.
##
## A component of the CORE-V-WALLY configurable RISC-V project.
## https://github.com/openhwfoundation/cvw
##
## Copyright (C) 2021-24 Harvey Mudd College & Oklahoma State University
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


# This file writes a bunch of bytes to the flash card based on a text
# file input with bytes written in hexadecimal.

usage() { echo "Usage: $0 [-zh] [-b <path/to/buildroot>] <device>" 1>&2; exit 1; }

help() {
    echo "Usage: $0 [OPTIONS] <device>"
    echo "  -i                          Input text file with hex bytes."
    echo "  -b <path/to/buildroot>      Output binary file."
    exit 0;
}

INPUTFILE=""
OUTPUTFILE=""

ARGS=()
while [ $OPTIND -le "$#" ] ; do
    if getopts "hi:o:" arg ; then
        case "${arg}" in
            h) help
               ;;
            i) INPUTFILE=${OPTARG}
               ;;
            o) OUTPUTFILE=${OPTARG}
               ;;
        esac
    else
        ARGS+=("${!OPTIND}")
        ((OPTIND++))
    fi
done

SDCARD=${ARGS[0]}

if [ ! -e $INPUTFILE ] ; then
    echo -e "Error: Input file $INPUTFILE does not exist."
    exit 1
fi

if [ -e $OUTPUTFILE ] ; then
    echo -e "Error: Output file $OUTPUTFILE already exists."
    exit 1
fi

for word in $(cat "$INPUTFILE")
do
    echo -en "\x$word" >> $OUTPUTFILE
done

dd if=$OUTPUTFILE of="$SDCARD"
