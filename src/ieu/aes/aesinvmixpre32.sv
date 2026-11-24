///////////////////////////////////////////
// aesinvmixpre32.sv
//
// Written:  David Harris 24 November 2026
// Modified:
//
// Purpose: Preprocessing that turns MixColumns into InvMixColumns (Daemen & Rijmen, The Design of
//          Rijndael, 4.1.3): InvMixColumns(a) = MixColumns(P(a)) with u = 04*(a0^a2), v = 04*(a1^a3),
//          P(a) = (a0^u, a1^v, a2^u, a3^v).
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module aesinvmixpre32(
  input  logic [31:0] a,
  output logic [31:0] y
);
  logic [7:0] u, v, u1, v1;
  galoismultforward8 gu0(a[7:0] ^ a[23:16], u1);
  galoismultforward8 gu1(u1, u);
  galoismultforward8 gv0(a[15:8] ^ a[31:24], v1);
  galoismultforward8 gv1(v1, v);
  assign y = a ^ {v, u, v, u};
endmodule
