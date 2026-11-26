//`include "timescale.v"
//`timescale 1ps / 1ps
`include "sd_defines.h"
`define tTLH 10 //Clock rise time
`define tHL 10 //Clock fall time
`define tISU 6 //Input setup time
`define tIH 0 //Input hold time
`define tODL 14 //Output delay
`define DLY_TO_OUTP 47 //47

`define BLOCKSIZE 512
`define MEMSIZE 24643590 // 2mb block
`define BLOCK_BUFFER_SIZE 1
`define TIME_BUSY 512

`define PRG 7
`define RCV 6
`define DATAS 5
`define TRAN 4

module    cvw_sdModel
  (
  input       sdClk,
  inout tri1       cmd,
  inout tri1 [3:0] dat
  );
   //parameter SD_FILE = "ramdisk2.hex";

  reg        oeCmd;
  reg        oeDat;
  reg        cmdOut;
  reg [3:0]  datOut;
  reg [10:0] transf_cnt;
  reg [10:0] BLOCK_WIDTH;

  reg [5:0]  lastCMD;
  reg        cardIdentificationState;
  reg        CardTransferActive;
  reg [2:0]  BusWidth;

  assign cmd = oeCmd ? cmdOut : 1'bz;
  assign dat = oeDat ? datOut : 4'bz;

  reg        InbuffStatus;
  reg [32:0] ByteAddr;
  reg [7:0]  Inbuff [0:511];
  reg [7:0]  FLASHmem [logic[32:0]];
  reg [7:0]  wide_data [0:63];

  reg [46:0] inCmd;
  reg [5:0]  cmdRead;
  reg [7:0]  cmdWrite;
  reg        crcIn;
  reg        crcEn;
  reg        crcRst;
  reg [31:0] CardStatus;
  reg [15:0] RCA;
  reg [31:0] OCR;
  reg [120:0] CID;
  reg [120:0] CSD;
  reg         Busy; //0 when busy
  wire [6:0]  crcOut;
  reg [4:0]   crc_c;

  reg [3:0]   CurrentState;
  reg [3:0]   DataCurrentState;

`define RCASTART 16'h2000
`define OCRSTART 32'h40ff8000 // SDHC
`define STATUSSTART 32'h0
`define CIDSTART 128'hffffffddddddddaaaaaaaa99999999  //Just some random data not really useful anyway
`define CSDSTART 128'hadaeeeddddddddaaaaaaaa12345678

