// coverage.svh
// David_Harris@hmc.edu 7 September 2024
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// This file is needed in the config subdirectory for each config supporting coverage.
// It defines which extensions are enabled for that config.

// Define XLEN, used in covergroups
`define XLEN32
`define VLEN512

// PMP Grain (G)
// Set G as needed (e.g., 0, 1, 2, ...)
`define G 4

// Uncomment below if G = 0
// `define G_IS_0

// PMP mode selection
`define PMP_16     // Choose between PMP_16 or PMP_64 or None

// Base addresses specific for PMP
`define RAM_BASE_ADDR       32'h80000000  // PMP Region starts at RAM_BASE_ADDR + LARGEST_PROGRAM
`define LARGEST_PROGRAM     32'h00002000

// Define relevant addresses
`define RVMODEL_ACCESS_FAULT_ADDRESS 32'h0000
`define CLINT_BASE 64'h02000000

// Unprivileged extensions
`define I_COVERAGE
`define M_COVERAGE
`define F_COVERAGE
`define D_COVERAGE
`define VX8_COVERAGE
`define VX16_COVERAGE
`define VX32_COVERAGE
`define VX64_COVERAGE
`define VF64_COVERAGE
`define VF32_COVERAGE
`define VF16_COVERAGE
`define ZBA_COVERAGE
`define ZBB_COVERAGE
`define ZBC_COVERAGE
`define ZBS_COVERAGE
`define ZFA_COVERAGE
`define ZFH_COVERAGE
// Note: Zfhmin is a subset of Zfh, so usually only one or the other would be used.  When Zfhmin and D are supported, ZfhD should also be enabled
`define ZFHMIN_COVERAGE
// Note: Zmmul is a subset of M, so usually only one or the other would be used.
`define ZMMUL_COVERAGE
`define ZICOND_COVERAGE
`define ZIFENCEI_COVERAGE
`define ZCA_COVERAGE
`define ZCB_COVERAGE
`define ZCF_COVERAGE
`define ZCD_COVERAGE
`define ZICSR_COVERAGE
`define ZBKB_COVERAGE
`define ZBKC_COVERAGE
`define ZBKX_COVERAGE
`define ZKND_COVERAGE
`define ZKNE_COVERAGE
`define ZKNH_COVERAGE
`define ZAAMO_COVERAGE
`define ZALRSC_COVERAGE
`define ZIFENCEI_COVERAGE

// Privileged extensions
`define VM_COVERAGE
`define RV32VM_PMP_COVERAGE
`define RV32PMP_COVERAGE
`define ZICSRM_COVERAGE
`define ZICSRS_COVERAGE
`define ZICSRU_COVERAGE
`define ZICSRF_COVERAGE
`define ZICSRV_COVERAGE
`define ZICSRVF_COVERAGE
`define ZICSRHV_COVERAGE
`define ENDIANU_COVERAGE
`define ENDIANS_COVERAGE
`define ENDIANM_COVERAGE
`define ENDIANZALRSC_COVERAGE
`define ENDIANZAAMO_COVERAGE
`define EXCEPTIONSM_COVERAGE
`define EXCEPTIONSS_COVERAGE
`define EXCEPTIONSU_COVERAGE
`define EXCEPTIONSV_COVERAGE
`define EXCEPTIONSHV_COVERAGE
`define EXCEPTIONSF_COVERAGE
`define EXCEPTIONSZC_COVERAGE
`define EXCEPTIONSZAAMO_COVERAGE
`define EXCEPTIONSZALRSC_COVERAGE
`define EXCEPTIONSZICBOS_COVERAGE
`define EXCEPTIONSZICBOU_COVERAGE
`define EXCEPTIONSVM_COVERAGE
`define ZICNTRU_COVERAGE
`define ZICNTRS_COVERAGE
`define ZICNTRM_COVERAGE
`define INTERRUPTSU_COVERAGE
`define INTERRUPTSM_COVERAGE
`define INTERRUPTSS_COVERAGE
`define INTERRUPTSSSTC_COVERAGE
`define SSSTRICTS_COVERAGE
`define SSSTRICTM_COVERAGE
// `define SSSTRICTV_COVERAGE
