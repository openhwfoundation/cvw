/// custom routines defined for the platform

// Design parameters, used in the code below and custom to this design!
//`define RAM_PATH soc_top.soc_instance.i_sram_subsystem.i_shared_ram
//sim:/testbench/dut/uncore/uncore/ram/ram/memory/RAM
//`define RAM_PATH cvw_testbench.dut.uncore.uncore.ram.ram.memory.RAM
//`define RAM_PATH cvw_testbench.dut.uncore.uncore.ram.ram.memory
`define RAM_PATH cvw_testbench.dut.uncoregen.uncore.ram.ram.memory.ram
//`define RAM_BASE_ADDR 32'h80000000
`define RAM_BASE_ADDR cvw_testbench.P.UNCORE_RAM_BASE

// These two routines are specific to a particular design. They are used
// to read and write to the "mailbox" locations, to synchronize behaviors
// between C code on the processors with activity performed in UVM (and
// among activities in UVM).
//
// Every design will be different. Here we just have a simple Verilog
// array that we can read and write.
//
function automatic void trek_backdoor_read64(
    input  longint unsigned address,
    output longint unsigned data,
    input      int unsigned debug = 1);

  bit [31:0] offset = ((address-`RAM_BASE_ADDR)/(cvw_testbench.P.XLEN/8));
  if (address[1:0] != 2'b00) begin: misaligned
    $display("%t trek_backdoor_read64: Misaligned address", $time);
    $finish();
  end

  if (cvw_testbench.P.XLEN == 32) begin
    data[31: 0] = `RAM_PATH.RAM[offset + 0];
    data[63:32] = `RAM_PATH.RAM[offset + 1];
  end else begin
    data[63:0] = `RAM_PATH.RAM[offset + 0];
  end

if (data != 0)
  $display("%t trek_backdoor_read64: Read 64'h%016h from address 64'h%016h",
           $time, data, address);
endfunction: trek_backdoor_read64


function automatic void trek_backdoor_write64(
    input longint unsigned address,
    input longint unsigned data,
    input     int unsigned debug = 1);

  //bit [15:0] offset = (address-`RAM_BASE_ADDR) >> 2;
  bit [31:0] offset = ((address-`RAM_BASE_ADDR)/(cvw_testbench.P.XLEN/8));

  if (address[1:0] != 2'b00) begin: misaligned
    $display("%t trek_backdoor_write64: Misaligned address", $time);
    $finish();
  end
  if (cvw_testbench.P.XLEN == 32) begin
    `RAM_PATH.RAM[offset + 0] = data[31: 0];
    `RAM_PATH.RAM[offset + 1] = data[63:32];
  end else begin
    `RAM_PATH.RAM[offset + 0] = data[63:0];
  end
  // $display("%t trek_backdoor_write64: Wrote 64'h%016h to address 64'h%016h",
  //          $time, data, address);
endfunction: trek_backdoor_write64


// For performance, we want to read mailboxes ONLY when they're written to!
// (This is very important on emulators!)
//
// Here we trigger a signal when a memory write happens to the range of
// addresses where the mailboxes are.
//
// A clock later, we go poll all the mailboxes (using the "backdoor_read"
// method above.
//
// Each design will be different, depending on where you are able to snoop
// for writes and how long it takes a write to propagate from that point
// to the place where the backdoor read will find it.

bit  trek_c2t_mbox_event;
bit  trek_is_event_addr;

//assign trek_is_event_addr =
//      ((((`RAM_PATH.ad << 2) + `RAM_BASE_ADDR) >= `TREK_C2T_MBOX_BASE) &&
//       (((`RAM_PATH.ad << 2) + `RAM_BASE_ADDR) <  `TREK_C2T_MBOX_LIMIT));
//
//always_ff @(posedge `RAM_PATH.clk) begin: trigger_reading_of_mailboxes
//  trek_c2t_mbox_event <= (trek_is_event_addr &&
//                          (`RAM_PATH.n_cs == 1'b0) &&
//                          (`RAM_PATH.n_we == 1'b0));
//end

// Design specific: one stage delayed so write has a time to settle
//always @(posedge trek_c2t_mbox_event) begin: read_all_mailboxes
always @(posedge cvw_testbench.clk) begin: read_all_mailboxes
  trek_poll_mbox();
end
