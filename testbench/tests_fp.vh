///////////////////////////////////////////
// tests_fp.vh
//
// Written: Katherine Parry 2022
// Modified:
//
// Purpose: List of floating-point tests to apply
//
// A component of the Wally configurable RISC-V project.
//
// Copyright (C) 2021-3 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

`define PATH "../../tests/fp/vectors/"
`define ADD_OPCTRL     3'b110
`define MUL_OPCTRL     3'b100
`define SUB_OPCTRL     3'b111
`define FMA_OPCTRL     3'b000
`define DIV_OPCTRL     3'b000
`define SQRT_OPCTRL    3'b001
`define LE_OPCTRL      3'b011
`define LT_OPCTRL      3'b001
`define EQ_OPCTRL      3'b010
`define TO_UI_OPCTRL   3'b000
`define TO_I_OPCTRL    3'b001
`define TO_UL_OPCTRL   3'b010
`define TO_L_OPCTRL    3'b011
`define FROM_UI_OPCTRL 3'b100
`define FROM_I_OPCTRL  3'b101
`define FROM_UL_OPCTRL 3'b110
`define FROM_L_OPCTRL  3'b111
`define RNE            3'b000
`define RZ             3'b001
`define RU             3'b011
`define RD             3'b010
`define RNM            3'b100
`define FMAUNIT        2
`define DIVUNIT        1
`define CVTINTUNIT     0
`define CVTFPUNIT      4
`define CMPUNIT        3

string f16rv32cvtint[] = '{
  "ui32_to_f16_rne.tv",
  "ui32_to_f16_rz.tv",
  "ui32_to_f16_ru.tv",
  "ui32_to_f16_rd.tv",
  "ui32_to_f16_rnm.tv",
  "i32_to_f16_rne.tv",
  "i32_to_f16_rz.tv",
  "i32_to_f16_ru.tv",
  "i32_to_f16_rd.tv",
  "i32_to_f16_rnm.tv",
  "f16_to_ui32_rne.tv",
  "f16_to_ui32_rz.tv",
  "f16_to_ui32_ru.tv",
  "f16_to_ui32_rd.tv",
  "f16_to_ui32_rnm.tv",
  "f16_to_i32_rne.tv",
  "f16_to_i32_rz.tv",
  "f16_to_i32_ru.tv",
  "f16_to_i32_rd.tv",
  "f16_to_i32_rnm.tv"
};

string f16rv64cvtint[] = '{
  "ui64_to_f16_rne.tv",
  "ui64_to_f16_rz.tv",
  "ui64_to_f16_ru.tv",
  "ui64_to_f16_rd.tv",
  "ui64_to_f16_rnm.tv",
  "i64_to_f16_rne.tv",
  "i64_to_f16_rz.tv",
  "i64_to_f16_ru.tv",
  "i64_to_f16_rd.tv",
  "i64_to_f16_rnm.tv",
  "f16_to_ui64_rne.tv",
  "f16_to_ui64_rz.tv",
  "f16_to_ui64_ru.tv",
  "f16_to_ui64_rd.tv",
  "f16_to_ui64_rnm.tv",
  "f16_to_i64_rne.tv",
  "f16_to_i64_rz.tv",
  "f16_to_i64_ru.tv",
  "f16_to_i64_rd.tv",
  "f16_to_i64_rnm.tv"
};

string f32rv32cvtint[] = '{
  "ui32_to_f32_rne.tv",
  "ui32_to_f32_rz.tv",
  "ui32_to_f32_ru.tv",
  "ui32_to_f32_rd.tv",
  "ui32_to_f32_rnm.tv",
  "i32_to_f32_rne.tv",
  "i32_to_f32_rz.tv",
  "i32_to_f32_ru.tv",
  "i32_to_f32_rd.tv",
  "i32_to_f32_rnm.tv",
  "f32_to_ui32_rne.tv",
  "f32_to_ui32_rz.tv",
  "f32_to_ui32_ru.tv",
  "f32_to_ui32_rd.tv",
  "f32_to_ui32_rnm.tv",
  "f32_to_i32_rne.tv",
  "f32_to_i32_rz.tv",
  "f32_to_i32_ru.tv",
  "f32_to_i32_rd.tv",
  "f32_to_i32_rnm.tv"
};

