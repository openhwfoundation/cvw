///////////////////////////////////////////
// csrv.sv
//
// Written: ytai@g.hmc.edu 2026-09-08
//
// Purpose: User-Mode Control and Status Registers for Vector Extension.
//
// Documentation: TODO: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module csrv import cvw::*;  #(parameter cvw_t P) (
  input  logic              clk, reset,
  input  logic              InstrValidNotFlushedM,
  input  logic              CSRWriteM, CSRUWriteM,
  input  logic [11:0]       CSRAdrM,
  input  logic [P.XLEN-1:0] CSRWriteValM,
  input  logic [1:0]        STATUS_VS,
  // vset commit inputs (TODO: vset not implemented yet, so tied to 0 for now)
  input  logic              WriteVLVTYPEM,
  input  logic [P.XLEN-1:0] NewVLM,
  input  logic [7:0]        NewVTYPEM,                // {vma, vta, vsew[2:0], vlmul[2:0]}
  input  logic              NewVILLM,
  // CSR-writes from executing vector instructions (TODO: VPU not implemented yet so tied to 0 for now)
  input  logic              SetVXSATM,
  input  logic              ClearVSTARTM,             // reset vstart when vector instruction completed
  // Outputs to VPU
  output logic [P.XLEN-1:0] VTYPE_REGW,
  output logic [P.XLEN-1:0] VL_REGW,
  output logic [$clog2(P.VLEN)-1:0] VSTART_REGW,
  output logic [1:0]        VXRM_REGW,
  // Outputs for mstatus.VS dirty
  output logic              WriteVXRMM,               // CSR write to vxrm or vcsr
  output logic              SetOrWriteVXSATM,         // CSR write to vxsat/vcsr, or SetVXSATM
  output logic              ClearOrWriteVSTARTM,      // CSR write to vstart, or ClearVSTARTM
  // CSR read / illegal
  output logic [P.XLEN-1:0] CSRVReadValM,
  output logic              IllegalCSRVAccessM
);

  // CSR addresses
  localparam VSTART = 12'h008;
  localparam VXSAT  = 12'h009;
  localparam VXRM   = 12'h00A;
  localparam VCSR   = 12'h00F;
  localparam VL     = 12'hC20;
  localparam VTYPE  = 12'hC21;
  localparam VLENB  = 12'hC22;

  // Storage widths
  localparam VSTART_WIDTH = $clog2(P.VLEN);    // have only enough writable bits to hold index of one less than maximum VLMAX

  logic [VSTART_WIDTH-1:0] NextVSTARTM;
  logic                    VXSAT_REGW, NextVXSATM;
  logic [1:0]              NextVXRMM;
  logic                    WriteVSTARTM, WriteVXSATM;
  logic [7:0]              VTYPE_CFG_REG;      // {vma, vta, vsew[2:0], vlmul[2:0]}
  logic                    VILL_REG;

  // Write enables
  assign WriteVSTARTM = CSRUWriteM & (STATUS_VS != 2'b00) & (CSRAdrM == VSTART);
  assign WriteVXSATM  = CSRUWriteM & (STATUS_VS != 2'b00) & (CSRAdrM == VXSAT | CSRAdrM == VCSR);
  assign WriteVXRMM   = CSRUWriteM & (STATUS_VS != 2'b00) & (CSRAdrM == VXRM  | CSRAdrM == VCSR);

  // Architecture writes from vector instructions
  assign ClearOrWriteVSTARTM = WriteVSTARTM | (ClearVSTARTM & InstrValidNotFlushedM);
  assign SetOrWriteVXSATM    = WriteVXSATM  | (SetVXSATM & InstrValidNotFlushedM);

  // Write values
  assign NextVSTARTM = WriteVSTARTM ? CSRWriteValM[VSTART_WIDTH-1:0] : '0;         // if reset by vector instruction, value is 0
  assign NextVXSATM  = WriteVXSATM ? CSRWriteValM[0] : 1'b1;                       // vxsat = vcsr[0]
  assign NextVXRMM   = (CSRAdrM == VCSR) ? CSRWriteValM[2:1] : CSRWriteValM[1:0];  // vxrm = vcsr[2:1]

  // CSRs
  flopenr #(VSTART_WIDTH) VSTARTreg (clk, reset, ClearOrWriteVSTARTM, NextVSTARTM, VSTART_REGW);
  flopenr #(1)            VXSATreg  (clk, reset, SetOrWriteVXSATM,    NextVXSATM,  VXSAT_REGW);
  flopenr #(2)            VXRMreg   (clk, reset, WriteVXRMM,          NextVXRMM,   VXRM_REGW);

  // vl / vtype written only by vset{i}vl{i}, CSR-write illegal
  flopenr #(P.XLEN) VLreg      (clk, reset, WriteVLVTYPEM & InstrValidNotFlushedM, NewVLM,    VL_REGW);
  flopenr #(8)      VTYPECFGreg(clk, reset, WriteVLVTYPEM & InstrValidNotFlushedM, NewVTYPEM, VTYPE_CFG_REG);
  flopenr #(1)      VILLreg    (clk, reset, WriteVLVTYPEM & InstrValidNotFlushedM, NewVILLM,  VILL_REG);

  // vtype[XLEN-1] = vill, vtype[7:0] = {vma, vta, vsew[2:0], vlmul[2:0]}, other bits reserved
  assign VTYPE_REGW = {VILL_REG, {(P.XLEN-9){1'b0}}, VTYPE_CFG_REG};

  // CSR Reads
  localparam [P.XLEN-1:0] VLENB_CONST = (P.XLEN)'(P.VLEN / 8);
  always_comb begin
    CSRVReadValM       = '0;
    IllegalCSRVAccessM = 1'b0;
    if (STATUS_VS == 2'b00) IllegalCSRVAccessM = 1'b1; // vector disabled, trap
    else begin
      case (CSRAdrM)
        VSTART:  CSRVReadValM = {{(P.XLEN-VSTART_WIDTH){1'b0}}, VSTART_REGW};
        VXSAT:   CSRVReadValM = {{(P.XLEN-1){1'b0}}, VXSAT_REGW};
        VXRM:    CSRVReadValM = {{(P.XLEN-2){1'b0}}, VXRM_REGW};
        VCSR:    CSRVReadValM = {{(P.XLEN-3){1'b0}}, VXRM_REGW, VXSAT_REGW};
        VL:      if (~CSRWriteM) CSRVReadValM = VL_REGW;     else IllegalCSRVAccessM = 1'b1; // read-only
        VTYPE:   if (~CSRWriteM) CSRVReadValM = VTYPE_REGW;  else IllegalCSRVAccessM = 1'b1; // read-only
        VLENB:   if (~CSRWriteM) CSRVReadValM = VLENB_CONST; else IllegalCSRVAccessM = 1'b1; // read-only
        default: IllegalCSRVAccessM = 1'b1;
      endcase
    end
  end
endmodule
