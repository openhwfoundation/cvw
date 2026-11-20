// 4-read, 2-write register file for superscalar in-order 2-wide processor.
// Write port I1 wins on a WAW conflict (I1 is later in program order).
// All read ports have same-cycle write bypass; I1 bypass > I0 bypass.

module RegFile(
    input   logic           clk,

    // Write port I0 (lower priority on WAW conflict)
    input   logic           WE_I0,
    input   logic [4:0]     A_WR_I0,
    input   logic [31:0]    WD_I0,

    // Write port I1 (higher priority — later in program order)
    input   logic           WE_I1,
    input   logic [4:0]     A_WR_I1,
    input   logic [31:0]    WD_I1,

    // 4 combinational read ports
    input   logic [4:0]     A_RD0, A_RD1, A_RD2, A_RD3,
    output  logic [31:0]    RD0,   RD1,   RD2,   RD3
);
    logic [31:0] rf[31:1];

    // Two write ports: I1 overwrites I0 if both target the same register
    always_ff @(posedge clk) begin
        if (WE_I0 && A_WR_I0 != 0) rf[A_WR_I0] <= WD_I0;
        if (WE_I1 && A_WR_I1 != 0) rf[A_WR_I1] <= WD_I1;
    end

    // Read with bypass: x0 → 0, else I1 write > I0 write > stored value
    assign RD0 = (A_RD0 == 0)                          ? 32'h0  :
                 (WE_I1 && A_WR_I1 == A_RD0)           ? WD_I1  :
                 (WE_I0 && A_WR_I0 == A_RD0)           ? WD_I0  :
                                                          rf[A_RD0];

    assign RD1 = (A_RD1 == 0)                          ? 32'h0  :
                 (WE_I1 && A_WR_I1 == A_RD1)           ? WD_I1  :
                 (WE_I0 && A_WR_I0 == A_RD1)           ? WD_I0  :
                                                          rf[A_RD1];

    assign RD2 = (A_RD2 == 0)                          ? 32'h0  :
                 (WE_I1 && A_WR_I1 == A_RD2)           ? WD_I1  :
                 (WE_I0 && A_WR_I0 == A_RD2)           ? WD_I0  :
                                                          rf[A_RD2];

    assign RD3 = (A_RD3 == 0)                          ? 32'h0  :
                 (WE_I1 && A_WR_I1 == A_RD3)           ? WD_I1  :
                 (WE_I0 && A_WR_I0 == A_RD3)           ? WD_I0  :
                                                          rf[A_RD3];
endmodule