string f32rv64cvtint[] = '{
  "ui64_to_f32_rne.tv",
  "ui64_to_f32_rz.tv",
  "ui64_to_f32_ru.tv",
  "ui64_to_f32_rd.tv",
  "ui64_to_f32_rnm.tv",
  "i64_to_f32_rne.tv",
  "i64_to_f32_rz.tv",
  "i64_to_f32_ru.tv",
  "i64_to_f32_rd.tv",
  "i64_to_f32_rnm.tv",
  "f32_to_ui64_rne.tv",
  "f32_to_ui64_rz.tv",
  "f32_to_ui64_ru.tv",
  "f32_to_ui64_rd.tv",
  "f32_to_ui64_rnm.tv",
  "f32_to_i64_rne.tv",
  "f32_to_i64_rz.tv",
  "f32_to_i64_ru.tv",
  "f32_to_i64_rd.tv",
  "f32_to_i64_rnm.tv"
};


string f64rv32cvtint[] = '{
  "ui32_to_f64_rne.tv",
  "ui32_to_f64_rz.tv",
  "ui32_to_f64_ru.tv",
  "ui32_to_f64_rd.tv",
  "ui32_to_f64_rnm.tv",
  "i32_to_f64_rne.tv",
  "i32_to_f64_rz.tv",
  "i32_to_f64_ru.tv",
  "i32_to_f64_rd.tv",
  "i32_to_f64_rnm.tv",
  "f64_to_ui32_rne.tv",
  "f64_to_ui32_rz.tv",
  "f64_to_ui32_ru.tv",
  "f64_to_ui32_rd.tv",
  "f64_to_ui32_rnm.tv",
  "f64_to_i32_rne.tv",
  "f64_to_i32_rz.tv",
  "f64_to_i32_ru.tv",
  "f64_to_i32_rd.tv",
  "f64_to_i32_rnm.tv"
};

string f64rv64cvtint[] = '{
  "ui64_to_f64_rne.tv",
  "ui64_to_f64_rz.tv",
  "ui64_to_f64_ru.tv",
  "ui64_to_f64_rd.tv",
  "ui64_to_f64_rnm.tv",
  "i64_to_f64_rne.tv",
  "i64_to_f64_rz.tv",
  "i64_to_f64_ru.tv",
  "i64_to_f64_rd.tv",
  "i64_to_f64_rnm.tv",
  "f64_to_ui64_rne.tv",
  "f64_to_ui64_rz.tv",
  "f64_to_ui64_ru.tv",
  "f64_to_ui64_rd.tv",
  "f64_to_ui64_rnm.tv",
  "f64_to_i64_rne.tv",
  "f64_to_i64_rz.tv",
  "f64_to_i64_ru.tv",
  "f64_to_i64_rd.tv",
  "f64_to_i64_rnm.tv"
};

string f128rv64cvtint[] = '{
  "ui64_to_f128_rne.tv",
  "ui64_to_f128_rz.tv",
  "ui64_to_f128_ru.tv",
  "ui64_to_f128_rd.tv",
  "ui64_to_f128_rnm.tv",
  "i64_to_f128_rne.tv",
  "i64_to_f128_rz.tv",
  "i64_to_f128_ru.tv",
  "i64_to_f128_rd.tv",
  "i64_to_f128_rnm.tv",
  "f128_to_ui64_rne.tv",
  "f128_to_ui64_rz.tv",
  "f128_to_ui64_ru.tv",
  "f128_to_ui64_rd.tv",
  "f128_to_ui64_rnm.tv",
  "f128_to_i64_rne.tv",
  "f128_to_i64_rz.tv",
  "f128_to_i64_ru.tv",
  "f128_to_i64_rd.tv",
  "f128_to_i64_rnm.tv"
};

