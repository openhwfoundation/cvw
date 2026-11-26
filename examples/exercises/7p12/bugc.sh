#!/bin/sh
sed -i 's/assign reset_ext = /assign reset_ext = 1 | /' $WALLY/testbench/cvw_testbench.sv
