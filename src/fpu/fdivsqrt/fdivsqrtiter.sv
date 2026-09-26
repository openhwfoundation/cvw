///////////////////////////////////////////
// fdivsqrtiter.sv
//
// Written: David_Harris@hmc.edu, me@KatherineParry.com, cturek@hmc.edu
// Modified:13 January 2022
//
// Purpose: k stages of divsqrt logic, plus registers
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
// except in compliance with the License, or, at your option, the Apache License version 2.0. You
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language governing permissions
// and limitations under the License.
////////////////////////////////////////////////////////////////////////////////////////////////

module fdivsqrtiter import cvw::*;  #(parameter cvw_t P) (
  input  logic              clk,
  input  logic              IFDivStartE,
  input  logic              FDivBusyE,
  input  logic              SqrtE,
  input  logic [P.DIVb+3:0] X, D,                  // Q4.DIVb
  output logic [P.DIVb:0]   FirstU, FirstUM,       // U1.DIVb
  output logic [P.DIVb+1:0] FirstC,                // Q2.DIVb
  output logic [P.DIVb+3:0] FirstWS, FirstWC       // Q4.DIVb
);

  logic [P.DIVb+3:0]      WSNext[P.DIVCOPIES-1:0]; // Q4.DIVb
  logic [P.DIVb+3:0]      WCNext[P.DIVCOPIES-1:0]; // Q4.DIVb
  logic [P.DIVb+3:0]      WS[P.DIVCOPIES:0];       // Q4.DIVb
  logic [P.DIVb+3:0]      WC[P.DIVCOPIES:0];       // Q4.DIVb
  logic [P.DIVb:0]        U[P.DIVCOPIES:0];        // U1.DIVb
  logic [P.DIVb:0]        UM[P.DIVCOPIES:0];       // U1.DIVb
  logic [P.DIVb:0]        UNext[P.DIVCOPIES-1:0];  // U1.DIVb
  logic [P.DIVb:0]        UMNext[P.DIVCOPIES-1:0]; // U1.DIVb
  logic [P.DIVb+1:0]      C[P.DIVCOPIES:0];        // Q2.DIVb
  logic [P.DIVb+1:0]      initC;                   // Q2.DIVb
  logic [P.DIVCOPIES-1:0] un;

  logic [P.DIVb+3:0]      WSN, WCN;                // Q4.DIVb
  logic [P.DIVb+3:0]      DBar, D2, DBar2;         // Q4.DIVb
  logic [P.DIVb+1:0]      NextC;                   // Q2.DIVb
  logic [P.DIVb:0]        UMux, UMMux;             // U1.DIVb
  logic [P.DIVb:0]        initU, initUM;           // U1.DIVb

  // Top Muxes and Registers
  // When start is asserted, the inputs are loaded into the divider.
  // Otherwise, the divisor is retained and the residual and result
  // are fed back for the next iteration.

  // Residual WS/SC registers/initialization mux
  mux2   #(P.DIVb+4) wsmux(WS[P.DIVCOPIES], X, IFDivStartE, WSN);
  mux2   #(P.DIVb+4) wcmux(WC[P.DIVCOPIES], '0, IFDivStartE, WCN);
  flopen #(P.DIVb+4) wsreg(clk, FDivBusyE, WSN, WS[0]);
  flopen #(P.DIVb+4) wcreg(clk, FDivBusyE, WCN, WC[0]);

  // UOTFC Result U and UM registers/initialization mux
  // Initialize U to 0 = 0.0000... and UM to -1 = 1.00000... (in Q1.Divb)
  assign initU  ={(P.DIVb+1){1'b0}};
  assign initUM = {{1'b1}, {(P.DIVb){1'b0}}};
  mux2   #(P.DIVb+1)  Umux(UNext[P.DIVCOPIES-1],  initU,  IFDivStartE, UMux);
  mux2   #(P.DIVb+1) UMmux(UMNext[P.DIVCOPIES-1], initUM, IFDivStartE, UMMux);
  flopen #(P.DIVb+1)  UReg(clk, FDivBusyE, UMux,  U[0]);
  flopen #(P.DIVb+1) UMReg(clk, FDivBusyE, UMMux, UM[0]);

  // C register/initialization mux: C = -R:
  // C = -4 = 00.000000... (in Q2.DIVb) for radix 4, C = -2 = 10.000000... for radix2
  if(P.RADIX == 4) assign initC = '0;
  else             assign initC = {2'b10, {{P.DIVb{1'b0}}}};
  mux2   #(P.DIVb+2) cmux(C[P.DIVCOPIES], initC, IFDivStartE, NextC);
  flopen #(P.DIVb+2) creg(clk, FDivBusyE, NextC, C[0]);

  // Divisor Selections
  assign DBar    = ~D;        // for -D
  if(P.RADIX == 4) begin : d2
    assign D2    = D << 1;    // for 2D,  only used in R4
    assign DBar2 = ~D2;       // for -2D, only used in R4
  end

  // k=DIVCOPIES of the recurrence logic
  genvar i;
  generate
    for(i=0; $unsigned(i)<P.DIVCOPIES; i++) begin : iterations
      if (P.RADIX == 2) begin : stage
        fdivsqrtstage2 #(P) fdivsqrtstage(.D, .DBar, .SqrtE,
          .WS(WS[i]), .WC(WC[i]), .WSNext(WSNext[i]), .WCNext(WCNext[i]),
          .C(C[i]), .U(U[i]), .UM(UM[i]), .CNext(C[i+1]), .UNext(UNext[i]), .UMNext(UMNext[i]), .un(un[i]));
      end else begin : stage
        fdivsqrtstage4 #(P) fdivsqrtstage(.D, .DBar, .D2, .DBar2, .SqrtE,
          .WS(WS[i]), .WC(WC[i]), .WSNext(WSNext[i]), .WCNext(WCNext[i]),
          .C(C[i]), .U(U[i]), .UM(UM[i]), .CNext(C[i+1]), .UNext(UNext[i]), .UMNext(UMNext[i]), .un(un[i]));
      end
      assign WS[i+1] = WSNext[i];
      assign WC[i+1] = WCNext[i];
      assign U[i+1]  = UNext[i];
      assign UM[i+1] = UMNext[i];
    end
  endgenerate

  // Send values from start of cycle for postprocessing
  assign FirstWS = WS[0];
  assign FirstWC = WC[0];
  assign FirstU  = U[0];
  assign FirstUM = UM[0];
  assign FirstC  = C[0];
endmodule
