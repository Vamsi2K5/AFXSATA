/******************************************Copyright@2025**************************************
                                    AdriftXCore  ALL rights reserved
                        https://github.com/AdriftXCore https://gitee.com/adriftxcore
=========================================FILE INFO.============================================
FILE Name       : sata_link_wrmod.sv
Last Update     : 2025/04/07 18:11:44
Latest Versions : 1.0
========================================AUTHOR INFO.===========================================
Created by      : zhanghx
Create date     : 2025/04/07 18:11:44
Version         : 1.0
Description     : SATA Link Write Module - Implements the write data path control logic for the 
                  SATA link layer. This module handles the state machine for write operations, 
                  including SOF transmission, data transfer, CRC calculation, EOF transmission, 
                  and wait states. The module interfaces with the PHY layer for data transfer 
                  and with the arbiter for write request and completion signaling.
=======================================UPDATE HISTPRY==========================================
Modified by     : 
Modified date   : 
Version         : 
Description     : 
******************************Licensed under the GPL-3.0 License******************************/
`include "sata_wrapper_define.svh"

// SATA Link Write Module
// This module implements the write data path in the SATA link layer. It manages the complete
// write transaction flow from start to finish, including:
// 1. Handling write requests from the link arbiter
// 2. Transmitting SOF (Start of Frame) primitive
// 3. Sending data payloads with proper flow control
// 4. Calculating and transmitting CRC
// 5. Sending EOF (End of Frame) primitive
// 6. Waiting for response (R_OK or R_ERR) from the receiver
module sata_link_wrmod #(
    parameter USER_W = 8              // User data width for AXI Stream interface
)(
    /**** clk/rst ****/
    input   logic                           clk             ,   // Main clock signal
    input   logic                           rst_n           ,   // Active-low reset signal

    /**** phy ****/
    input   logic                           phyrdy          ,   // PHY layer ready signal

    /**** arbiter ****/
    input   logic                           wr_req          ,   // Write request from link arbiter
    output  logic                           wr_cpl          ,   // Write operation completion signal
    output  logic                           wr_no_busy      ,   // Write path not busy signal

    input   logic                           roll_insert     ,   // Roll insertion request for ALIGN primitives

    // Slave AXI Stream interface (from transport layer)
    input   logic       [31         :0]     s_aixs_tdata    ,   // Slave data payload
    input   logic       [USER_W   -1:0]     s_aixs_tuser    ,   // Slave user signals {drop,err,keep[3:0],sop,eop}
    input   logic                           s_aixs_tvalid   ,   // Slave data valid signal
    output  logic                           s_aixs_tready   ,   // Slave ready signal

    // Statistics counters
    output  logic       [31         :0]     ecp_cnt         ,   // ECP (Error Correction Protocol) counter
    output  logic       [31         :0]     err_cnt         ,   // Error counter
    output  logic       [31         :0]     tx_sop_cnt      ,   // Transmit start of packet counter
    output  logic       [31         :0]     tx_eop_cnt      ,   // Transmit end of packet counter

    /**** rx link dat ****/
    // Received data from link decoder
    input   sata_p_t                        rx_dat_type     ,   // Received data type (primitive or data)
    input   logic       [32       -1:0]     rx_dat          ,   // Received data payload
    input   logic       [4        -1:0]     rx_char         ,   // Received character indicator

    /**** tx link dat ****/
    // Transmit data to link encoder
    output  sata_p_t                        tx_dat_type     ,   // Transmit data type (primitive or data)
    output  logic       [32       -1:0]     tx_dat          ,   // Transmit data payload
    output  logic       [4        -1:0]     tx_char           // Transmit character indicator
);

// Internal signal declarations
logic                 dat_unvld           ;   // Data not valid flag
logic                 dat_vld             ;   // Data valid flag
logic                 dat_sop             ;   // Data start of packet flag
logic                 nocommerr           ;   // No communication error flag
logic                 sync_idle           ;   // SYNC primitive received (idle)
logic                 link_ignor_p        ;   // Link ignore primitive flag

logic                 end_write           ;   // End of write operation flag

logic [32       -1:0] crc_result          ;   // CRC calculation result

logic                 roll_insert_r       ;   // Registered roll insert signal
logic                 roll_insert_pause   ;   // Pause operations during roll insertion

// State transition signals
logic                 idl2sendsof_s       ;   // Transition from IDLE to SENDSOF
logic                 sendsof2senddata_s  ;   // Transition from SENDSOF to SENDDATA
logic                 sendsof2idl_s       ;   // Transition from SENDSOF to IDLE
logic                 senddat2rcvrhold_s  ;   // Transition from SENDDATA to RCVRHOLD
logic                 senddat2sendhold_s  ;   // Transition from SENDDATA to SENDHOLD
logic                 senddat2sendcrc_s   ;   // Transition from SENDDATA to SENDCRC
logic                 senddat2idl_s       ;   // Transition from SENDDATA to IDLE
logic                 rcvrhold2senddat_s  ;   // Transition from RCVRHOLD to SENDDATA
logic                 rcvrhold2idl_s      ;   // Transition from RCVRHOLD to IDLE
logic                 sendhold2senddat_s  ;   // Transition from SENDHOLD to SENDDATA
logic                 sendhold2rcvrhold_s ;   // Transition from SENDHOLD to RCVRHOLD
logic                 sendhold2sendcrc_s  ;   // Transition from SENDHOLD to SENDCRC
logic                 sendhold2idl_s      ;   // Transition from SENDHOLD to IDLE
logic                 sendcrc2sendeof_s   ;   // Transition from SENDCRC to SENDEOF
logic                 sendcrc2idl_s       ;   // Transition from SENDCRC to IDLE
logic                 sendeof2wait_s      ;   // Transition from SENDEOF to WAIT
logic                 sendeof2idl_s       ;   // Transition from SENDEOF to IDLE
logic                 wait2idl_s          ;   // Transition from WAIT to IDLE

// CRC module interface signals
logic [32       -1:0] crc_data_in         ;   // CRC input data
logic                 crc_init            ;   // CRC initialization signal
logic                 crc_en              ;   // CRC enable signal
logic [32       -1:0] crc_out             ;   // CRC output result

// State machine width definition
localparam STATE_W = 8;

// State bit positions
localparam  S0_BIT      = 'd0  ,        // IDLE state bit
            S1_BIT      = 'd1  ,        // LT3_SENDSOF state bit
            S2_BIT      = 'd2  ,        // LT4_SENDDATA state bit
            S3_BIT      = 'd3  ,        // LT5_RCVRHOLD state bit
            S4_BIT      = 'd4  ,        // LT6_SENDHOLD state bit
            S5_BIT      = 'd5  ,        // LT7_SENDCRC state bit
            S6_BIT      = 'd6  ,        // LT8_SENDEOF state bit
            S7_BIT      = 'd7  ;        // LT9_WAIT state bit

// State machine type definition
// S0_IDLE:           Idle state, waiting for write request
// S1_LT3_SENDSOF:    Send SOF (Start of Frame) primitive
// S2_LT4_SENDDATA:   Send data payload
// S3_LT5_RCVRHOLD:   Receiver HOLD state - receiver cannot accept more data
// S4_LT6_SENDHOLD:   Send HOLD primitive - transmitter cannot send more data
// S5_LT7_SENDCRC:    Send CRC (Cyclic Redundancy Check)
// S6_LT8_SENDEOF:    Send EOF (End of Frame) primitive
// S7_LT9_WAIT:       Wait for response (R_OK or R_ERR)
typedef enum logic [STATE_W-1:0]{
    S0_IDLE             = STATE_W'(1) << S0_BIT    ,   // Idle state
    S1_LT3_SENDSOF      = STATE_W'(1) << S1_BIT    ,   // Send SOF state
    S2_LT4_SENDDATA     = STATE_W'(1) << S2_BIT    ,   // Send data state
    S3_LT5_RCVRHOLD     = STATE_W'(1) << S3_BIT    ,   // Receive HOLD state
    S4_LT6_SENDHOLD     = STATE_W'(1) << S4_BIT    ,   // Send HOLD state
    S5_LT7_SENDCRC      = STATE_W'(1) << S5_BIT    ,   // Send CRC state
    S6_LT8_SENDEOF      = STATE_W'(1) << S6_BIT    ,   // Send EOF state
    S7_LT9_WAIT         = STATE_W'(1) << S7_BIT      // Wait for response state
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
            if(idl2sendsof_s)
                state_n = S1_LT3_SENDSOF;
            else
                state_n = state_c;
        end
        state_c[S1_BIT]:begin //S1_LT3_SENDSOF - Send SOF primitive
            if(sendsof2idl_s)
                state_n = S0_IDLE;
            else if(sendsof2senddata_s)
                state_n = S2_LT4_SENDDATA;
            else
                state_n = state_c;
        end
        state_c[S2_BIT]:begin //S2_LT4_SENDDATA - Send data payload
            if(senddat2idl_s)
                state_n = S0_IDLE;
            else if(senddat2rcvrhold_s)
                state_n = S3_LT5_RCVRHOLD;
            else if(senddat2sendhold_s)
                state_n = S4_LT6_SENDHOLD;
            else if(senddat2sendcrc_s)
                state_n = S5_LT7_SENDCRC;
            else
                state_n = state_c;
        end
        state_c[S3_BIT]:begin //S3_LT5_RCVRHOLD - Receiver HOLD state
            if(rcvrhold2idl_s)
                state_n = S0_IDLE;
            else if(rcvrhold2senddat_s)
                state_n = S2_LT4_SENDDATA;
            else
                state_n = state_c;
        end
        state_c[S4_BIT]:begin //S4_LT6_SENDHOLD - Send HOLD primitive
            if(sendhold2idl_s)
                state_n = S0_IDLE;
            else if(sendhold2rcvrhold_s)
                state_n = S3_LT5_RCVRHOLD;
            else if(sendhold2sendcrc_s)
                state_n = S5_LT7_SENDCRC;  
            else if(sendhold2senddat_s)
                state_n = S2_LT4_SENDDATA;
            else
                state_n = state_c;
        end
        state_c[S5_BIT]:begin //S5_LT7_SENDCRC - Send CRC
            if(sendcrc2idl_s)
                state_n = S0_IDLE;
            else if(sendcrc2sendeof_s)
                state_n = S6_LT8_SENDEOF;
            else
                state_n = state_c;
        end
        state_c[S6_BIT]:begin //S6_LT8_SENDEOF - Send EOF primitive
            if(sendeof2idl_s)
                state_n = S0_IDLE;
            else if(sendeof2wait_s)
                state_n = S7_LT9_WAIT;
            else
                state_n = state_c;
        end
        state_c[S7_BIT]:begin //S7_LT9_WAIT - Wait for response
            if(wait2idl_s)
                state_n = S0_IDLE;
            else
                state_n = state_c;
        end
        default: begin
            state_n = S0_IDLE;
        end
    endcase
end

// State transition conditions
assign idl2sendsof_s        = (state_c == S0_IDLE        ) && wr_req && phyrdy && (rx_dat_type == r_rdy) && dat_vld && dat_sop;
assign sendsof2senddata_s   = (state_c == S1_LT3_SENDSOF ) && (~roll_insert_pause);
assign sendsof2idl_s        = (state_c == S1_LT3_SENDSOF ) && (nocommerr | sync_idle);
assign senddat2rcvrhold_s   = (state_c == S2_LT4_SENDDATA) && (rx_dat_type == hold);
assign senddat2sendhold_s   = (state_c == S2_LT4_SENDDATA) && dat_unvld;
assign senddat2sendcrc_s    = (state_c == S2_LT4_SENDDATA) && end_write;
assign senddat2idl_s        = (state_c == S2_LT4_SENDDATA) && (nocommerr | sync_idle);
assign rcvrhold2senddat_s   = (state_c == S3_LT5_RCVRHOLD) && (rx_dat_type != hold);
assign rcvrhold2idl_s       = (state_c == S3_LT5_RCVRHOLD) && (nocommerr | sync_idle);
assign sendhold2senddat_s   = (state_c == S4_LT6_SENDHOLD) &&  dat_vld;
assign sendhold2rcvrhold_s  = (state_c == S4_LT6_SENDHOLD) && (rx_dat_type == hold);
assign sendhold2sendcrc_s   = (state_c == S4_LT6_SENDHOLD) && end_write;
assign sendhold2idl_s       = (state_c == S4_LT6_SENDHOLD) && (nocommerr | sync_idle);
assign sendcrc2sendeof_s    = (state_c == S5_LT7_SENDCRC ) && (~roll_insert_pause);
assign sendcrc2idl_s        = (state_c == S5_LT7_SENDCRC ) && (nocommerr | sync_idle);
assign sendeof2wait_s       = (state_c == S6_LT8_SENDEOF ) && (~roll_insert_pause);
assign sendeof2idl_s        = (state_c == S6_LT8_SENDEOF ) && (nocommerr | sync_idle);
assign wait2idl_s           = (state_c == S7_LT9_WAIT    ) && ((rx_dat_type == r_ok) || (rx_dat_type == r_err) ||(nocommerr | sync_idle));

// Error and status signal assignments
assign nocommerr    = (~phyrdy) && (state_c != S0_IDLE);           // No communication error when PHY not ready
assign sync_idle    = (rx_dat_type == sync ) && (state_c != S0_IDLE); // SYNC primitive (idle)
assign link_ignor_p = (rx_dat_type == align) && (state_c == S0_IDLE); // Ignore ALIGN in idle state
assign dat_vld      =  s_aixs_tvalid;                               // Data valid from transport layer
assign dat_sop      = s_aixs_tuser[1];                             // Start of packet flag
assign dat_unvld    = (~s_aixs_tvalid);                            // Data not valid
assign end_write    = s_aixs_tvalid && s_aixs_tready && s_aixs_tuser[0]; // End of write operation

// Roll insertion control
assign roll_insert_pause   =  roll_insert    || roll_insert_r;

// Slave ready signal generation
// Ready to accept data when in SENDDATA state and not receiving HOLD, or in IDLE state with valid non-SOP data
assign s_aixs_tready = (((state_c == S2_LT4_SENDDATA) && (rx_dat_type != hold)) && (~roll_insert_pause)) || ((state_c == S0_IDLE) && dat_vld && ~dat_sop);

// Write path busy status
assign wr_no_busy    = (state_c == S0_IDLE);

// Transmit data type, data, and character assignments
// Based on current state, determine what primitive or data to send
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        tx_dat_type <=  x_rdy ;        // Default to X_RDY primitive
        tx_dat      <= `X_RDYp;        // X_RDY primitive value
        tx_char     <= 'b1000 ;        // K-character indicator
    end
    else if(roll_insert_pause)begin     // During roll insertion, send ALIGN primitive
        tx_dat_type <= align;
        tx_dat      <= `ALIGNp;
        tx_char     <= 'b1000;
    end
    else unique case(state_c)
        S0_IDLE:begin                   // Idle state - send X_RDY
            tx_dat_type <=  x_rdy ;
            tx_dat      <= `X_RDYp;
            tx_char     <= 'b1000 ;
        end
        S1_LT3_SENDSOF:begin            // Send SOF primitive
            if(nocommerr | sync_idle)begin
                tx_dat_type <=  sync ;
                tx_dat      <= `SYNCp;
                tx_char     <= 'b1000;
            end
            else begin
                tx_dat_type <=  sof  ;
                tx_dat      <= `SOFp ;
                tx_char     <= 'b1000;
            end
        end
        S2_LT4_SENDDATA:begin           // Send data payload
            if(rx_dat_type == hold)begin
                tx_dat_type <=  holda ;
                tx_dat      <= `HOLDAp;
                tx_char     <= 'b1000 ;
            end
            else if(dat_unvld)begin
                tx_dat_type <=  hold ;
                tx_dat      <= `HOLDp;
                tx_char     <= 'b1000;
            end
            else begin
                tx_dat_type <= is_dat  ;
                tx_dat      <= s_aixs_tdata;
                tx_char     <= 'b0000;
            end
        end
        S3_LT5_RCVRHOLD:begin           // Receive HOLD - send HOLDA
            tx_dat_type <=  holda ;
            tx_dat      <= `HOLDAp;
            tx_char     <= 'b1000 ;
        end
        S4_LT6_SENDHOLD:begin           // Send HOLD primitive
            tx_dat_type <=  hold  ;
            tx_dat      <= `HOLDp ;
            tx_char     <= 'b1000 ;
        end
        S5_LT7_SENDCRC:begin            // Send CRC result
            tx_dat_type <= is_crc     ;
            tx_dat      <= crc_result ;
            tx_char     <= 'b0000     ;
        end
        S6_LT8_SENDEOF:begin            // Send EOF primitive
            tx_dat_type <=  eof       ;
            tx_dat      <= `EOFp      ;
            tx_char     <= 'b1000     ;
        end
        S7_LT9_WAIT:begin               // Wait state - send WTRM
            tx_dat_type <=  wtrm      ;
            tx_dat      <= `WTRMp     ;
            tx_char     <= 'b1000     ;
        end
        default:begin                   // Default - send SYNC
            tx_dat_type <=  sync ;
            tx_dat      <= `SYNCp;
            tx_char     <= 'b1000;
        end
    endcase
end

// Write completion signal
// Indicates when a write operation has completed (either successfully or with error)
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        wr_cpl <= 'd0;
    else if(wait2idl_s | ((nocommerr | sync_idle) && (state_c != S0_IDLE)))
        wr_cpl <= 'd1;
    else
        wr_cpl <= 'd0;
end

// Register roll insert signal for pause detection
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        roll_insert_r  <= 'd0;
    end
    else begin
        roll_insert_r  <= roll_insert  ;
    end
end

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
assign crc_data_in = s_aixs_tdata;      // Input data for CRC calculation
assign crc_en      = s_aixs_tvalid && s_aixs_tready; // Enable CRC when data is transferred
assign crc_result  = crc_out;          // CRC result output
assign crc_init    = (state_c == S1_LT3_SENDSOF ); // Initialize CRC on SOF transmission

// ECP (Error Correction Protocol) counter
// Counts communication errors and state transitions to IDLE
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        ecp_cnt <= 'd0;
    else if(sendsof2idl_s | senddat2idl_s | rcvrhold2idl_s | sendhold2idl_s | sendcrc2idl_s | sendeof2idl_s | ((state_c == S7_LT9_WAIT) && (nocommerr | sync_idle)))
        ecp_cnt <= ecp_cnt + 1'b1;
end

// Error counter
// Counts write operations that resulted in R_ERR response
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        err_cnt <= 'd0;
    else if((state_c == S7_LT9_WAIT) && (rx_dat_type == r_err))
        err_cnt <= err_cnt + 1'b1;
end

// Transmit start of packet counter
// Counts transmitted start of packet occurrences
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        tx_sop_cnt <= 'd0;
    else if(s_aixs_tuser[1] && s_aixs_tvalid && s_aixs_tready && (state_c != S0_IDLE))
        tx_sop_cnt <= tx_sop_cnt + 1'b1;
end

// Transmit end of packet counter
// Counts transmitted end of packet occurrences
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        tx_eop_cnt <= 'd0;
    else if(s_aixs_tuser[0] && s_aixs_tvalid && s_aixs_tready && (state_c != S0_IDLE))
        tx_eop_cnt <= tx_eop_cnt + 1'b1;
end

endmodule