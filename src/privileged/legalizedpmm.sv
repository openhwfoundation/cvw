///////////////////////////////////////////
// legalizedpmm.sv
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
  input  logic [1:0] OldPMM,       // current PMM field
  input  logic [1:0] WritePMM,     // PMM field of the CSR write
  output logic [1:0] LegalizedPMM  // reserved encodings (01, and 11 without PMLEN 16) keep the old value
);
  assign LegalizedPMM = (WritePMM == 2'b01 | (WritePMM == 2'b11 & !P.PMLEN16_SUPPORTED)) ? OldPMM : WritePMM;
endmodule
