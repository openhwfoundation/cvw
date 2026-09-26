//////////////////////////////////////////
// cvw.sv
//
// Written: David_Harris@hmc.edu 27 January 2022
//
// Purpose: package with shared CORE-V-Wally global parameters
//
// A component of the Wally configurable RISC-V project.
//
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
// except in compliance with the License, or, at your option, the Apache License version 2.0. You
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language governing permissions
// and limitations under the License.
////////////////////////////////////////////////////////////////////////////////////////////////

// Using global `define statements isn't ideal in a large SystemVerilog system because
// of the risk of `define name conflicts across different subsystems.
// Instead, CORE-V-Wally loads the appropriate configuration one time and places it in a package
// that is referenced by all Wally modules but not by other subsystems.

`ifndef CVW_T

`define CVW_T 1

package cvw;

  `include "BranchPredictorType.vh"

typedef struct packed {
  int           XLEN;     // Machine width (32 or 64)
  logic         IEEE754;  // IEEE754 NaN handling (0 = use RISC-V NaN propagation instead)
  int           MISA;     // Machine Instruction Set Architecture
  int           AHBW;     // AHB bus width (usually = XLEN)
  int           RAM_LATENCY; // Latency to stress AHB
  logic         BURST_EN; // Support AHB Burst Mode

  // RISC-V Features
  logic         ZICSR_SUPPORTED;
  logic         ZIFENCEI_SUPPORTED;
  logic [11:0]  COUNTERS;
  logic         ZICNTR_SUPPORTED;
  logic         ZIHPM_SUPPORTED;
  logic         ZFH_SUPPORTED;
  logic         ZFA_SUPPORTED;
  logic         SSTC_SUPPORTED;
  logic         VIRTMEM_SUPPORTED;
  logic         SVPBMT_SUPPORTED;
  logic         SVNAPOT_SUPPORTED;
  logic         SVINVAL_SUPPORTED;
  logic         SVADU_SUPPORTED;
  logic         SV32_SUPPORTED;
  logic         SV39_SUPPORTED;
  logic         SV48_SUPPORTED;
  logic         SV57_SUPPORTED;
  logic         VECTORED_INTERRUPTS_SUPPORTED;
  logic         BIGENDIAN_SUPPORTED;
  logic         ZMMUL_SUPPORTED;
  logic         ZICBOM_SUPPORTED;
  logic         ZICBOZ_SUPPORTED;
  logic         ZICBOP_SUPPORTED;
  logic         ZICCLSM_SUPPORTED;
  logic         ZICOND_SUPPORTED;
  logic         ZAAMO_SUPPORTED;
  logic         ZALRSC_SUPPORTED;

  // Microarchitectural Features
  logic         BUS_SUPPORTED;
  logic         DCACHE_SUPPORTED;
  logic         ICACHE_SUPPORTED;

// TLB configuration.  Entries should be a power of 2
  int           ITLB_ENTRIES;
  int           DTLB_ENTRIES;

// Cache configuration.  Sizes should be a power of two
// typical configuration 4 ways, 4096 ints per way, 256 bit or more lines
  int           DCACHE_NUMWAYS;
  int           DCACHE_WAYSIZEINBYTES;
  int           DCACHE_LINELENINBITS;
  int           ICACHE_NUMWAYS;
  int           ICACHE_WAYSIZEINBYTES;
  int           ICACHE_LINELENINBITS;
  int           CACHE_SRAMLEN;

// Integer Divider Configuration
// IDIV_BITSPERCYCLE must be 1, 2, or 4
  int           IDIV_BITSPERCYCLE;
  logic         IDIV_ON_FPU;

// Legal number of PMP entries are 0, 16, or 64
  int           PMP_ENTRIES;
  int           PMP_G; // grain

// Address space
  logic [63:0]  RESET_VECTOR;

// WFI Timeout Wait
  int           WFI_TIMEOUT_BIT;

// Peripheral Addresses
// Peripheral memory space extends from BASE to BASE+RANGE
// Range should be a thermometer code with 0's in the upper bits and 1s in the lower bits
  logic         DTIM_SUPPORTED;
  logic [63:0]  DTIM_BASE;
  logic [63:0]  DTIM_RANGE;
  logic         IROM_SUPPORTED;
  logic [63:0]  IROM_BASE;
  logic [63:0]  IROM_RANGE;
  logic         BOOTROM_SUPPORTED;
  logic [63:0]  BOOTROM_BASE;
  logic [63:0]  BOOTROM_RANGE;
  logic         BOOTROM_PRELOAD;
  logic         UNCORE_RAM_SUPPORTED;
  logic [63:0]  UNCORE_RAM_BASE;
  logic [63:0]  UNCORE_RAM_RANGE;
  logic         UNCORE_RAM_PRELOAD;
  logic         EXT_MEM_SUPPORTED;
  logic [63:0]  EXT_MEM_BASE;
  logic [63:0]  EXT_MEM_RANGE;
  logic         CLINT_SUPPORTED;
  logic [63:0]  CLINT_BASE;
  logic [63:0]  CLINT_RANGE;
  logic         GPIO_SUPPORTED;
  logic [63:0]  GPIO_BASE;
  logic [63:0]  GPIO_RANGE;
  logic         UART_SUPPORTED;
  logic [63:0]  UART_BASE;
  logic [63:0]  UART_RANGE;
  logic         PLIC_SUPPORTED;
  logic [63:0]  PLIC_BASE;
  logic [63:0]  PLIC_RANGE;
  logic         SDC_SUPPORTED;
  logic [63:0]  SDC_BASE;
  logic [63:0]  SDC_RANGE;
  logic         SPI_SUPPORTED;
  logic [63:0]  SPI_BASE;
  logic [63:0]  SPI_RANGE;

// Test modes

// Tie GPIO outputs back to inputs
  logic         GPIO_LOOPBACK_TEST;
  logic         SPI_LOOPBACK_TEST;

// Hardware configuration
  int           UART_PRESCALE ;

// Interrupt configuration
  int           PLIC_NUM_SRC;
  logic         PLIC_NUM_SRC_LT_32;
  int           PLIC_GPIO_ID;
  int           PLIC_UART_ID;
  int           PLIC_SPI_ID;
  int           PLIC_SDC_ID;

  logic                BPRED_SUPPORTED;
  logic [31:0]         BPRED_TYPE;
  int                  BPRED_NUM_LHR;
  int                  BPRED_SIZE;
  int                  BTB_SIZE;
  int                  RAS_SIZE;
  logic                INSTR_CLASS_PRED; // is class predictor enabled

// FPU division architecture
  int           RADIX;
  int           DIVCOPIES;

// bit manipulation
  logic         ZBA_SUPPORTED;
  logic         ZBB_SUPPORTED;
  logic         ZBC_SUPPORTED;
  logic         ZBS_SUPPORTED;

// compressed
  logic         ZCA_SUPPORTED;
  logic         ZCB_SUPPORTED;
  logic         ZCD_SUPPORTED;
  logic         ZCF_SUPPORTED;

// Cryptography
  logic         ZBKB_SUPPORTED;
  logic         ZBKC_SUPPORTED;
  logic         ZBKX_SUPPORTED;
  logic         ZKND_SUPPORTED;
  logic         ZKNE_SUPPORTED;
  logic         ZKNH_SUPPORTED;
  logic         ZKN_SUPPORTED;

// Memory synthesis configuration
  logic         USE_SRAM;

// constants defining different privilege modes
// defined in Table 1.1 of the privileged spec
  logic [1:0] M_MODE ;
  logic [1:0] S_MODE ;
  logic [1:0] U_MODE ;

// Virtual Memory Constants
  int VPN_SEGMENT_BITS;
  int VPN_BITS;
  int PPN_BITS;
  int PA_BITS;
  int SVMODE_BITS;
  int ASID_BASE;
  int ASID_BITS;

// constants to check SATP_MODE against
// defined in Table 4.3 of the privileged spec
  logic [3:0] NO_TRANSLATE;
  logic [3:0] SV32;
  logic [3:0] SV39;
  logic [3:0] SV48;
  logic [3:0] SV57;

// macros to define supported modes
  logic A_SUPPORTED;
  logic B_SUPPORTED;
  logic C_SUPPORTED;
  logic D_SUPPORTED;
  logic E_SUPPORTED;
  logic F_SUPPORTED;
  logic I_SUPPORTED;
  logic M_SUPPORTED;
  logic Q_SUPPORTED;
  logic S_SUPPORTED;
  logic U_SUPPORTED;

// logarithm of XLEN, used for number of index bits to select
  int LOG_XLEN;

// Number of 64 bit PMP Configuration Register entries (or pairs of 32 bit entries)
  int PMPCFG_ENTRIES;

// Floating point constants for Quad, Double, Single, and Half precisions
  int         Q_LEN;
  int         Q_NE;
  int         Q_NF;
  int         Q_BIAS;
  logic [1:0] Q_FMT;
  int         D_LEN;
  int         D_NE;
  int         D_NF;
  int         D_BIAS;
  logic [1:0] D_FMT;
  int         S_LEN;
  int         S_NE;
  int         S_NF;
  int         S_BIAS;
  logic [1:0] S_FMT;
  int         H_LEN;
  int         H_NE;
  int         H_NF;
  int         H_BIAS;
  logic [1:0] H_FMT;

// Floating point length FLEN and number of exponent (NE) and fraction (NF) bits
  int         FLEN;
  int         LOGFLEN;
  int         NE  ;
  int         NF  ;
  logic [1:0] FMT ;
  int         BIAS;

// Floating point constants needed for FPU paramerterization
  int         FPSIZES;
  int         FMTBITS;
  int         LEN1 ;
  int         NE1  ;
  int         NF1  ;
  logic [1:0] FMT1 ;
  int         BIAS1;
  int         LEN2 ;
  int         NE2  ;
  int         NF2  ;
  logic [1:0] FMT2 ;
  int         BIAS2;

// largest length in IEU/FPU
  int CVTLEN;
  int LLEN;
  int LOGCVTLEN;
  int NORMSHIFTSZ;
  int LOGNORMSHIFTSZ;
  int FMALEN;

// division constants
  int LOGR       ;
  int RK         ;
  int FPDUR      ;
  int DURLEN     ;
  int DIVb       ;
  int DIVBLEN    ;
// integer division/remainder constants
  int INTDIVb    ;

  // Debug Specification Variables
  logic DEBUG_SUPPORTED;
  logic [31:0] JEDEC;
  logic [5:0] ABITS;
  int         DTM_INSTR_WIDTH;

  // Trigger Module
  logic       TRIG_SUPPORTED;

} cvw_t;

endpackage

`endif
