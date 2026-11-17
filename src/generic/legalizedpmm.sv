///////////////////////////////////////////
// csrm.sv
//
// Written:  naichewa@gmail.com 17 November 2026
// Modified:
//
// Purpose: Legalized PMM logic for ZPM extension.
//
// Documentation:
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module legalizedpmm import cvw::*; #(parameter cvw_t P) (
    input logic [63:0] XENVCFG_REGW,
    input logic [63:0] XENVCFG_PreWriteValM,
    output logic [1:0]       LegalizedPMM
);
  assign LegalizedPMM = ((XENVCFG_PreWriteValM[33:32] == 2'b01) |
                         (XENVCFG_PreWriteValM[33:32] == 2'b11 & !P.PMLEN16_SUPPORTED)) ? // If PMM write value is reserved (01 or 11 when PMLEN16 is not supported, do not write)
                          XENVCFG_REGW[33:32] : XENVCFG_PreWriteValM[33:32];
endmodule
