///////////////////////////////////////////
// priorityonehot.sv
//
// Written:  Thomas Fleming tfleming@hmc.edu, Jessica Torrey jtorrey@hmc.edu 7 April 2021
// Modified: David Harris David_Harris@hmc.edu, Kip Macsai-Goren kmacsaigoren@hmc.edu, Madeleine Masser-Frye mmasserfrye@hmc.edu, Teo Ene teo.ene@okstate.edu
//
// Purpose: Priority circuit that outputs a one-hot vector marking the least significant 1 in its input.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-27 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

module priorityonehot #(parameter N = 8) (
  input  logic  [N-1:0] a,
  output logic  [N-1:0] y
);

  genvar i;

  assign y[0] = a[0];
  for (i=1; i<N; i++) begin : poh
    assign y[i] = a[i] & ~|a[i-1:0];
  end

endmodule
