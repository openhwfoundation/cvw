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
#
# Licensed under the Solderpad Hardware License v 2.1 (the
# “License”); you may not use this file except in compliance with the
# License, or, at your option, the Apache License version 2.0. You
# may obtain a copy of the License at
#
# https://solderpad.org/licenses/SHL-2.1/
#
# Unless required by applicable law or agreed to in writing, any work
# distributed under the License is distributed on an “AS IS” BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied. See the License for the specific language governing
# permissions and limitations under the License.
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
