///////////////////////////////////////////
// fdivsqrtiter.sv
//
// Written:  David Harris David_Harris@hmc.edu, Katherine Parry me@KatherineParry.com, Cedar Turek cturek@hmc.edu 15 July 2022
// Modified: Kevin Kim, Alessandro Maiuolo
//
// Purpose: Divide and square root recurrence registers and stages.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2022-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module fdivsqrtiter import cvw::*; #(parameter cvw_t P) (
  input  logic              clk,
  input  logic              IFDivStartE,
  input  logic              IterEnE,          // advance the iteration registers
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

  logic [P.DIVb+3:0]      WSN, WCN;                // Q4.DIVb
  logic [P.DIVb+3:0]      DBar, D2, DBar2;         // Q4.DIVb
  logic [P.DIVb:0]        UMux, UMMux;             // U1.DIVb
  logic [P.DIVb:0]        initU, initUM;           // U1.DIVb

  // Top Muxes and Registers
  // When start is asserted, the inputs are loaded into the divider.
  // Otherwise, the divisor is retained and the residual and result
  // are fed back for the next iteration.

  // Residual WS/WC registers/initialization mux
  mux2   #(P.DIVb+4) wsmux(WS[P.DIVCOPIES], X, IFDivStartE, WSN);
  mux2   #(P.DIVb+4) wcmux(WC[P.DIVCOPIES], '0, IFDivStartE, WCN);
  flopen #(P.DIVb+4) wsreg(clk, IterEnE, WSN, WS[0]);
  flopen #(P.DIVb+4) wcreg(clk, IterEnE, WCN, WC[0]);

  // UOTFC Result U and UM registers/initialization mux
  // Initialize U to 0 = 0.0000... and UM to -1 = 1.00000... (in Q1.Divb)
  assign initU  = {(P.DIVb+1){1'b0}};
  assign initUM = {{1'b1}, {(P.DIVb){1'b0}}};
  mux2   #(P.DIVb+1)  uinitmux(UNext[P.DIVCOPIES-1],  initU,  IFDivStartE, UMux);
  mux2   #(P.DIVb+1) uminitmux(UMNext[P.DIVCOPIES-1], initUM, IFDivStartE, UMMux);
  flopen #(P.DIVb+1)  UReg(clk, IterEnE, UMux,  U[0]);
  flopen #(P.DIVb+1) UMReg(clk, IterEnE, UMMux, UM[0]);

  // C register/initialization mux: C = -R:
  // C = -4 = 00.000000... (in Q2.DIVb) for radix 4, C = -2 = 10.000000... for radix 2
  if (P.RADIX == 4) assign initC = '0;
  else             assign initC = {2'b10, {{P.DIVb{1'b0}}}};
  // C is a thermometer code that gains RK ones per cycle, so at the start of each cycle it is uniform in groups
  // of RK bits (below CTOP leading bits that never change).  Register one bit per group and replicate it.  Besides
  // saving flops, this shows synthesis that the one-hot K vectors each stage derives from C can only be nonzero
  // at fixed offsets within a group, which shrinks the on-the-fly converters and F generation.
  localparam CW   = P.DIVb+2;
  localparam CNG  = CW / P.RK;          // number of groups
  localparam CTOP = CW - CNG*P.RK;      // leading bits above the groups (1 for radix 2 with RK > 1, else 0)
  logic [CNG-1:0] CG, CGNext, initCG;
  genvar g;
  for (g = 0; g < CNG; g++) begin : cgroups
    assign initCG[g] = initC[g*P.RK];
    assign C[0][g*P.RK +: P.RK] = {P.RK{CG[g]}};
  end
  if (CTOP > 0) begin : ctop
    assign C[0][CW-1 -: CTOP] = initC[CW-1 -: CTOP]; // constant ones
  end
  mux2   #(CNG) cmux({1'b1, CG[CNG-1:1]}, initCG, IFDivStartE, CGNext);
  flopen #(CNG) creg(clk, IterEnE, CGNext, CG);

  // Divisor Selections
  assign DBar    = ~D;        // for -D
  if (P.RADIX == 4) begin : radix4divisor
    assign D2    = D << 1;    // for 2D,  only used in R4
    assign DBar2 = ~D2;       // for -2D, only used in R4
  end

  // k = DIVCOPIES of the recurrence logic
  genvar i;
  generate
    for (i = 0; $unsigned(i) < P.DIVCOPIES; i++) begin : iterations
      if (P.RADIX == 2) begin : stage
        fdivsqrtstage2 #(P) fdivsqrtstage(.D, .DBar, .SqrtE,
          .WS(WS[i]), .WC(WC[i]), .WSNext(WSNext[i]), .WCNext(WCNext[i]),
          .C(C[i]), .U(U[i]), .UM(UM[i]), .CNext(C[i+1]), .UNext(UNext[i]), .UMNext(UMNext[i]));
      end else begin : stage
        fdivsqrtstage4 #(P) fdivsqrtstage(.D, .DBar, .D2, .DBar2, .SqrtE,
          .WS(WS[i]), .WC(WC[i]), .WSNext(WSNext[i]), .WCNext(WCNext[i]),
          .C(C[i]), .U(U[i]), .UM(UM[i]), .CNext(C[i+1]), .UNext(UNext[i]), .UMNext(UMNext[i]));
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
