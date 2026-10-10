#!/bin/bash
#######################################################################
# splitfile.sh
#
# Written: Jacob Pease jacob.pease@okstate.edu 7/22/2024
#
# Purpose: Used to split boot.mem into two sections for FPGA
#
#
#
# A component of the Wally configurable RISC-V project.
#
# Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
#
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
######################################################################


# Acquired from here.
# https://stackoverflow.com/questions/3066948/how-to-file-split-at-a-line-number
file_name=$1

# set first K lines:
K=512

# line count (N):
N=$(wc -l < $file_name)

# length of the bottom file:
L=$(( $N - $K ))

# create the top of file:
head -n $K $file_name > boot.mem

# create bottom of file:
tail -n $L $file_name > data.mem
