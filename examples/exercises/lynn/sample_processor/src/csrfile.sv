module csrfile(
  input  logic        clk, reset,
  input  logic        WE3,
  input  logic [11:0] A1,
  input  logic [11:0] A2,
  input  logic [31:0] WD3,
  output logic [31:0] RD1,
  // Performance counter inputs
  input  logic        IncrementCycle,
  input  logic        IncrementInstret,
  input  logic        IncrementAdd,
  input  logic        IncrementBranch,
  input  logic        IncrementBranchTaken,
  input  logic        BranchMisPrediction,
  input  logic        IncrementLoads,
  input  logic        IncrementStores,
  input  logic        IncrementStalls,
  input  logic        IncrementFlushes
);




  // 64-bit counters
  logic [31:0] cycle, instret;
  // logic [31:0] hpmcounter3;  // add count
  logic [31:0] hpmcounter4;  // branch count
  logic [31:0] hpmcounter5;  // branch taken count
  logic [31:0] hpmcounter6;
//   logic [63:0] hpmcounter7;
//   logic [63:0] hpmcounter8;
  //logic [31:0] hpmcounter9;
  logic [31:0] hpmcounter10;




  // Increment counters every cycle
  always_ff @(posedge clk, posedge reset) begin
      if (reset) begin
          cycle <= 0;
          // time_counter <= 0;
          instret <= 0;
          // hpmcounter3 <= 0;
          hpmcounter4 <= 0;
          hpmcounter5 <= 0;
          hpmcounter6 <= 0;
        //   hpmcounter7 <= 0;
        //   hpmcounter8 <= 0;
          //hpmcounter9 <= 0;
          hpmcounter10 <= 0;
      end else begin
          // Always increment cycle and time
           // $display("CSR: IncrementLoads=%b, IncrementStores=%b, IncrementJumps=%b, IncrementStalls=%b, IncrementFlushes=%b",
           //       IncrementBranchTaken, IncrementStores, IncrementJumps, IncrementStalls, IncrementFlushes);


          cycle <= cycle + 1;
          // time_counter <= time_counter + 1;




          // Increment instret when instruction retires (completes WB)
          if (IncrementInstret) begin
              instret <= instret + 1;
          end




           // HPM counters
          //  if (IncrementAdd) begin
          //     hpmcounter3 <= hpmcounter3 + 1;
          //  //    $display("CSR: IncrementLoads=%b, IncrementStores=%b, IncrementJumps=%b, IncrementStalls=%b, IncrementFlushes=%b",
          //  //      IncrementLoads, IncrementStores, IncrementJumps, IncrementStalls, IncrementFlushes);
          //  end


           if (IncrementBranch)
              hpmcounter4 <= hpmcounter4 + 1;


           if (IncrementBranchTaken)
              hpmcounter5 <= hpmcounter5 + 1;


           if (BranchMisPrediction)
               hpmcounter6 <= hpmcounter6 + 1;


        //    if (IncrementLoads)
        //        hpmcounter7 <= hpmcounter7 + 1;


        //    if (IncrementStores)
        //        hpmcounter8 <= hpmcounter8 + 1;


          //  if (IncrementStalls)
          //      hpmcounter9 <= hpmcounter9 + 1;


           if (IncrementFlushes)
               hpmcounter10 <= hpmcounter10 + 1;




          // thigns to add for other ones cld be - count loads, stores, jumps, etc.
      end
  end




  // Read logic - combinational
  always_comb begin
      // if (A1 != 12'h000) $display("CSR Read: A1 = 0x%h (expecting 0xC02 for instret)", A1);




      case (A1)
          // Zicntr - low 32 bits
          // User-mode counters (unprivileged - 0xC00-0xC1F)
          12'hC00: RD1 = cycle;           // cycle
          12'hC01: RD1 = cycle;    // time
          12'hC02: begin
              // $display("Reading instret = %0d", instret[31:0]);
              RD1 = instret[31:0];
          end


          // User-mode counter upper 32 bits
        //   12'hC80: RD1 = cycle[63:32];          // cycleh
        //   12'hC81: RD1 = time_counter[63:32];   // timeh
        //   12'hC82: RD1 = instret[63:32];        // instreth


          // Machine-mode counters (privileged - 0xB00-0xB1F)
          12'hB00: RD1 = cycle[31:0];           // mcycle (same as cycle)
          12'hB02: RD1 = instret[31:0];         // minstret (same as instret)


          // Machine-mode counter upper 32 bits
        //   12'hB80: RD1 = cycle[63:32];          // mcycleh
        //   12'hB82: RD1 = instret[63:32];        // minstreth




          // Zihpm - low 32 bits
          // 12'hC03: RD1 = hpmcounter3[31:0];   // add count
          12'hC04: RD1 = hpmcounter4[31:0];   // branch count
          12'hC05: RD1 = hpmcounter5[31:0];   // branch taken
          12'hC06: RD1 = hpmcounter6[31:0];   // todo
        //   12'hC07: RD1 = hpmcounter7[31:0];   // todo
        //   12'hC08: RD1 = hpmcounter8[31:0];   // todo
          //12'hC09: RD1 = hpmcounter9[31:0];   // todo
          12'hC0A: RD1 = hpmcounter10[31:0];  // todo




          // Zihpm - high 32 bits
        //   12'hC83: RD1 = hpmcounter3[63:32];
        //   12'hC84: RD1 = hpmcounter4[63:32];
        //   12'hC85: RD1 = hpmcounter5[63:32];
        //   12'hC86: RD1 = hpmcounter6[63:32];
        //   12'hC87: RD1 = hpmcounter7[63:32];
        //   12'hC88: RD1 = hpmcounter8[63:32];
        //   12'hC89: RD1 = hpmcounter9[63:32];
        //   12'hC8A: RD1 = hpmcounter10[63:32];




          default: RD1 = 32'h0;
      endcase
  end




endmodule
