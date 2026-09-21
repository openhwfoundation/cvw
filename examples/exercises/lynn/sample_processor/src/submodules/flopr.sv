// riscvsingle.sv
// RISC-V single-cycle processor
// kacassidy@hmc.edu 2025

module flopr #(parameter WIDTH, parameter DEFAULT = 0) (
        input   logic               clk,
        input   logic               reset,
        input   logic [WIDTH-1:0]   D,
        output  logic [WIDTH-1:0]   Q
    );

    always_ff @(posedge clk, posedge reset) begin
        if (reset)  Q <= DEFAULT;
        else        Q <= D;
    end

endmodule
