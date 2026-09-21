// C Runtime entry point
// James Kaden Cassidy
// kacassidy@hmc.edu
// 1/21/2026

.extern add_test
.extern or_test
.extern and_test
.extern sub_test
.extern beq_test
.extern slt_test

    .section .text.init
    .globl main
    .globl return_add_test
    .globl return_or_test
    .globl return_and_test
    .globl return_sub_test
    .globl return_beq_test
    .globl return_slt_test
    .type  main, @function

main:
    j add_test

return_add_test:
    j or_test

return_or_test:
    j and_test

return_and_test:
    j sub_test

return_sub_test:
    j beq_test

return_beq_test:
    j slt_test

return_slt_test:
    j pass
