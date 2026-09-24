///////////////////////////////////////////
// vdecoder.sv
//
// Written: Rose Thompson rose.thompson@skyworksinc.com
// Created: 26 August 2026
// Modified: 26 August 2026
//
// Purpose: vector decoder module
//
// Documentation: RISC-V System on Chip Design Volume 2
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University & Skyworks Solutions Inc.
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

/* verilator lint_off UNUSEDPARAM */
// *** this will be useful later. Remove the lint_off when ready
module vdecoder import cvw::*;  #(parameter cvw_t P) (
/* verilator lint_on UNUSEDPARAM */
  input  logic        clk, reset,
  // Decode stage control signals
  input  logic        StallD, FlushD,           // Stall, flush Decode stage
  input  logic [31:0] InstrD,                   // lmul sequenced micro-op instruction in Decode stage
  // CSR state
  input  logic [1:0]        STATUS_VS,
  input  logic [P.XLEN-1:0] VTYPE_REGW,
  // Decode stage outputs
  output logic [4:0]  Vs1D, Vs2D,               // Vector Source 1 and 2
  output logic [4:0]  VdD,                      // Vector Destination read (overwrite)
  output logic        VmD,                      // 0 = mask enabled, 1 mask disabled
  output logic [5:0]  Funct6D,
  output logic [2:0]  Funct3D,
  output logic        VWriteIntD, VWriteFPD, VRegWriteD,
  output logic [2:0]  VEUTypeD,                 // type of EU an instruction needs (INT, FP, LSU)
  output logic [3:0]  VOpClassD,                // execution block requirement for the EU
  output logic [5:0]  VLSModeD,                 // addressing modes for load/store
  output logic        VReductionD,              // instr is a reduction op
  output logic [1:0]  VdEEWD, Vs1EEWD, Vs2EEWD, // effective element width of Vd/Vs1/Vs2
  output logic [2:0]  VLSEEWD,                  // effective element width of load/store
  output logic [1:0]  VALUSrcAD,
  output logic        VALUSrcBD,
  output logic        VALUResultD,
  output logic        IllegalVPUInstrD,
  output logic        VsetD,                    // vsetvli, vsetivli, or vsetvl
  output logic        VsetvlD,                  // vsetvl: vtype comes from rs2 rather than an immediate
  output logic        VsetivliD,                // vsetivli: AVL is the uimm5 in the rs1 field
  output logic [10:0] VTYPEImmD                 // zero-extended vtype immediate for vsetvli / vsetivli
);

  logic [6:0] OpD;                              // Opcode in Decode stage
  logic       OPIVVD, OPFVVD, OPMVVD, OPIVID;
  logic       OPIVXD, OPFVFD, OPMVXD, VSETD;

  `define VCTRLW 7

  logic [`VCTRLW-1:0] VControlsD;

  // Field extraction
  assign OpD     = InstrD[6:0];
  assign Funct3D = InstrD[14:12];
  assign Funct6D = InstrD[31:26];
  assign Vs1D    = InstrD[19:15];
  assign Vs2D    = InstrD[24:20];
  assign VdD     = InstrD[11:7];
  assign VmD     = InstrD[25];

  assign OPIVVD  = (OpD == 7'b1010111) & (Funct3D == 3'b000);
  assign OPFVVD  = (OpD == 7'b1010111) & (Funct3D == 3'b001);
  assign OPMVVD  = (OpD == 7'b1010111) & (Funct3D == 3'b010);
  assign OPIVID  = (OpD == 7'b1010111) & (Funct3D == 3'b011);
  assign OPIVXD  = (OpD == 7'b1010111) & (Funct3D == 3'b100);
  assign OPFVFD  = (OpD == 7'b1010111) & (Funct3D == 3'b101);
  assign OPMVXD  = (OpD == 7'b1010111) & (Funct3D == 3'b110);
  assign VSETD   = (OpD == 7'b1010111) & (Funct3D == 3'b111);

  // Vector load/store sub-decode
  logic [2:0] NfD;                       // nf+1 fields per segment
  logic [1:0] MopD;                      // addressing mode
  logic [4:0] LSumopD;                   // unit-stride sub-opcode
  logic       MewD;                      // element width extension (mew=1 reserved)
  logic       SupportedEEWD;             // element width is defined and fits in ELEN

  assign NfD     = InstrD[31:29];
  assign MewD    = InstrD[28];
  assign MopD    = InstrD[27:26];
  assign LSumopD = InstrD[24:20];

  // Vls width field to element width
  always_comb begin
    VLSEEWD        = 3'b000;
    SupportedEEWD = 1'b0;
    if (~MewD) begin
      case (Funct3D)
        3'b000:  begin VLSEEWD = 3'd0; SupportedEEWD = 1'b1;            end // 8b
        3'b101:  begin VLSEEWD = 3'd1; SupportedEEWD = (P.ELEN >= 16);  end // 16b
        3'b110:  begin VLSEEWD = 3'd2; SupportedEEWD = (P.ELEN >= 32);  end // 32b
        3'b111:  begin VLSEEWD = 3'd3; SupportedEEWD = (P.ELEN >= 64);  end // 64b
        default: begin VLSEEWD = 3'd0; SupportedEEWD = 1'b0;            end
      endcase
    end
  end

  // Vls addressing modes
  localparam logic [5:0] VLSMODE_SEGMENT    = 6'b000001,
                         VLSMODE_STRIDED    = 6'b000010,
                         VLSMODE_INDEXED    = 6'b000100,
                         VLSMODE_ORDERED    = 6'b001000,
                         VLSMODE_FAULTFIRST = 6'b010000,
                         VLSMODE_WHOLEREG   = 6'b100000;

  logic       VLSFunctD;
  logic [5:0] VSegmentD;

  assign VSegmentD = (NfD == 3'd0) ? 6'b000000 : VLSMODE_SEGMENT;

  always_comb begin
    VLSModeD  = 6'b000000;
    VLSFunctD = 1'b0;
    if (SupportedEEWD)
      case (MopD)
        2'b00: case (LSumopD)      // unit-stride
                 5'b00000: begin   // vle{8,16,32,64}.v, vse...
                             VLSFunctD = 1'b1;
                             VLSModeD  = VSegmentD;
                           end
                 5'b01000: begin   // vl<nr>re<eew>.v, vs<nr>r.v
                             VLSFunctD = VmD & ((NfD == 3'd0) | (NfD == 3'd1) | (NfD == 3'd3) | (NfD == 3'd7)) &
                                         ((OpD == 7'b0000111) | (Funct3D == 3'b000));  // whole register stores are 8 bit
                             VLSModeD  = VLSMODE_WHOLEREG;                             // nf is a register count here
                           end
                 5'b01011:   VLSFunctD = VmD & (NfD == 3'd0) & (Funct3D == 3'b000);    // vlm.v, vsm.v
                 5'b10000: begin   // vle<eew>ff.v, loads only
                             VLSFunctD = OpD == 7'b0000111;   // loads only
                             VLSModeD  = VLSMODE_FAULTFIRST | VSegmentD;
                           end
                 default: ;
               endcase
        2'b01: begin VLSFunctD = 1'b1; VLSModeD = VLSMODE_INDEXED | VSegmentD;                   end
        2'b10: begin VLSFunctD = 1'b1; VLSModeD = VLSMODE_STRIDED | VSegmentD;                   end
        2'b11: begin VLSFunctD = 1'b1; VLSModeD = VLSMODE_INDEXED | VLSMODE_ORDERED | VSegmentD; end
        default: ;
      endcase
  end

  // vset decoding
  logic VsetvliD;

  assign VsetvliD  = VSETD & (InstrD[31] == 1'b0);             // vsetvli:  InstrD[31]    == 0       → vtype imm = InstrD[30:20], AVL = rs1   InstrD[19:15]
  assign VsetivliD = VSETD & (InstrD[31:30] == 2'b11);         // vsetivli: InstrD[31:30] == 11      → vtype imm = InstrD[29:20], AVL = uimm5 InstrD[19:15]
  assign VsetvlD   = VSETD & (InstrD[31:25] == 7'b1000000);    // vsetvl:   InstrD[31:25] == 1000000 → vtype rs2 = InstrD[24:20], AVL = rs1   InstrD[19:15]
  assign VTYPEImmD = VsetivliD ? {1'b0, InstrD[29:20]} : InstrD[30:20];

  // execution unit class
  localparam logic [2:0] VEUTYPE_INT = 3'b001, VEUTYPE_FP = 3'b010, VEUTYPE_MEM = 3'b100;

  `define VEUCTRLW 11

  logic [7:0]           SupportedFunct6D;       // members this family defines, one bit per funct6[2:0]
  logic [`VEUCTRLW-1:0] VEUControlsD;
  logic [`VEUCTRLW-1:0] VUnaryControlsD;
  logic                 VFunctD;                // a defined OP-V encoding in a configured category
  logic                 VUnaryD;                // vs1 holds a sub-opcode, not a source register
  logic                 SupportedUnaryD;        // and that vs1 value is defined
  logic                 VUnaryWriteIntD, VUnaryWriteFPD;  // writes x[rd] or f[rd] instead of Vd
  logic [7:0]           SupportedCvtD;          // conversions, indexed by vs1[2:0] in a width group

  assign VUnaryD = (OPMVVD & ((Funct6D == 6'b010000) | (Funct6D == 6'b010010) | (Funct6D == 6'b010100))) |
                   (OPFVVD & ((Funct6D == 6'b010000) | (Funct6D == 6'b010010) | (Funct6D == 6'b010011))) |
                   (OPIVID &  (Funct6D == 6'b100111));

  // Legal instructions
  always_comb
    if (OPIVVD)
      case (Funct6D[5:3])
        3'b000:  SupportedFunct6D = 8'b1111_0101;   // 7:vmax 6:vmaxu 5:vmin 4:vminu 3:- 2:vsub 1:- 0:vadd
        3'b001:  SupportedFunct6D = 8'b0101_1110;   // 7:- 6:vrgatherei16 5:- 4:vrgather 3:vxor 2:vor 1:vand 0:-
        3'b010:  SupportedFunct6D = 8'b1000_1111;   // 7:vmerge/vmv 6:- 5:- 4:- 3:vmsbc 2:vsbc 1:vmadc 0:vadc
        3'b011:  SupportedFunct6D = 8'b0011_1111;   // 7:- 6:- 5:vmsle 4:vmsleu 3:vmslt 2:vmsltu 1:vmsne 0:vmseq
        3'b100:  SupportedFunct6D = 8'b1010_1111;   // 7:vsmul 6:- 5:vsll 4:- 3:vssub 2:vssubu 1:vsadd 0:vsaddu
        3'b101:  SupportedFunct6D = 8'b1111_1111;   // 7:vnclip.w 6:vnclipu.w 5:vnsra.w 4:vnsrl.w 3:vssra 2:vssrl 1:vsra 0:vsrl
        3'b110:  SupportedFunct6D = 8'b0000_0011;   // 7:- 6:- 5:- 4:- 3:- 2:- 1:vwredsum 0:vwredsumu
        default: SupportedFunct6D = 8'b0000_0000;
      endcase
    else if (OPIVXD)
      case (Funct6D[5:3])
        3'b000:  SupportedFunct6D = 8'b1111_1101;   // 7:vmax 6:vmaxu 5:vmin 4:vminu 3:vrsub 2:vsub 1:- 0:vadd
        3'b001:  SupportedFunct6D = 8'b1101_1110;   // 7:vslidedown 6:vslideup 5:- 4:vrgather 3:vxor 2:vor 1:vand 0:-
        3'b010:  SupportedFunct6D = 8'b1000_1111;   // 7:vmerge/vmv 6:- 5:- 4:- 3:vmsbc 2:vsbc 1:vmadc 0:vadc
        3'b011:  SupportedFunct6D = 8'b1111_1111;   // 7:vmsgt 6:vmsgtu 5:vmsle 4:vmsleu 3:vmslt 2:vmsltu 1:vmsne 0:vmseq
        3'b100:  SupportedFunct6D = 8'b1010_1111;   // 7:vsmul 6:- 5:vsll 4:- 3:vssub 2:vssubu 1:vsadd 0:vsaddu
        3'b101:  SupportedFunct6D = 8'b1111_1111;   // 7:vnclip.w 6:vnclipu.w 5:vnsra.w 4:vnsrl.w 3:vssra 2:vssrl 1:vsra 0:vsrl
        default: SupportedFunct6D = 8'b0000_0000;
      endcase
    else if (OPIVID)
      case (Funct6D[5:3])
        3'b000:  SupportedFunct6D = 8'b0000_1001;   // 7:- 6:- 5:- 4:- 3:vrsub 2:- 1:- 0:vadd
        3'b001:  SupportedFunct6D = 8'b1101_1110;   // 7:vslidedown 6:vslideup 5:- 4:vrgather 3:vxor 2:vor 1:vand 0:-
        3'b010:  SupportedFunct6D = 8'b1000_0011;   // 7:vmerge/vmv 6:- 5:- 4:- 3:- 2:- 1:vmadc 0:vadc
        3'b011:  SupportedFunct6D = 8'b1111_0011;   // 7:vmsgt 6:vmsgtu 5:vmsle 4:vmsleu 3:- 2:- 1:vmsne 0:vmseq
        3'b100:  SupportedFunct6D = 8'b1010_0011;   // 7:vmv1r/vmv2r/vm 6:- 5:vsll 4:- 3:- 2:- 1:vsadd 0:vsaddu
        3'b101:  SupportedFunct6D = 8'b1111_1111;   // 7:vnclip.w 6:vnclipu.w 5:vnsra.w 4:vnsrl.w 3:vssra 2:vssrl 1:vsra 0:vsrl
        default: SupportedFunct6D = 8'b0000_0000;
      endcase
    else if (OPMVVD)
      case (Funct6D[5:3])
        3'b000:  SupportedFunct6D = 8'b1111_1111;   // 7:vredmax 6:vredmaxu 5:vredmin 4:vredminu 3:vredxor 2:vredor 1:vredand 0:vredsum
        3'b001:  SupportedFunct6D = 8'b0000_1111;   // 7:- 6:- 5:- 4:- 3:vasub 2:vasubu 1:vaadd 0:vaaddu
        3'b010:  SupportedFunct6D = 8'b1001_0101;   // 7:vcompress 6:- 5:- 4:vid/viota/vmsb 3:- 2:vsext/vzext 1:- 0:vcpop/vfirst/v
        3'b011:  SupportedFunct6D = 8'b1111_1111;   // 7:vmxnor 6:vmnor 5:vmnand 4:vmorn 3:vmxor 2:vmor 1:vmand 0:vmandn
        3'b100:  SupportedFunct6D = 8'b1111_1111;   // 7:vmulh 6:vmulhsu 5:vmul 4:vmulhu 3:vrem 2:vremu 1:vdiv 0:vdivu
        3'b101:  SupportedFunct6D = 8'b1010_1010;   // 7:vnmsac 6:- 5:vmacc 4:- 3:vnmsub 2:- 1:vmadd 0:-
        3'b110:  SupportedFunct6D = 8'b1111_1111;   // 7:vwsub.w 6:vwsubu.w 5:vwadd.w 4:vwaddu.w 3:vwsub 2:vwsubu 1:vwadd 0:vwaddu
        3'b111:  SupportedFunct6D = 8'b1011_1101;   // 7:vwmaccsu 6:- 5:vwmacc 4:vwmaccu 3:vwmul 2:vwmulsu 1:- 0:vwmulu
        default: SupportedFunct6D = 8'b0000_0000;
      endcase
    else if (OPMVXD)
      case (Funct6D[5:3])
        3'b001:  SupportedFunct6D = 8'b1100_1111;   // 7:vslide1down 6:vslide1up 5:- 4:- 3:vasub 2:vasubu 1:vaadd 0:vaaddu
        3'b010:  SupportedFunct6D = 8'b0000_0001;   // 7:- 6:- 5:- 4:- 3:- 2:- 1:- 0:vmv
        3'b100:  SupportedFunct6D = 8'b1111_1111;   // 7:vmulh 6:vmulhsu 5:vmul 4:vmulhu 3:vrem 2:vremu 1:vdiv 0:vdivu
        3'b101:  SupportedFunct6D = 8'b1010_1010;   // 7:vnmsac 6:- 5:vmacc 4:- 3:vnmsub 2:- 1:vmadd 0:-
        3'b110:  SupportedFunct6D = 8'b1111_1111;   // 7:vwsub.w 6:vwsubu.w 5:vwadd.w 4:vwaddu.w 3:vwsub 2:vwsubu 1:vwadd 0:vwaddu
        3'b111:  SupportedFunct6D = 8'b1111_1101;   // 7:vwmaccsu 6:vwmaccus 5:vwmacc 4:vwmaccu 3:vwmul 2:vwmulsu 1:- 0:vwmulu
        default: SupportedFunct6D = 8'b0000_0000;
      endcase
    else if (OPFVVD)
      case (Funct6D[5:3])
        3'b000:  SupportedFunct6D = 8'b1111_1111;   // 7:vfredmax 6:vfmax 5:vfredmin 4:vfmin 3:vfredosum 2:vfsub 1:vfredusum 0:vfadd
        3'b001:  SupportedFunct6D = 8'b0000_0111;   // 7:- 6:- 5:- 4:- 3:- 2:vfsgnjx 1:vfsgnjn 0:vfsgnj
        3'b010:  SupportedFunct6D = 8'b0000_1101;   // 7:- 6:- 5:- 4:- 3:vfclass/vfrec7 2:vfcvt/vfncvt/v 1:- 0:vfmv
        3'b011:  SupportedFunct6D = 8'b0001_1011;   // 7:- 6:- 5:- 4:vmfne 3:vmflt 2:- 1:vmfle 0:vmfeq
        3'b100:  SupportedFunct6D = 8'b0001_0001;   // 7:- 6:- 5:- 4:vfmul 3:- 2:- 1:- 0:vfdiv
        3'b101:  SupportedFunct6D = 8'b1111_1111;   // 7:vfnmsac 6:vfmsac 5:vfnmacc 4:vfmacc 3:vfnmsub 2:vfmsub 1:vfnmadd 0:vfmadd
        3'b110:  SupportedFunct6D = 8'b0101_1111;   // 7:- 6:vfwsub.w 5:- 4:vfwadd.w 3:vfwredosum 2:vfwsub 1:vfwredusum 0:vfwadd
        3'b111:  SupportedFunct6D = 8'b1111_0001;   // 7:vfwnmsac 6:vfwmsac 5:vfwnmacc 4:vfwmacc 3:- 2:- 1:- 0:vfwmul
        default: SupportedFunct6D = 8'b0000_0000;
      endcase
    else if (OPFVFD)
      case (Funct6D[5:3])
        3'b000:  SupportedFunct6D = 8'b0101_0101;   // 7:- 6:vfmax 5:- 4:vfmin 3:- 2:vfsub 1:- 0:vfadd
        3'b001:  SupportedFunct6D = 8'b1100_0111;   // 7:vfslide1down 6:vfslide1up 5:- 4:- 3:- 2:vfsgnjx 1:vfsgnjn 0:vfsgnj
        3'b010:  SupportedFunct6D = 8'b1000_0001;   // 7:vfmerge/vfmv 6:- 5:- 4:- 3:- 2:- 1:- 0:vfmv
        3'b011:  SupportedFunct6D = 8'b1011_1011;   // 7:vmfge 6:- 5:vmfgt 4:vmfne 3:vmflt 2:- 1:vmfle 0:vmfeq
        3'b100:  SupportedFunct6D = 8'b1001_0011;   // 7:vfrsub 6:- 5:- 4:vfmul 3:- 2:- 1:vfrdiv 0:vfdiv
        3'b101:  SupportedFunct6D = 8'b1111_1111;   // 7:vfnmsac 6:vfmsac 5:vfnmacc 4:vfmacc 3:vfnmsub 2:vfmsub 1:vfnmadd 0:vfmadd
        3'b110:  SupportedFunct6D = 8'b0101_0101;   // 7:- 6:vfwsub.w 5:- 4:vfwadd.w 3:- 2:vfwsub 1:- 0:vfwadd
        3'b111:  SupportedFunct6D = 8'b1111_0001;   // 7:vfwnmsac 6:vfwmsac 5:vfwnmacc 4:vfwmacc 3:- 2:- 1:- 0:vfwmul
        default: SupportedFunct6D = 8'b0000_0000;
      endcase
    else       SupportedFunct6D = 8'b0000_0000;   // funct3 = 111 is vset{i}vl{i}, decoded above

  // Control signals for EU
  // VEUControlsD = VOpClass_Reduction_VdEEW_Vs1EEW_Vs2EEW
  // EEW: 00 SEW, 01 2*SEW, 10 mask, 11: width field for load/store, vs1 for vzext/vsext, fixed 16 bits for vrgatherei16
  always_comb
    if      (OPIVVD)
      casez (Funct6D)
        6'b0000?0: VEUControlsD = `VEUCTRLW'b0000_0_00_00_00;   // vadd vsub
        6'b0001??: VEUControlsD = `VEUCTRLW'b0001_0_00_00_00;   // vmax vmaxu vmin vminu
        6'b0010??: VEUControlsD = `VEUCTRLW'b0000_0_00_00_00;   // vand vor vxor
        6'b001100: VEUControlsD = `VEUCTRLW'b0100_0_00_00_00;   // vrgather
        6'b001110: VEUControlsD = `VEUCTRLW'b0100_0_00_11_00;   // vrgatherei16
        6'b0100?0: VEUControlsD = `VEUCTRLW'b0000_0_00_00_00;   // vadc vsbc
        6'b0100?1: VEUControlsD = `VEUCTRLW'b0000_0_10_00_00;   // vmadc vmsbc
        6'b010111: VEUControlsD = `VEUCTRLW'b0000_0_00_00_00;   // vmerge vmv
        6'b011???: VEUControlsD = `VEUCTRLW'b0001_0_10_00_00;   // vmseq vmsle vmsleu vmslt vmsltu vmsne
        6'b1000??: VEUControlsD = `VEUCTRLW'b0000_0_00_00_00;   // vsadd vsaddu vssub vssubu
        6'b100101: VEUControlsD = `VEUCTRLW'b0000_0_00_00_00;   // vsll
        6'b100111: VEUControlsD = `VEUCTRLW'b0010_0_00_00_00;   // vsmul
        6'b1010??: VEUControlsD = `VEUCTRLW'b0000_0_00_00_00;   // vsra vsrl vssra vssrl
        6'b1011??: VEUControlsD = `VEUCTRLW'b0000_0_00_00_01;   // vnclip.w vnclipu.w vnsra.w vnsrl.w
        6'b11000?: VEUControlsD = `VEUCTRLW'b0000_1_01_00_00;   // vwredsum vwredsumu
        default:   VEUControlsD = `VEUCTRLW'b0000_0_00_00_00;
      endcase
    else if (OPIVXD)
      casez (Funct6D)
        6'b0000??: VEUControlsD = `VEUCTRLW'b0000_0_00_00_00;   // vadd vrsub vsub
        6'b0001??: VEUControlsD = `VEUCTRLW'b0001_0_00_00_00;   // vmax vmaxu vmin vminu
        6'b0010??: VEUControlsD = `VEUCTRLW'b0000_0_00_00_00;   // vand vor vxor
        6'b0011??: VEUControlsD = `VEUCTRLW'b0100_0_00_00_00;   // vrgather vslidedown vslideup
        6'b0100?0: VEUControlsD = `VEUCTRLW'b0000_0_00_00_00;   // vadc vsbc
        6'b0100?1: VEUControlsD = `VEUCTRLW'b0000_0_10_00_00;   // vmadc vmsbc
        6'b010111: VEUControlsD = `VEUCTRLW'b0000_0_00_00_00;   // vmerge vmv
        6'b011???: VEUControlsD = `VEUCTRLW'b0001_0_10_00_00;   // vmseq vmsgt vmsgtu vmsle vmsleu vmslt vmsltu vmsne
        6'b1000??: VEUControlsD = `VEUCTRLW'b0000_0_00_00_00;   // vsadd vsaddu vssub vssubu
        6'b100101: VEUControlsD = `VEUCTRLW'b0000_0_00_00_00;   // vsll
        6'b100111: VEUControlsD = `VEUCTRLW'b0010_0_00_00_00;   // vsmul
        6'b1010??: VEUControlsD = `VEUCTRLW'b0000_0_00_00_00;   // vsra vsrl vssra vssrl
        6'b1011??: VEUControlsD = `VEUCTRLW'b0000_0_00_00_01;   // vnclip.w vnclipu.w vnsra.w vnsrl.w
        default:   VEUControlsD = `VEUCTRLW'b0000_0_00_00_00;
      endcase
    else if (OPIVID)
      casez (Funct6D)
        6'b0000??: VEUControlsD = `VEUCTRLW'b0000_0_00_00_00;   // vadd vrsub
        6'b0010??: VEUControlsD = `VEUCTRLW'b0000_0_00_00_00;   // vand vor vxor
        6'b0011??: VEUControlsD = `VEUCTRLW'b0100_0_00_00_00;   // vrgather vslidedown vslideup
        6'b010000: VEUControlsD = `VEUCTRLW'b0000_0_00_00_00;   // vadc
        6'b010001: VEUControlsD = `VEUCTRLW'b0000_0_10_00_00;   // vmadc
        6'b010111: VEUControlsD = `VEUCTRLW'b0000_0_00_00_00;   // vmerge vmv
        6'b011???: VEUControlsD = `VEUCTRLW'b0001_0_10_00_00;   // vmseq vmsgt vmsgtu vmsle vmsleu vmsne
        6'b100111: VEUControlsD = `VEUCTRLW'b0100_0_00_00_00;   // vmv1r vmv2r vmv4r vmv8r
        6'b100?0?: VEUControlsD = `VEUCTRLW'b0000_0_00_00_00;   // vsadd vsaddu vsll
        6'b1010??: VEUControlsD = `VEUCTRLW'b0000_0_00_00_00;   // vsra vsrl vssra vssrl
        6'b1011??: VEUControlsD = `VEUCTRLW'b0000_0_00_00_01;   // vnclip.w vnclipu.w vnsra.w vnsrl.w
        default:   VEUControlsD = `VEUCTRLW'b0000_0_00_00_00;
      endcase
    else if (OPMVVD)
      casez (Funct6D)
        6'b000???: VEUControlsD = `VEUCTRLW'b0000_1_00_00_00;   // vredand vredmax vredmaxu vredmin vredminu vredor vredsum vre
        6'b0010??: VEUControlsD = `VEUCTRLW'b0000_0_00_00_00;   // vaadd vaaddu vasub vasubu
        6'b010010: VEUControlsD = `VEUCTRLW'b0000_0_00_00_11;   // vsext vzext
        6'b010111: VEUControlsD = `VEUCTRLW'b0100_0_00_00_00;   // vcompress
        6'b011???: VEUControlsD = `VEUCTRLW'b0000_0_10_10_10;   // vmand vmandn vmnand vmnor vmor vmorn vmxnor vmxor
        6'b1000??: VEUControlsD = `VEUCTRLW'b0011_0_00_00_00;   // vdiv vdivu vrem vremu
        6'b1001??: VEUControlsD = `VEUCTRLW'b0010_0_00_00_00;   // vmul vmulh vmulhsu vmulhu
        6'b101?01: VEUControlsD = `VEUCTRLW'b0010_0_00_00_00;   // vmacc vmadd
        6'b101?11: VEUControlsD = `VEUCTRLW'b0010_0_00_00_01;   // vnmsac vnmsub
        6'b1100??: VEUControlsD = `VEUCTRLW'b0000_0_01_00_00;   // vwadd vwaddu vwsub vwsubu
        6'b1101??: VEUControlsD = `VEUCTRLW'b0000_0_01_00_01;   // vwadd.w vwaddu.w vwsub.w vwsubu.w
        6'b111???: VEUControlsD = `VEUCTRLW'b0010_0_01_00_00;   // vwmacc vwmaccsu vwmaccu vwmul vwmulsu vwmulu
        default:   VEUControlsD = `VEUCTRLW'b0000_0_00_00_00;
      endcase
    else if (OPMVXD)
      casez (Funct6D)
        6'b0010??: VEUControlsD = `VEUCTRLW'b0000_0_00_00_00;   // vaadd vaaddu vasub vasubu
        6'b00111?: VEUControlsD = `VEUCTRLW'b0100_0_00_00_00;   // vslide1down vslide1up
        6'b010000: VEUControlsD = `VEUCTRLW'b0000_0_00_00_00;   // vmv
        6'b1000??: VEUControlsD = `VEUCTRLW'b0011_0_00_00_00;   // vdiv vdivu vrem vremu
        6'b1001??: VEUControlsD = `VEUCTRLW'b0010_0_00_00_00;   // vmul vmulh vmulhsu vmulhu
        6'b101?01: VEUControlsD = `VEUCTRLW'b0010_0_00_00_00;   // vmacc vmadd
        6'b101?11: VEUControlsD = `VEUCTRLW'b0010_0_00_00_01;   // vnmsac vnmsub
        6'b1100??: VEUControlsD = `VEUCTRLW'b0000_0_01_00_00;   // vwadd vwaddu vwsub vwsubu
        6'b1101??: VEUControlsD = `VEUCTRLW'b0000_0_01_00_01;   // vwadd.w vwaddu.w vwsub.w vwsubu.w
        6'b111???: VEUControlsD = `VEUCTRLW'b0010_0_01_00_00;   // vwmacc vwmaccsu vwmaccu vwmaccus vwmul vwmulsu vwmulu
        default:   VEUControlsD = `VEUCTRLW'b0000_0_00_00_00;
      endcase
    else if (OPFVVD)
      casez (Funct6D)
        6'b0000?0: VEUControlsD = `VEUCTRLW'b0110_0_00_00_00;   // vfadd vfsub
        6'b0000?1: VEUControlsD = `VEUCTRLW'b0110_1_00_00_00;   // vfredosum vfredusum
        6'b0001?0: VEUControlsD = `VEUCTRLW'b1001_0_00_00_00;   // vfmax vfmin
        6'b0001?1: VEUControlsD = `VEUCTRLW'b1001_1_00_00_00;   // vfredmax vfredmin
        6'b0010??: VEUControlsD = `VEUCTRLW'b1010_0_00_00_00;   // vfsgnj vfsgnjn vfsgnjx
        6'b010000: VEUControlsD = `VEUCTRLW'b1010_0_00_00_00;   // vfmv
        6'b011???: VEUControlsD = `VEUCTRLW'b1001_0_00_00_00;   // vmfeq vmfle vmflt vmfne
        6'b100000: VEUControlsD = `VEUCTRLW'b0111_0_00_00_00;   // vfdiv
        6'b100100: VEUControlsD = `VEUCTRLW'b0110_0_00_00_00;   // vfmul
        6'b101??0: VEUControlsD = `VEUCTRLW'b0110_0_00_00_00;   // vfmacc vfmadd vfmsac vfmsub
        6'b101??1: VEUControlsD = `VEUCTRLW'b0110_0_00_00_01;   // vfnmacc vfnmadd vfnmsac vfnmsub
        6'b1100?0: VEUControlsD = `VEUCTRLW'b0110_0_01_00_00;   // vfwadd vfwsub
        6'b1100?1: VEUControlsD = `VEUCTRLW'b0110_1_01_00_00;   // vfwredosum vfwredusum
        6'b1101?0: VEUControlsD = `VEUCTRLW'b0110_0_01_00_01;   // vfwadd.w vfwsub.w
        6'b111???: VEUControlsD = `VEUCTRLW'b0110_0_01_00_00;   // vfwmacc vfwmsac vfwmul vfwnmacc vfwnmsac
        default:   VEUControlsD = `VEUCTRLW'b0000_0_00_00_00;
      endcase
    else if (OPFVFD)
      casez (Funct6D)
        6'b0000?0: VEUControlsD = `VEUCTRLW'b0110_0_00_00_00;   // vfadd vfsub
        6'b0001?0: VEUControlsD = `VEUCTRLW'b1001_0_00_00_00;   // vfmax vfmin
        6'b0010??: VEUControlsD = `VEUCTRLW'b1010_0_00_00_00;   // vfsgnj vfsgnjn vfsgnjx
        6'b00111?: VEUControlsD = `VEUCTRLW'b0100_0_00_00_00;   // vfslide1down vfslide1up
        6'b010???: VEUControlsD = `VEUCTRLW'b1010_0_00_00_00;   // vfmerge vfmv
        6'b011???: VEUControlsD = `VEUCTRLW'b1001_0_00_00_00;   // vmfeq vmfge vmfgt vmfle vmflt vmfne
        6'b10000?: VEUControlsD = `VEUCTRLW'b0111_0_00_00_00;   // vfdiv vfrdiv
        6'b1001??: VEUControlsD = `VEUCTRLW'b0110_0_00_00_00;   // vfmul vfrsub
        6'b101??0: VEUControlsD = `VEUCTRLW'b0110_0_00_00_00;   // vfmacc vfmadd vfmsac vfmsub
        6'b101??1: VEUControlsD = `VEUCTRLW'b0110_0_00_00_01;   // vfnmacc vfnmadd vfnmsac vfnmsub
        6'b1100?0: VEUControlsD = `VEUCTRLW'b0110_0_01_00_00;   // vfwadd vfwsub
        6'b1101?0: VEUControlsD = `VEUCTRLW'b0110_0_01_00_01;   // vfwadd.w vfwsub.w
        6'b111???: VEUControlsD = `VEUCTRLW'b0110_0_01_00_00;   // vfwmacc vfwmsac vfwmul vfwnmacc vfwnmsac
        default:   VEUControlsD = `VEUCTRLW'b0000_0_00_00_00;
      endcase
    else           VEUControlsD = `VEUCTRLW'b0000_0_00_00_00;   // funct3 = 111 is vset{i}vl{i}


  // unary, vs1 is sub-decode
  always_comb begin
    VUnaryControlsD = `VEUCTRLW'b0000_0_00_00_00;
    SupportedUnaryD = 1'b0;
    VUnaryWriteIntD = 1'b0;
    VUnaryWriteFPD  = 1'b0;
    SupportedCvtD   = 8'b0000_0000;
    if (OPMVVD & (Funct6D == 6'b010000)) begin            // VWXUNARY0, all three write an integer register
      VUnaryWriteIntD = 1'b1;
      case (Vs1D)
        5'b00000: begin SupportedUnaryD = 1'b1; VUnaryControlsD = `VEUCTRLW'b0000_0_00_00_00; end // vmv.x.s
        5'b10000: begin SupportedUnaryD = 1'b1; VUnaryControlsD = `VEUCTRLW'b0101_0_00_00_10; end // vcpop.m
        5'b10001: begin SupportedUnaryD = 1'b1; VUnaryControlsD = `VEUCTRLW'b0101_0_00_00_10; end // vfirst.m
        default: ;                                                                                // reserved vs1
      endcase
    end else if (OPMVVD & (Funct6D == 6'b010010)) begin   // VXUNARY0
      SupportedUnaryD = (Vs1D[4:3] == 2'b00) & (Vs1D[2:1] != 2'b00);
      VUnaryControlsD = `VEUCTRLW'b0000_0_00_00_11;                                               // vzext, vsext
    end else if (OPMVVD & (Funct6D == 6'b010100)) begin   // VMUNARY0
      case (Vs1D)
        5'b00001: begin SupportedUnaryD = 1'b1; VUnaryControlsD = `VEUCTRLW'b0101_0_10_00_10; end // vmsbf.m
        5'b00010: begin SupportedUnaryD = 1'b1; VUnaryControlsD = `VEUCTRLW'b0101_0_10_00_10; end // vmsof.m
        5'b00011: begin SupportedUnaryD = 1'b1; VUnaryControlsD = `VEUCTRLW'b0101_0_10_00_10; end // vmsif.m
        5'b10000: begin SupportedUnaryD = 1'b1; VUnaryControlsD = `VEUCTRLW'b0101_0_00_00_10; end // viota.m
        5'b10001: begin SupportedUnaryD = 1'b1; VUnaryControlsD = `VEUCTRLW'b0101_0_00_00_00; end // vid.v
        default: ;                                                                                // reserved vs1
      endcase
    end else if (OPFVVD & (Funct6D == 6'b010000)) begin   // VWFUNARY0
      SupportedUnaryD = (Vs1D == 5'b00000);
      VUnaryWriteFPD  = 1'b1;
      VUnaryControlsD = `VEUCTRLW'b1010_0_00_00_00;                                               // vfmv.f.s
    end else if (OPFVVD & (Funct6D == 6'b010010)) begin   // VFUNARY0
      case (Vs1D[4:3])
      // 7:rtz.x 6:rtz.xu 5:- 4:f.f 3:f.x 2:f.xu 1:x.f 0:xu.f
        2'b00:   begin SupportedCvtD = 8'b1100_1111; VUnaryControlsD = `VEUCTRLW'b1000_0_00_00_00; end // vfcvt
        2'b01:   begin SupportedCvtD = 8'b1101_1111; VUnaryControlsD = `VEUCTRLW'b1000_0_01_00_00; end // vfwcvt
        2'b10:   begin SupportedCvtD = 8'b1111_1111; VUnaryControlsD = `VEUCTRLW'b1000_0_00_00_01; end // vfncvt
        default: ;                                                                                     // reserved width group
      endcase
      SupportedUnaryD = SupportedCvtD[Vs1D[2:0]];
    end else if (OPFVVD & (Funct6D == 6'b010011)) begin   // VFUNARY1
      case (Vs1D)
        5'b00000: begin SupportedUnaryD = 1'b1; VUnaryControlsD = `VEUCTRLW'b0111_0_00_00_00; end // vfsqrt.v, on the divider
        5'b00100: begin SupportedUnaryD = 1'b1; VUnaryControlsD = `VEUCTRLW'b1010_0_00_00_00; end // vfrsqrt7.v
        5'b00101: begin SupportedUnaryD = 1'b1; VUnaryControlsD = `VEUCTRLW'b1010_0_00_00_00; end // vfrec7.v
        5'b10000: begin SupportedUnaryD = 1'b1; VUnaryControlsD = `VEUCTRLW'b1010_0_00_00_00; end // vfclass.v
        default: ;                                                                                // reserved vs1
      endcase
    end else if (OPIVID & (Funct6D == 6'b100111)) begin   // vmv<nr>r.v, vs1 holds nr-1
      SupportedUnaryD = (Vs1D == 5'd0) | (Vs1D == 5'd1) | (Vs1D == 5'd3) | (Vs1D == 5'd7);
      VUnaryControlsD = `VEUCTRLW'b0100_0_00_00_00;
    end
  end

  // Load/store runs in LSU, and unary overrides family entry
  assign {VOpClassD, VReductionD, VdEEWD, Vs1EEWD, Vs2EEWD} =
    (OpD == 7'b0000111) | (OpD == 7'b0100111) ? `VEUCTRLW'b1011_0_00_00_00 :
    VUnaryD                                   ? VUnaryControlsD : VEUControlsD;

  // Legality of instruction decode
  assign VFunctD      = SupportedFunct6D[Funct6D[2:0]] & (~VUnaryD | SupportedUnaryD) &
                        (~(OPFVVD | OPFVFD) | P.ZVE32F_SUPPORTED);

  // Main vector instruction decoder
  always_comb
    if (STATUS_VS == 2'b00)                    // vector instr are illegal when VS is off
      VControlsD = `VCTRLW'b0_0_0_0_0_0_1;
    else if (VTYPE_REGW[P.XLEN-1] & ~VSETD)    // vtype.vill, only vset may execute
      VControlsD = `VCTRLW'b0_0_0_0_0_0_1;
    else begin
      VControlsD = `VCTRLW'b0_0_0_0_0_0_1;     // default illegal instr
      case(OpD)
      // VRegWrite_VWriteInt_VWriteFP_Vset_VALUResult_VALUSrcB_Illegal
        7'b0000111: if (VLSFunctD)                               // vector loads, address from x[rs1]
                        VControlsD = `VCTRLW'b1_0_0_0_1_0_0;
        7'b0100111: if (VLSFunctD)                               // vector stores, data is Vs3 in the Vd field
                        VControlsD = `VCTRLW'b0_0_0_0_0_1_0;
        7'b1010111: if      (VsetvliD | VsetivliD | VsetvlD)     // vsetvli, vsetivli, vsetvl
                        VControlsD = `VCTRLW'b0_1_0_1_0_0_0;
                    else if (VFunctD & VUnaryWriteIntD)          // vmv.x.s, vcpop.m, vfirst.m write rd
                        VControlsD = `VCTRLW'b0_1_0_0_0_0_0;
                    else if (VFunctD & VUnaryWriteFPD)           // vfmv.f.s writes fd
                        VControlsD = `VCTRLW'b0_0_1_0_0_0_0;
                    else if (VFunctD)                            // vector arithmetic writes vd
                        VControlsD = `VCTRLW'b1_0_0_0_0_0_0;
        default:        VControlsD = `VCTRLW'b0_0_0_0_0_0_1;
      endcase
    end

  // control bits
  assign {VRegWriteD, VWriteIntD, VWriteFPD, VsetD, VALUResultD, VALUSrcBD, IllegalVPUInstrD} = VControlsD;

  // load/store runs in LSU; arithmetic categories set by class above
  assign VEUTypeD = (OpD == 7'b0000111) | (OpD == 7'b0100111) ? VEUTYPE_MEM :
                    (OPFVVD | OPFVFD)                         ? VEUTYPE_FP : VEUTYPE_INT;

  // second operand: 00 = vs1, 01 = imm, 10 = rs1 or fs1
  always_comb
    if      (OPIVID)                           VALUSrcAD = 2'b01;
    else if (OPIVXD | OPFVFD | OPMVXD | VSETD) VALUSrcAD = 2'b10;
    else                                       VALUSrcAD = 2'b00;

endmodule
