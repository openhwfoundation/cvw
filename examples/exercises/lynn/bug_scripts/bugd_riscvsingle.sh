#!/bin/sh
# James Kaden Cassidy
# kacassidy@hmc.edu
# 1/22/26
sed -i 's/assign LT = Neg \^ Overflow;/assign LT = Neg;/' "$WALLY/examples/exercises/lynn/sample_processor/src/alu.sv"
