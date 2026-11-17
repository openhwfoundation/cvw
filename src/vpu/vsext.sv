///////////////////////////////////////////
// vsext.sv
//
// Written: Malina Andrews mandrews@g.hmc.edu
// Created: 11 November 2026
// Modified: 17 November 2026
//
// Purpose: Vector mask scan and count
//
// Documentation: RISC-V System on Chip Design Volume 2
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////


//All vsext for one e64 wide vs2
//sign extend SEW/2 (e32) to SEW destination, lmul = 1
//EEW = 32
module vsext.vf2 import cvw::*; #(parameter cvw_t P) (
input logic [P.ELEN-1:0] B,           // mask source register, vs2 = B
output logic [P.ELEN-1:0] Vd
);
logic sign;
    assign sign = B[0];
Vd =  {{32{sign & vs2[31]}}, vs2[31:0]};
endmodule

//sign extend SEW/4 (e16) to SEW destination, lmul = 1
//EEW = 16
module vsext.vf4 import cvw::*; #(parameter cvw_t P) (
input logic [P.ELEN-1:0] B,           // mask source register, vs2 = B
output logic [P.ELEN-1:0] Vd
);
logic sign;
    assign sign = B[0];
Vd =  {{16{sign & vs2[15]}}, vs2[15:0]};
endmodule

//sign extend SEW/8 (e8) to SEW destination, lmul = 1
//EEW = 8
module vsext.vf8 import cvw::*; #(parameter cvw_t P) (
input logic [P.ELEN-1:0] B,           // mask source register, vs2 = B
//output logic [$clog2(P.ELEN):0] VPopCnt // 7 bit scalar result (up to 64)
output logic [P.ELEN-1:0] Vd
);
logic sign;
    assign sign = B[0];
Vd =  {{8{sign & vs2[7]}}, vs2[7:0]};
endmodule
