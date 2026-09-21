///////////////////////////////////////////
// tb_fma_wally.sv
//
// Written:  james.stine@okstate.edu, qkoenin@okstate.edu
// Modified:
//
// Purpose: Testbench to run fma operation individually from CV-Wally
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-25 Harvey Mudd College & Oklahoma State University
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

`include "config.vh"
import cvw::*;
`include "parameter-defs.vh"

`define PATH "./"

module stimulus;

   parameter MAXVECTORS = 8388610;

   logic                          clk;
   logic                          rst;

   logic                          Xs, Ys, Zs;                   // input's signs
   logic [P.NE-1:0]               Xe, Ye, Ze;                   // input's biased exponents in B(NE.0) format
   logic [P.NF:0]                 Xm, Ym, Zm;                   // input's significands in U(0.NF) format
   logic                          XZero, YZero, ZZero;          // is the input zero
   logic [2:0]                    OpCtrl;                       // operation control
   logic                          ASticky;                      // sticky bit that is calculated during alignment
   logic [P.FMALEN-1:0]           Sm;                           // the positive sum's significand
   logic                          InvA;                         // Was A inverted for effective subtraction (P-A or -P+A)
   logic                          As;                           // the aligned addend's sign (modified Z sign for other operations)
   logic                          Ps;                           // the product's sign
   logic                          Ss;                           // the sum's sign
   logic [P.NE+1:0]               Se;                           // the sum's exponent
   logic [$clog2(P.FMALEN+1)-1:0] SCnt;                         // normalization shift count

   logic [31:0]                   errors;
   logic [31:0]                   vectornum;

   integer                        i;
   integer                        j;
   integer                        y_integer;
   logic [263:0]                  testvectors1 [];
   logic [63:0]                   X, Y, Z, Res;
   logic [4:0]                    Flg;

   integer                        num_vectors = 0;
   parameter string               VEC_FILE;

   logic [2:0]                    Frm;
   logic [1:0]                    Fmt;
   logic [1:0]                    PostProcSel;
   logic [P.CVTLEN-1:0]           CvtLzcIn;
   logic [P.FLEN-1:0]             PostProcRes;
   logic [4:0]                    PostProcFlg;
   logic [P.XLEN-1:0]             FCvtIntRes;
   logic [P.NE+1:0]               DivUe;
   logic [P.DIVb:0]               DivUm;
   logic [P.NE:0]                 CvtCe;
   logic [P.LOGCVTLEN-1:0]        CvtShiftAmt;

   logic Zero;
   logic XSubnorm;
   logic XExpMax;
   logic DivSticky;
   logic XNaN;
   logic YNaN;
   logic ZNaN;
   logic XSNaN;
   logic YSNaN;
   logic ZSNaN;
   logic XInf;
   logic YInf;
   logic ZInf;
   logic [P.FLEN-1:0]             XPostBox;                     // X after being properly NaN-boxed
   logic [P.NE-2:0]               Bias;                         // Exponent bias
   logic [P.LOGFLEN-1:0]          Nf;                           // Number of fractional bits

   integer                        fd;
   integer                        handle3;
   string                         line;

   logic [31:0]                   VectorNum=0;                  // index for test vector
   logic [31:0]                   FrmNum=0;                     // index for rounding mode
   logic [31:0]                   OpCtrlNum=0;                  // index for OpCtrl
   logic [P.Q_LEN*4+7:0]          TestVectors[MAXVECTORS-1:0];  // list of test vectors
   logic                          vectors_ready;

   unpack #(P) unpack (.X(X), .Y(Y), .Z(Z), .Fmt(Fmt), .XEn(1'b1),
                       .YEn(1'b1), .ZEn(1'b1), .FPUActive(1'b1), .Xs(Xs), .Ys(Ys), .Zs(Zs),
                       .Xe(Xe), .Ye(Ye), .Ze(Ze), .Xm(Xm), .Ym(Ym), .Zm(Zm), .XNaN(XNaN), .YNaN(YNaN),
                       .ZNaN(ZNaN), .XSNaN(XSNaN), .YSNaN(YSNaN), .ZSNaN(ZSNaN), .XSubnorm(XSubnorm),
                       .XZero(XZero), .YZero(YZero), .ZZero(ZZero), .XInf(XInf), .YInf(YInf), .ZInf(ZInf),
                       .XExpMax(XExpMax), .XPostBox(XPostBox), .Bias(Bias), .Nf(Nf));

   fma #(P) dut (.Xs(Xs), .Ys(Ys), .Zs(Zs), .Xe(Xe), .Ye(Ye), .Ze(Ze),
         .Xm(Xm), .Ym(Ym), .Zm(Zm), .XZero(XZero), .YZero(YZero), .ZZero(ZZero),
         .OpCtrl(OpCtrl), .ASticky(ASticky),  .Sm(Sm), .InvA(InvA), .As(As),
         .Ps(Ps), .Ss(Ss), .Se(Se), .SCnt(SCnt));

   postprocess #(P) postprocess(.Xs(Xs), .Ys(Ys), .Xm(Xm), .Ym(Ym), .Zm(Zm), .Frm(Frm), .Fmt(Fmt),
                .FmaASticky(ASticky), .XZero(XZero), .YZero(YZero), .XInf(XInf), .YInf(YInf), .DivUm(DivUm), .FmaSs(Ss),
                .ZInf(ZInf), .XNaN(XNaN), .YNaN(YNaN), .ZNaN(ZNaN), .XSNaN(XSNaN), .YSNaN(YSNaN), .ZSNaN(ZSNaN),
                .FmaSm(Sm), .DivUe(DivUe), .FmaAs(As), .FmaPs(Ps), .OpCtrl(OpCtrl), .FmaSCnt(SCnt), .FmaSe(Se),
                .CvtCe(CvtCe), .CvtResSubnormUf(1'b0),.CvtShiftAmt(CvtShiftAmt), .CvtCs(1'b0),
                .ToInt(1'b0), .Zfa(1'b0), .DivSticky(DivSticky), .CvtLzcIn(CvtLzcIn), .IntZero(1'b0),
                .PostProcSel(PostProcSel), .PostProcRes(PostProcRes), .PostProcFlg(PostProcFlg), .FCvtIntRes(FCvtIntRes));

   initial
     begin
        clk = 1'b1;
        forever #10 clk = ~clk;
     end

   // Define the output file
   initial
     begin
       handle3 = $fopen("fma16.out");
     end

   // ---------- Pass 1 (count) + Pass 2 (readmemh) ----------
   initial begin : load_vectors
      vectors_ready = 0;
      num_vectors   = 0;
      errors = 0;

      fd = $fopen(VEC_FILE, "r");
      if (fd == 0) begin
     $display("ERROR: Could not open %s.", VEC_FILE);
     $finish;
      end

      // Count usable lines (skip blanks/comments)
      while ($fgets(line, fd)) begin
     if (line.len() == 0) continue;
     if ((line == "\n") || (line == "\r") || (line == "\r\n")) continue;
     if (line.substr(0,0) == "#") continue;
     num_vectors++;
      end
      $fclose(fd);

      // Load into TestVectors
      $readmemh(VEC_FILE, TestVectors);

      vectors_ready = 1;
   end // block: load_vectors

   // ---------- Stimulus / consume vectors ----------
   initial begin : drive_and_check
      // Wait until vectors are loaded
      wait (vectors_ready);

      // OpCtrl
      // 000 - fmadd
      // 001 - fmsub
      // 010 - fnmsub
      // 011 - fnmadd
      // 100 - mul
      // 110 - add
      // 111 - sub
      #10 OpCtrl      = 3'b000;
      // Fmt: 00 SP, 01: DP, 10: HP, 11: QP
      #0  Fmt         = 2'b10;
      #0  PostProcSel = 2'b10;
      // Frm: 000: RNE, 001: RTZ, 010: RDN, 011: RUP, 100: RNM,
      //      101,110: Reserved, 111: DYN (dynamic)
      #0  Frm         = 3'b000;

      if (num_vectors == 0) begin
        $display("ERROR: No valid vectors found.");
        $finish;
      end

      for (int i = 0; i < num_vectors; i++) begin
        // take the ith packed vector
        #40 X   = {{P.Q_LEN-P.H_LEN{1'b1}}, TestVectors[i][8+4*(P.H_LEN)-1 : 8+3*(P.H_LEN)]};
        #0  Y   = {{P.Q_LEN-P.H_LEN{1'b1}}, TestVectors[i][8+3*(P.H_LEN)-1 : 8+2*(P.H_LEN)]};
        #0  Z   = {{P.Q_LEN-P.H_LEN{1'b1}}, TestVectors[i][8+2*(P.H_LEN)-1 : 8+P.H_LEN]};
        #0  Res = {{P.Q_LEN-P.H_LEN{1'b1}}, TestVectors[i][8+(P.H_LEN-1)   : 8]};
        #0  Flg = TestVectors[i][4:0];
        #40 if ((PostProcRes != Res) || (PostProcFlg != Flg)) begin
          errors += 1;
          $fdisplay(handle3, "FAIL: got=%h expected=%h | flags=%b exp_flags=%b",
                    PostProcRes, Res, PostProcFlg, Flg);
          end else begin
            $fdisplay(handle3, "PASS: Sim Result: %h_%b || TV Result: %h_%b || #Errors: %0d",
                     PostProcRes, PostProcFlg, Res, Flg, errors);
        end

        $fdisplay(handle3, "X=%h Y=%h Z=%h | Res=%h Flg=%b",
                  X, Y, Z, Res, Flg);
        $fdisplay(handle3, "Xs=%b Ys=%b Zs=%b | Xe=%h Ye=%h Ze=%h | Xm=%h Ym=%h Zm=%h",
                  Xs, Ys, Zs, Xe, Ye, Ze, Xm, Ym, Zm);
        $fdisplay(handle3, "XZero=%b YZero=%b ZZero=%b OpCtrl=%b ASticky=%b | Sm=%h | InvA=%h As=%h Ps=%h Ss=%h | Se=%h SCnt=%h",
                  XZero, YZero, ZZero, OpCtrl, ASticky, Sm, InvA, As, Ps, Ss, Se, SCnt);
        $fdisplay(handle3, "-----");
      end

      $display("Number of vectors = %0d", num_vectors);
      $display("Number of errors  = %0d", errors);
      $fclose(handle3);
      $finish;
   end

endmodule //stimulus
