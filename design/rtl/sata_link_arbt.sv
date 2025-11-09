/******************************************Copyright@2025**************************************
                                    AdriftXCore  ALL rights reserved
                        https://github.com/AdriftXCore https://gitee.com/adriftxcore
=========================================FILE INFO.============================================
FILE Name       : sata_link_arbt.sv
Last Update     : 2025/04/07 18:11:44
Latest Versions : 1.0
========================================AUTHOR INFO.===========================================
Created by      : zhanghx
Create date     : 2025/04/07 18:11:44
Version         : 1.0
Description     : SATA Link Arbitration Module - Controls access to the SATA link layer by 
                  arbitrating between read and write requests from the transport layer. This 
                  module ensures proper sequencing of operations and handles flow control 
                  between different layers of the SATA protocol stack.
=======================================UPDATE HISTPRY==========================================
Modified by     : 
Modified date   : 
Version         : 
Description     : 
******************************Licensed under the GPL-3.0 License******************************/
`include "sata_wrapper_define.svh"

// SATA Link Arbitration Module
// This module arbitrates access to the SATA link layer between read and write operations.
// It manages the flow control between the transport layer and the link layer, ensuring that
// only one operation type is processed at a time and that proper sequencing is maintained.
module sata_link_arbt(
    /**** clk/rst ****/
    input   logic                    clk         ,   // Clock signal
    input   logic                    rst_n       ,   // Reset signal (active low)

    /**** transport ****/
    input   logic                    rx_req      ,   // Receive request from transport layer

    /**** link ****/
    input   sata_p_t                 rx_dat_type ,   // Received data type from link layer

    /**** phy ****/
    input   logic                    phyrdy      ,   // PHY ready signal

    /**** arbt ****/
    input   logic                    roll_insert ,   // Roll insertion request

    output  logic                    wr_req      ,   // Write request to link layer
    input   logic                    wr_cpl      ,   // Write completion signal
    input   logic                    wr_no_busy  ,   // Write not busy signal
    output  logic                    rd_req      ,   // Read request to link layer
    input   logic                    rd_cpl      ,   // Read completion signal
    input   logic                    rd_no_busy      // Read not busy signal
);

// State machine signal definitions
// Defines the states for the arbitration state machine
localparam STATE_W =  3;

// State bit position definitions
localparam  IDLE_BIT    = 'd0 ,        // Idle state bit
            S1_BIT      = 'd1 ,        // Write state bit
            S2_BIT      = 'd2 ;        // Read state bit

// State enumeration type
// IDLE: No active operation
// WR:   Write operation in progress
// RD:   Read operation in progress
typedef enum logic [STATE_W-1:0]{
    IDLE    = STATE_W'(1) << IDLE_BIT,   // Idle state - waiting for requests
    WR      = STATE_W'(1) << S1_BIT  ,   // Write state - processing write request
    RD      = STATE_W'(1) << S2_BIT      // Read state - processing read request
}state_t;

state_t state_c;    // Current state register
state_t state_n;    // Next state register

// State transition control signals
logic               idl2wr              ;   // Transition from IDLE to WR state
logic               idl2rd              ;   // Transition from IDLE to RD state
logic               wr2idl              ;   // Transition from WR to IDLE state
logic               wr2rd               ;   // Transition from WR to RD state
logic               rd2idl              ;   // Transition from RD to IDLE state

// Timer signals for arbitration delay
logic [32     -1:0] cnt_timer           ;   // Timer counter for arbitration delay
logic               add_cnt_timer       ;   // Increment timer counter
logic               end_cnt_timer       ;   // Timer reached end count
logic               start_arbt          ;   // Start arbitration after delay

// Roll insertion control signals
logic               roll_insert_r       ;   // Registered roll insert signal
logic               roll_insert_pause   ;   // Pause arbitration due to roll insert

// Roll insertion pause logic - prevents new operations during roll insertion
assign roll_insert_pause   =  roll_insert    || roll_insert_r;

// State register update - synchronous with clock and reset
always_ff@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        state_c <= IDLE;
    else
        state_c <= state_n;
end

// Next state logic - combinational
always_comb begin
    case (1)
        state_c[IDLE_BIT]:begin//IDLE state
            if(idl2wr)
                state_n = WR;
            else if(idl2rd)
                state_n = RD;
            else
                state_n = state_c;
        end
        state_c[S1_BIT]:begin//WR state
            if(wr2rd)
                state_n = RD;
            else if(wr2idl)
                state_n = IDLE;
            else 
                state_n = state_c;

        end
        state_c[S2_BIT]:begin//RD state
            if(rd2idl)
                state_n = IDLE;
            else
                state_n = state_c;
        end
        default: begin
            state_n = IDLE;
        end
    endcase
end

// State transition conditions
// idl2wr: Transition from IDLE to WR when:
// - Not in roll insertion pause
// - Arbitration started
// - PHY is ready
// - Receive request is active
assign idl2wr = (state_c == IDLE) && (~roll_insert_pause) && start_arbt && phyrdy && rx_req                ;

// idl2rd: Transition from IDLE to RD when:
// - Not in roll insertion pause
// - Arbitration started
// - PHY is ready
// - Received data type is x_rdy (ready for read)
assign idl2rd = (state_c == IDLE) && (~roll_insert_pause) && start_arbt && phyrdy && (rx_dat_type == x_rdy);

// wr2rd: Transition from WR to RD when:
// - Write is not busy
// - Received data type is x_rdy (ready for read)
assign wr2rd  = (state_c == WR  ) && wr_no_busy && (rx_dat_type == x_rdy);

// wr2idl: Transition from WR to IDLE when write is complete
assign wr2idl = (state_c == WR  ) && wr_cpl;

// rd2idl: Transition from RD to IDLE when read is complete
assign rd2idl = (state_c == RD  ) && rd_cpl;

// Output request signals
// wr_req: Asserted when in write state
assign wr_req = (state_c == WR);

// rd_req: Asserted when in read state
assign rd_req = (state_c == RD);

// Timer counter for arbitration startup delay
// This delay ensures proper initialization before starting arbitration
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        cnt_timer <= 0;
    end
    else if(add_cnt_timer)begin
        if(end_cnt_timer)
            cnt_timer <= 0;
        else
            cnt_timer <= cnt_timer + 1'b1;
    end
end

// Timer control logic
// Start counting when arbitration has not yet started
assign add_cnt_timer = !start_arbt;

// End count when timer reaches 150 cycles
assign end_cnt_timer = add_cnt_timer && cnt_timer == 150 - 1;

// Start arbitration flag
// Set when timer completes its count
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        start_arbt <= 'd0;
    else if(end_cnt_timer)
        start_arbt <= 'd1;
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

endmodule