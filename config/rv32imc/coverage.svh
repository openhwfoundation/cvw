// coverage.svh
// David_Harris@hmc.edu 7 September 2024
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// This file is needed in the config subdirectory for each config supporting coverage.
// It defines which extensions are enabled for that config.

// Define XLEN, used in covergroups
`define XLEN32

// Define relevant addresses
`define RVMODEL_ACCESS_FAULT_ADDRESS 32'h0000
`define CLINT_BASE 64'h02000000

// Unprivileged extensions
`define I_COVERAGE
`define M_COVERAGE
`define ZCA_COVERAGE
`define ZICSR_COVERAGE

// Privileged extensions
`define ZICSRM_COVERAGE
`define ZICSRU_COVERAGE
`define EXCEPTIONSM_COVERAGE
`define EXCEPTIONSU_COVERAGE
`define EXCEPTIONSZC_COVERAGE
`define ZICNTRU_COVERAGE
`define ZICNTRM_COVERAGE
`define INTERRUPTSU_COVERAGE
`define INTERRUPTSM_COVERAGE
