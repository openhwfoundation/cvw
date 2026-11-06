module spi_fifo #(parameter M = 3, N = 8) (                 // 2^M entries of N bits each
  input  logic         PCLK, wen, ren, PRESETn,
  input  logic         winc, rinc,
  input  logic [N-1:0] wdata,
  input  logic [M-1:0] wwatermarklevel, rwatermarklevel,
  output logic [N-1:0] rdata,
  output logic         wfull, rempty,
  output logic         wwatermark, rwatermark);

  /* Pointer FIFO using design elements from "Simulation and Synthesis Techniques
     for Asynchronous FIFO Design" by Clifford E. Cummings. Namely, M bit read and write pointers
     are an extra bit larger than address size to determine full/empty conditions.
     Watermark comparisons use 2's complement subtraction between the M-1 bit pointers,
     which are also used to address memory
  */

  logic [N-1:0] mem[2**M];
  logic [M:0] rptr, wptr;
  logic [M:0] rptrnext, wptrnext;
  logic [M-1:0] raddr;
  logic [M-1:0] waddr;

  logic [M-1:0] numVals;

  assign numVals = waddr - raddr;

  assign rdata = mem[raddr];
  always_ff @(posedge PCLK)
    if (winc & wen & ~wfull) mem[waddr] <= wdata;

  // write and read are enabled
  always_ff @(posedge PCLK)
    if (~PRESETn) begin
      rptr <= '0;
      wptr <= '0;
      wfull <= 1'b0;
      rempty <= 1'b1;
    end else begin
      if (wen) begin
        wfull <= ({~wptrnext[M], wptrnext[M-1:0]} == rptr);
        wptr  <= wptrnext;
      end
      if (ren) begin
        rptr <= rptrnext;
        rempty <= (wptr == rptrnext);
      end
    end

  assign raddr = rptr[M-1:0];
  assign rptrnext = rptr + {{(M){1'b0}}, (rinc & ~rempty)};
  assign rwatermark = ((waddr - raddr) < rwatermarklevel) & ~wfull;
  assign waddr = wptr[M-1:0];
  assign wwatermark = ((waddr - raddr) > wwatermarklevel) | wfull;
  assign wptrnext = wptr + {{(M){1'b0}}, (winc & ~wfull)};
endmodule
