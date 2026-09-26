// riscvsingle.sv
// RISC-V single-cycle processor
// kacassidy@hmc.edu 2025

module mux2 #(parameter WIDTH) (
        input   logic [WIDTH-1:0]   A,
        input   logic [WIDTH-1:0]   B,
        input   logic               select,

        output  logic [WIDTH-1:0]   result
    );

    assign result = ~select ? A : B;

endmodule
