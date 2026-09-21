// riscvsingle.sv
// RISC-V single-cycle processor
// David_Harris@hmc.edu 2020

module cmp(
        input   logic [31:0]    R1, R2,
        output  logic           Eq
    );

    assign Eq = (R1 == R2);
endmodule
