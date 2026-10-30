// Floating point datapath parameter structure FP for the scalar FPU from the cvw parameter structure P

localparam int   FPU_XLEN          = P.XLEN;
localparam logic FPU_IEEE754       = P.IEEE754;
localparam logic FPU_F_SUPPORTED   = P.F_SUPPORTED;
localparam logic FPU_D_SUPPORTED   = P.D_SUPPORTED;
localparam logic FPU_Q_SUPPORTED   = P.Q_SUPPORTED;
localparam logic FPU_ZFH_SUPPORTED = P.ZFH_SUPPORTED;
localparam logic FPU_ZFA_SUPPORTED = P.ZFA_SUPPORTED;
localparam logic FPU_ROUND_TO_ODD_SUPPORTED = 1'b0; // only the vector FPU rounds to odd (vfncvt.rod)
localparam logic FPU_IDIV_ON_FPU   = P.IDIV_ON_FPU;
localparam int   FPU_RADIX         = P.RADIX;
localparam int   FPU_DIVCOPIES     = P.DIVCOPIES;

`include "fpu-config-shared.vh"
