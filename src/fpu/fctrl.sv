///////////////////////////////////////////
// fctrl.sv
//
// Written: me@KatherineParry.com
// Modified: 7/5/2022
//
// Purpose: floating-point control unit
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

module fctrl import cvw::*;  #(parameter cvw_t P) (
  input  logic                 clk,
  input  logic                 reset,
  // input control signals
  input  logic                 StallE, StallM, StallW,             // stall signals
  input  logic                 FlushE, FlushM, FlushW,             // flush signals
  input  logic                 IntDivE,                            // is inteteger division
  input  logic [2:0]           FRM_REGW,                           // rounding mode from CSR
  input  logic [1:0]           STATUS_FS,                          // is FPU enabled?
  input  logic                 FDivBusyE,                          // is the divider busy
  // instruction
  input  logic [31:0]          InstrD,                             // the full instruction
  input  logic [6:0]           Funct7D,                            // bits 31:25 of instruction - may contain precision
  input  logic [6:0]           OpD,                                // bits 6:0 of instruction
  input  logic [4:0]           Rs2D,                               // bits 24:20 of instruction
  input  logic [2:0]           Funct3D,                            // bits 14:12 of instruction - may contain rounding mode
  // input mux selections
  output logic                 XEnD, YEnD, ZEnD,                   // enable inputs
  output logic                 XEnE, YEnE, ZEnE,                   // enable inputs
  // operation mux selections
  output logic                 FCvtIntE, FCvtIntW,                 // convert to integer operation
  output logic [2:0]           FrmE, FrmM,                          // FP rounding mode
  output logic [P.FMTBITS-1:0] FmtE, FmtM,                         // FP format
  output logic [2:0]           OpCtrlE, OpCtrlM,                   // Select which operation to do in each component
  output logic                 FpLoadStoreM,                       // FP load or store instruction
  output logic [1:0]           PostProcSelE, PostProcSelM,         // select result in the post processing unit
  output logic [1:0]           FResSelE, FResSelM, FResSelW,       // Select one of the results that finish in the memory stage
  output logic                 FPUActiveE,                         // FP instruction being executed
  output logic                 ZfaE, ZfaM,                         // Zfa variants of instructions (fli, fminm, fmaxm, fround, froundnx, fleq, fltq, fmvh, fmvp, fcvtmod)
  output logic                 ZfaFRoundNXE,                       // Zfa froundnx instruction
  // register control signals
  output logic                 FRegWriteE, FRegWriteM, FRegWriteW, // FP register write enable
  output logic                 FWriteIntE, FWriteIntM,             // Write to integer register
  output logic [4:0]           Adr1D, Adr2D, Adr3D,                // addresses of each input
  output logic [4:0]           Adr1E, Adr2E, Adr3E,                // addresses of each input
  // other control signals
  output logic                 IllegalFPUInstrD,                   // Is the instruction an illegal fpu instruction
  output logic                 FDivStartE, IDivStartE              // Start division or squareroot
  );

  `define FCTRLW 14

  logic [`FCTRLW-1:0]          ControlsD;                          // control signals
  logic                        FRegWriteD;                         // FP register write enable
  logic                        FDivStartD;                         // start division/sqrt
  logic                        FWriteIntD;                         // integer register write enable
  logic [2:0]                  OpCtrlD;                            // Select which operation to do in each component
  logic [1:0]                  PostProcSelD;                       // select result in the post processing unit
  logic [1:0]                  FResSelD;                           // Select one of the results that finish in the memory stage
  logic [2:0]                  FrmD;                               // FP rounding mode
  logic [P.FMTBITS-1:0]        FmtD;                               // FP format
  logic [1:0]                  Fmt, Fmt2;                          // format - before possible reduction
  logic                        SupportedFmt;                       // is the format supported
  logic                        SupportedFmt2;                      // is the source format supported for fp -> fp
  logic                        SupportedRM;                        // is the rounding mode supported
  logic                        FCvtIntD, FCvtIntM;                 // convert to integer operation
  logic                        ZfaD;                               // Zfa variants of instructions
  logic                        ZfaFRoundNXD;                       // Zfa froundnx instruction

  // FPU Instruction Decoder
  assign Fmt = Funct7D[1:0];
  assign Fmt2 = Rs2D[1:0]; // source format for fcvt fp->fp

  assign SupportedFmt =  (Fmt == 2'b00  | (Fmt == 2'b01 & P.D_SUPPORTED) |
                         (Fmt == 2'b10 & P.ZFH_SUPPORTED)  | (Fmt == 2'b11 & P.Q_SUPPORTED));
  assign SupportedFmt2 = (Fmt2 == 2'b00 | (Fmt2 == 2'b01 & P.D_SUPPORTED) |
                         (Fmt2 == 2'b10 & P.ZFH_SUPPORTED) | (Fmt2 == 2'b11 & P.Q_SUPPORTED));
  // rounding modes 5 and 6 are reserved.  Rounding mode 7 is dynamic, and is reserved if FRM is 5, 6, or 7
  assign SupportedRM =  ~(Funct3D == 3'b101 | Funct3D == 3'b110 | (Funct3D == 3'b111 & (FRM_REGW == 3'b101 | FRM_REGW == 3'b110 | FRM_REGW == 3'b111))) |
                         (OpD == 7'b1010011 & Funct3D == 3'b101 & Funct7D[6:2] == 5'b10100 & P.ZFA_SUPPORTED); // Zfa fltq has a funny rounding mode

  // decode the instruction
  // FRegWrite_FWriteInt_FResSel_PostProcSel_FOpCtrl_FDivStart_IllegalFPUInstr_FCvtInt_Zfa_FroundNX
  always_comb
    if (STATUS_FS == 2'b00) // FPU instructions are illegal when FPU is disabled
      ControlsD = `FCTRLW'b0_0_00_00_000_0_1_0_0_0;
    else if (OpD != 7'b0000111 & OpD != 7'b0100111 & (~SupportedFmt | ~SupportedRM))
      ControlsD = `FCTRLW'b0_0_00_00_000_0_1_0_0_0; // for anything other than loads and stores, check for supported format and rounding mode
    else begin
      ControlsD = `FCTRLW'b0_0_00_00_000_0_1_0_0_0; // default: non-implemented instruction
      /* verilator lint_off CASEINCOMPLETE */   // default value above has priority so no other default needed
      case(OpD)
        7'b0000111: case(Funct3D)
                      3'b010:                       ControlsD = `FCTRLW'b1_0_10_00_0xx_0_0_0_0_0; // flw
                      3'b011:  if (P.D_SUPPORTED)   ControlsD = `FCTRLW'b1_0_10_00_0xx_0_0_0_0_0; // fld
                      3'b100:  if (P.Q_SUPPORTED)   ControlsD = `FCTRLW'b1_0_10_00_0xx_0_0_0_0_0; // flq
                      3'b001:  if (P.ZFH_SUPPORTED) ControlsD = `FCTRLW'b1_0_10_00_0xx_0_0_0_0_0; // flh
                    endcase
        7'b0100111: case(Funct3D)
                      3'b010:                       ControlsD = `FCTRLW'b0_0_10_00_0xx_0_0_0_0_0; // fsw
                      3'b011:  if (P.D_SUPPORTED)   ControlsD = `FCTRLW'b0_0_10_00_0xx_0_0_0_0_0; // fsd
                      3'b100:  if (P.Q_SUPPORTED)   ControlsD = `FCTRLW'b0_0_10_00_0xx_0_0_0_0_0; // fsq
                      3'b001:  if (P.ZFH_SUPPORTED) ControlsD = `FCTRLW'b0_0_10_00_0xx_0_0_0_0_0; // fsh
                    endcase
        7'b1000011:   ControlsD = `FCTRLW'b1_0_01_10_000_0_0_0_0_0; // fmadd
        7'b1000111:   ControlsD = `FCTRLW'b1_0_01_10_001_0_0_0_0_0; // fmsub
        7'b1001011:   ControlsD = `FCTRLW'b1_0_01_10_010_0_0_0_0_0; // fnmsub
        7'b1001111:   ControlsD = `FCTRLW'b1_0_01_10_011_0_0_0_0_0; // fnmadd
        7'b1010011: casez(Funct7D)
                      7'b00000??: ControlsD = `FCTRLW'b1_0_01_10_110_0_0_0_0_0; // fadd
                      7'b00001??: ControlsD = `FCTRLW'b1_0_01_10_111_0_0_0_0_0; // fsub
                      7'b00010??: ControlsD = `FCTRLW'b1_0_01_10_100_0_0_0_0_0; // fmul
                      7'b00011??: ControlsD = `FCTRLW'b1_0_01_01_xx0_1_0_0_0_0; // fdiv
                      7'b01011??: if (Rs2D == 5'b0000) ControlsD = `FCTRLW'b1_0_01_01_xx1_1_0_0_0_0; // fsqrt
                      7'b00100??: case(Funct3D)
                                    3'b000:  ControlsD = `FCTRLW'b1_0_00_00_000_0_0_0_0_0; // fsgnj
                                    3'b001:  ControlsD = `FCTRLW'b1_0_00_00_001_0_0_0_0_0; // fsgnjn
                                    3'b010:  ControlsD = `FCTRLW'b1_0_00_00_010_0_0_0_0_0; // fsgnjx
                                  endcase
                      7'b00101??: case(Funct3D)
                                    3'b000:  ControlsD = `FCTRLW'b1_0_00_00_110_0_0_0_0_0; // fmin
                                    3'b001:  ControlsD = `FCTRLW'b1_0_00_00_101_0_0_0_0_0; // fmax
                                    3'b010:  if (P.ZFA_SUPPORTED) ControlsD = `FCTRLW'b1_0_00_00_110_0_0_0_1_0; // fminm  (Zfa)
                                    3'b011:  if (P.ZFA_SUPPORTED) ControlsD = `FCTRLW'b1_0_00_00_101_0_0_0_1_0; // fmaxm  (Zfa)
                                  endcase
                      7'b10100??: case(Funct3D)
                                    3'b000:  ControlsD = `FCTRLW'b0_1_00_00_011_0_0_0_0_0; // fle
                                    3'b001:  ControlsD = `FCTRLW'b0_1_00_00_001_0_0_0_0_0; // flt
                                    3'b010:  ControlsD = `FCTRLW'b0_1_00_00_010_0_0_0_0_0; // feq
                                    3'b100:  if (P.ZFA_SUPPORTED) ControlsD = `FCTRLW'b0_1_00_00_011_0_0_0_1_0; // fleq  (Zfa)
                                    3'b101:  if (P.ZFA_SUPPORTED) ControlsD = `FCTRLW'b0_1_00_00_001_0_0_0_1_0; // fltq  (Zfa)
                                  endcase
                      7'b11100??: if (Funct3D == 3'b001 & Rs2D == 5'b00000)
                                                ControlsD = `FCTRLW'b0_1_10_00_000_0_0_0_0_0; // fclass
                                  else if (Funct3D == 3'b000 & Rs2D == 5'b00000) begin
                                    if (Fmt[1:0] == 2'b00 | Fmt[1:0] == 2'b10 | (P.XLEN == 64 & Fmt[1:0] == 2'b01)) // coverage-tag: fmv fp to int
                                                ControlsD = `FCTRLW'b0_1_11_00_000_0_0_0_0_0; // fmv.x.w/d/h  fp to int register (double only in RV64)
                                  end else if (P.ZFA_SUPPORTED & P.XLEN == 32 & P.D_SUPPORTED & Funct7D[1:0] == 2'b01 & Funct3D == 3'b000 & Rs2D == 5'b00001)
                                                ControlsD = `FCTRLW'b0_1_11_00_000_0_0_0_1_0; // fmvh.x.d  (Zfa)
                                  //  Q not supported in RV64GC
                                  // coverage off
                                  else if (P.ZFA_SUPPORTED & P.XLEN == 64 & P.Q_SUPPORTED & Funct7D[1:0] == 2'b11 & Funct3D == 3'b000 & Rs2D == 5'b00001)
                                                ControlsD = `FCTRLW'b0_1_11_00_000_0_0_0_1_0; // fmvh.x.q  (Zfa)
                                  // coverage on
                      7'b11110??: if (Funct3D == 3'b000 & Rs2D == 5'b00000) begin
                                    if (Fmt[1:0] == 2'b00 | Fmt[1:0] == 2'b10 | (P.XLEN == 64 & Fmt[1:0] == 2'b01))  // coverage-tag: fmv int to fp
                                                ControlsD = `FCTRLW'b1_0_00_00_011_0_0_0_0_0; // fmv.w/d/h.x  int to fp reg (double only in RV64)
                                  end else if (P.ZFA_SUPPORTED & Funct3D == 3'b000 & Rs2D == 5'b00001)
                                                ControlsD = `FCTRLW'b1_0_00_00_111_0_0_0_1_0; // fli  (Zfa)
                      7'b0100000: if (Rs2D[4:2] == 3'b000 & SupportedFmt2 & Rs2D[1:0] != 2'b00)
                                                ControlsD = `FCTRLW'b1_0_01_00_000_0_0_0_0_0; // fcvt.s.(d/q/h)
                                  else if (Rs2D == 5'b00100 & P.ZFA_SUPPORTED)
                                                ControlsD = `FCTRLW'b1_0_00_00_100_0_0_0_1_0; // fround.s  (Zfa)
                                  else if (Rs2D == 5'b00101 & P.ZFA_SUPPORTED)
                                                ControlsD = `FCTRLW'b1_0_00_00_100_0_0_0_1_1; // froundnx.s  (Zfa)
                      7'b0100001: if (Rs2D[4:2] == 3'b000  & SupportedFmt2 & Rs2D[1:0] != 2'b01)
                                                ControlsD = `FCTRLW'b1_0_01_00_001_0_0_0_0_0; // fcvt.d.(s/h/q)
                                  else if (Rs2D == 5'b00100 & P.ZFA_SUPPORTED)
                                                ControlsD = `FCTRLW'b1_0_00_00_100_0_0_0_1_0; // fround.d  (Zfa)
                                  else if (Rs2D == 5'b00101 & P.ZFA_SUPPORTED)
                                                ControlsD = `FCTRLW'b1_0_00_00_100_0_0_0_1_1; // froundnx.d  (Zfa)
                      7'b0100010: if (Rs2D[4:2] == 3'b000 & SupportedFmt2 & Rs2D[1:0] != 2'b10)
                                                ControlsD = `FCTRLW'b1_0_01_00_010_0_0_0_0_0; // fcvt.h.(s/d/q)
                                  else if (Rs2D == 5'b00100 & P.ZFA_SUPPORTED)
                                                ControlsD = `FCTRLW'b1_0_00_00_100_0_0_0_1_0; // fround.h  (Zfa)
                                  else if (Rs2D == 5'b00101 & P.ZFA_SUPPORTED)
                                                ControlsD = `FCTRLW'b1_0_00_00_100_0_0_0_1_1; // froundnx.h  (Zfa)
                      // coverage off
                      // Not covered in testing because rv64gc does not support quad precision
                      7'b0100011: if (Rs2D[4:2] == 3'b000  & SupportedFmt2 & Rs2D[1:0] != 2'b11)
                                                ControlsD = `FCTRLW'b1_0_01_00_011_0_0_0_0_0; // fcvt.q.(s/h/d)
                                  else if (Rs2D == 5'b00100 & P.ZFA_SUPPORTED)
                                                ControlsD = `FCTRLW'b1_0_00_00_100_0_0_0_1_0; // fround.q  (Zfa)
                                  else if (Rs2D == 5'b00101 & P.ZFA_SUPPORTED)
                                                ControlsD = `FCTRLW'b1_0_00_00_100_0_0_0_1_1; // froundnx.q  (Zfa)
                      // coverage on
                      7'b1101000: case(Rs2D)
                                    5'b00000:    ControlsD = `FCTRLW'b1_0_01_00_101_0_0_0_0_0; // fcvt.s.w   w->s
                                    5'b00001:    ControlsD = `FCTRLW'b1_0_01_00_100_0_0_0_0_0; // fcvt.s.wu wu->s
                                    5'b00010:    if (P.XLEN == 64) ControlsD = `FCTRLW'b1_0_01_00_111_0_0_0_0_0; // fcvt.s.l   l->s
                                    5'b00011:    if (P.XLEN == 64) ControlsD = `FCTRLW'b1_0_01_00_110_0_0_0_0_0; // fcvt.s.lu lu->s
                                  endcase
                      7'b1100000: case(Rs2D)
                                    5'b00000:    ControlsD = `FCTRLW'b0_1_01_00_001_0_0_1_0_0; // fcvt.w.s   s->w
                                    5'b00001:    ControlsD = `FCTRLW'b0_1_01_00_000_0_0_1_0_0; // fcvt.wu.s  s->wu
                                    5'b00010:    if (P.XLEN == 64) ControlsD = `FCTRLW'b0_1_01_00_011_0_0_1_0_0; // fcvt.l.s   s->l
                                    5'b00011:    if (P.XLEN == 64) ControlsD = `FCTRLW'b0_1_01_00_010_0_0_1_0_0; // fcvt.lu.s  s->lu
                                  endcase
                      7'b1101001: case(Rs2D)
                                    5'b00000:    ControlsD = `FCTRLW'b1_0_01_00_101_0_0_0_0_0; // fcvt.d.w   w->d
                                    5'b00001:    ControlsD = `FCTRLW'b1_0_01_00_100_0_0_0_0_0; // fcvt.d.wu wu->d
                                    5'b00010:    if (P.XLEN == 64) ControlsD = `FCTRLW'b1_0_01_00_111_0_0_0_0_0; // fcvt.d.l   l->d
                                    5'b00011:    if (P.XLEN == 64) ControlsD = `FCTRLW'b1_0_01_00_110_0_0_0_0_0; // fcvt.d.lu lu->d
                                  endcase
                      7'b1100001: case(Rs2D)
                                    5'b00000:    ControlsD = `FCTRLW'b0_1_01_00_001_0_0_1_0_0; // fcvt.w.d   d->w
                                    5'b00001:    ControlsD = `FCTRLW'b0_1_01_00_000_0_0_1_0_0; // fcvt.wu.d  d->wu
                                    5'b00010:    if (P.XLEN == 64) ControlsD = `FCTRLW'b0_1_01_00_011_0_0_1_0_0; // fcvt.l.d   d->l
                                    5'b00011:    if (P.XLEN == 64) ControlsD = `FCTRLW'b0_1_01_00_010_0_0_1_0_0; // fcvt.lu.d  d->lu
                                    5'b01000: if (P.ZFA_SUPPORTED & P.D_SUPPORTED & Funct3D == 3'b001)
                                                 ControlsD = `FCTRLW'b0_1_01_00_001_0_0_1_1_0; // fcvtmod.w.d (Zfa)
                                  endcase
                      7'b1101010: case(Rs2D)
                                    5'b00000:    ControlsD = `FCTRLW'b1_0_01_00_101_0_0_0_0_0; // fcvt.h.w   w->h
                                    5'b00001:    ControlsD = `FCTRLW'b1_0_01_00_100_0_0_0_0_0; // fcvt.h.wu wu->h
                                    5'b00010:    if (P.XLEN == 64) ControlsD = `FCTRLW'b1_0_01_00_111_0_0_0_0_0; // fcvt.h.l   l->h
                                    5'b00011:    if (P.XLEN == 64) ControlsD = `FCTRLW'b1_0_01_00_110_0_0_0_0_0; // fcvt.h.lu lu->h
                                  endcase
                      7'b1100010: case(Rs2D)
                                    5'b00000:    ControlsD = `FCTRLW'b0_1_01_00_001_0_0_1_0_0; // fcvt.w.h   h->w
                                    5'b00001:    ControlsD = `FCTRLW'b0_1_01_00_000_0_0_1_0_0; // fcvt.wu.h  h->wu
                                    5'b00010:    if (P.XLEN == 64) ControlsD = `FCTRLW'b0_1_01_00_011_0_0_1_0_0; // fcvt.l.h   h->l
                                    5'b00011:    if (P.XLEN == 64) ControlsD = `FCTRLW'b0_1_01_00_010_0_0_1_0_0; // fcvt.lu.h  h->lu
                                  endcase
                      // Not covered in testing because rv64gc does not support quad precision
                      // coverage off
                      7'b1101011: case(Rs2D)
                                    5'b00000:    ControlsD = `FCTRLW'b1_0_01_00_101_0_0_0_0_0; // fcvt.q.w   w->q
                                    5'b00001:    ControlsD = `FCTRLW'b1_0_01_00_100_0_0_0_0_0; // fcvt.q.wu wu->q
                                    5'b00010:    if (P.XLEN == 64) ControlsD = `FCTRLW'b1_0_01_00_111_0_0_0_0_0; // fcvt.q.l   l->q
                                    5'b00011:    if (P.XLEN == 64) ControlsD = `FCTRLW'b1_0_01_00_110_0_0_0_0_0; // fcvt.q.lu lu->q
                                  endcase
                      7'b1100011: case(Rs2D)
                                    5'b00000:    ControlsD = `FCTRLW'b0_1_01_00_001_0_0_1_0_0; // fcvt.w.q   q->w
                                    5'b00001:    ControlsD = `FCTRLW'b0_1_01_00_000_0_0_1_0_0; // fcvt.wu.q  q->wu
                                    5'b00010:    if (P.XLEN == 64) ControlsD = `FCTRLW'b0_1_01_00_011_0_0_1_0_0; // fcvt.l.q   q->l
                                    5'b00011:    if (P.XLEN == 64) ControlsD = `FCTRLW'b0_1_01_00_010_0_0_1_0_0; // fcvt.lu.q  q->lu
                                  endcase
                      // coverage off
                      // Not covered in testing because rv64gc is not RV64Q or RV32D
                      7'b1011001: if (P.ZFA_SUPPORTED & P.XLEN == 32 & P.D_SUPPORTED & Funct3D == 3'b000)
                                                  ControlsD = `FCTRLW'b1_0_00_00_011_0_0_0_1_0; // fmvp.d.x  (Zfa)
                      7'b1011011: if (P.ZFA_SUPPORTED & P.XLEN == 64 & P.Q_SUPPORTED & Funct3D == 3'b000)
                                                  ControlsD = `FCTRLW'b1_0_00_00_011_0_0_0_1_0; // fmvp.q.x  (Zfa)
                      // coverage on
                   endcase
      endcase
    end
    /* verilator lint_on CASEINCOMPLETE */

  // unswizzle control bits
  assign {FRegWriteD, FWriteIntD, FResSelD, PostProcSelD, OpCtrlD, FDivStartD, IllegalFPUInstrD, FCvtIntD, ZfaD, ZfaFRoundNXD} = ControlsD;

  // rounding modes:
  //    000 - round to nearest, ties to even
  //    001 - round twords 0 - round to min magnitude
  //    010 - round down - round twords negative infinity
  //    011 - round up - round twords positive infinity
  //    100 - round to nearest, ties to max magnitude - round to nearest, ties away from zero
  //    111 - dynamic - choose FRM_REGW as rounding mode
  assign FrmD = (Funct3D == 3'b111) ? FRM_REGW : Funct3D;

  // Precision
  //    00 - single
  //    01 - double
  //    10 - half
  //    11 - quad

    if (P.FPSIZES == 1)
      assign FmtD = 1'b0;
    else if (P.FPSIZES == 2) begin
      logic [1:0] FmtTmp;
      assign FmtTmp = ((Funct7D[6:3] == 4'b0100)&OpD[4]&~Rs2D[2]) ? Rs2D[1:0] : (~OpD[6]&(&OpD[2:0])) ? {~Funct3D[1], ~(Funct3D[1]^Funct3D[0])} : Funct7D[1:0];
      assign FmtD = (P.FMT == FmtTmp);
    end else if (P.FPSIZES == 3|P.FPSIZES == 4)
      assign FmtD = ((Funct7D[6:3] == 4'b0100)&OpD[4]&~Rs2D[2]) ? Rs2D[1:0] : Funct7D[1:0];

  // Enables indicate that a source register is used and may need stalls. Also indicate special cases for infinity or NaN.
  // When disabled infinity and NaN on source registers are ignored by the unpacker and thus special case logic.

  //    X - all except int->fp, store, load, mv int->fp
  assign XEnD = ~(((FResSelD==2'b10)&~FWriteIntD)|                                                 // load/store
                  ((FResSelD==2'b00)&FRegWriteD&(OpCtrlD==3'b011))|                                // mv int to float
                  ((FResSelD==2'b01)&(PostProcSelD==2'b00)&OpCtrlD[2]));                           // cvt int to float

  //    Y - all except cvt, mv, load, class, sqrt
  assign YEnD = ~(((FResSelD==2'b10)&(FWriteIntD|FRegWriteD))|                                     // load or class
                  ((FResSelD==2'b00)&FRegWriteD&(OpCtrlD==3'b011))|                                // mv int to float as above
                  ((FResSelD==2'b11)&(PostProcSelD==2'b00))|                                       // mv float to int
                  ((FResSelD==2'b01)&((PostProcSelD==2'b00)|((PostProcSelD==2'b01)&OpCtrlD[0])))); // cvt both or sqrt

  //    Z - fma ops only
  assign ZEnD = (PostProcSelD==2'b10)&(~OpCtrlD[2]|OpCtrlD[1]);                                    // fma, add, sub

  //  Final Res Sel:
  //        fp      int
  //  00  other     cmp
  //  01  postproc  cvt
  //  10  store     class
  //  11            mv

  //  post processing Sel:
  //  00  cvt
  //  01  div
  //  10  fma

  //  Other Sel:
  //    Ctrl signal = {OpCtrl[2], &FOpctrl[1:0]}
  //        000 - sign            00
  //        001 - negate sign     00
  //        010 - xor sign        00
  //        011 - mv to fp        01
  //        110 - min             10
  //        101 - max             10
  //        100 - fround          11
  //        111 - fli             11

  //  OpCtrl:
  //    Fma: {not multiply-add?, negate prod?, negate Z?}
  //        000 - fmadd
  //        001 - fmsub
  //        010 - fnmsub
  //        011 - fnmadd
  //        100 - mul
  //        110 - add
  //        111 - sub
  //    Div:
  //        0 - div
  //        1 - sqrt
  //    Cvt Int: {Int to Fp?, 64 bit int?, signed int?}
  //    Cvt Fp: output format
  //        10 - to half
  //        00 - to single
  //        01 - to double
  //        11 - to quad
  //    Cmp: {equal?, less than?}
  //        010 - eq
  //        001 - lt
  //        011 - le
  //        110 - min
  //        101 - max
  //    Sgn:
  //        00 - sign
  //        01 - negate sign
  //        10 - xor sign

  // rename input addresses for readability
  assign Adr1D = InstrD[19:15];
  assign Adr2D = InstrD[24:20];
  assign Adr3D = InstrD[31:27];

  // D/E pipeline register
  flopenrc #(`FCTRLW+2+P.FMTBITS) DECtrlReg3(clk, reset, FlushE, ~StallE,
              {FRegWriteD, PostProcSelD, FResSelD, FrmD, FmtD, OpCtrlD, FWriteIntD, FCvtIntD, ZfaD, ZfaFRoundNXD, ~IllegalFPUInstrD},
              {FRegWriteE, PostProcSelE, FResSelE, FrmE, FmtE, OpCtrlE, FWriteIntE, FCvtIntE, ZfaE, ZfaFRoundNXE, FPUActiveE});
  flopenrc #(15) DEAdrReg(clk, reset, FlushE, ~StallE, {Adr1D, Adr2D, Adr3D}, {Adr1E, Adr2E, Adr3E});
  flopenrc #(1) DEFDivStartReg(clk, reset, FlushE, ~StallE|FDivBusyE, FDivStartD, FDivStartE);
  flopenrc #(3) DEEnReg(clk, reset, FlushE, ~StallE, {XEnD, YEnD, ZEnD}, {XEnE, YEnE, ZEnE});

  // Integer division on FPU divider
  if (P.M_SUPPORTED & P.IDIV_ON_FPU) assign IDivStartE = IntDivE;
  else                               assign IDivStartE = 1'b0;

  // E/M pipeline register
  flopenrc #(14+int'(P.FMTBITS)) EMCtrlReg (clk, reset, FlushM, ~StallM,
              {FRegWriteE, FResSelE, PostProcSelE, FrmE, FmtE, OpCtrlE, FWriteIntE, FCvtIntE, ZfaE},
              {FRegWriteM, FResSelM, PostProcSelM, FrmM, FmtM, OpCtrlM, FWriteIntM, FCvtIntM, ZfaM});

  // renameing for readability
  assign FpLoadStoreM = FResSelM[1];

  // M/W pipeline register
  flopenrc #(4)  MWCtrlReg(clk, reset, FlushW, ~StallW,
          {FRegWriteM, FResSelM, FCvtIntM},
          {FRegWriteW, FResSelW, FCvtIntW});

endmodule
