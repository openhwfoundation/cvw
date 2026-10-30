// Derive the floating point datapath parameter structure FP from a few FPU configuration inputs
// The including scope should set these inputs first:
//   FPU_XLEN          integer width the FP datapath converts to/from (XLEN for the scalar FPU)
//   FPU_IEEE754       IEEE754 NaN handling (0 = use RISC-V NaN propagation instead)
//   FPU_F_SUPPORTED, FPU_D_SUPPORTED, FPU_Q_SUPPORTED, FPU_ZFH_SUPPORTED   supported formats
//   FPU_ZFA_SUPPORTED additional floating point instructions
//   FPU_ROUND_TO_ODD_SUPPORTED   round to odd rounding mode (Frm = 110), vector fp specific
//   FPU_IDIV_ON_FPU   integer division on the FP divider
//   FPU_RADIX, FPU_DIVCOPIES   FP divider architecture

// Floating point constants for Quad, Double, Single, and Half precisions
localparam FPU_Q_LEN = 32'd128;
localparam FPU_Q_NE = 32'd15;
localparam FPU_Q_NF = 32'd112;
localparam FPU_Q_BIAS = 32'd16383;
localparam FPU_Q_FMT = 2'd3;
localparam FPU_D_LEN = 32'd64;
localparam FPU_D_NE = 32'd11;
localparam FPU_D_NF = 32'd52;
localparam FPU_D_BIAS = 32'd1023;
localparam FPU_D_FMT = 2'd1;
localparam FPU_S_LEN = 32'd32;
localparam FPU_S_NE = 32'd8;
localparam FPU_S_NF = 32'd23;
localparam FPU_S_BIAS = 32'd127;
localparam FPU_S_FMT = 2'd0;
localparam FPU_H_LEN = 32'd16;
localparam FPU_H_NE = 32'd5;
localparam FPU_H_NF = 32'd10;
localparam FPU_H_BIAS = 32'd15;
localparam FPU_H_FMT = 2'd2;

// Floating point length FLEN and number of exponent (NE) and fraction (NF) bits (for longest format supported)
localparam FPU_FLEN = FPU_Q_SUPPORTED ? FPU_Q_LEN  : FPU_D_SUPPORTED ? FPU_D_LEN  : FPU_S_LEN;
localparam FPU_NE   = FPU_Q_SUPPORTED ? FPU_Q_NE   : FPU_D_SUPPORTED ? FPU_D_NE   : FPU_S_NE;
localparam FPU_NF   = FPU_Q_SUPPORTED ? FPU_Q_NF   : FPU_D_SUPPORTED ? FPU_D_NF   : FPU_S_NF;
localparam FPU_FMT  = FPU_Q_SUPPORTED ? 2'd3       : FPU_D_SUPPORTED ? 2'd1       : 2'd0;
localparam FPU_BIAS = FPU_Q_SUPPORTED ? FPU_Q_BIAS : FPU_D_SUPPORTED ? FPU_D_BIAS : FPU_S_BIAS;
localparam FPU_LOGFLEN = $clog2(FPU_FLEN);

// Floating point constants needed for FPU paramerterization
// LEN1/NE1/NF1/FNT1 is the size of the second longest supported format
localparam FPU_FPSIZES = (32)'(FPU_Q_SUPPORTED)+(32)'(FPU_D_SUPPORTED)+(32)'(FPU_F_SUPPORTED)+(32)'(FPU_ZFH_SUPPORTED);
localparam FPU_FMTBITS = (32)'(FPU_FPSIZES>=3)+1;
localparam FPU_LEN1  = (FPU_FLEN > FPU_D_LEN) ? FPU_D_LEN  : (FPU_FLEN > FPU_S_LEN) ? FPU_S_LEN  : FPU_H_LEN;
localparam FPU_NE1   = (FPU_FLEN > FPU_D_LEN) ? FPU_D_NE   : (FPU_FLEN > FPU_S_LEN) ? FPU_S_NE   : FPU_H_NE;
localparam FPU_NF1   = (FPU_FLEN > FPU_D_LEN) ? FPU_D_NF   : (FPU_FLEN > FPU_S_LEN) ? FPU_S_NF   : FPU_H_NF;
localparam FPU_FMT1  = (FPU_FLEN > FPU_D_LEN) ? 2'd1       : (FPU_FLEN > FPU_S_LEN) ? 2'd0       : 2'd2;
localparam FPU_BIAS1 = (FPU_FLEN > FPU_D_LEN) ? FPU_D_BIAS : (FPU_FLEN > FPU_S_LEN) ? FPU_S_BIAS : FPU_H_BIAS;

