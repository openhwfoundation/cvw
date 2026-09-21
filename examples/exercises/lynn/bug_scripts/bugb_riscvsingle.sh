#!/bin/sh
# James Kaden Cassidy
# kacassidy@hmc.edu
# 1/22/26
sed -i 's/cmp cmp(\.R1, \.R2, \.Eq);/cmp cmp(.R1(R1), .R2(R1), .Eq);/' "$WALLY/examples/exercises/lynn/sample_processor/src/datapath.sv"