string f128rv32cvtint[] = '{
  "ui32_to_f128_rne.tv",
  "ui32_to_f128_rz.tv",
  "ui32_to_f128_ru.tv",
  "ui32_to_f128_rd.tv",
  "ui32_to_f128_rnm.tv",
  "i32_to_f128_rne.tv",
  "i32_to_f128_rz.tv",
  "i32_to_f128_ru.tv",
  "i32_to_f128_rd.tv",
  "i32_to_f128_rnm.tv",
  "f128_to_ui32_rne.tv",
  "f128_to_ui32_rz.tv",
  "f128_to_ui32_ru.tv",
  "f128_to_ui32_rd.tv",
  "f128_to_ui32_rnm.tv",
  "f128_to_i32_rne.tv",
  "f128_to_i32_rz.tv",
  "f128_to_i32_ru.tv",
  "f128_to_i32_rd.tv",
  "f128_to_i32_rnm.tv"
};

string f32f16cvt[] = '{
  "f32_to_f16_rne.tv",
  "f32_to_f16_rz.tv",
  "f32_to_f16_ru.tv",
  "f32_to_f16_rd.tv",
  "f32_to_f16_rnm.tv",
  "f16_to_f32_rne.tv",
  "f16_to_f32_rz.tv",
  "f16_to_f32_ru.tv",
  "f16_to_f32_rd.tv",
  "f16_to_f32_rnm.tv"
};

string f64f16cvt[] = '{
  "f64_to_f16_rne.tv",
  "f64_to_f16_rz.tv",
  "f64_to_f16_ru.tv",
  "f64_to_f16_rd.tv",
  "f64_to_f16_rnm.tv",
  "f16_to_f64_rne.tv",
  "f16_to_f64_rz.tv",
  "f16_to_f64_ru.tv",
  "f16_to_f64_rd.tv",
  "f16_to_f64_rnm.tv"
};

string f128f16cvt[] = '{
  "f128_to_f16_rne.tv",
  "f128_to_f16_rz.tv",
  "f128_to_f16_ru.tv",
  "f128_to_f16_rd.tv",
  "f128_to_f16_rnm.tv",
  "f16_to_f128_rne.tv",
  "f16_to_f128_rz.tv",
  "f16_to_f128_ru.tv",
  "f16_to_f128_rd.tv",
  "f16_to_f128_rnm.tv"
};

string f64f32cvt[] = '{
  "f64_to_f32_rne.tv",
  "f64_to_f32_rz.tv",
  "f64_to_f32_ru.tv",
  "f64_to_f32_rd.tv",
  "f64_to_f32_rnm.tv",
  "f32_to_f64_rne.tv",
  "f32_to_f64_rz.tv",
  "f32_to_f64_ru.tv",
  "f32_to_f64_rd.tv",
  "f32_to_f64_rnm.tv"
};

string f128f32cvt[] = '{
  "f128_to_f32_rne.tv",
  "f128_to_f32_rz.tv",
  "f128_to_f32_ru.tv",
  "f128_to_f32_rd.tv",
  "f128_to_f32_rnm.tv",
  "f32_to_f128_rne.tv",
  "f32_to_f128_rz.tv",
  "f32_to_f128_ru.tv",
  "f32_to_f128_rd.tv",
  "f32_to_f128_rnm.tv"
};

string f128f64cvt[] = '{
  "f128_to_f64_rne.tv",
  "f128_to_f64_rz.tv",
  "f128_to_f64_ru.tv",
  "f128_to_f64_rd.tv",
  "f128_to_f64_rnm.tv",
  "f64_to_f128_rne.tv",
  "f64_to_f128_rz.tv",
  "f64_to_f128_ru.tv",
  "f64_to_f128_rd.tv",
  "f64_to_f128_rnm.tv"
};

