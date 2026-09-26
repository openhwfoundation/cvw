///////////////////////////////////////////
// crsr.sv
//
// Written: David_Harris@hmc.edu 9 January 2021
// Modified:
//
// Purpose: Status register (and environment configuration register and others shared across modes)
//          See RISC-V Privileged Mode Specification 20190608
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

module csrsr import cvw::*;  #(parameter cvw_t P) (
  input  logic              clk, reset, StallW,
  input  logic              WriteMSTATUSM, WriteMSTATUSHM, WriteSSTATUSM,
  input  logic              TrapM, FRegWriteM,
  input  logic [1:0]        NextPrivilegeModeM, PrivilegeModeW,
  input  logic              mretM, sretM,
  input  logic              WriteFRMM, SetOrWriteFFLAGSM,
  input  logic [P.XLEN-1:0] CSRWriteValM,
  input  logic              SelHPTW,
  output logic [P.XLEN-1:0] MSTATUS_REGW, SSTATUS_REGW, MSTATUSH_REGW,
  output logic [1:0]        STATUS_MPP,
  output logic              STATUS_SPP, STATUS_TSR, STATUS_TW,
  output logic              STATUS_MIE, STATUS_SIE,
  output logic              STATUS_MXR, STATUS_SUM,
  output logic              STATUS_MPRV, STATUS_TVM,
  output logic [1:0]        STATUS_FS,
  output logic              BigEndianM
);

  logic STATUS_SD, STATUS_TW_INT, STATUS_TSR_INT, STATUS_TVM_INT, STATUS_MXR_INT, STATUS_SUM_INT, STATUS_MPRV_INT;
  logic [1:0] STATUS_SXL, STATUS_UXL, STATUS_XS, STATUS_FS_INT, STATUS_MPP_NEXT;
  logic STATUS_MPIE, STATUS_SPIE, STATUS_UBE, STATUS_SBE, STATUS_MBE;
  logic nextMBE, nextSBE;

  // STATUS REGISTER FIELD
  // See Privileged Spec Section 3.1.6
  // Lower privilege status registers are a subset of the full status register
  if (P.XLEN==64) begin : csrsr64 // RV64
    assign MSTATUS_REGW  = {STATUS_SD, 25'b0, STATUS_MBE, STATUS_SBE, STATUS_SXL, STATUS_UXL, 9'b0,
                           STATUS_TSR, STATUS_TW, STATUS_TVM, STATUS_MXR, STATUS_SUM, STATUS_MPRV,
                           STATUS_XS, STATUS_FS, STATUS_MPP, 2'b0,
                           STATUS_SPP, STATUS_MPIE, STATUS_UBE, STATUS_SPIE, 1'b0,
                           STATUS_MIE, 1'b0, STATUS_SIE, 1'b0};
    assign SSTATUS_REGW  = {STATUS_SD, /*27'b0, */ 29'b0, /*STATUS_SXL, */ {STATUS_UXL}, /*9'b0, */ 12'b0,
                          /*STATUS_TSR, STATUS_TW, STATUS_TVM, */STATUS_MXR, STATUS_SUM, /* STATUS_MPRV, */ 1'b0,
                           STATUS_XS, STATUS_FS, /*STATUS_MPP, 2'b0*/ 4'b0,
                           STATUS_SPP, /*STATUS_MPIE*/ 1'b0, STATUS_UBE, STATUS_SPIE,
                          /*1'b0, STATUS_MIE, 1'b0*/ 3'b0, STATUS_SIE, 1'b0};
    assign MSTATUSH_REGW = '0; // does not exist when XLEN=64, and accessing will throw an illegal instruction
  end else begin : csrsr32 // RV32
    assign MSTATUS_REGW  = {STATUS_SD, 8'b0,
                           STATUS_TSR, STATUS_TW, STATUS_TVM, STATUS_MXR, STATUS_SUM, STATUS_MPRV,
                           STATUS_XS, STATUS_FS, STATUS_MPP, 2'b0,
                           STATUS_SPP, STATUS_MPIE, STATUS_UBE, STATUS_SPIE, 1'b0, STATUS_MIE, 1'b0, STATUS_SIE, 1'b0};
    assign MSTATUSH_REGW = {26'b0, STATUS_MBE, STATUS_SBE, 4'b0};
    assign SSTATUS_REGW  = {STATUS_SD, 11'b0,
                          /*STATUS_TSR, STATUS_TW, STATUS_TVM, */STATUS_MXR, STATUS_SUM, /* STATUS_MPRV, */ 1'b0,
                           STATUS_XS, STATUS_FS, /*STATUS_MPP, 2'b0*/ 4'b0,
                           STATUS_SPP, /*STATUS_MPIE*/ 1'b0, STATUS_UBE, STATUS_SPIE,
                          /*1'b0, STATUS_MIE, 1'b0*/ 3'b0, STATUS_SIE, 1'b0};
  end

  // extract values to write to upper status register on 64/32-bit access
  if (P.XLEN==64) begin : upperstatus
    assign nextMBE = P.BIGENDIAN_SUPPORTED & CSRWriteValM[37];
    assign nextSBE = P.S_SUPPORTED & P.BIGENDIAN_SUPPORTED & CSRWriteValM[36];
  end else begin : upperstatus
    assign nextMBE = P.BIGENDIAN_SUPPORTED & STATUS_MBE;
    assign nextSBE = P.S_SUPPORTED & P.BIGENDIAN_SUPPORTED & STATUS_SBE;
  end

  // hardwired STATUS bits
  assign STATUS_TSR  = P.S_SUPPORTED & STATUS_TSR_INT; // override register with 0 if supervisor mode not supported
  assign STATUS_TW   = P.U_SUPPORTED & STATUS_TW_INT; // override register with 0 if only machine mode supported
  assign STATUS_TVM  = P.S_SUPPORTED & STATUS_TVM_INT; // override register with 0 if supervisor mode not supported
  assign STATUS_MXR  = P.S_SUPPORTED & STATUS_MXR_INT; // override register with 0 if supervisor mode not supported
  // SXL and UXL bits only matter for RV64.  Set to 10 for RV64 if mode is supported, or 0 if not
  assign STATUS_SXL  = P.S_SUPPORTED ? 2'b10 : 2'b00; // 10 if supervisor mode supported
  assign STATUS_UXL  = P.U_SUPPORTED ? 2'b10 : 2'b00; // 10 if user mode supported
  assign STATUS_SUM  = P.S_SUPPORTED & P.VIRTMEM_SUPPORTED & STATUS_SUM_INT; // override register with 0 if supervisor mode not supported
  assign STATUS_MPRV = P.U_SUPPORTED & STATUS_MPRV_INT; // override with 0 if user mode not supported
  assign STATUS_FS   = P.F_SUPPORTED ? STATUS_FS_INT : 2'b00; // off if no FP
  assign STATUS_SD   = (STATUS_FS == 2'b11) | (STATUS_XS == 2'b11); // dirty state logic
  assign STATUS_XS   = 2'b00; // No additional user-mode state to be dirty

  always_comb
    if      (CSRWriteValM[12:11] == P.U_MODE & P.U_SUPPORTED) STATUS_MPP_NEXT = P.U_MODE;
    else if (CSRWriteValM[12:11] == P.S_MODE & P.S_SUPPORTED) STATUS_MPP_NEXT = P.S_MODE;
    else if (CSRWriteValM[12:11] == P.M_MODE)                 STATUS_MPP_NEXT = P.M_MODE;
    else                                                      STATUS_MPP_NEXT = STATUS_MPP; // do not change MPP when trying to write reserved 10 or unsupported mode

  ///////////////////////////////////////////
  // Endianness logic Privileged Spec 3.1.6.4
  ///////////////////////////////////////////

  if (P.BIGENDIAN_SUPPORTED) begin : endianmux
    // determine whether big endian accesses should be made
    logic [1:0] EndiannessPrivMode;
    always_comb begin
      if      (SelHPTW)                                  EndiannessPrivMode = P.S_MODE;
      //coverage off -item c 1 -feccondrow 1
      // status.MPRV always gets reset upon leaving machine mode, so MPRV will never be high when out of machine mode
      else if (PrivilegeModeW == P.M_MODE & STATUS_MPRV) EndiannessPrivMode = STATUS_MPP;
      //coverage on
      else                                               EndiannessPrivMode = PrivilegeModeW;

      case (EndiannessPrivMode)
        P.M_MODE: BigEndianM = STATUS_MBE;
        P.S_MODE: BigEndianM = STATUS_SBE;
        default: BigEndianM  = STATUS_UBE;
      endcase
    end
  end else begin : endianmux
    assign BigEndianM = 1'b0;
  end

  // registers for STATUS bits
  // complex register with reset, write enable, and the ability to update other bits in certain cases
  always_ff @(posedge clk) //, posedge reset)
    if (reset) begin
      STATUS_TSR_INT  <= 1'b0;
      STATUS_TW_INT   <= 1'b0;
      STATUS_TVM_INT  <= 1'b0;
      STATUS_MXR_INT  <= 1'b0;
      STATUS_SUM_INT  <= 1'b0;
      STATUS_MPRV_INT <= 1'b0; // Per Priv 3.3
      STATUS_FS_INT   <= 2'b00; // leave floating-point off until activated, even if F_SUPPORTED
      STATUS_MPP      <= 2'b00;
      STATUS_SPP      <= 1'b0;
      STATUS_MPIE     <= 1'b0;
      STATUS_SPIE     <= 1'b0;
      STATUS_MIE      <= 1'b0;
      STATUS_SIE      <= 1'b0;
      STATUS_MBE      <= 1'b0;
      STATUS_SBE      <= 1'b0;
      STATUS_UBE      <= 1'b0;
    end else if (~StallW) begin
      if (TrapM) begin
        // Update interrupt enables per Privileged Spec p. 21
        // y = PrivilegeModeW
        // x = NextPrivilegeModeM
        // Modes: 11 = Machine, 01 = Supervisor, 00 = User
        if (NextPrivilegeModeM == P.M_MODE) begin
          STATUS_MPIE <= STATUS_MIE;
          STATUS_MIE  <= 1'b0;
          STATUS_MPP  <= PrivilegeModeW;
        end else if (P.S_SUPPORTED) begin // supervisor mode
          STATUS_SPIE <= STATUS_SIE;
          STATUS_SIE  <= 1'b0;
          STATUS_SPP  <= PrivilegeModeW[0];
       end
      end else if (mretM) begin // Privileged 3.1.6.1
        STATUS_MIE      <= STATUS_MPIE; // restore global interrupt enable
        STATUS_MPIE     <= 1'b1; //
        STATUS_MPP      <= P.U_SUPPORTED ? P.U_MODE : P.M_MODE; // set MPP to lowest supported privilege level
        STATUS_MPRV_INT <= STATUS_MPRV_INT & (STATUS_MPP == P.M_MODE); // page 21 of privileged spec.
      end else if (sretM & P.S_SUPPORTED) begin
        STATUS_SIE      <= STATUS_SPIE; // restore global interrupt enable
        STATUS_SPIE     <= P.S_SUPPORTED;
        STATUS_SPP      <= 1'b0; // set SPP to lowest supported privilege level to catch bugs
        STATUS_MPRV_INT <= 1'b0; // always clear MPRV
      end else if (WriteMSTATUSM) begin
        STATUS_TSR_INT  <= P.S_SUPPORTED & CSRWriteValM[22];
        STATUS_TW_INT   <= P.U_SUPPORTED & CSRWriteValM[21];
        STATUS_TVM_INT  <= P.S_SUPPORTED & CSRWriteValM[20];
        STATUS_MXR_INT  <= P.S_SUPPORTED & CSRWriteValM[19];
        STATUS_SUM_INT  <= P.VIRTMEM_SUPPORTED & CSRWriteValM[18];
        STATUS_MPRV_INT <= P.U_SUPPORTED & CSRWriteValM[17];
        STATUS_FS_INT   <= CSRWriteValM[14:13];
        STATUS_MPP      <= STATUS_MPP_NEXT;
        STATUS_SPP      <= P.S_SUPPORTED & CSRWriteValM[8];
        STATUS_MPIE     <= CSRWriteValM[7];
        STATUS_SPIE     <= P.S_SUPPORTED & CSRWriteValM[5];
        STATUS_MIE      <= CSRWriteValM[3];
        STATUS_SIE      <= P.S_SUPPORTED & CSRWriteValM[1];
        STATUS_UBE      <= P.U_SUPPORTED & P.BIGENDIAN_SUPPORTED & CSRWriteValM[6];
        STATUS_MBE      <= nextMBE;
        STATUS_SBE      <= nextSBE;
      // coverage off
      // MSTATUSH only exists in 32-bit configurations, will not be hit on rv64gc
      end else if ((P.XLEN == 32) & WriteMSTATUSHM) begin
        STATUS_MBE      <= P.BIGENDIAN_SUPPORTED & CSRWriteValM[5];
        STATUS_SBE      <= P.S_SUPPORTED & P.BIGENDIAN_SUPPORTED & CSRWriteValM[4];
      // coverage on
      end else if (P.S_SUPPORTED & WriteSSTATUSM) begin // write a subset of the STATUS bits
        STATUS_MXR_INT  <= P.S_SUPPORTED & CSRWriteValM[19];
        STATUS_SUM_INT  <= P.VIRTMEM_SUPPORTED & CSRWriteValM[18];
        STATUS_FS_INT   <= CSRWriteValM[14:13];
        STATUS_SPP      <= P.S_SUPPORTED & CSRWriteValM[8];
        STATUS_SPIE     <= P.S_SUPPORTED & CSRWriteValM[5];
        STATUS_SIE      <= P.S_SUPPORTED & CSRWriteValM[1];
        STATUS_UBE      <= P.U_SUPPORTED & P.BIGENDIAN_SUPPORTED & CSRWriteValM[6];
      end else if (FRegWriteM | WriteFRMM | SetOrWriteFFLAGSM) STATUS_FS_INT <= 2'b11;
    end
endmodule
