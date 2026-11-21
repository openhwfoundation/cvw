// vactivemask_tb.sv
// Self-checking unit test of the vd byte mask from vl and v0.
// Run: tests/vector/unit/run vactivemask
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

module vactivemask_tb;
  localparam VLEN = 256, BYTES = VLEN/8;

  logic [$clog2(VLEN):0] VLD;
  logic [2:0]            VdEEWD, MicroOpIndexD;
  logic                  VMaskedD;
  logic [1:0]            VWriteElementsD;
  logic [VLEN-1:0]       v0D;
  logic [BYTES-1:0]      ActiveByteMaskD;
  int                    errors = 0, checks = 0;

  vactivemask #(VLEN) dut(.*);

  // reference: byte b of micro-op k belongs to element (k*BYTES + b) >> log2(EEW/8) of the vd group
  task automatic check(input string name, input int vl, input int eew, input int microop, input logic masked,
                       input logic [1:0] elements, input logic [VLEN-1:0] v0,
                       input logic [BYTES-1:0] expected = '0, input bit directed = 1);
    logic [BYTES-1:0] model;
    int shift, element;
    VLD = ($clog2(VLEN)+1)'(vl); VdEEWD = 3'(eew); MicroOpIndexD = 3'(microop); VMaskedD = masked;
    VWriteElementsD = elements; v0D = v0;
    shift = eew - 3;
    for (int b = 0; b < BYTES; b++) begin
      element = (microop*BYTES + b) >> shift;
      case (elements)
        2'b00:   model[b] = (element < vl) & (~masked | v0[element]);
        2'b01:   model[b] = (element == 0) & (vl != 0);
        2'b10:   model[b] = (vl != 0);
        default: model[b] = 1'b1;
      endcase
    end
    #1;
    checks++;
    if (ActiveByteMaskD !== model || (directed && model !== expected)) begin
      $display("FAIL %s: vl %0d eew %0d microop %0d masked %b elements %b: got %h, model %h, expected %h",
               name, vl, eew, microop, masked, elements, ActiveByteMaskD, model, expected);
      errors++;
    end
  endtask

  initial begin
    // directed
    check("e64 vl=2",          2, 6, 0, 0, 2'b00, '0, 32'h0000_FFFF);
    check("e8 vl=5",           5, 3, 0, 0, 2'b00, '0, 32'h0000_001F);
    check("e32 vl=0",          0, 5, 0, 0, 2'b00, '1, 32'h0000_0000);
    check("e16 vl=VLMAX",     16, 4, 0, 0, 2'b00, '0, 32'hFFFF_FFFF);
    check("e64 m2 second reg", 6, 6, 1, 0, 2'b00, '0, 32'h0000_FFFF);   // elements 4, 5 of the group
    check("e64 m2 past vl",    3, 6, 1, 0, 2'b00, '0, 32'h0000_0000);
    check("e32 masked",        8, 5, 0, 1, 2'b00, 256'b1010_0101, 32'hF0F0_0F0F);
    check("e64 masked reg 1",  8, 6, 1, 1, 2'b00, 256'b0110_0000, 32'h00FF_FF00);  // v0 bits 5, 6
    check("merge ignores v0",  8, 5, 0, 0, 2'b00, '0, 32'hFFFF_FFFF);
    check("element 0 e32",     8, 5, 0, 1, 2'b01, '0, 32'h0000_000F);
    check("element 0 vl=0",    0, 5, 0, 0, 2'b01, '1, 32'h0000_0000);
    check("element 0 reg 1",   8, 5, 1, 0, 2'b01, '1, 32'h0000_0000);
    check("mask result",       3, 0, 0, 1, 2'b10, '0, 32'hFFFF_FFFF);
    check("mask result vl=0",  0, 0, 0, 0, 2'b10, '0, 32'h0000_0000);
    check("whole register",    0, 6, 3, 1, 2'b11, '0, 32'hFFFF_FFFF);

    // random against the model
    repeat (5000) begin
      int eew, microop, vl;
      eew = $urandom_range(3, 6);
      microop = $urandom_range(0, 7);
      vl = $urandom_range(0, (8*VLEN/8) >> (eew-3));   // up to VLMAX at LMUL=8
      check("random", vl, eew, microop, 1'($urandom), 2'($urandom), {$urandom, $urandom, $urandom, $urandom,
                                                                     $urandom, $urandom, $urandom, $urandom}, '0, 0);
    end

    if (errors == 0) $display("vactivemask_tb PASSED (%0d checks)", checks);
    else             $display("vactivemask_tb FAILED: %0d errors", errors);
    $finish;
  end

endmodule