string f16add[] = '{
  "f16_add_rne.tv",
  "f16_add_rz.tv",
  "f16_add_ru.tv",
  "f16_add_rd.tv",
  "f16_add_rnm.tv"
};

string f32add[] = '{
  "f32_add_rne.tv",
  "f32_add_rz.tv",
  "f32_add_ru.tv",
  "f32_add_rd.tv",
  "f32_add_rnm.tv"
};

string f64add[] = '{
  "f64_add_rne.tv",
  "f64_add_rz.tv",
  "f64_add_ru.tv",
  "f64_add_rd.tv",
  "f64_add_rnm.tv"
};

string f128add[] = '{
  "f128_add_rne.tv",
  "f128_add_rz.tv",
  "f128_add_ru.tv",
  "f128_add_rd.tv",
  "f128_add_rnm.tv"
};

string f16sub[] = '{
  "f16_sub_rne.tv",
  "f16_sub_rz.tv",
  "f16_sub_ru.tv",
  "f16_sub_rd.tv",
  "f16_sub_rnm.tv"
};

string f32sub[] = '{
  "f32_sub_rne.tv",
  "f32_sub_rz.tv",
  "f32_sub_ru.tv",
  "f32_sub_rd.tv",
  "f32_sub_rnm.tv"
};

string f64sub[] = '{
  "f64_sub_rne.tv",
  "f64_sub_rz.tv",
  "f64_sub_ru.tv",
  "f64_sub_rd.tv",
  "f64_sub_rnm.tv"
};

string f128sub[] = '{
  "f128_sub_rne.tv",
  "f128_sub_rz.tv",
  "f128_sub_ru.tv",
  "f128_sub_rd.tv",
  "f128_sub_rnm.tv"
};

string f16mul[] = '{
  "f16_mul_rne.tv",
  "f16_mul_rz.tv",
  "f16_mul_ru.tv",
  "f16_mul_rd.tv",
  "f16_mul_rnm.tv"
};

string f32mul[] = '{
  "f32_mul_rne.tv",
  "f32_mul_rz.tv",
  "f32_mul_ru.tv",
  "f32_mul_rd.tv",
  "f32_mul_rnm.tv"
};

string f64mul[] = '{
  "f64_mul_rne.tv",
  "f64_mul_rz.tv",
  "f64_mul_ru.tv",
  "f64_mul_rd.tv",
  "f64_mul_rnm.tv"
};

string f128mul[] = '{
  "f128_mul_rne.tv",
  "f128_mul_rz.tv",
  "f128_mul_ru.tv",
  "f128_mul_rd.tv",
  "f128_mul_rnm.tv"
};

string f16div[] = '{
  "f16_div_rne.tv",
  "f16_div_rz.tv",
  "f16_div_ru.tv",
  "f16_div_rd.tv",
  "f16_div_rnm.tv"
};

string f32div[] = '{
  "f32_div_rne.tv",
  "f32_div_rz.tv",
  "f32_div_ru.tv",
  "f32_div_rd.tv",
  "f32_div_rnm.tv"
};

string f64div[] = '{
  "f64_div_rne.tv",
  "f64_div_rz.tv",
  "f64_div_ru.tv",
  "f64_div_rd.tv",
  "f64_div_rnm.tv"
};

string f128div[] = '{
  "f128_div_rne.tv",
  "f128_div_rz.tv",
  "f128_div_ru.tv",
  "f128_div_rd.tv",
  "f128_div_rnm.tv"
};

string f16sqrt[] = '{
  "f16_sqrt_rne.tv",
  "f16_sqrt_rz.tv",
  "f16_sqrt_ru.tv",
  "f16_sqrt_rd.tv",
  "f16_sqrt_rnm.tv"
};

string f32sqrt[] = '{
  "f32_sqrt_rne.tv",
  "f32_sqrt_rz.tv",
  "f32_sqrt_ru.tv",
  "f32_sqrt_rd.tv",
  "f32_sqrt_rnm.tv"
};

