// C Runtime entry point
// James Kaden Cassidy
// kacassidy@hmc.edu
// 1/21/2026
// Sadhvi Narayanan
// sanarayanan@hmc.edu
// 2/5/2026


.extern add_test
.extern or_test
.extern and_test
.extern sub_test
.extern shift_tests
.extern sltu_tests
.extern loadstore_tests
.extern branch_tests
.extern upper_tests

    .section .text.init
    .globl main
    .globl return_add_test
    .globl return_or_test
    .globl return_and_test
    .globl return_sub_test
    .globl return_shift_tests
    .globl return_sltu_tests
    .globl return_loadstore_tests
    .globl return_branch_tests
    .globl return_upper_tests
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
    j shift_tests

return_shift_tests:
    j sltu_tests

return_sltu_tests:
    j loadstore_tests

return_loadstore_tests:
    j branch_tests

return_branch_tests:
    j upper_tests

return_upper_tests:
    j pass






# // C Runtime entry point
# // James Kaden Cassidy
# // kacassidy@hmc.edu
# // 1/21/2026
# // Sadhvi Narayanan
# // sanarayanan@hmc.edu
# // 2/5/2026


# .extern add_test
# .extern or_test
# .extern and_test
# .extern sub_test
# .extern shift_tests
# .extern sltu_tests
# .extern loadstore_tests
# .extern branch_tests
# .extern upper_tests

#     .section .text.init
#     .globl main
#     .globl return_add_test
#     .globl return_or_test
#     .globl return_and_test
#     .globl return_sub_test
#     .globl return_shift_tests
#     .globl return_sltu_tests
#     .globl return_loadstore_tests
#     .globl return_branch_tests
#     .globl return_upper_tests
#     .type  main, @function

# main:
#     j add_test

# return_add_test:
#     j or_test

# return_or_test:
#     j and_test

# return_and_test:
#     j sub_test

# return_sub_test:
#     j shift_tests

# return_shift_tests:
#     j sltu_tests

# return_sltu_tests:
#     j loadstore_tests

# return_loadstore_tests:
#     j branch_tests

# return_branch_tests:
#     j upper_tests

# return_upper_tests:
#     j pass


# // C Runtime entry point
# // James Kaden Cassidy
# // kacassidy@hmc.edu
# // 1/21/2026

# .extern add_test
# .extern or_test
# .extern and_test
# .extern sub_test

#     .section .text.init
#     .globl main
#     .globl return_add_test
#     .globl return_or_test
#     .globl return_and_test
#     .globl return_sub_test
#     .type  main, @function

# main:
#     j add_test

# return_add_test:
#     j or_test

# return_or_test:
#     j and_test

# return_and_test:
#     j sub_test

# return_sub_test:
#     j pass
