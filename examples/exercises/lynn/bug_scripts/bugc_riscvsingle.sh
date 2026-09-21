#!/bin/sh
# James Kaden Cassidy
# kacassidy@hmc.edu
# 1/22/26
sed -i 's/if (reset)  PC <= entry_addr;/if (1 | reset)  PC <= entry_addr;/' "$WALLY/examples/exercises/lynn/sample_processor/src/ifu.sv"