// LEN2 etc is the size of the third longest supported format
localparam FPU_LEN2  = (FPU_LEN1 > FPU_S_LEN) ? FPU_S_LEN  : FPU_H_LEN;
localparam FPU_NE2   = (FPU_LEN1 > FPU_S_LEN) ? FPU_S_NE   : FPU_H_NE;
localparam FPU_NF2   = (FPU_LEN1 > FPU_S_LEN) ? FPU_S_NF   : FPU_H_NF;
localparam FPU_FMT2  = (FPU_LEN1 > FPU_S_LEN) ? 2'd0       : 2'd2;
localparam FPU_BIAS2 = (FPU_LEN1 > FPU_S_LEN) ? FPU_S_BIAS : FPU_H_BIAS;

// divider r and rk (bits per digit, bits per cycle)
localparam FPU_LOGR        = $clog2(FPU_RADIX);                     // r = log(R) bits per digit
localparam FPU_RK          = FPU_LOGR*FPU_DIVCOPIES;                // r*k bits per cycle generated

// intermediate division parameters not directly used in fdivsqrt hardware
localparam FPU_FPDIVMINb   = FPU_NF + 2; // minimum length of fractional part: Nf result bits + guard and round bits + 1 extra bit to allow sqrt being shifted right
localparam FPU_DIVMINb     = ((FPU_FPDIVMINb<FPU_XLEN) & FPU_IDIV_ON_FPU) ? FPU_XLEN : FPU_FPDIVMINb; // minimum fractional bits b = max(XLEN, FPDIVMINb)
localparam FPU_RESBITS     = FPU_DIVMINb + FPU_LOGR; // number of bits in a result: r integer + b fractional

// division constants
localparam FPU_FPDUR       = (FPU_RESBITS-1)/FPU_RK + 1 ;           // ceiling((r+b)/rk)
localparam FPU_DIVb        = FPU_FPDUR*FPU_RK - FPU_LOGR;           // divsqrt fractional bits, so total number of bits is a multiple of rk after r integer bits
localparam FPU_DURLEN      = $clog2(FPU_FPDUR);                     // enough bits to count the duration
localparam FPU_DIVBLEN     = $clog2(FPU_DIVb+1);                    // enough bits to count number of fractional bits + 1 integer bit

// integer division/remainder constants
localparam FPU_INTRESBITS  = FPU_XLEN + FPU_LOGR; // number of bits in a result: r integer + XLEN fractional
localparam FPU_INTFPDUR    = (FPU_INTRESBITS-1)/FPU_RK + 1 ;
localparam FPU_INTDIVb     = FPU_INTFPDUR*FPU_RK - FPU_LOGR;