`define outDelay 4
  reg [2:0]   outDelayCnt;
  reg [9:0]   flash_write_cnt;
  reg [8:0]   flash_blockwrite_cnt;

  parameter SIZE = 10;
  parameter CONTENT_SIZE = 40;
  parameter
    IDLE   =  10'b0000_0000_01,
    READ_CMD       =  10'b0000_0000_10,
    ANALYZE_CMD    =  10'b0000_0001_00,
    SEND_CMD       =  10'b0000_0010_00;
  reg [SIZE-1:0] state;
  reg [SIZE-1:0] next_state;

  parameter
    DATA_IDLE   =10'b0000_0000_01,
    READ_WAITS  =10'b0000_0000_10,
    READ_DATA   =10'b0000_0001_00,
    WRITE_FLASH =10'b0000_0010_00,
    WRITE_DATA  =10'b0000_0100_00;
  parameter okcrctoken = 4'b0101;
  parameter invalidcrctoken = 4'b1111;
  reg [SIZE-1:0] dataState;
  reg [SIZE-1:0] next_datastate;

  reg   ValidCmd;
  reg   inValidCmd;

  reg [7:0]   response_S;
  reg [135:0] response_CMD;
  integer     responseType;

  reg [9:0] block_cnt;
  reg       wptr;
  reg       crc_ok;
  reg [3:0] last_din;

  reg         crcDat_rst;
  reg         mult_read;
  reg         mult_write;
  reg         crcDat_en;
  reg [3:0]   crcDat_in;
  wire [15:0] crcDat_out [3:0];

  integer sdModel_file_desc;

  genvar i;
    for(i=0; i<4; i=i+1) begin:CRC_16_gen
    cvw_sd_crc_16 CRC_16_i (crcDat_in[i],crcDat_en, sdClk, crcDat_rst, crcDat_out[i]);
    end

  cvw_sd_crc_7 crc_7
    (
      crcIn,
      crcEn,
      sdClk,
      crcRst,
      crcOut
    );

  reg stop;

  reg appendCrc;
  reg [31:0] startUppCnt;

  reg q_start_bit;

   //Card initialization DAT contents
   //initial $readmemh(SD_FILE, FLASHmem);

  initial begin
    wide_data[0] <= 'h00;
    wide_data[1] <= 'hc8;
    wide_data[2] <= 'h80;
    wide_data[3] <= 'h01;
    wide_data[4] <= 'h80;
    wide_data[5] <= 'h01;
    wide_data[6] <= 'h80;
    wide_data[7] <= 'h01;
    wide_data[8] <= 'h80;
    wide_data[9] <= 'h01;
    wide_data[10] <= 'hc0;
    wide_data[11] <= 'h01;
    wide_data[12] <= 'h80;
    wide_data[13] <= 'h03;
    wide_data[14] <= 'h00;
    wide_data[15] <= 'h00;
    wide_data[16] <= 'h01;
    wide_data[17] <= 00;
    wide_data[18] <= 00;
    wide_data[19] <= 00;
    wide_data[20] <= 00;
    wide_data[21] <= 00;
    wide_data[22] <= 00;
    wide_data[23] <= 00;
    wide_data[24] <= 00;
    wide_data[25] <= 00;
    wide_data[26] <= 00;
    wide_data[27] <= 00;
    wide_data[28] <= 00;
    wide_data[29] <= 00;
    wide_data[30] <= 00;
    wide_data[31] <= 00;
    wide_data[32] <= 00;
    wide_data[33] <= 00;
    wide_data[34] <= 00;
    wide_data[35] <= 00;
    wide_data[36] <= 00;
    wide_data[37] <= 00;
    wide_data[38] <= 00;
    wide_data[39] <= 00;
    wide_data[40] <= 00;
    wide_data[41] <= 00;
    wide_data[42] <= 00;
    wide_data[43] <= 00;
    wide_data[44] <= 00;
    wide_data[45] <= 00;
    wide_data[46] <= 00;
    wide_data[47] <= 00;
    wide_data[48] <= 00;
    wide_data[49] <= 00;
    wide_data[50] <= 00;
    wide_data[51] <= 00;
    wide_data[52] <= 00;
    wide_data[53] <= 00;
    wide_data[54] <= 00;
    wide_data[55] <= 00;
    wide_data[56] <= 00;
    wide_data[57] <= 00;
    wide_data[58] <= 00;
    wide_data[59] <= 00;
    wide_data[60] <= 00;
    wide_data[61] <= 00;
    wide_data[62] <= 00;
    wide_data[63] <= 00;
/* -----\/----- EXCLUDED -----\/-----
    wide_data[0] <= 00;
    wide_data[1] <= 20;
    wide_data[2] <= 80;
    wide_data[3] <= 01;
    wide_data[4] <= 80;
    wide_data[5] <= 01;
    wide_data[6] <= 80;
    wide_data[7] <= 01;
    wide_data[8] <= 80;
    wide_data[9] <= 01;
    wide_data[10] <= 80;
    wide_data[11] <= 01;
    wide_data[12] <= 80;
    wide_data[13] <= 03;
    wide_data[14] <= 00;
    wide_data[15] <= 00;
    wide_data[16] <= 01;
    wide_data[17] <= 00;
    wide_data[18] <= 00;
    wide_data[19] <= 00;
    wide_data[20] <= 00;
    wide_data[21] <= 00;
    wide_data[22] <= 00;
    wide_data[23] <= 00;
    wide_data[24] <= 00;
    wide_data[25] <= 00;
    wide_data[26] <= 00;
    wide_data[27] <= 00;
    wide_data[28] <= 00;
    wide_data[29] <= 00;
    wide_data[30] <= 00;
    wide_data[31] <= 00;
    wide_data[32] <= 00;
    wide_data[33] <= 00;
    wide_data[34] <= 00;
    wide_data[35] <= 00;
    wide_data[36] <= 00;
    wide_data[37] <= 00;
    wide_data[38] <= 00;
    wide_data[39] <= 00;
    wide_data[40] <= 00;
    wide_data[41] <= 00;
    wide_data[42] <= 00;
    wide_data[43] <= 00;
    wide_data[44] <= 00;
    wide_data[45] <= 00;
    wide_data[46] <= 00;
    wide_data[47] <= 00;
    wide_data[48] <= 00;
    wide_data[49] <= 00;
    wide_data[50] <= 00;
    wide_data[51] <= 00;
    wide_data[52] <= 00;
    wide_data[53] <= 00;
    wide_data[54] <= 00;
    wide_data[55] <= 00;
    wide_data[56] <= 00;
    wide_data[57] <= 00;
    wide_data[58] <= 00;
    wide_data[59] <= 00;
    wide_data[60] <= 00;
    wide_data[61] <= 00;
    wide_data[62] <= 00;
    wide_data[63] <= 00;
-----/\----- EXCLUDED -----/\----- */
  end



  integer   k;

  reg qCmd;
  reg [2:0] crcCnt;

  reg      add_wrong_cmd_crc;
  reg      add_wrong_cmd_indx;
  reg      add_wrong_data_crc;

  initial begin
    add_wrong_data_crc<=0;
    add_wrong_cmd_indx<=0;
    add_wrong_cmd_crc<=0;
    stop<=1;
    cardIdentificationState<=1;
    state<=IDLE;
    dataState<=DATA_IDLE;
    Busy<=0;
    oeCmd<=0;
    crcCnt<=0;
    CardTransferActive<=0;
    qCmd<=1;
    oeDat<=0;
    cmdOut<=0;
    cmdWrite<=0;
    InbuffStatus<=0;
    datOut<=0;
    inCmd<=0;
    BusWidth<=1;
    responseType=0;
    mult_read=0;
    mult_write=0;
    crcIn<=0;
    response_S<=0;
    crcEn<=0;
    crcRst<=0;
    cmdRead<=0;
    ValidCmd<=0;
    inValidCmd=0;
    appendCrc<=0;
    RCA<= `RCASTART;
    OCR<= `OCRSTART;
    CardStatus <= `STATUSSTART;
    CID<=`CIDSTART;
    CSD<=`CSDSTART;
    response_CMD<=0;
    outDelayCnt<=0;
    crcDat_rst<=1;
    crcDat_en<=0;
    crcDat_in<=0;
    transf_cnt<=0;
    ByteAddr<=0;
    block_cnt <=0;
    wptr<=0;
    transf_cnt<=0;
    crcDat_rst<=1;
    crcDat_en<=0;
    crcDat_in<=0;
    flash_write_cnt<=0;
    startUppCnt<=0;
    flash_blockwrite_cnt<=0;
  end

   //CARD logic

  always @ (state or cmd or cmdRead or ValidCmd or inValidCmd or cmdWrite or outDelayCnt)
    begin : FSM_COMBO
      next_state  = 0;
      case(state)
        IDLE: begin
          if (!cmd)
            next_state = READ_CMD;
          else
            next_state = IDLE;
        end
        READ_CMD: begin
          if (cmdRead>= 47)
            next_state = ANALYZE_CMD;
          else
            next_state =  READ_CMD;
        end
        ANALYZE_CMD: begin
          if ((ValidCmd  )   & (outDelayCnt >= `outDelay )) // outDelayCnt >= 4 (NCR)
            next_state = SEND_CMD;
          else if (inValidCmd)
            next_state =  IDLE;
          else
            next_state =  ANALYZE_CMD;
        end
        SEND_CMD: begin
          if (cmdWrite>= response_S)
            next_state = IDLE;
          else
            next_state =  SEND_CMD;
        end

      endcase
    end

  always @ (dataState or CardStatus or crc_c or flash_write_cnt or dat[0] )
    begin : FSM_COMBODAT
      next_datastate  = 0;
      case(dataState)
        DATA_IDLE: begin
          if ((CardStatus[12:9]==`RCV) |  (mult_write == 1'b1) )
            next_datastate = READ_WAITS;
          else if ((CardStatus[12:9]==`DATAS )|  (mult_read == 1'b1) )
            next_datastate = WRITE_DATA;
          else
            next_datastate = DATA_IDLE;
        end

        READ_WAITS: begin
          if ( dat[0] == 1'b0 )
            next_datastate =  READ_DATA;
          else
            next_datastate =  READ_WAITS;
        end

        READ_DATA : begin
          if (crc_c==0  )
            next_datastate =  WRITE_FLASH;
          else begin
            if (stop == 1'b0)
              next_datastate =  READ_DATA;
            else
              next_datastate =  DATA_IDLE;
            end
        end

        WRITE_FLASH : begin
          if (flash_write_cnt>265 )
            next_datastate =  DATA_IDLE;
          else
            next_datastate =  WRITE_FLASH;
        end

        WRITE_DATA : begin
          if (transf_cnt >= BLOCK_WIDTH) // transf_cnt >= 1044
            next_datastate= DATA_IDLE;
          else
            begin
              if (stop == 1'b0)
                next_datastate=WRITE_DATA;
              else
                next_datastate =  DATA_IDLE;
            end
        end

      endcase
  end

  always @ (posedge sdClk  )
    begin
      q_start_bit <= dat[0];
    end

  always @ (posedge sdClk  )
    begin : FSM_SEQ
      state <= next_state;
    end

  always @ (posedge sdClk  )
    begin : FSM_SEQDAT
      dataState <= next_datastate;
    end

  always @ (posedge sdClk) begin
    if (CardTransferActive) begin
      if (InbuffStatus==0) //empty
        CardStatus[8]<=1;
      else
        CardStatus[8]<=0;
      end
      else
        CardStatus[8]<=1;
        startUppCnt<=startUppCnt+1;
        OCR[31]<=Busy; // THERE IS NO TILDA "OCR[31]<=~BUSY", BUSY is OCR[31]
        if (startUppCnt == `TIME_BUSY) // startUppCnt == 63 (counts until ACMD41 valid)
          Busy <=1;
  end // always @ (posedge sdClk)


  always @ (posedge sdClk) begin
    qCmd<=cmd;
  end

   //read data and cmd on rising edge
  always @ (posedge sdClk) begin
    case(state)
      IDLE: begin
        mult_write <= 0;
        mult_read <=0;
        crcIn<=0;
        crcEn<=0;
        crcRst<=1;
        oeCmd<=0;
        stop<=0;
        cmdRead<=0;
        appendCrc<=0;
        ValidCmd<=0;
        inValidCmd=0;
        cmdWrite<=0;
        crcCnt<=0;
        response_CMD<=0;
        response_S<=0;
        outDelayCnt<=0;
        responseType=0;
      end // case: IDLE

      READ_CMD: begin //read cmd
        crcEn<=1;
        crcRst<=0;
        crcIn <= #`tIH qCmd; // tIH 0
        inCmd[47-cmdRead]  <= #`tIH qCmd;    // tIH 0
        cmdRead <= cmdRead+1;
        if (cmdRead >= 40)
          crcEn<=0;
        if (cmdRead == 46) begin
          oeCmd<=1;
          cmdOut<=1;
        end
      end // case: READ_CMD

      ANALYZE_CMD: begin//check for valid cmd
        //Wrong CRC go idle
        if (inCmd[46] == 0) //start
          inValidCmd=1;
        else if (inCmd[7:1] != crcOut) begin
          inValidCmd=1;
          $fdisplay(sdModel_file_desc, "**sd_Model Command Packet - CRC Error") ;
          $display(sdModel_file_desc, "**sd_Model Command Packet - CRC Error") ;
        end
        else if  (inCmd[0] != 1)  begin//stop
          inValidCmd=1;
          $fdisplay(sdModel_file_desc, "**sd_Model Command Packet - No Stop Bit Error") ;
          $display(sdModel_file_desc, "**sd_Model Command Packet - No Stop Bit Error") ;
        end
        else begin
          if(outDelayCnt ==0 )
            CardStatus[3]<=0; // AKE_SEQ_ERROR = no error in sequence of authentication process, until I say otherwise
          case(inCmd[45:40])
            0 : response_S <= 0; // GO_IDLE_STATE
            2 : response_S <= 136; //ALL_SEND_CARD_ID (CID)
            3 : response_S <= 48; //SEND_RELATIVE_CARD_ADDRESS (RCA)
            7 : response_S <= 48; // SELECT_CARD
            8 : response_S <= 48; // SEND_INTERFACE_CONDITION (IC)
            9 : response_S <= 136; // SEND_CARD_SPECIFIC_DATA (CSD)
            14 : response_S <= 0; // reserved (why is this even here?)
            16 : response_S <= 48; // SET_BLOCK_LENGTH (Does nothing for SDHC/SDXC)
            17 : response_S <= 48; // READ_SINGLE_BLOCK of data from card
            18 : response_S <= 48; // READ_MULTIPLE_BLOCKS of data from card
            24 : response_S <= 48; // WRITE_BLOCK of data to card
            25 : response_S <= 48; // WRITE_MULTIPLE_BLOCKS of data to card
            33 : response_S <= 48; // ERASE_WR_BLK_END
            55 : response_S <= 48; // APP_CMD
            41 : response_S <= 48; // CMD41 - SD_SEND_OCR
          endcase // case (inCmd[45:40])

          case(inCmd[45:40])
            0 : begin // GO_IDLE_STATE
              response_CMD <= 0;
              cardIdentificationState<=1;
              ResetCard;
            end
            2 : begin //ALL_SEND_CARD_ID (CID)
              if (lastCMD != 41 & outDelayCnt==0) begin
                $fdisplay(sdModel_file_desc, "**Error in sequence, ACMD 41 should precede 2 in Start-up state") ;
                //$display(sdModel_file_desc, "**Error in sequence, ACMD 41 should precede 2 in Start-up state") ;
                CardStatus[3]<=1; // AKE_SEQ_ERROR = ERROR in sequence of authentication process
              end
              response_CMD[127:8] <= CID;
              appendCrc<=0;
              CardStatus[12:9] <=2;
            end
            3 :  begin //SEND_RELATIVE_CARD_ADDRESS (RCA)
              if (lastCMD != 2 & outDelayCnt==0 ) begin
                $fdisplay(sdModel_file_desc, "**Error in sequence, CMD 2 should precede 3 in Start-up state") ;
                //$display(sdModel_file_desc, "**Error in sequence, CMD 2 should precede 3 in Start-up state") ;
                CardStatus[3]<=1; // AKE_SEQ_ERROR = ERROR in sequence of authentication process
              end
              response_CMD[127:112] <= RCA[15:0] ;
              response_CMD[111:96] <= CardStatus[15:0] ;
              appendCrc<=1;
              CardStatus[12:9] <=3;
              cardIdentificationState<=0;
            end
            6 : begin
              if (lastCMD == 55 & outDelayCnt==0) begin //ACMD6 - SET_BUS_WIDTH
                if (inCmd[9:8] == 2'b10) begin
                  BusWidth <=4;
                  $display(sdModel_file_desc, "**BUS WIDTH 4 ") ;
                end
                else
                  BusWidth <=1;
                  response_S<=48;
                  response_CMD[127:96] <= CardStatus;
                end
              else if (outDelayCnt==0) begin //CMD6 - SWITCH_CARD_FUNCTION (Clock speed)
                if (CardStatus[12:9] == `TRAN) begin //If card is in transfer state
                  CardStatus[12:9] <=`DATAS;//Put card in data state
                  response_CMD[127:96] <= CardStatus ;
                  response_S<=48;
                  BLOCK_WIDTH <= 11'd148;
                  $fdisplay(sdModel_file_desc, "**Error Invalid CMD, %h",inCmd[45:40]);
                  $display(sdModel_file_desc, "**Error Invalid CMD, %h",inCmd[45:40]);
                end
                else begin
                  response_S <= 0;
                  response_CMD[127:96] <= 0;
                  $fdisplay(sdModel_file_desc, "**Error Invalid CMD, %h, card not in transfer state",inCmd[45:40]);
                  $display(sdModel_file_desc,  "**Error Invalid CMD, %h, card not in transfer state",inCmd[45:40]);
                end // else: !if(CardStatus[12:9] == `TRAN)
              end // if (outDelayCnt==0)
            end // case: 6

            7: begin // SELECT_CARD
              if (outDelayCnt==0) begin
                if (inCmd[39:24]== RCA[15:0]) begin
                  CardTransferActive <= 1;
                  response_CMD[127:96] <= CardStatus ;
                  CardStatus[12:9] <=`TRAN;
                end
                else begin
                  CardTransferActive <= 0;
                  response_CMD[127:96] <= CardStatus ;
                  CardStatus[12:9] <=3;
                end
              end
            end // case: 7

            8 : begin // SEND_INTERFACE_CONDITION (IC)
              response_CMD[127:96] <= {20'h00000 , inCmd[19:8]}; //not supported by V1.0 card
              response_S<=48;

              $fdisplay(sdModel_file_desc, "**Warning Unofficially Supported CMD, %h",inCmd[45:40]);
              $display(sdModel_file_desc, "**Warning Unofficially Supported CMD, %h",inCmd[45:40]);
            end

            9 : begin // SEND_CARD_SPECIFIC_DATA (CSD)
              if (lastCMD != 41 & outDelayCnt==0) begin
                $fdisplay(sdModel_file_desc, "**Error in sequence, ACMD 41 should precede 9 in Start-up state") ;
                //$display(sdModel_file_desc, "**Error in sequence, ACMD 41 should precede 9 in Start-up state") ;
                CardStatus[3]<=1; // AKE_SEQ_ERROR = ERROR in sequence of authentication process
              end
              response_CMD[127:8] <= CSD;
              appendCrc<=0;
              CardStatus[12:9] <=2;
            end

            12: begin // STOP_TRANSMISSION
              response_CMD[127:96] <= CardStatus ;
              stop<=1;
              mult_write <= 0;
              mult_read <=0;
              CardStatus[12:9] <= `TRAN;
            end

            16 : begin // SET_BLOCK_LENGTH (Does nothing for SDHC/SDXC)
              response_CMD[127:96] <= CardStatus ;
            end

            17 :  begin // READ_SINGLE_BLOCK of data from card
              if (outDelayCnt==0) begin
                if (CardStatus[12:9] == `TRAN) begin //If card is in transfer state
                  CardStatus[12:9] <=`DATAS;//Put card in data state
                  response_CMD[127:96] <= CardStatus ;
                  BLOCK_WIDTH <= 11'd1044;
                  ByteAddr = inCmd[39:8] << 9;
                  if (ByteAddr%512 !=0)
                    $display("**Block Misalign Error");
                end
                else begin
                  response_S <= 0;
                  response_CMD[127:96] <= 0;
                end
              end
            end

            18 :  begin // READ_MULTIPLE_BLOCKS of data from card
              if (outDelayCnt==0) begin
                if (CardStatus[12:9] == `TRAN) begin //If card is in transfer state
                  CardStatus[12:9] <=`DATAS;//Put card in data state
                  response_CMD[127:96] <= CardStatus ;
                  mult_read <= 1;
                  ByteAddr = inCmd[39:8] << 9;
                  if (ByteAddr%512 !=0)
                    $display("**Block Misalign Error");
                end
                else begin
                  response_S <= 0;
                  response_CMD[127:96] <= 0;
                end
              end
            end

            24 : begin // WRITE_BLOCK of data to card
              if (outDelayCnt==0) begin
                if (CardStatus[12:9] == `TRAN) begin //If card is in transfer state
                  if (CardStatus[8]) begin //If Free write buffer
                    CardStatus[12:9] <=`RCV;//Put card in Rcv state
                    response_CMD[127:96] <= CardStatus ;
                    ByteAddr = inCmd[39:8] << 9;
                    if (ByteAddr%512 !=0)
                      $display("**Block Misalign Error");
                  end
                  else begin
                    response_CMD[127:96] <= CardStatus;
                    $fdisplay(sdModel_file_desc, "**Error Try to blockwrite when No Free Writebuffer") ;
                    $display("**Error Try to blockwrite when No Free Writebuffer") ;
                  end
                end
                else begin
                  response_S <= 0;
                  response_CMD[127:96] <= 0;
                end
              end
            end // case: 24

            25 : begin // WRITE_MULTIPLE_BLOCKS of data to card
              if (outDelayCnt==0) begin
                if (CardStatus[12:9] == `TRAN) begin //If card is in transfer state
                  if (CardStatus[8]) begin //If Free write buffer
                    CardStatus[12:9] <=`RCV;//Put card in Rcv state
                    response_CMD[127:96] <= CardStatus ;
                    ByteAddr = inCmd[39:8] << 9;
                    mult_write <= 1;
                    if (ByteAddr%512 !=0)
                      $display("**Block Misalign Error");
                  end
                  else begin
                    response_CMD[127:96] <= CardStatus;
                    $fdisplay(sdModel_file_desc, "**Error Try to blockwrite when No Free Writebuffer") ;
                    $display("**Error Try to blockwrite when No Free Writebuffer") ;
                  end // else: !if(CardStatus[8])
                end // if (CardStatus[12:9] == `TRAN)
                else begin
                  response_S <= 0;
                  response_CMD[127:96] <= 0;
                end // else: !if(CardStatus[12:9] == `TRAN)
              end // if (outDelayCnt==0)
            end // case: 25

            33 : response_CMD[127:96] <= 48; // ERASE_WR_BLK_END

            55 :
              begin // APP_CMD
                response_CMD[127:96] <= CardStatus ;
                CardStatus[5] <=1;      //Next CMD is AP specific CMD
                appendCrc<=1;
              end

            41 : // CMD41 - SD_SEND_OCR
              begin
                if (cardIdentificationState) begin
                  if (lastCMD != 55 & outDelayCnt==0) begin // CMD41 - Reserved/Invalid
                    $fdisplay(sdModel_file_desc, "**Error in sequence, CMD 55 should precede 41 in Start-up state") ;
                    $display( "**Error in sequence, CMD 55 should precede 41 in Start-up state") ;
                    CardStatus[3]<=1; // AKE_SEQ_ERROR = ERROR in sequence of authentication process
                  end
                  else begin // CMD41 - SD_SEND_OCR
                    responseType=3;
                    response_CMD[127:96] <= OCR;
                    appendCrc<=0;
                    CardStatus[5] <=0;  // not expecting next command to be ACMD
                    if (Busy==1)
                      CardStatus[12:9] <=1; // READY
                  end // else: !if(lastCMD != 55 & outDelayCnt==0)
                end // if (cardIdentificationState)
              end // case: 41
          endcase // case (inCmd[45:40])

          ValidCmd<=1;
          crcIn<=0;

          outDelayCnt<=outDelayCnt+1;
          if (outDelayCnt==`outDelay)       // if (outDelayCnt == 4)
            crcRst<=1;

          oeCmd<=1;
          cmdOut<=1;
          response_CMD[135:134] <=0; // Start bit = 0, tx bit = 0 (response from card)

          // for those who aren't keeping track, we are still in 'else: !if(inCmd[0] != 1)'
          if (responseType != 3)
            if (!add_wrong_cmd_indx)
              response_CMD[133:128] <=inCmd[45:40];
            else
              response_CMD[133:128] <=0;

          if (responseType == 3)
            response_CMD[133:128] <=6'b111111;

          lastCMD <=inCmd[45:40];
        end // else: !if(inCmd[0] != 1)
      end // case: ANALYZE_CMD
    endcase // case (state)
  end // always @ (posedge sdClk)

  always @ ( negedge sdClk) begin
    case(state)

      SEND_CMD: begin
        crcRst<=0;
        crcEn<=1;
        cmdWrite<=cmdWrite+1;
        if (response_S!=0)
          cmdOut<=0;
        else
          cmdOut<=1;

        if ((cmdWrite>0) &  (cmdWrite < response_S-8)) begin
          cmdOut<=response_CMD[135-cmdWrite];
          crcIn<=response_CMD[134-cmdWrite];
          if (cmdWrite >= response_S-9)
            crcEn<=0;
        end
        else if (cmdWrite!=0) begin
          crcEn<=0;
          if (add_wrong_cmd_crc) begin
            cmdOut<=0;
            crcCnt<=crcCnt+1;
          end
          else begin
            cmdOut<=crcOut[6-crcCnt];
            crcCnt<=crcCnt+1;
            if (responseType == 3)
              cmdOut<=1;
          end
        end // if (cmdWrite!=0)
        if (cmdWrite == response_S-1)
          cmdOut<=1;
      end // case: SEND_CMD
    endcase // case (state)
  end // always @ ( negedge sdClk)

  integer outdly_cnt;

  always @ (posedge sdClk) begin // Read DATA from host on positive clock edge
    case (dataState)
      DATA_IDLE: begin
        crcDat_rst<=1;
        crcDat_en<=0;
        crcDat_in<=0;
      end

      READ_WAITS: begin
        oeDat<=0;
        crcDat_rst<=0;
        crcDat_en<=1;
        crcDat_in<=0;
        crc_c<=15;//
        crc_ok<=1;
      end

      READ_DATA: begin
        InbuffStatus<=1;
        if (transf_cnt<`BIT_BLOCK_REC) begin
          if (wptr)
            Inbuff[block_cnt][3:0] <= dat;
          else
            Inbuff[block_cnt][7:4] <= dat;

          if (!add_wrong_data_crc)
            crcDat_in<=dat;
          else
            crcDat_in<=4'b1010;

          crc_ok<=1;
          transf_cnt<=transf_cnt+1;
          if (wptr)
            block_cnt<=block_cnt+1;
            wptr<=~wptr;
        end // if (transf_cnt<`BIT_BLOCK_REC)

        else if  ( transf_cnt <= (`BIT_BLOCK_REC +`BIT_CRC_CYCLE-1)) begin
          transf_cnt<=transf_cnt+1;
          crcDat_en<=0;
          last_din <=dat;

          if (transf_cnt> `BIT_BLOCK_REC) begin
            crc_c<=crc_c-1;

            if (crcDat_out[0][crc_c] != last_din[0])
              crc_ok<=0;
            if  (crcDat_out[1][crc_c] != last_din[1])
              crc_ok<=0;
            if  (crcDat_out[2][crc_c] != last_din[2])
              crc_ok<=0;
            if  (crcDat_out[3][crc_c] != last_din[3])
              crc_ok<=0;
          end // if (transf_cnt> `BIT_BLOCK_REC)
        end // if ( transf_cnt <= (`BIT_BLOCK_REC +`BIT_CRC_CYCLE-1))
      end // case: READ_DATA

      WRITE_FLASH: begin
        oeDat<=1;
        block_cnt <=0;
        wptr<=0;
        transf_cnt<=0;
        crcDat_rst<=1;
        crcDat_en<=0;
        crcDat_in<=0;
      end

    endcase // case (dataState)

  end // always @ (posedge sdClk)

  reg data_send_index;
  integer write_out_index;
  always @ (negedge sdClk) begin // Write DATA to Host on negative clock edge

    case (dataState)
      DATA_IDLE: begin
        write_out_index<=0;
        transf_cnt<=0;
        data_send_index<=0;
        outdly_cnt<=0;
        flash_write_cnt<=0;
      end

      WRITE_DATA: begin
        oeDat<=1;
        outdly_cnt<=outdly_cnt+1;
        datOut <= 4'b1111; // listen... until I tell you otherwise, DAT bus is all high (thanks Rose)


        if ( outdly_cnt > `DLY_TO_OUTP) begin // if (outdly_cnt > 47) NAC cycles elapsed
          transf_cnt <= transf_cnt+1; // start counting bits transferred
          crcDat_en<=1; // Enable CRC16
          crcDat_rst<=0; // Stop reset of CRC16
          oeDat<=1;   // Enable output
        end

        else begin // NAC cycles have not elapsed
          crcDat_en<=0; // Disable CRC16 generation
          crcDat_rst<=1; // Reset CRC16 generators
          oeDat<=0;   // Do NOT enable output (I REALLY DO AGREE WITH THIS!)
          crc_c<=16; // point to bit 16 of CRC16
        end // else: !if( outdly_cnt > `DLY_TO_OUTP)

        if (transf_cnt==1) begin  // first nibble
          if (BLOCK_WIDTH == 11'd1044) begin
            last_din <= FLASHmem[ByteAddr+(write_out_index)][7:4]; // LOAD register with upper nibble
            crcDat_in<= FLASHmem[ByteAddr+(write_out_index)][7:4];  // LOAD CRC16 with upper nibble
          end
          else begin
            // code for wide width data
            last_din <= wide_data[write_out_index][7:4];
            crcDat_in <= wide_data[write_out_index][7:4];
          end
          datOut<=0; // Send nothing yet
          data_send_index<=1; // Next nibble is lower nibble
        end

        else if ( (transf_cnt>=2) & (transf_cnt<=BLOCK_WIDTH -`CRC_OFF )) begin  // if (2 <= transf_cnt <= 1025)
          data_send_index<=~data_send_index; //toggle
          if (!data_send_index) begin //upper nibble
            if (BLOCK_WIDTH == 11'd1044) begin
              last_din <= FLASHmem[ByteAddr+(write_out_index)][7:4]; // LOAD register with upper nibble
              crcDat_in<= FLASHmem[ByteAddr+(write_out_index)][7:4];  // LOAD CRC16 with upper nibble
            end
            else begin
              // code for wide width data
              last_din <= wide_data[write_out_index][7:4];
              crcDat_in <= wide_data[write_out_index][7:4];
            end
          end // if (!data_send_index)
          else begin //lower nibble
            if (BLOCK_WIDTH == 11'd1044) begin
              last_din<=FLASHmem[ByteAddr+(write_out_index)][3:0];
            end
            else begin
              last_din <= wide_data[write_out_index][3:0];
            end
            if (!add_wrong_data_crc)
              if (BLOCK_WIDTH == 11'd1044) begin
                crcDat_in<= FLASHmem[ByteAddr+(write_out_index)][3:0];
              end
              else begin
                crcDat_in <= wide_data[write_out_index][3:0];
              end
            else // SNAFU
              crcDat_in<=4'b1010;
              write_out_index<=write_out_index+1; // Having sent the lower nibble, increment the byte counter

          end // else: !if(!data_send_index)

          datOut<= last_din; // output content of register


          if ( transf_cnt >=BLOCK_WIDTH-`CRC_OFF ) begin // if (trans_cnt >= 1025)
            crcDat_en<=0;                              // Disable CRC16 Generators
          end
        end // if ( (transf_cnt>=2) & (transf_cnt<=`BIT_BLOCK-`CRC_OFF ))

        else if (transf_cnt>BLOCK_WIDTH-`CRC_OFF & crc_c!=0) begin // if ((transf_cnt > 1025) and (crc_c /= 0))
          datOut<= last_din; // if sent all data bitsbut not crc16 bits yet
          crcDat_en<=0; // Disable CRC16 generators
          crc_c<=crc_c-1; // point to next bit of CRC16 to begin transmission of CRC16
          if (crc_c<= 16) begin // begin sending CRC16 (16 downto 1)
            datOut[0]<=crcDat_out[0][crc_c-1];
            datOut[1]<=crcDat_out[1][crc_c-1];
            datOut[2]<=crcDat_out[2][crc_c-1];
            datOut[3]<=crcDat_out[3][crc_c-1];
          end

        end // if (transf_cnt>`BIT_BLOCK-`CRC_OFF & crc_c!=0)
        else if (transf_cnt==BLOCK_WIDTH-2) begin     // if (transf_cnt = 1042) Last CRC16 bit is 1041
          datOut<=4'b1111;          // send end bits
        end
        else if ((transf_cnt !=0) & (crc_c == 0 ))begin // if sent data bits and crc_c points past last bit of CRC
          oeDat<=0; // disable output on DAT bus
          CardStatus[12:9] <= `TRAN; // put card in transfer state
        end

      end // case: WRITE_DATA


      WRITE_FLASH: begin
        flash_write_cnt<=flash_write_cnt+1;
        CardStatus[12:9] <= `PRG;
        datOut[0]<=0;
        datOut[1]<=1;
        datOut[2]<=1;
        datOut[3]<=1;
        if (flash_write_cnt == 0)
          datOut<=1;
        else if(flash_write_cnt == 1)
          datOut[0]<=1;
        else if(flash_write_cnt == 2)
          datOut[0]<=0;
        else if ((flash_write_cnt > 2) & (flash_write_cnt < 7)) begin
          if (crc_ok)
            datOut[0] <=okcrctoken[6-flash_write_cnt];
          else
            datOut[0] <= invalidcrctoken[6-flash_write_cnt];
        end
        else if  ((flash_write_cnt >= 7) & (flash_write_cnt < 264)) begin
          datOut[0]<=0;
          flash_blockwrite_cnt<=flash_blockwrite_cnt+2;
          FLASHmem[ByteAddr+(flash_blockwrite_cnt)]=Inbuff[flash_blockwrite_cnt];
          FLASHmem[ByteAddr+(flash_blockwrite_cnt+1)]=Inbuff[flash_blockwrite_cnt+1];
        end
        else begin
            datOut<=1;
            InbuffStatus<=0;
            CardStatus[12:9] <= `TRAN;
        end // else: !if((flash_write_cnt >= 7) & (flash_write_cnt < 264))
      end // case: WRITE_FLASH
    endcase // case (dataState)
  end // always @ (negedge sdClk)

  initial
    begin
      sdModel_file_desc = $fopen("sd_model.log");
      if (sdModel_file_desc < 2) begin
        $display("*E Could not open/create testbench log file in /log/ directory!");
        $finish;
      end
    end

  task ResetCard; //  MAC registers
    begin
      add_wrong_data_crc<=0;
      add_wrong_cmd_indx<=0;
      add_wrong_cmd_crc<=0;
      cardIdentificationState<=1;
      state<=IDLE;
      dataState<=DATA_IDLE;
      Busy<=0;
      oeCmd<=0;
      crcCnt<=0;
      CardTransferActive<=0;
      qCmd<=1;
      oeDat<=0;
      cmdOut<=0;
      cmdWrite<=0;
      startUppCnt<=0;
      InbuffStatus<=0;
      datOut<=0;
      inCmd<=0;
      BusWidth<=1;
      responseType=0;
      crcIn<=0;
      response_S<=0;
      crcEn<=0;
      crcRst<=0;
      cmdRead<=0;
      ValidCmd<=0;
      inValidCmd=0;
      appendCrc<=0;
      RCA<= `RCASTART;
      OCR<= `OCRSTART;
      CardStatus <= `STATUSSTART;
      CID<=`CIDSTART;
      CSD<=`CSDSTART;
      response_CMD<=0;
      outDelayCnt<=0;
      crcDat_rst<=1;
      crcDat_en<=0;
      crcDat_in<=0;
      transf_cnt<=0;
      ByteAddr<=0;
      block_cnt <=0;
      wptr<=0;
      transf_cnt<=0;
      crcDat_rst<=1;
      crcDat_en<=0;
      crcDat_in<=0;
      flash_write_cnt<=0;
      flash_blockwrite_cnt<=0;
    end
  endtask

endmodule // sdModel
