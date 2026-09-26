#!/bin/sh
# James Kaden Cassidy
# kacassidy@hmc.edu
# 1/22/26
sed -i 's/logic \[11:0\] controls;/logic        controls;/' "$WALLY/examples/exercises/lynn/sample_processor/src/controller.sv"
