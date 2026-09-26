// James Kaden Cassidy
// kacassidy@hmc.edu
// 1/5/2026

`ifndef PARAMETERS
`define PARAMETERS

    `define XLEN32

    `ifdef XLEN32
        `define XLEN 32
    `endif
    `ifdef XLEN64
        `define XLEN 64
    `endif

    //`define DEBUG

`endif
