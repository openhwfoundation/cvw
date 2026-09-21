`ifndef DMI_VH
`define DMI_VH

// Width of Debug Transport Module instructions inside the instruction
// register.
`define INSTWIDTH 5

// ABITS is equal to the width of Addresses inside the Debug Module.
`define ABITS 7

// DTM Control and Status register fields
typedef struct packed {
   logic [10:0] reserved0;   // all 0s
   logic [2:0] errinfo;
   logic       dtmhardreset;
   logic       dmireset;
   logic       reserved1;    // single 0
   logic [2:0] idle;
   logic [1:0] dmistat;
   logic [5:0] abits;
   logic [3:0] version;
} dtmcs_t;

typedef struct packed {
   logic [6:0]   addr;
   logic [31:0]  data;
   logic [1:0]   op;
} dmi_t;

// Debug Module Interface fields
typedef struct packed {
   logic [6:0]   addr;
   logic [31:0]  data;
   logic [1:0]   op;
   logic         ready;
   logic         valid;
} dmi_req_t;

// Debug Module Interface fields
typedef struct packed {
   logic [31:0] data;
   logic [1:0]  op;
   logic        ready;
   logic        valid;
} dmi_rsp_t;

// Currently implemented instructions for the Debug Transport Module.
typedef enum logic [4:0] {
   BYPASS = 5'b11111,
   IDCODE = 5'b00001,
   DTMCS  = 5'b10000,
   DMIREG = 5'b10001
} DTMINST;

typedef enum logic [1:0] {
   NOP = 2'b00,
   RD  = 2'b01,
   WR  = 2'b10
} DMIOPW;

`define DTMCS_RESET {11'b0, 3'd4, 6'd0, 2'b0, 6'd`ABITS, 4'b1}
`define DMI_WIDTH `ABITS + 32 + 2
// `define DMI_RESET `DMI_WIDTH'h
`endif
