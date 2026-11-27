///////////////////////////////////////////
// uartPC16550D.sv
//
// Written:  David Harris David_Harris@hmc.edu 21 January 2021
// Modified: Rose Thompson, Ben Bracker, Lucio, Jacob Pease
//
// Purpose: UART emulating the TI PC16550D.
//          Datasheet: https://media.digikey.com/pdf/Data%20Sheets/Texas%20Instruments%20PDFs/PC16550D.pdf
//          Section numbers below refer to the June 1995 datasheet.
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

module uartPC16550D #(parameter UART_PRESCALE) (
  // Processor Interface
  input  logic       PCLK, PRESETn,                  // UART clock and active low reset
  input  logic [2:0] A,                              // address input (8 registers)
  input  logic [7:0] Din,                            // 8-bit WriteData
  output logic [7:0] Dout,                           // 8-bit ReadData
  input  logic       MEMRb, MEMWb,                   // Active low memory read/write
  output logic       INTR, TXRDYb, RXRDYb,           // interrupt and ready lines
  // Clocks
  output logic       BAUDOUTb,                       // active low baud clock
  input  logic       RCLK,                           // usually BAUDOUTb tied to RCLK externally
  // E1A Driver
  input  logic       SIN, DSRb, DCDb, CTSb, RIb,     // UART external serial and flow-control inputs
  output logic       SOUT, RTSb, DTRb, OUT1b, OUT2b  // UART external serial and flow-control outputs
);

  // register map
  localparam UART_DLL_RBR = 3'b000;
  localparam UART_DLM_IER = 3'b001;
  localparam UART_IIR     = 3'b010;
  localparam UART_LCR     = 3'b011;
  localparam UART_MCR     = 3'b100;
  localparam UART_LSR     = 3'b101;
  localparam UART_MSR     = 3'b110;
  localparam UART_SCR     = 3'b111;

  // transmit and receive states
  typedef enum logic [1:0] {UART_IDLE, UART_ACTIVE, UART_DONE, UART_BREAK} statetype;

  // Registers
  logic [10:0] RBR;
  logic [7:0]  FCR, LCR, LSR, SCR, DLL, DLM;
  logic [3:0]  IER, MSR;
  logic [4:0]  MCR;

  // Synchronized and delayed UART signals
  logic        SINd, DSRbd, DCDbd, CTSbd, RIbd;
  logic        SINsync, DSRbsync, DCDbsync, CTSbsync, RIbsync;
  logic        DSRb2, DCDb2, CTSb2, RIb2;
  logic        SOUTbit;

  // Control signals
  logic        loop; // loopback mode
  logic        DLAB; // Divisor Latch Access Bit (LCR bit 7)
  logic        thrwrite, rbrread, lsrread, msrread, fcrwrite, fifomodechange;

  // Baud and rx/tx timing
  logic                         baudpulse, txbaudpulse, rxbaudpulse; // high one system clk cycle each baud/16 period
  logic [16+UART_PRESCALE-1:0]  baudcount;
  logic [3:0]                   rxoversampledcnt, txoversampledcnt;  // count oversampled-by-16
  logic [3:0]                   rxbitsreceived, txbitssent;
  statetype rxstate, txstate;

  // shift registers and FIFOs
  // The FIFO pointers have an extra wrap bit, so equal pointers mean empty and pointers that differ
  // only in the wrap bit mean full (16 entries).
  logic [9:0]                   rxshiftreg;
  logic [10:0]                  rxfifo[15:0];       // {break, framing error, parity error, data}
  logic [7:0]                   txfifo[15:0];
  logic [4:0]                   rxfifohead, rxfifotail, txfifohead, txfifotail;
  logic [4:0]                   rxfifoentries, rxfifotriggerlevel;
  logic [3:0]                   rxfifowaddr;
  logic [3:0]                   rxbitsexpected, txbitsexpected, txframebits;
  logic                         txhalfstop;

  // receive data
  logic [10:0]                  RXBR;
  logic [9:0]                   rxtimeoutcnt, rxtimeoutlimit;
  logic                         rxcentered, rxdone;
  logic                         rxparity, rxparitybit, rxparityexpected, rxstopbit;
  logic                         rxparityerr, rxoverrunerr, rxframingerr, rxbreak, rxfifohaserr;
  logic                         rxdataready, rxbrfull;
  logic                         rxfifoempty, rxfifofull, rxfifotriggered, rxfifotimeout;
  logic                         rxpush, rxpop, rxfifoclear;
  logic                         rxfifodmaready;
  logic [8:0]                   rxdata9;
  logic [7:0]                   rxdata, rxdatamask;
  logic [2:0]                   rxerr, rxnewerr;   // {break, framing error, parity error}, as in LSR[4:2]
  logic [15:0]                  RXerrbit, rxfullbit;

  // transmit data
  logic [7:0]                   TXHR, nexttxdata;
  logic [11:0]                  txdata, txsr;
  logic                         txnextbit, txhrfull, txsrfull;
  logic                         txparity, txparitydata;
  logic                         txfifoempty, txfifofull, txfifodmaready, txfifoclear;
  logic [4:0]                   txfifoentries;
  logic                         txfifohadtwo, txthredelay, txload;

  // control signals
  logic                         fifoenabled, fifodmamodesel, evenparitysel, stickparity;

  // interrupts
  logic                         RXerrIP;
  logic                         THRE, THRE_IP, squashTHRE_IP, prevSquashTHRE_IP, setSquashTHRE_IP, resetSquashTHRE_IP;
  logic                         rxdataavailintr, modemstatusintr, intrpending;
  logic [2:0]                   intrID;

  logic                         baudpulseComb;

  ///////////////////////////////////////////
  // Input synchronization: 2-stage synchronizer
  ///////////////////////////////////////////

  synchronizer #(5) inputsync(.clk(PCLK), .d({SIN, DSRb, DCDb, CTSb, RIb}), .q({SINd, DSRbd, DCDbd, CTSbd, RIbd}));
  // loopback signals are already synchronous to PCLK
  assign {SINsync, DSRbsync, DCDbsync, CTSbsync, RIbsync} = loop ? {SOUTbit, ~MCR[0], ~MCR[3], ~MCR[1], ~MCR[2]} :
                                                                   {SINd, DSRbd, DCDbd, CTSbd, RIbd};
  always_ff @(posedge PCLK)
    {DSRb2, DCDb2, CTSb2, RIb2} <= {DSRbsync, DCDbsync, CTSbsync, RIbsync}; // for detecting state changes

  ///////////////////////////////////////////
  // Register interface (Table II, note some are read only and some write only)
  ///////////////////////////////////////////

  assign thrwrite = ~MEMWb & (A == UART_DLL_RBR) & ~DLAB;
  assign rbrread  = ~MEMRb & (A == UART_DLL_RBR) & ~DLAB;
  assign lsrread  = ~MEMRb & (A == UART_LSR);
  assign msrread  = ~MEMRb & (A == UART_MSR);
  assign fcrwrite = ~MEMWb & (A == UART_IIR);
  assign fifomodechange = fcrwrite & (Din[0] ^ FCR[0]); // changing FCR[0] clears both FIFOs (8.5)

  always_ff @(posedge PCLK)
    if (~PRESETn) begin // Table I Reset Configuration
      IER <= 4'b0;
      FCR <= 8'b0;
      LCR <= 8'b11; // PC16550D datasheet resets to 0, but all modern systems will use 8-bit data.  Wally resets to 3 for 8-bit data.
      MCR <= 5'b0;
      LSR <= 8'b0110_0000;
      MSR <= 4'b0;
      DLL <= 8'd1; // this cannot be zero with DLM also zero.
      DLM <= 8'b0;
      SCR <= 8'b0; // not strictly necessary to reset
    end else begin
      if (~MEMWb) begin
        /* verilator lint_off CASEINCOMPLETE */
        case (A)
          UART_DLL_RBR: if (DLAB) DLL <= Din; // else TXHR <= Din; // TX handled in TX register/FIFO section
          UART_DLM_IER: if (DLAB) DLM <= Din; else IER <= Din[3:0];
          // Write only FIFO Control Register; 4:5 reserved and 2:1 self-clearing.  The other bits are
          // programmed only when FCR[0] is written 1 (8.5).
          UART_IIR:     if (Din[0]) FCR <= {Din[7:6], 2'b0, Din[3], 2'b0, 1'b1};
                        else        FCR[0] <= 1'b0;
          UART_LCR:     LCR <= Din;
          UART_MCR:     MCR <= Din[4:0];
          UART_SCR:     SCR <= Din;
        endcase
        /* verilator lint_on CASEINCOMPLETE */
      end

      // Line Status Register (8.4).  LSR[0] is rxdataready, so it changes in the same cycle as the error
      // flags of the character it reports.  An LSR read clears the error flags it returned, but not a flag
      // set in the same cycle.
      if (~MEMWb & (A == UART_LSR))
        LSR[6:1] <= Din[6:1]; // recommended only for test, see 8.4
      else begin
        LSR[1]   <= (LSR[1] & ~lsrread) | (rxdone & rxoverrunerr); // overrun error, reported at once
        LSR[4:2] <= (LSR[4:2] & ~{3{lsrread}}) | rxnewerr;        // break, framing, parity errors
        LSR[5]   <= THRE; // THRE
        LSR[6]   <= ~txsrfull & THRE; // TEMT
        LSR[7]   <= fifoenabled & (rxfifohaserr | (rxpush & |rxerr) | (LSR[7] & ~lsrread)); // retain unacknowledged FIFO errors
      end

      // Modem Status Register (8.9).  A read clears the deltas it returned, but not a change seen in the same cycle.
      if (~MEMWb & (A == UART_MSR))
        MSR <= Din[3:0];
      else begin
        MSR[0] <= (MSR[0] & ~msrread) | (CTSb2 ^ CTSbsync);  // Delta Clear to Send
        MSR[1] <= (MSR[1] & ~msrread) | (DSRb2 ^ DSRbsync);  // Delta Data Set Ready
        MSR[2] <= (MSR[2] & ~msrread) | (~RIb2 & RIbsync);   // Trailing Edge of Ring Indicator
        MSR[3] <= (MSR[3] & ~msrread) | (DCDb2 ^ DCDbsync);  // Delta Data Carrier Detect
      end
    end

  always_comb
    if (~MEMRb)
      case (A)
        UART_DLL_RBR: if (DLAB) Dout = DLL; else Dout = RBR[7:0];
        UART_DLM_IER: if (DLAB) Dout = DLM; else Dout = {4'b0, IER[3:0]};
        UART_IIR:     Dout = {{2{fifoenabled}}, 2'b00, intrID[2:0], ~intrpending}; // Read only Interrupt Ident Register
        UART_LCR:     Dout = LCR;
        UART_MCR:     Dout = {3'b000, MCR};
        UART_LSR:     Dout = {LSR[7] & fifoenabled, LSR[6:1], rxdataready}; // LSR7 is always zero in 16450 mode
        UART_MSR:     Dout = {~DCDbsync, ~RIbsync, ~DSRbsync, ~CTSbsync, MSR[3:0]};
        UART_SCR:     Dout = SCR;
      endcase
    else Dout = 8'b0;

  ///////////////////////////////////////////
  // Baud rate generator
  // consider switching to same fixed-frequency reference clock used for TIME register
  // prescale by factor of 2^UART_PRESCALE to allow for high-frequency reference clock
  // Unlike PC16550D, this unit is hardwired with same rx and tx baud clock
  // For example, with PCLK = 320 MHz, UART_PRESCALE = 5, DLM = 0, DLL = 65,
  // 320 MHz system clock is divided by 65 x 2^5.  The UART clock 16x oversamples
  // the data, so the baud rate is 320x10^6 / (65 x 2^5 x 16) = 9615 Hz, which is
  // close enough to 9600 baud to stay synchronized over the duration of one character.
  ///////////////////////////////////////////
  always_ff @(posedge PCLK)
    if (~PRESETn) begin
      baudcount <= 1;
      baudpulse <= 1'b0;
    end else if (~MEMWb & DLAB & (A == UART_DLL_RBR | A == UART_DLM_IER)) begin // writing DLL or DLM restarts the baud counter
      baudcount <= 1;
    end else begin
      // the baudpulse is too long by 2 clock cycles.
      // This is because baudpulse is registered adding 1 cycle and
      // baudcount is reset when baudcount equals the threshold {DLM, DLL, UART_PRESCALE}
      // rather than 1 less than that value.  Alternatively the reset value could be 1 rather
      // than 0.
      baudpulse <= baudpulseComb;
      baudcount <= baudpulseComb ? 1 : baudcount + 1;
    end

  assign baudpulseComb = (baudcount == {DLM, DLL, {(UART_PRESCALE){1'b0}}});

  assign txbaudpulse = baudpulse;
  assign BAUDOUTb = ~baudpulse;
  assign rxbaudpulse = ~RCLK; // usually BAUDOUTb tied to RCLK externally

  ///////////////////////////////////////////
  // receive timing and control
  ///////////////////////////////////////////

  always_ff @(posedge PCLK)
    if (~PRESETn) begin
      rxoversampledcnt   <= '0;
      rxstate            <= UART_IDLE;
      rxbitsreceived     <= '0;
      rxtimeoutcnt       <= '0;
    end else begin
      if (rxstate == UART_IDLE & ~SINsync) begin // got start bit
        rxstate          <= UART_ACTIVE;
        rxoversampledcnt <= '0;
        rxbitsreceived   <= '0;
      end else if (rxbaudpulse & (rxstate == UART_ACTIVE)) begin
        rxoversampledcnt <= rxoversampledcnt + 4'b1;  // 16x oversampled counter
        if (rxcentered) rxbitsreceived <= rxbitsreceived + 1;
        if (rxcentered & (rxbitsreceived == 0) & SINsync) rxstate <= UART_IDLE; // false start bit: the line is high again mid-bit
        else if (rxbitsreceived == rxbitsexpected) rxstate <= UART_DONE; // pulse rxdone for a cycle
      end else if (rxstate == UART_DONE | rxstate == UART_BREAK) begin
        if (rxbreak & ~SINsync) rxstate <= UART_BREAK; // the next character needs the line to return to marking (8.4 BI)
        else if (rxframingerr & ~rxbreak & ~SINsync & (rxstate == UART_DONE)) begin
          // After a framing error, the bad stop bit is taken as the next start bit (8.4 FE): its middle
          // has just been sampled, so continue with the first data bit, keeping the bit timing.
          rxstate        <= UART_ACTIVE;
          rxbitsreceived <= 4'd1;
        end else rxstate <= UART_IDLE;
      end
      // Character timeout timer (8.11): reset by a read of the FIFO, and by a newly received character
      // unless the timeout has already occurred; idle while the FIFO is empty.
      if (rxfifoempty | rxpop | rxfifoclear | ~fifoenabled) rxtimeoutcnt <= '0;
      else if (rxdone & ~rxfifotimeout)                       rxtimeoutcnt <= '0;
      else if (rxbaudpulse & ~rxfifotimeout)                  rxtimeoutcnt <= rxtimeoutcnt + 1; // count 16x baud pulses while characters wait
    end

  assign rxcentered = rxbaudpulse & (rxoversampledcnt == 4'b1000);     // implies rxstate = UART_ACTIVE
  assign rxdone = (rxstate == UART_DONE);

  assign rxbitsexpected = 4'd1 + (4'd5 + {2'b00, LCR[1:0]}) + {3'b000, LCR[3]} + 4'd1; // start bit + data bits + (parity bit) + stop bit

  // 4 character times in 16x baud pulses: 64 per bit, including a second stop bit (half of one for
  // 5-bit characters) when programmed (8.11).
  assign rxtimeoutlimit = {rxbitsexpected, 6'b0} + (LCR[2] ? ((LCR[1:0] == 2'b00) ? 10'd32 : 10'd64) : 10'd0);

  ///////////////////////////////////////////
  // receive shift register, buffer register, FIFO
  ///////////////////////////////////////////

  always_ff @(posedge PCLK)
    if (~PRESETn) rxshiftreg <= 10'b0000000001; // initialize so that there is a valid stop bit
    else if (rxcentered) rxshiftreg <= {rxshiftreg[8:0], SINsync}; // capture bit
  assign rxparitybit = rxshiftreg[1]; // parity, if it exists, in bit 1 when all done
  assign rxstopbit = rxshiftreg[0];
  always_comb
    case (LCR[1:0]) // check how many bits used.  Grab all bits including possible parity
      2'b00: rxdata9 = {3'b0, rxshiftreg[1], rxshiftreg[2], rxshiftreg[3], rxshiftreg[4], rxshiftreg[5], rxshiftreg[6]}; // 5-bit character
      2'b01: rxdata9 = {2'b0, rxshiftreg[1], rxshiftreg[2], rxshiftreg[3], rxshiftreg[4], rxshiftreg[5], rxshiftreg[6], rxshiftreg[7]}; // 6-bit
      2'b10: rxdata9 = {1'b0, rxshiftreg[1], rxshiftreg[2], rxshiftreg[3], rxshiftreg[4], rxshiftreg[5], rxshiftreg[6], rxshiftreg[7], rxshiftreg[8]}; // 7-bit
      2'b11: rxdata9 = {      rxshiftreg[1], rxshiftreg[2], rxshiftreg[3], rxshiftreg[4], rxshiftreg[5], rxshiftreg[6], rxshiftreg[7], rxshiftreg[8], rxshiftreg[9]}; // 8-bit
    endcase
  always_comb
    case (LCR[1:0])
      2'b00: rxdatamask = 8'h1F;
      2'b01: rxdatamask = 8'h3F;
      2'b10: rxdatamask = 8'h7F;
      2'b11: rxdatamask = 8'hFF;
    endcase
  assign rxdata = (LCR[3] ? rxdata9[7:0] : rxdata9[8:1]) & rxdatamask; // discard the parity bit, keep only the data bits

  // ERROR CONDITIONS
  assign rxparity         = ^rxdata;
  assign rxparityexpected = stickparity ? ~evenparitysel : rxparity ^ ~evenparitysel; // stick parity: 0 if even, 1 if odd (8.1)
  assign rxparityerr      = LCR[3] & (rxparitybit ^ rxparityexpected);
  assign rxframingerr     = ~rxstopbit; // framing error if no stop bit
  assign rxbreak          = rxframingerr & (rxdata9 == 9'b0); // break when 0 for start + data + parity + stop time
  assign rxerr            = {rxbreak, rxframingerr, rxparityerr};

  // receive FIFO and register
  assign rxfifoclear  = fcrwrite & (Din[0] ? (Din[1] | ~FCR[0]) : FCR[0]); // FCR[1] or a FIFO mode change (8.5)
  assign rxoverrunerr = fifoenabled ? (rxfifofull & ~rbrread) : (rxbrfull & ~rbrread); // no room for the character
  assign rxpush       = rxdone & fifoenabled & ~rxoverrunerr; // an overrunning character is not transferred to the FIFO (8.4 OE)
  assign rxpop        = rbrread & fifoenabled & ~rxfifoempty;
  assign rxfifowaddr  = rxfifoclear ? 4'b0 : rxfifohead[3:0]; // a character completing as the FIFO is reset lands in the empty FIFO

  always_ff @(posedge PCLK)
    if (~PRESETn) begin
      rxfifohead <= '0; rxfifotail <= '0; rxbrfull <= 1'b0; RXBR <= '0;
    end else begin
      // Reading LSR acknowledges only the current character's errors, not errors still queued behind it.
      // A simultaneous arrival into the same slot takes priority over this clear.
      if (lsrread & fifoenabled & ~rxfifoempty) rxfifo[rxfifotail[3:0]][10:8] <= '0;
      if (rxpush) rxfifo[rxfifowaddr] <= {rxerr, rxdata};
      if (rxfifoclear) begin
        rxfifohead <= {4'b0, rxpush};
        rxfifotail <= '0;
      end else begin
        rxfifohead <= rxfifohead + {4'b0, rxpush};
        rxfifotail <= rxfifotail + {4'b0, rxpop};
      end
      // 16450 mode: receive buffer register
      if (rxdone & ~fifoenabled) begin
        RXBR     <= {rxerr, rxdata}; // load receive buffer register; an overrun replaces the unread character (8.4 OE)
        rxbrfull <= 1'b1;
      end else if (rbrread | fifomodechange) rxbrfull <= 1'b0; // a FIFO mode change also clears the receive buffer
    end

  assign rxfifoentries = rxfifohead - rxfifotail;
  assign rxfifoempty   = (rxfifohead == rxfifotail);
  assign rxfifofull    = (rxfifoentries == 5'd16);
  assign rxdataready   = fifoenabled ? ~rxfifoempty : rxbrfull;
  assign rxfifotriggered = rxfifoentries >= rxfifotriggerlevel;
  assign rxfifotimeout   = rxtimeoutcnt >= rxtimeoutlimit; // 4 character times without a character received or read

  // Error flags for LSR[4:2] (8.4).  In 16450 mode they come with the character.  In FIFO mode each
  // character's flags are revealed when it reaches the top of the FIFO: when it arrives in an empty
  // FIFO, or when the character ahead of it is read.
  always_comb
    if (~fifoenabled)                                    rxnewerr = rxdone ? rxerr : 3'b0;
    else if (rxfifoclear)                                rxnewerr = rxpush ? rxerr : 3'b0;
    else if (rxpop & (rxfifoentries > 5'd1))             rxnewerr = rxfifo[rxfifotail[3:0] + 4'd1][10:8];
    else if (rxpush & (rxfifoentries == {4'b0, rxpop}))  rxnewerr = rxerr;
    else                                                 rxnewerr = 3'b0;

  // detect any errors in rx fifo: slot i holds a character when it lies within rxfifoentries slots above the tail (mod 16)
  genvar i;
  for (i = 0; i < 16; i++) begin : rx
    assign RXerrbit[i]  = |rxfifo[i][10:8] & ~(lsrread & (rxfifotail[3:0] == 4'(i))); // exclude the error acknowledged by this LSR read
    assign rxfullbit[i] = {1'b0, 4'(i) - rxfifotail[3:0]} < rxfifoentries;
  end
  assign rxfifohaserr   = |(RXerrbit & rxfullbit);

  // receive buffer register and ready bit
  always_ff @(posedge PCLK) // track rxrdy for DMA mode (FCR3 = FCR0 = 1)
    if (~PRESETn) rxfifodmaready <= 1'b0;
    else if (rxfifotriggered | rxfifotimeout) rxfifodmaready <= 1'b1;
    else if (rxfifoempty) rxfifodmaready <= 1'b0;

  always_comb
    if (fifoenabled) begin
      if (rxfifoempty) RBR = 11'b0;
      else             RBR = rxfifo[rxfifotail[3:0]];
      if (fifodmamodesel) RXRDYb = ~rxfifodmaready;
      else                RXRDYb = rxfifoempty;
    end else begin
      RBR    = RXBR;
      RXRDYb = ~rxdataready;
    end

  ///////////////////////////////////////////
  // transmit timing and control
  ///////////////////////////////////////////

  always_ff @(posedge PCLK)
    if (~PRESETn) begin
      txoversampledcnt <= '0;
      txstate          <= UART_IDLE;
      txbitssent       <= '0;
    end else if ((txstate == UART_IDLE) & txsrfull) begin // start transmitting
      txstate          <= UART_ACTIVE;
      txoversampledcnt <= 4'b1;
      txbitssent       <= '0;
    end else if (txbaudpulse & (txstate == UART_ACTIVE)) begin
      txoversampledcnt <= txoversampledcnt + 1'b1;
      if (txnextbit) begin // transmit at end of phase
        txbitssent <= txbitssent + 1'b1;
        if (txbitssent == txframebits) txstate <= UART_DONE;
      end else if (txhalfstop & (txbitssent == txframebits) & (txoversampledcnt == 4'd8))
        txstate <= UART_DONE; // 1.5 stop bits: end halfway through the second stop bit
    end else if (txstate == UART_DONE) begin
      txstate <= UART_IDLE;
    end

  // The frame is set by LCR when the character is loaded into the shift register (txframebits, txhalfstop),
  // so a later LCR change does not cut the character short.
  assign txbitsexpected = 4'd1 + (4'd5 + {2'b00, LCR[1:0]}) + {3'b000, LCR[3]} + 4'd1 + {3'b000, LCR[2]} - 4'd1; // start bit + data bits + (parity bit) + stop bit(s) - 1
  assign txnextbit = txbaudpulse & (txoversampledcnt == 4'b0000);  // implies txstate = UART_ACTIVE

  ///////////////////////////////////////////
  // transmit holding register, shift register, FIFO
  ///////////////////////////////////////////

  always_comb begin // compute value for parity and tx holding register
    nexttxdata = fifoenabled ? txfifo[txfifotail[3:0]] : TXHR; // pick from FIFO or holding register
    case (LCR[1:0]) // compute parity from appropriate number of bits
      2'b00: txparitydata = ^nexttxdata[4:0];
      2'b01: txparitydata = ^nexttxdata[5:0];
      2'b10: txparitydata = ^nexttxdata[6:0];
      2'b11: txparitydata = ^nexttxdata[7:0];
    endcase
    txparity = stickparity ? ~evenparitysel : txparitydata ^ ~evenparitysel; // stick parity: 0 if even, 1 if odd (8.1)
    case ({LCR[3], LCR[1:0]}) // parity, data bits
      // load up start bit (0), 5-8 data bits, 0-1 parity bits, 2 stop bits (only one sometimes used), padding
      3'b000: txdata = {1'b0, nexttxdata[0], nexttxdata[1], nexttxdata[2], nexttxdata[3], nexttxdata[4], 6'b111111};                                                       // 5 data, no parity
      3'b001: txdata = {1'b0, nexttxdata[0], nexttxdata[1], nexttxdata[2], nexttxdata[3], nexttxdata[4], nexttxdata[5], 5'b11111};                                         // 6 data, no parity
      3'b010: txdata = {1'b0, nexttxdata[0], nexttxdata[1], nexttxdata[2], nexttxdata[3], nexttxdata[4], nexttxdata[5], nexttxdata[6], 4'b1111};                           // 7 data, no parity
      3'b011: txdata = {1'b0, nexttxdata[0], nexttxdata[1], nexttxdata[2], nexttxdata[3], nexttxdata[4], nexttxdata[5], nexttxdata[6], nexttxdata[7], 3'b111};             // 8 data, no parity
      3'b100: txdata = {1'b0, nexttxdata[0], nexttxdata[1], nexttxdata[2], nexttxdata[3], nexttxdata[4], txparity, 5'b11111};                                              // 5 data, parity
      3'b101: txdata = {1'b0, nexttxdata[0], nexttxdata[1], nexttxdata[2], nexttxdata[3], nexttxdata[4], nexttxdata[5], txparity, 4'b1111};                                // 6 data, parity
      3'b110: txdata = {1'b0, nexttxdata[0], nexttxdata[1], nexttxdata[2], nexttxdata[3], nexttxdata[4], nexttxdata[5], nexttxdata[6], txparity, 3'b111};                  // 7 data, parity
      3'b111: txdata = {1'b0, nexttxdata[0], nexttxdata[1], nexttxdata[2], nexttxdata[3], nexttxdata[4], nexttxdata[5], nexttxdata[6], nexttxdata[7], txparity, 2'b11};    // 8 data, parity
    endcase
  end

  // registers & FIFO
  assign txfifoclear = fcrwrite & (Din[0] ? (Din[2] | ~FCR[0]) : FCR[0]); // FCR[2] or a FIFO mode change (8.5)
  assign txload = (txstate == UART_IDLE) & (fifoenabled ? (~txfifoempty & ~txsrfull) : txhrfull);

  always_ff @(posedge PCLK)
    if (~PRESETn) begin
      txfifohead <= '0; txfifotail <= '0; txhrfull <= 1'b0; txsrfull <= 1'b0; TXHR <= '0; txsr <= 12'hfff;
      txframebits <= '0; txhalfstop <= 1'b0;
    end else begin
      if (txstate == UART_IDLE) begin // move data into tx shift register if available
        if (txload) begin
          txsr        <= txdata;
          txsrfull    <= 1'b1;
          txframebits <= txbitsexpected;
          txhalfstop  <= LCR[2] & (LCR[1:0] == 2'b00); // 1.5 stop bits with 5-bit characters (8.1)
          if (fifoenabled) txfifotail <= txfifotail + 1;
          else             txhrfull   <= 1'b0;
        end
      end else if (txstate == UART_DONE) txsrfull <= 1'b0; // done transmitting shift register
      else if (txstate == UART_ACTIVE & txnextbit) txsr <= {txsr[10:0], 1'b1}; // shift txhr
      if (thrwrite) begin // writing transmit holding register or fifo
        if (fifoenabled) begin
          if (~txfifofull) begin // a write to a full XMIT FIFO is discarded
            txfifo[txfifohead[3:0]] <= Din;
            txfifohead              <= txfifohead + 1;
          end
        end else begin
          TXHR     <= Din;
          txhrfull <= 1'b1;
        end
        $write("%c", Din); // for testbench
      end
      if (txfifoclear) begin // XMIT FIFO reset or FIFO mode change clears the FIFO, not the shift register
        txfifohead <= '0; txfifotail <= '0;
      end
      if (fifomodechange) txhrfull <= 1'b0; // the 16450-mode holding register is cleared too
    end

  assign txfifoempty = (txfifohead == txfifotail);
  assign txfifofull  = (txfifohead == {~txfifotail[4], txfifotail[3:0]});
  assign txfifoentries = txfifohead - txfifotail;

  // PC16550D 8.11: after a single-byte refill, delay the FIFO-empty indication by one character
  // minus its last stop bit.  The frame already latched in the shifter supplies that timing: release
  // THRE as its last stop bit begins.  If two bytes were queued together, no delay is required.
  // Reset/mode changes leave the initial empty indication immediate; 16450 mode has no FIFO delay.
  always_ff @(posedge PCLK)
    if (~PRESETn) begin
      txfifohadtwo <= 1'b0;
      txthredelay <= 1'b0;
    end else if (txfifoclear | ~fifoenabled) begin
      txfifohadtwo <= 1'b0;
      txthredelay <= 1'b0;
    end else begin
      if (txfifoempty) txfifohadtwo <= 1'b0;
      else if (txfifoentries >= 5'd2) txfifohadtwo <= 1'b1;
      if (txload) txthredelay <= (txfifoentries == 5'd1) & ~txfifohadtwo;
      else if ((txstate == UART_ACTIVE) & txnextbit & (txbitssent == txframebits - 4'd1))
        txthredelay <= 1'b0;
    end

  // transmit buffer ready bit
  always_ff @(posedge PCLK) // track txrdy for DMA mode (FCR3 = FCR0 = 1)
    if (~PRESETn)         txfifodmaready <= 1'b0;
    else if (txfifoempty) txfifodmaready <= 1'b1;
    else if (txfifofull)  txfifodmaready <= 1'b0;

  always_comb
    if (fifoenabled & fifodmamodesel) TXRDYb = ~txfifodmaready;
    else TXRDYb = fifoenabled ? ~txfifoempty : txhrfull; // DMA mode 0 follows buffer occupancy, without the interrupt delay

  // Transmitter pin
  assign SOUTbit = txsr[11]; // transmit most significant bit
  assign SOUT    = loop ? 1 : (LCR[6] ? '0 : SOUTbit); // tied to 1 during loopback or 0 during break

  ///////////////////////////////////////////
  // interrupts
  ///////////////////////////////////////////

  assign RXerrIP = |LSR[4:1]; // LS interrupt if any of the flags are true; cleared by reading LSR
  assign rxdataavailintr = fifoenabled ? rxfifotriggered : rxdataready;
  assign THRE = fifoenabled ? (txfifoempty & ~txthredelay) : ~txhrfull;
  assign THRE_IP = THRE & ~squashTHRE_IP; // THRE_IP squashed upon reading IIR
  assign modemstatusintr = |MSR[3:0]; // set interrupt when modem pins change

  // IIR: interrupt priority (Table IV)
  // set intrID based on highest priority pending interrupt source; otherwise, no interrupt is pending
  always_comb begin
    intrpending = 1'b1;
    if      (RXerrIP & IER[2])                     intrID = 3'b011; // receiver line status
    else if (rxdataavailintr & IER[0])             intrID = 3'b010; // received data available
    else if (rxfifotimeout & fifoenabled & IER[0]) intrID = 3'b110; // character timeout
    else if (THRE_IP & IER[1])                     intrID = 3'b001; // transmitter holding register empty
    else if (modemstatusintr & IER[3])             intrID = 3'b000; // modem status
    else begin
      intrID = 3'b000;
      intrpending = 1'b0;
    end
  end
  always_ff @(posedge PCLK) INTR <= intrpending; // prevent glitches on interrupt pin

  // Side effect of reading IIR is lowering THRE_IP if most significant intr.  Writing THR raises it again
  // once THR is empty, and so does enabling it in IER (as real 16550s do, which Linux's 8250 driver checks
  // for, UART_BUG_THRE) or changing FCR[0] (8.11: the first transmitter interrupt is then immediate).
  assign setSquashTHRE_IP = ~MEMRb & (A == UART_IIR) & (intrID == 3'h1); // there's a 1-cycle delay on set squash so that THRE_IP doesn't change during the process of reading IIR (otherwise combinational loop)
  assign resetSquashTHRE_IP = thrwrite | (~MEMWb & (A == UART_DLM_IER) & ~DLAB & Din[1]) | fifomodechange;
  assign squashTHRE_IP = prevSquashTHRE_IP & ~resetSquashTHRE_IP;
  flopr #(1) squashTHRE_IPreg(PCLK, ~PRESETn, squashTHRE_IP | setSquashTHRE_IP, prevSquashTHRE_IP);

  ///////////////////////////////////////////
  // modem control logic
  ///////////////////////////////////////////

  assign loop  = MCR[4];
  assign DTRb  = ~MCR[0] | loop; // disable modem signals in loopback mode
  assign RTSb  = ~MCR[1] | loop;
  assign OUT1b = ~MCR[2] | loop;
  assign OUT2b = ~MCR[3] | loop;

  assign DLAB = LCR[7];
  assign evenparitysel  = LCR[4];
  assign stickparity    = LCR[5];
  assign fifoenabled    = FCR[0];
  assign fifodmamodesel = FCR[3];
  always_comb
    case (FCR[7:6])
      2'b00: rxfifotriggerlevel = 5'd1;
      2'b01: rxfifotriggerlevel = 5'd4;
      2'b10: rxfifotriggerlevel = 5'd8;
      2'b11: rxfifotriggerlevel = 5'd14;
    endcase

endmodule
