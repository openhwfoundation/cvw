///////////////////////////////////////////
// rom1p1r
//
// Written: David_Harris@hmc.edu 8/24/22
//
// Purpose: Single-ported ROM
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
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

// This model actually works correctly with vivado.

module rom1p1r #(parameter ADDR_WIDTH = 8, DATA_WIDTH = 32, PRELOAD_ENABLED = 0)
  (input  logic                  clk,
   input  logic                  ce,
   input  logic [ADDR_WIDTH-1:0] addr,
   output logic [DATA_WIDTH-1:0] dout
);


   // Core Memory
   bit [DATA_WIDTH-1:0]    ROM [(2**ADDR_WIDTH)-1:0];

   // dh 10/30/23 ROM macros are presently commented out
   // because they don't point to a generated ROM
/*   if ((`USE_SRAM == 1) & (ADDR_WDITH == 7) & (DATA_WIDTH == 64)) begin
      rom1p1r_128x64 rom1 (.CLK(clk), .CEB(~ce), .A(addr[6:0]), .Q(dout));

   end if ((`USE_SRAM == 1) & (ADDR_WDITH == 7) & (DATA_WIDTH == 32)) begin
 rom1p1r_128x32 rom1 (.CLK(clk), .CEB(~ce), .A(addr[6:0]), .Q(dout));

  end else begin */

  `ifdef VERILATOR
    import "DPI-C" function string getenvval(input string env_name);
  `endif

  initial
    if (PRELOAD_ENABLED) begin
      if (DATA_WIDTH == 64) begin
        `ifdef VERILATOR
            // because Verilator doesn't automatically accept $WALLY from shell
            static string WALLY_DIR = getenvval("WALLY");
            $readmemh({WALLY_DIR,"/fpga/src/boot.mem"}, ROM, 0);  // load boot ROM for FPGA
        `else
            $readmemh({"$WALLY/fpga/src/boot.mem"}, ROM, 0);  // load boot ROM for FPGA
        `endif
      end else begin // put something in the ROM so it is not optimized away
        ROM[0] = 'h00002197;
      end
    end

  always_ff @ (posedge clk)
    if(ce) dout <= ROM[addr];

   // for FPGA, initialize with zero-stage bootloader
   /*if(PRELOAD_ENABLED) begin
      initial begin
        ROM[0]=64'h8001819300002197;
        ROM[1]=64'h4281420141014081;
        ROM[2]=64'h4481440143814301;
        ROM[3]=64'h4681460145814501;
        ROM[4]=64'h4881480147814701;
        ROM[5]=64'h4a814a0149814901;
        ROM[6]=64'h4c814c014b814b01;
        ROM[7]=64'h4e814e014d814d01;
        ROM[8]=64'h0110011b4f814f01;
        ROM[9]=64'h059b45011161016e;
        ROM[10]=64'h0004063705fe0010;
        ROM[11]=64'h1f6000ef8006061b;
        ROM[12]=64'h0ff003930000100f;
        ROM[13]=64'h4e952e3110060e37;
        ROM[14]=64'hc602829b0053f2b7;
        ROM[15]=64'h2023fe02dfe312fd;
        ROM[16]=64'h829b0053f2b7007e;
        ROM[17]=64'hfe02dfe312fdc602;
        ROM[18]=64'h4de31efd000e2023;
        ROM[19]=64'h059bf1402573fdd0;
        ROM[20]=64'h0000061705e20870;
        ROM[21]=64'h0010029b01260613;
        ROM[22]=64'h68110002806702fe;
        ROM[23]=64'h0085179bf0080813;
        ROM[24]=64'h038008130107f7b3;
        ROM[25]=64'h480508a86c632781;
        ROM[26]=64'h1533357902a87963;
        ROM[27]=64'h38030000181700a8;
        ROM[28]=64'h1c6301057833f268;
        ROM[29]=64'h081a403018370808;
        ROM[30]=64'h0105783342280813;
        ROM[31]=64'h1815751308081063;
        ROM[32]=64'h00367513c295e14d;
        ROM[33]=64'h654ded510207e793;
        ROM[34]=64'hc1701ff00613f130;
        ROM[35]=64'h0637c530fff6861b;
        ROM[36]=64'h664dcd10167d0200;
        ROM[37]=64'h17fd001007b7c25c;
        ROM[38]=64'h859b5a5cc20cd21c;
        ROM[39]=64'h02062a23dfed0007;
        ROM[40]=64'h4785fffd561c664d;
        ROM[41]=64'h4501461c06f59063;
        ROM[42]=64'h4a1cc35c465cc31c;
        ROM[43]=64'he29dc75c4a5cc71c;
        ROM[44]=64'h0c63086008138082;
        ROM[45]=64'h1ae30a9008130105;
        ROM[46]=64'hb7710017e793f905;
        ROM[47]=64'he793b75901d7e793;
        ROM[48]=64'h5f5c674db7410197;
        ROM[49]=64'h66cd02072e23dffd;
        ROM[50]=64'hfff78513ff7d5698;
        ROM[51]=64'h40a0053300a03533;
        ROM[52]=64'hbfb100a7e7938082;
        ROM[53]=64'he0a2715d8082557d;
        ROM[54]=64'he486f052f44ef84a;
        ROM[55]=64'hfa13e85aec56fc26;
        ROM[56]=64'h843289ae892a0086;
        ROM[57]=64'h00959993000a1463;
        ROM[58]=64'h864ac4396b054a85;
        ROM[59]=64'h0009859b4549870a;
        ROM[60]=64'h0004049b05540363;
        ROM[61]=64'h86a66485008b7363;
        ROM[62]=64'h870a87aaec7ff0ef;
        ROM[63]=64'h4531458146014681;
        ROM[64]=64'hf0ef0207c9639c05;
        ROM[65]=64'h17820094979beb1f;
        ROM[66]=64'h873e020541639381;
        ROM[67]=64'h993e99ba020a1963;
        ROM[68]=64'h870aa8094501f85d;
        ROM[69]=64'he8bff0ef45454685;
        ROM[70]=64'h60a64505fe0559e3;
        ROM[71]=64'h79a2794274e26406;
        ROM[72]=64'h61616b426ae27a02;
        ROM[73]=64'h9301020497138082;
        ROM[74]=64'hf40647057179b7f1;
        ROM[75]=64'hd79867cdec26f022;
        ROM[76]=64'hdff58b85571c674d;
        ROM[77]=64'h2423d35c03600793;
        ROM[78]=64'hfffd571c674d0207;
        ROM[79]=64'h0007a737b00026f3;
        ROM[80]=64'hb00027f311f70713;
        ROM[81]=64'h674dfef77de38f95;
        ROM[82]=64'h4f5ccf9d8b895b1c;
        ROM[83]=64'h26f3cf5c0027e793;
        ROM[84]=64'h071305f5e737b000;
        ROM[85]=64'h8f95b00027f30ff7;
        ROM[86]=64'h4f5c674dfef77de3;
        ROM[87]=64'hb00026f3cf5c9bf5;
        ROM[88]=64'h67f7071300989737;
        ROM[89]=64'h7de38f95b00027f3;
        ROM[90]=64'h458146014681fef7;
        ROM[91]=64'hddbff0ef4501870a;
        ROM[92]=64'h059346014681870a;
        ROM[93]=64'hdcbff0ef45211aa0;
        ROM[94]=64'h1aa007134782e939;
        ROM[95]=64'h816393d117d24411;
        ROM[96]=64'h85220ff0041302e7;
        ROM[97]=64'h614564e270a27402;
        ROM[98]=64'h46e3da5ff0efa0cd;
        ROM[99]=64'h0207c7634782fe05;
        ROM[100]=64'h458146014681870a;
        ROM[101]=64'hd8bff0ef03700513;
        ROM[102]=64'h46014681870a87aa;
        ROM[103]=64'h0a900513403005b7;
        ROM[104]=64'h4409bf7dfc07d9e3;
        ROM[105]=64'hc3998b8583f9bfe1;
        ROM[106]=64'h4681870a00846413;
        ROM[107]=64'hf0ef450945814601;
        ROM[108]=64'h870afa0540e3d59f;
        ROM[109]=64'h123405b746014681;
        ROM[110]=64'h46e3d45ff0ef450d;
        ROM[111]=64'h870a77c14482f805;
        ROM[112]=64'h85a6460146818cfd;
        ROM[113]=64'h4ae3d2dff0ef451d;
        ROM[114]=64'hd3d8470567cdf605;
        ROM[115]=64'h000f4737b00026f3;
        ROM[116]=64'hb00027f323f70713;
        ROM[117]=64'h67cdfef77de38f95;
        ROM[118]=64'h4681870a0007ae23;
        ROM[119]=64'h0370051385a64601;
        ROM[120]=64'hf2054fe3cf7ff0ef;
        ROM[121]=64'h458146014681870a;
        ROM[122]=64'hce3ff0ef08600513;
        ROM[123]=64'h4681870af20545e3;
        ROM[124]=64'h4541200005934601;
        ROM[125]=64'hf0055de3ccfff0ef;
        ROM[126]=64'h3023bf010113bf09;
        ROM[127]=64'h4605842a86aa4081;
        ROM[128]=64'h40113423850a4585;
        ROM[129]=64'h86a265a6da5ff0ef;
        ROM[130]=64'hd99ff0ef04084605;
        ROM[131]=64'h2201358322813603;
        ROM[132]=64'h86a2260508700513;
        ROM[133]=64'hd81ff0ef05629e0d;
        ROM[134]=64'h2a0135832a813603;
        ROM[135]=64'h9e0d86a226054505;
        ROM[136]=64'h3603d6bff0ef057e;
        ROM[137]=64'h0513320135833281;
        ROM[138]=64'h9e0d86a226054010;
        ROM[139]=64'h3083d53ff0ef0556;
        ROM[140]=64'h4501400134034081;
        ROM[141]=64'h0000808241010113;

      end // if (PRELOAD_ENABLED)
   end*/

endmodule