string f64sqrt[] = '{
  "f64_sqrt_rne.tv",
  "f64_sqrt_rz.tv",
  "f64_sqrt_ru.tv",
  "f64_sqrt_rd.tv",
  "f64_sqrt_rnm.tv"
};

string f128sqrt[] = '{
  "f128_sqrt_rne.tv",
  "f128_sqrt_rz.tv",
  "f128_sqrt_ru.tv",
  "f128_sqrt_rd.tv",
  "f128_sqrt_rnm.tv"
};

string f16cmp[] = '{
  "f16_eq_rne.tv",
  "f16_eq_rz.tv",
  "f16_eq_ru.tv",
  "f16_eq_rd.tv",
  "f16_eq_rnm.tv",
  "f16_le_rne.tv",
  "f16_le_rz.tv",
  "f16_le_ru.tv",
  "f16_le_rd.tv",
  "f16_le_rnm.tv",
  "f16_lt_rne.tv",
  "f16_lt_rz.tv",
  "f16_lt_ru.tv",
  "f16_lt_rd.tv",
  "f16_lt_rnm.tv"
};

string f32cmp[] = '{
  "f32_eq_rne.tv",
  "f32_eq_rz.tv",
  "f32_eq_ru.tv",
  "f32_eq_rd.tv",
  "f32_eq_rnm.tv",
  "f32_le_rne.tv",
  "f32_le_rz.tv",
  "f32_le_ru.tv",
  "f32_le_rd.tv",
  "f32_le_rnm.tv",
  "f32_lt_rne.tv",
  "f32_lt_rz.tv",
  "f32_lt_ru.tv",
  "f32_lt_rd.tv",
  "f32_lt_rnm.tv"
};

string f64cmp[] = '{
  "f64_eq_rne.tv",
  "f64_eq_rz.tv",
  "f64_eq_ru.tv",
  "f64_eq_rd.tv",
  "f64_eq_rnm.tv",
  "f64_le_rne.tv",
  "f64_le_rz.tv",
  "f64_le_ru.tv",
  "f64_le_rd.tv",
  "f64_le_rnm.tv",
  "f64_lt_rne.tv",
  "f64_lt_rz.tv",
  "f64_lt_ru.tv",
  "f64_lt_rd.tv",
  "f64_lt_rnm.tv"
};

string f128cmp[] = '{
  "f128_eq_rne.tv",
  "f128_eq_rz.tv",
  "f128_eq_ru.tv",
  "f128_eq_rd.tv",
  "f128_eq_rnm.tv",
  "f128_le_rne.tv",
  "f128_le_rz.tv",
  "f128_le_ru.tv",
  "f128_le_rd.tv",
  "f128_le_rnm.tv",
  "f128_lt_rne.tv",
  "f128_lt_rz.tv",
  "f128_lt_ru.tv",
  "f128_lt_rd.tv",
  "f128_lt_rnm.tv"
};

string f16fma[] = '{
  "f16_mulAdd_rne.tv",
  "f16_mulAdd_rz.tv",
  "f16_mulAdd_ru.tv",
  "f16_mulAdd_rd.tv",
  "f16_mulAdd_rnm.tv"
};

string f32fma[] = '{
  "f32_mulAdd_rne.tv",
  "f32_mulAdd_rz.tv",
  "f32_mulAdd_ru.tv",
  "f32_mulAdd_rd.tv",
  "f32_mulAdd_rnm.tv"
};

string f64fma[] = '{
  "f64_mulAdd_rne.tv",
  "f64_mulAdd_rz.tv",
  "f64_mulAdd_ru.tv",
  "f64_mulAdd_rd.tv",
  "f64_mulAdd_rnm.tv"
};

string f128fma[] = '{
  "f128_mulAdd_rne.tv",
  "f128_mulAdd_rz.tv",
  "f128_mulAdd_ru.tv",
  "f128_mulAdd_rd.tv",
  "f128_mulAdd_rnm.tv"
};
