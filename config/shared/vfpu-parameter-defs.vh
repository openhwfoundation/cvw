// Floating point datapath parameter structure FP for the vector FPU from the cvw parameter structure P

localparam int   FPU_XLEN          = P.ELEN;              // vector converts are to/from ELEN-bit integers
localparam logic FPU_IEEE754       = P.IEEE754;
localparam logic FPU_F_SUPPORTED   = P.VF_SUPPORTED;
localparam logic FPU_D_SUPPORTED   = P.ZVE64D_SUPPORTED;
localparam logic FPU_Q_SUPPORTED   = 1'b0;                // no quad precision vector extension
localparam logic FPU_ZFH_SUPPORTED = P.ZVFH_SUPPORTED | P.ZVFHMIN_SUPPORTED; // Zvfhmin needs half precision for vfwcvt/vfncvt
localparam logic FPU_ZFA_SUPPORTED = 1'b0;                // no Zfa vector instructions
localparam logic FPU_ROUND_TO_ODD_SUPPORTED = 1'b1;       // vfncvt.rod
localparam logic FPU_IDIV_ON_FPU   = 1'b0;                // vector integer divide does not use the FP divider
localparam int   FPU_RADIX         = P.RADIX;
localparam int   FPU_DIVCOPIES     = P.DIVCOPIES;

`include "fpu-config-shared.vh"
