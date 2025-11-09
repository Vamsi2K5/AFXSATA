/******************************************Copyright@2025**************************************
                                    AdriftXCore  ALL rights reserved
                        https://github.com/AdriftXCore https://gitee.com/adriftxcore
=========================================FILE INFO.============================================
FILE Name       : sata_link_rdmod.sv
Last Update     : 2025/04/09 11:04:00
Latest Versions : 1.0
========================================AUTHOR INFO.===========================================
Created by      : zhanghx
Create date     : 2025/04/07 18:11:44
Version         : 1.0
Description     : SATA Link Read Module - Implements the read data path control logic for the 
                  SATA link layer. This module handles the state machine for read operations, 
                  including receiving data from the PHY layer, CRC checking, buffering data for 
                  the transport layer, and generating appropriate link layer responses.
=======================================UPDATE HISTPRY==========================================
Modified by     : 
Modified date   : 
Version         : 
Description     : 
******************************Licensed under the GPL-3.0 License******************************/
`include "sata_wrapper_define.svh"

// SATA Link Read Module
// This module handles the read data path in the SATA link layer. It receives data from the
// physical layer, performs CRC checking, buffers the data for the transport layer, and
// generates appropriate link layer responses (R_RDY, R_IP, R_OK, R_ERR).
module sata_link_rdmod #(
    parameter USER_W = 8              // User data width for AXI Stream interface
)(
    /**** clk/rst ****/
    input   logic                           clk             ,   // Main clock signal
    input   logic                           rst_n           ,   // Active-low reset signal

    /**** phy ****/
    input   logic                           phyrdy          ,   // PHY layer ready signal

    /**** arbiter ****/
    input   logic                           rd_req          ,   // Read request from link arbiter
    output  logic                           rd_cpl          ,   // Read operation completion signal
    output  logic                           rd_no_busy      ,   // Read path not busy signal

    input   logic                           roll_insert     ,   // Roll insertion request for ALIGN primitives

    // Master AXI Stream interface (to transport layer)
    output  logic       [31         :0]     m_aixs_tdata    ,   // Master data payload
    output  logic       [USER_W   -1:0]     m_aixs_tuser    ,   // Master user signals {drop,err,keep[3:0],sop,eop}
    output  logic                           m_aixs_tvalid   ,   // Master data valid signal
    input   logic                           m_aixs_tready   ,   // Master ready signal

    // Buffer status signals
    input   logic                           buffer_full     ,   // Buffer full indicator
    input   logic                           tl_ok           ,   // Transport layer OK signal
    input   logic                           tl_err          ,   // Transport layer error signal

    /**** rx link dat ****/
    // Received data from link decoder
    input   sata_p_t                        rx_dat_type     ,   // Received data type (primitive or data)
    input   logic       [32       -1:0]     rx_dat          ,   // Received data payload
    input   logic       [4        -1:0]     rx_char         ,   // Received character indicator

    /**** tx link dat ****/
    // Transmit data to link encoder
    output  sata_p_t                        tx_dat_type     ,   // Transmit data type (primitive)
    output  logic       [32       -1:0]     tx_dat          ,   // Transmit data payload
    output  logic       [4        -1:0]     tx_char         ,   // Transmit character indicator

    // Statistics counters
    output  logic       [31         :0]     ecp_cnt         ,   // ECP (Error Correction Protocol) counter
    output  logic       [31         :0]     err_cnt         ,   // Error counter
    output  logic       [32       -1:0]     tx_sop_cnt      ,   // Transmit start of packet counter
    output  logic       [32       -1:0]     tx_eop_cnt           
);

// CRC module interface signals
logic [32       -1:0] crc_data_in             ;   // CRC input data
logic                 crc_init                ;   // CRC initialization signal
logic                 crc_en                  ;   // CRC enable signal
logic [32       -1:0] crc_out                 ;   // CRC output result

// Error and status signals
logic                 nocommerr               ;   // No communication error flag
logic                 crc_check_ok            ;   // CRC check passed
logic                 crc_check_err           ;   // CRC check failed
logic                 no_sof                  ;   // No SOF (Start of Frame) primitive
logic                 no_x_rdy                ;   // No X_RDY primitive
logic                 sync_idle               ;   // SYNC primitive received (idle)

// AXI Stream control signals
logic                 m_aixs_tsop             ;   // Start of packet indicator
logic                 m_aixs_teop             ;   // End of packet indicator
logic [3          :0] m_aixs_tkeep            ;   // Byte enable signals

// Error flags
logic                 link_rd_error           ;   // Link read error flag
logic                 buffer_overflow_err     ;   // Buffer overflow error flag

// Packet processing flags
logic                 sop_flag                ;   // Start of packet flag
logic                 recv_flag               ;   // Receiving data flag

// Data ready signals
logic                 dat_rdy                 ;   // Data ready (buffer not full)
logic                 dat_unrdy               ;   // Data not ready (buffer full)

// State transition signals
logic                 idl2rcvwaitfifo_s         ;   // Transition from IDLE to RCVWAITFIFO
logic                 rcvchkrdy2rcvdata_s     ;   // Transition from RCVCHKRDY to RCVDATA
logic                 rcvchkrdy2idl_s         ;   // Transition from RCVCHKRDY to IDLE
logic                 rcvwaitfifo2rcvchkrdy_s ;   // Transition from RCVWAITFIFO to RCVCHKRDY
logic                 rcvwaitfifo2idl_s       ;   // Transition from RCVWAITFIFO to IDLE
logic                 rcvdata2hold_s          ;   // Transition from RCVDATA to HOLD
logic                 rcvdata2rcvhold_s       ;   // Transition from RCVDATA to RCVHOLD
logic                 rcvdata2rcveof_s        ;   // Transition from RCVDATA to RCVEOF
logic                 rcvdata2badend_s        ;   // Transition from RCVDATA to BADEND
logic                 rcvdata2idl_s           ;   // Transition from RCVDATA to IDLE
logic                 hold2rcvdata_s          ;   // Transition from HOLD to RCVDATA
logic                 hold2rcveof_s           ;   // Transition from HOLD to RCVEOF
logic                 hold2rcvhold_s          ;   // Transition from HOLD to RCVHOLD
logic                 hold2idl_s              ;   // Transition from HOLD to IDLE
logic                 rcvhold2rcveof_s        ;   // Transition from RCVHOLD to RCVEOF
logic                 rcvhold2rcvdata_s       ;   // Transition from RCVHOLD to RCVDATA
logic                 rcvhold2idl_s           ;   // Transition from RCVHOLD to IDLE
logic                 rcveof2goodcrc_s        ;   // Transition from RCVEOF to GOODCRC
logic                 rcveof2badend_s         ;   // Transition from RCVEOF to BADEND
logic                 rcveof2idl_s            ;   // Transition from RCVEOF to IDLE
logic                 goodcrc2goodend_s       ;   // Transition from GOODCRC to GOODEND
logic                 goodcrc2badend_s        ;   // Transition from GOODCRC to BADEND
logic                 goodcrc2idl_s           ;   // Transition from GOODCRC to IDLE
logic                 goodend2idl_s           ;   // Transition from GOODEND to IDLE
logic                 badend2idl_s            ;   // Transition from BADEND to IDLE

// Roll insertion control signals
logic                 roll_insert_r           ;   // Registered roll insert signal
logic                 roll_insert_pause       ;   // Pause operations during roll insertion

// Registered AXI Stream signals
logic                 r_m_aixs_tvalid         ;   // Registered master valid signal
logic                 is_dat_pulse            ;   // Data pulse indicator
logic                 no_dat_pulse            ;   // No data pulse indicator

logic [31         :0] r_m_aixs_tdata          ;   // Registered master data
logic [31         :0] rr_m_aixs_tdata         ;   // Double registered master data

logic                 packet_scan             ;   // Packet scanning indicator

// State machine width definition
localparam STATE_W = 10;

// State bit positions
localparam  S0_BIT      = 'd0  ,        // IDLE state bit
            S1_BIT      = 'd1  ,        // RCVCHKRDY state bit
            S2_BIT      = 'd2  ,        // RCVWAITFIFO state bit
            S3_BIT      = 'd3  ,        // RCVDATA state bit
            S4_BIT      = 'd4  ,        // HOLD state bit
            S5_BIT      = 'd5  ,        // RCVHOLD state bit
            S6_BIT      = 'd6  ,        // RCVEOF state bit
            S7_BIT      = 'd7  ,        // GOODCRC state bit
            S8_BIT      = 'd8  ,        // GOODEND state bit
            S9_BIT      = 'd9  ,        // BADEND state bit
            S10_BIT     = 'd10 ;        // Additional state bit

// State machine type definition
// S0_IDLE:           Idle state, waiting for read request
// S1_LR1_RCVCHKRDY:  Receive check ready, waiting for SOF or X_RDY
// S2_LR2_RCVWAITFIFO:Wait for buffer space to become available
// S3_LR3_RCVDATA:    Receive data from PHY
// S4_LR4_HOLD:       Send HOLD primitive when buffer is full
// S5_LR5_RCVHOLD:    Receive HOLD acknowledgment
// S6_LR6_RCVEOF:     Receive EOF and check CRC
// S7_LR7_GOODCRC:    CRC check passed, waiting for TL response
// S8_LR8_GOODEND:    Good end sequence, send R_OK
// S9_LR9_BADEND:     Bad end sequence, send R_ERR
typedef enum logic [STATE_W-1:0]{
    S0_IDLE             = STATE_W'(1) << S0_BIT    ,   // Idle state
    S1_LR1_RCVCHKRDY    = STATE_W'(1) << S1_BIT    ,   // Receive check ready state
    S2_LR2_RCVWAITFIFO  = STATE_W'(1) << S2_BIT    ,   // Receive wait for FIFO state
    S3_LR3_RCVDATA      = STATE_W'(1) << S3_BIT    ,   // Receive data state
    S4_LR4_HOLD         = STATE_W'(1) << S4_BIT    ,   // Hold state
    S5_LR5_RCVHOLD      = STATE_W'(1) << S5_BIT    ,   // Receive hold state
    S6_LR6_RCVEOF       = STATE_W'(1) << S6_BIT    ,   // Receive EOF state
    S7_LR7_GOODCRC      = STATE_W'(1) << S7_BIT    ,   // Good CRC state
    S8_LR8_GOODEND      = STATE_W'(1) << S8_BIT    ,   // Good end state
    S9_LR9_BADEND       = STATE_W'(1) << S9_BIT      // Bad end state
}state_t;

state_t state_c;    // Current state register
state_t state_n;    // Next state register

// State register - synchronous with clock and reset
always_ff@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        state_c <= S0_IDLE;
    else
        state_c <= state_n;
end

// Next state logic - combinational
always_comb begin
    case (1)
        state_c[S0_BIT]:begin //S0_IDLE - Idle state
            if(idl2rcvwaitfifo_s)
                state_n = S2_LR2_RCVWAITFIFO;
            else
                state_n = state_c;
        end
        state_c[S1_BIT]:begin //S1_LR1_RCVCHKRDY - Receive check ready
            if(rcvchkrdy2rcvdata_s)
                state_n = S3_LR3_RCVDATA;
            else if(rcvchkrdy2idl_s)
                state_n = S0_IDLE;
            else
                state_n = state_c;
        end
        state_c[S2_BIT]:begin //S2_LR2_RCVWAITFIFO - Wait for FIFO availability
            if(rcvwaitfifo2rcvchkrdy_s)
                state_n = S1_LR1_RCVCHKRDY;
            else if(rcvwaitfifo2idl_s)
                state_n = S0_IDLE;
            else
                state_n = state_c;
        end
        state_c[S3_BIT]:begin //S3_LR3_RCVDATA - Receive data
            if(rcvdata2rcvhold_s)
                state_n = S5_LR5_RCVHOLD;
            else if(rcvdata2rcveof_s)
                state_n = S6_LR6_RCVEOF;
            else if(rcvdata2badend_s)
                state_n = S9_LR9_BADEND;
            else if(rcvdata2idl_s)
                state_n = S0_IDLE;
            else if(rcvdata2hold_s)
                state_n = S4_LR4_HOLD;
            else
                state_n = state_c;
        end
        state_c[S4_BIT]:begin //S4_LR4_HOLD - Send HOLD primitive
            if(hold2rcveof_s)
                state_n = S6_LR6_RCVEOF;
            else if(hold2rcvhold_s)
                state_n = S5_LR5_RCVHOLD;
            else if(hold2idl_s)
                state_n = S0_IDLE;
            else if(hold2rcvdata_s)
                state_n = S3_LR3_RCVDATA;
            else
                state_n = state_c;
        end
        state_c[S5_BIT]:begin //S5_LR5_RCVHOLD - Receive HOLD acknowledgment
            if(rcvhold2rcveof_s)
                state_n = S6_LR6_RCVEOF;
            else if(rcvhold2idl_s)
                state_n = S0_IDLE;
            else if(rcvhold2rcvdata_s)
                state_n = S3_LR3_RCVDATA;
            else
                state_n = state_c;
        end
        state_c[S6_BIT]:begin //S6_LR6_RCVEOF - Receive EOF and check CRC
            if(rcveof2goodcrc_s)
                state_n = S7_LR7_GOODCRC;
            else if(rcveof2idl_s)
                state_n = S0_IDLE;
            else if(rcveof2badend_s)
                state_n = S9_LR9_BADEND;
            else
                state_n = state_c;
        end
        state_c[S7_BIT]:begin //S7_LR7_GOODCRC - Good CRC check
            if(goodcrc2idl_s)
                state_n = S0_IDLE;
            else if(goodcrc2goodend_s)
                state_n = S8_LR8_GOODEND;
            else if(goodcrc2badend_s)
                state_n = S9_LR9_BADEND;
            else
                state_n = state_c;
        end
        state_c[S8_BIT]:begin //S8_LR8_GOODEND - Good end sequence
            if(goodend2idl_s)
                state_n = S0_IDLE;
            else
                state_n = state_c;
        end
        state_c[S9_BIT]:begin //S9_LR9_BADEND - Bad end sequence
            if(badend2idl_s)
                state_n = S0_IDLE;
            else
                state_n = state_c;
        end
        default: begin
            state_n = S1_LR1_RCVCHKRDY;
        end
    endcase
end

// State transition conditions
assign idl2rcvwaitfifo_s        = (state_c == S0_IDLE           ) && rd_req;    
assign rcvchkrdy2rcvdata_s      = (state_c == S1_LR1_RCVCHKRDY  ) && (rx_dat_type == sof  );
assign rcvchkrdy2idl_s          = (state_c == S1_LR1_RCVCHKRDY  ) && ((no_sof && no_x_rdy) || nocommerr);
assign rcvwaitfifo2rcvchkrdy_s  = (state_c == S2_LR2_RCVWAITFIFO) && (rx_dat_type == x_rdy) && dat_rdy;
assign rcvwaitfifo2idl_s        = (state_c == S2_LR2_RCVWAITFIFO) && (no_x_rdy || nocommerr);
assign rcvdata2hold_s           = (state_c == S3_LR3_RCVDATA    ) &&  dat_unrdy;
assign rcvdata2rcvhold_s        = (state_c == S3_LR3_RCVDATA    ) && (rx_dat_type == hold);
assign rcvdata2rcveof_s         = (state_c == S3_LR3_RCVDATA    ) && (rx_dat_type == eof  );
assign rcvdata2badend_s         = (state_c == S3_LR3_RCVDATA    ) && (rx_dat_type == wtrm );
assign rcvdata2idl_s            = (state_c == S3_LR3_RCVDATA    ) && (sync_idle || nocommerr);
assign hold2rcveof_s            = (state_c == S4_LR4_HOLD       ) && (rx_dat_type == eof  );
assign hold2rcvhold_s           = (state_c == S4_LR4_HOLD       ) && dat_rdy && (rx_dat_type == hold );
assign hold2rcvdata_s           = (state_c == S4_LR4_HOLD       ) && dat_rdy && (rx_dat_type != align );
assign hold2idl_s               = (state_c == S4_LR4_HOLD       ) && (sync_idle || nocommerr);
assign rcvhold2rcveof_s         = (state_c == S5_LR5_RCVHOLD    ) && (rx_dat_type == eof  );
assign rcvhold2rcvdata_s        = (state_c == S5_LR5_RCVHOLD    ) && (rx_dat_type != hold ) && (rx_dat_type != align );
assign rcvhold2idl_s            = (state_c == S5_LR5_RCVHOLD    ) && (sync_idle || nocommerr);
assign rcveof2goodcrc_s         = (state_c == S6_LR6_RCVEOF     ) && crc_check_ok;
assign rcveof2badend_s          = (state_c == S6_LR6_RCVEOF     ) && crc_check_err;
assign rcveof2idl_s             = (state_c == S6_LR6_RCVEOF     ) && nocommerr;
assign goodcrc2idl_s            = (state_c == S7_LR7_GOODCRC    ) && (sync_idle || nocommerr);
assign goodcrc2goodend_s        = (state_c == S7_LR7_GOODCRC    ) &&  tl_ok;
assign goodcrc2badend_s         = (state_c == S7_LR7_GOODCRC    ) && (tl_err || (link_rd_error || buffer_overflow_err));
assign goodend2idl_s            = (state_c == S8_LR8_GOODEND    ) && (sync_idle || nocommerr);
assign badend2idl_s             = (state_c == S9_LR9_BADEND     ) && (sync_idle || nocommerr);

// Error and status signal assignments
assign nocommerr    = (~phyrdy) && (state_c != S0_IDLE);           // No communication error when PHY not ready
assign no_sof       = (rx_dat_type != sof  ) && (rx_dat_type != align); // No SOF primitive
assign no_x_rdy     = (rx_dat_type != x_rdy) && (rx_dat_type != align); // No X_RDY primitive
assign sync_idle    = (rx_dat_type == sync);                        // SYNC primitive (idle)
assign dat_rdy      = ~buffer_full;                                // Data ready when buffer not full
assign dat_unrdy    =  buffer_full;                                // Data not ready when buffer full

// Read path busy status
assign rd_no_busy   = (state_c == S0_IDLE);

// Read completion signal
// Indicates when a read operation has completed (either successfully or with error)
assign rd_cpl = rcvchkrdy2idl_s | rcvwaitfifo2idl_s | rcvdata2idl_s | rcvhold2idl_s | rcveof2idl_s | goodcrc2idl_s | goodend2idl_s | badend2idl_s;

// Roll insertion control
// Register roll insert signal for pause detection
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        roll_insert_r  <= 'd0;
    end
    else begin
        roll_insert_r  <= roll_insert  ;
    end
end

// Roll insertion pause logic - pause operations during roll insertion
assign roll_insert_pause   =  roll_insert    || roll_insert_r;

// Transmit data type, data, and character assignments
// Based on current state, determine what primitive or data to send
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        tx_dat_type <=  sync   ;        // Default to SYNC primitive
        tx_dat      <= `SYNCp  ;        // SYNC primitive value
        tx_char     <=  4'b1000;        // K-character indicator
    end
    else if(roll_insert_pause)begin     // During roll insertion, send ALIGN primitive
        tx_dat_type <= align;
        tx_dat      <= `ALIGNp;
        tx_char     <= 'b1000;
    end
    else unique case(state_c)
        S0_IDLE:begin                   // Idle state - send SYNC
            tx_dat_type <=  sync   ;
            tx_dat      <= `SYNCp  ;
            tx_char     <=  4'b1000;
        end
        S1_LR1_RCVCHKRDY:begin          // Receive check ready - send R_RDY
            tx_dat_type <=  r_rdy   ;
            tx_dat      <= `R_RDYp  ;
            tx_char     <=  4'b1000;
        end
        S2_LR2_RCVWAITFIFO:begin        // Wait for FIFO - send SYNC
            tx_dat_type <=  sync   ;
            tx_dat      <= `SYNCp  ;
            tx_char     <=  4'b1000;
        end
        S3_LR3_RCVDATA:begin            // Receive data - send HOLD if buffer full, otherwise R_IP
            if(dat_unrdy)begin
                tx_dat_type <=  hold   ;
                tx_dat      <= `HOLDp  ;
                tx_char     <=  4'b1000;
            end
            else begin
                tx_dat_type <=  r_ip   ;
                tx_dat      <= `R_IPp  ;
                tx_char     <=  4'b1000;
            end
        end
        S4_LR4_HOLD:begin               // Hold state - send HOLD
            tx_dat_type <=  hold   ;
            tx_dat      <= `HOLDp  ;
            tx_char     <=  4'b1000;
        end
        S5_LR5_RCVHOLD:begin            // Receive hold - send HOLDA
            tx_dat_type <=  holda  ;
            tx_dat      <= `HOLDAp ;
            tx_char     <=  4'b1000;
        end
        S6_LR6_RCVEOF:begin             // Receive EOF - send R_IP
            tx_dat_type <=  r_ip   ;
            tx_dat      <= `R_IPp  ;
            tx_char     <=  4'b1000;
        end
        S7_LR7_GOODCRC:begin            // Good CRC - send R_IP
            tx_dat_type <=  r_ip   ;
            tx_dat      <= `R_IPp  ;
            tx_char     <=  4'b1000;
        end
        S8_LR8_GOODEND:begin            // Good end - send R_OK
            tx_dat_type <=  r_ok   ;
            tx_dat      <= `R_OKp  ;
            tx_char     <=  4'b1000;
        end
        S9_LR9_BADEND:begin             // Bad end - send R_ERR
            tx_dat_type <=  r_err  ;
            tx_dat      <= `R_ERRp ;
            tx_char     <=  4'b1000;
        end
        default:begin                   // Default - send SYNC
            tx_dat_type <=  sync ;
            tx_dat      <= `SYNCp;
            tx_char     <= 'b1000;
        end
    endcase
end

// Register received data for pipeline stages
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        r_m_aixs_tdata  <= 'd0;
    end
    else if(rx_dat_type == is_dat)begin
        r_m_aixs_tdata  <= rx_dat;
    end
end

// Double register received data
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        rr_m_aixs_tdata <= 'd0;
    else
        rr_m_aixs_tdata <= r_m_aixs_tdata;
end

// Output registered data
assign m_aixs_tdata = rr_m_aixs_tdata;

// AXI Stream valid signal generation
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        r_m_aixs_tvalid <= 'd0;
    end
    else if((rx_dat_type == is_dat) || (no_dat_pulse && (rx_dat_type == eof)))begin
        r_m_aixs_tvalid <= 1'b1;
    end
    else begin
        r_m_aixs_tvalid <= 'd0;
    end
end

// Master valid signal control
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        m_aixs_tvalid <= 'd0;
    else if(is_dat_pulse && (rx_dat_type != is_dat) && (rx_dat_type != eof))
        m_aixs_tvalid <= 'd0;
    else if(no_dat_pulse && (rx_dat_type == is_dat))
        m_aixs_tvalid <= 'd1;
    else
        m_aixs_tvalid <= r_m_aixs_tvalid;
end

// Start of packet flag management
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        sop_flag <= 'd0;
    else if((rx_dat_type == sof   ) && (state_c == S1_LR1_RCVCHKRDY))
        sop_flag <= 'd1;
    else if((rx_dat_type == is_dat) && (state_c == S3_LR3_RCVDATA ))
        sop_flag <= 'd0;
end

// Master start of packet signal
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        m_aixs_tsop <= 'd0;
    else if(sop_flag && (rx_dat_type == is_dat))
        m_aixs_tsop <= 'd1;
    else
        m_aixs_tsop <= 'd0;
end

// Receive flag management
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        recv_flag <= 'd0;
    else if((rx_dat_type == sof) && (state_c == S1_LR1_RCVCHKRDY))
        recv_flag <= 'd1;
    else if(rx_dat_type == eof)
        recv_flag <= 'd0;
end 

// Byte keep signal management
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        m_aixs_tkeep <= 'd0;
    else if(rx_dat_type == is_dat)
        m_aixs_tkeep <= 4'b1111;
end

// End of packet user signal
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        m_aixs_tuser[0]  <= 'd0;
    else if(m_aixs_tuser[0]  && m_aixs_tvalid)
        m_aixs_tuser[0]  <= 'd0;
    else if(rx_dat_type == eof)
        m_aixs_tuser[0]  <= 'd1;
end

// Start of packet user signal
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        m_aixs_tuser[1]  <= 'd0;
    else if(m_aixs_tsop)
        m_aixs_tuser[1]  <= 'd1;
    else if(m_aixs_tvalid)
        m_aixs_tuser[1]  <= 'd0;
end

// Other user signals (keep, error flags)
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        m_aixs_tuser[7:2] <= 'd0;
    end
    else begin
        m_aixs_tuser[5:2]    <= m_aixs_tkeep;                // Byte keep signals
        m_aixs_tuser[6]      <= (crc_check_err || nocommerr || sync_idle) && recv_flag; // Error flag
        m_aixs_tuser[7]      <= link_rd_error;              // Link read error flag
    end
end

// Link read error flag
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        link_rd_error <= 'd0;
    else if(buffer_overflow_err)
        link_rd_error <= 'd1;
end

// Buffer overflow error detection
assign buffer_overflow_err   = (~m_aixs_tready) && (rx_dat_type == is_dat);

// Instantiate CRC module for data integrity checking
sata_link_crc u_sata_link_crc(
    .data_in  	(crc_data_in    ),      // CRC input data
    .crc_init 	(crc_init       ),      // CRC initialization
    .crc_en   	(crc_en         ),      // CRC enable
    .crc_out  	(crc_out        ),      // CRC output result
    .rst_n    	(rst_n          ),      // Reset signal
    .clk      	(clk            )       // Clock signal
);

// CRC module control signals
assign crc_data_in = rx_dat;                           // Input data for CRC calculation
assign crc_init    = (state_c == S1_LR1_RCVCHKRDY  ) && (rx_dat_type == sof  ); // Initialize on SOF
assign crc_en      = (rx_dat_type == is_dat);          // Enable CRC for data

// CRC check results
assign crc_check_ok = (crc_out == 32'h00000000) && (state_c == S6_LR6_RCVEOF     ); // CRC passed
assign crc_check_err= (crc_out != 32'h00000000) && (state_c == S6_LR6_RCVEOF     ); // CRC failed

// Data pulse detection
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        is_dat_pulse   <= 'd0;
    else
        is_dat_pulse <= (rx_dat_type == is_dat);
end

// No data pulse detection
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        no_dat_pulse   <= 'd0;
    else
        no_dat_pulse <= (rx_dat_type != eof) && (rx_dat_type != is_dat) && packet_scan;
end

// Packet scanning indicator
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        packet_scan <= 'd0;
    else if(packet_scan && (state_c == S0_IDLE))
        packet_scan <= 'd0;
    else if(rx_dat_type == is_dat)
        packet_scan <= 'd1;
    else if(rx_dat_type == eof)
        packet_scan <= 'd0;
end

// Transmit start of packet counter
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        tx_sop_cnt <= 'd0;
    else if(m_aixs_tvalid && m_aixs_tready && m_aixs_tuser[1])
        tx_sop_cnt <= tx_sop_cnt + 1'b1;
end

// Transmit end of packet counter
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        tx_eop_cnt <= 'd0;
    else if(m_aixs_tvalid && m_aixs_tready && m_aixs_tuser[0])
        tx_eop_cnt <= tx_eop_cnt + 1'b1;
end

// ECP (Error Correction Protocol) counter
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        ecp_cnt <= 'd0;
    else if(rcvchkrdy2idl_s | rcvwaitfifo2idl_s | rcvdata2idl_s | rcvhold2idl_s | rcveof2idl_s | goodcrc2idl_s)
        ecp_cnt <= ecp_cnt + 1'b1;
end

// Error counter
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        err_cnt <= 'd0;
    else if(goodcrc2badend_s )
        err_cnt <= err_cnt + 1'b1;
end

endmodule