// largest length in IEU/FPU
localparam FPU_BASECVTLEN = (FPU_XLEN > FPU_NF) ? FPU_XLEN : FPU_NF; // convert length excluding Zfa fcvtmod.w.d
localparam FPU_CVTLEN = (FPU_ZFA_SUPPORTED & FPU_D_SUPPORTED & (32'd84 > FPU_BASECVTLEN)) ? 32'd84 : FPU_BASECVTLEN; // fcvtmod.w.d needs at least 32+52 because a double with 52 fractional bits might be into upper bits of 32 bit word
localparam FPU_LOGCVTLEN = $unsigned($clog2(FPU_CVTLEN+1));

// size of FMA output in U(NF+4).(3NF+2) format
localparam FPU_FMALEN = 3*FPU_NF + 6;

// NORMSHIFTSIZE is the bits out of the normalization shifter
localparam FPU_CVTSHIFTSZ = FPU_CVTLEN + FPU_NF + 1;
localparam FPU_DIVSHIFTSZ = FPU_DIVb + 1 + FPU_NF + 1;
localparam FPU_FMASHIFTSZ = FPU_FMALEN + 2;
localparam FPU_NORMSHIFTSZ = (FPU_CVTSHIFTSZ > FPU_DIVSHIFTSZ) ? ((FPU_CVTSHIFTSZ > FPU_FMASHIFTSZ) ? FPU_CVTSHIFTSZ : FPU_FMASHIFTSZ)
                                                              : ((FPU_DIVSHIFTSZ > FPU_FMASHIFTSZ) ? FPU_DIVSHIFTSZ : FPU_FMASHIFTSZ);

localparam FPU_LOGNORMSHIFTSZ = ($clog2(FPU_NORMSHIFTSZ));          // log_2(NORMSHIFTSZ)

// Populate floating point datapath parameter structure
localparam fpu_pkg::fpu_t FP = '{
  XLEN           : FPU_XLEN,
  IEEE754        : FPU_IEEE754,
  D_SUPPORTED    : FPU_D_SUPPORTED,
  Q_SUPPORTED    : FPU_Q_SUPPORTED,
  ZFH_SUPPORTED  : FPU_ZFH_SUPPORTED,
  ZFA_SUPPORTED  : FPU_ZFA_SUPPORTED,
  ROUND_TO_ODD_SUPPORTED : FPU_ROUND_TO_ODD_SUPPORTED,
  IDIV_ON_FPU    : FPU_IDIV_ON_FPU,
  RADIX          : FPU_RADIX,
  DIVCOPIES      : FPU_DIVCOPIES,
  Q_LEN          : FPU_Q_LEN,
  Q_NE           : FPU_Q_NE,
  Q_NF           : FPU_Q_NF,
  Q_BIAS         : FPU_Q_BIAS,
  Q_FMT          : FPU_Q_FMT,
  D_LEN          : FPU_D_LEN,
  D_NE           : FPU_D_NE,
  D_NF           : FPU_D_NF,
  D_BIAS         : FPU_D_BIAS,
  D_FMT          : FPU_D_FMT,
  S_LEN          : FPU_S_LEN,
  S_NE           : FPU_S_NE,
  S_NF           : FPU_S_NF,
  S_BIAS         : FPU_S_BIAS,
  S_FMT          : FPU_S_FMT,
  H_LEN          : FPU_H_LEN,
  H_NE           : FPU_H_NE,
  H_NF           : FPU_H_NF,
  H_BIAS         : FPU_H_BIAS,
  H_FMT          : FPU_H_FMT,
  FLEN           : FPU_FLEN,
  LOGFLEN        : FPU_LOGFLEN,
  NE             : FPU_NE,
  NF             : FPU_NF,
  FMT            : FPU_FMT,
  BIAS           : FPU_BIAS,
  FPSIZES        : FPU_FPSIZES,
  FMTBITS        : FPU_FMTBITS,
  LEN1           : FPU_LEN1,
  NE1            : FPU_NE1,
  NF1            : FPU_NF1,
  FMT1           : FPU_FMT1,
  BIAS1          : FPU_BIAS1,
  LEN2           : FPU_LEN2,
  NE2            : FPU_NE2,
  NF2            : FPU_NF2,
  FMT2           : FPU_FMT2,
  BIAS2          : FPU_BIAS2,
  CVTLEN         : FPU_CVTLEN,
  LOGCVTLEN      : FPU_LOGCVTLEN,
  NORMSHIFTSZ    : FPU_NORMSHIFTSZ,
  LOGNORMSHIFTSZ : FPU_LOGNORMSHIFTSZ,
  FMALEN         : FPU_FMALEN,
  LOGR           : FPU_LOGR,
  RK             : FPU_RK,
  FPDUR          : FPU_FPDUR,
  DURLEN         : FPU_DURLEN,
  DIVb           : FPU_DIVb,
  DIVBLEN        : FPU_DIVBLEN,
  INTDIVb        : FPU_INTDIVb
};
