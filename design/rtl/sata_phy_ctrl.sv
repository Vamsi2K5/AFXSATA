/******************************************Copyright@2025**************************************
                                    AdriftXCore  ALL rights reserved
                        https://github.com/AdriftXCore https://gitee.com/adriftxcore
=========================================FILE INFO.============================================
FILE Name       : sata_phy_ctrl.v
Last Update     : 2025/02/01 18:11:44
Latest Versions : 1.0
========================================AUTHOR INFO.===========================================
Created by      : zhanghx
Create date     : 2025/02/01 18:11:44
Version         : 1.0
Description     : SATA PHY Control - Implements the physical layer control for SATA interface.
                  This module handles the SATA link initialization, speed negotiation, 
                  out-of-band signaling, and data transmission/reception control.
=======================================UPDATE HISTPRY==========================================
Modified by     : zhanghx 
Modified date   : 2025/10/16 22:24:05 
Version         : 1.0
Description     : Fix HR_SENDALIGN bug
******************************Licensed under the GPL-3.0 License******************************/
module sata_phy_ctrl #(
    parameter CYCLE = 150_000_000,      // System clock frequency in Hz

    //local param
    parameter US_CYCLE  = CYCLE/1000000 // Microsecond cycle count
)(
    /************ sys_clk ************/
    input   logic               rx_clk          ,   // Receive clock from PHY
    input   logic               tx_clk          ,   // Transmit clock to PHY
    input   logic               rst_n           ,   // Active low reset signal

    /************ sys_clk ************/
    input   logic   [31  :0]    timeout_time    ,   // Timeout value for link state transitions
    output  logic               hr_reset        ,   // Hard reset request to link layer

    /************ gt_dat ************/
    input   logic   [3   :0]    rx_charisk      ,   // Received character identifier (K-char)
    input   logic   [31  :0]    rx_data         ,   // Received data from PHY

    output  logic   [3   :0]    tx_charisk      ,   // Transmit character identifier (K-char)
    output  logic   [31  :0]    tx_data         ,   // Transmit data to PHY
    /************ gt_OOB ************/
    input   logic               rx_comwake      ,   // Received COMWAKE signal (out-of-band)
    input   logic               rx_cominit      ,   // Received COMINIT signal (out-of-band)
    input   logic               rx_eleidle      ,   // Electrical idle detection

    output  logic               tx_cominit      ,   // Transmit COMINIT signal (out-of-band)
    output  logic               tx_comwake      ,   // Transmit COMWAKE signal (out-of-band)

    /************ phy to link ************/
    input   logic   [31  :0]    dat_i           ,   // Data input from link layer
    input   logic   [3   :0]    datchar_i       ,   // Data character input from link layer
    input   logic               hreset          ,   // Hardware reset request
    output  logic               phyrdy          ,   // PHY ready signal to link layer
    input   logic               slumber         ,   // Slumber power management mode
    input   logic               partial         ,   // Partial power management mode
    input   logic               nearafelb       ,   // Near-end analog loopback mode
    input   logic               farafelb        ,   // Far-end analog loopback mode
    input   logic               spdsedl         ,   // Speed selection from device list
    output  logic               spdmode         ,   // Speed mode indicator
    output  logic               device_detect   ,   // Device detection signal
    output  logic               phy_internal_err,   // PHY internal error flag
    output  logic  [31   :0]    dat_o           ,   // Data output to link layer
    output  logic  [3    :0]    datchar_o       ,   // Data character output to link layer
    output  logic               rxclock         ,   // Receive clock output
    output  logic               cominit         ,   // COMINIT signal output
    output  logic               comwake         ,   // COMWAKE signal output
    output  logic               comma           // Comma character detection output
);

/************ state mechine signal ************/
// State transition control signals for SATA link initialization sequence
logic               hr_reset2hr_awaitcominit            ;   // Transition from HR_RESET to HR_AWAITCOMINIT
logic               hr_awaitcominit2hr_awaitnocominit   ;   // Transition from HR_AWAITCOMINIT to HR_AWAITNOCOMINIT
logic               hr_awaitcominit2hr_reset            ;   // Transition from HR_AWAITCOMINIT to HR_RESET
logic               hr_awaitnocominit2hr_cailbrate      ;   // Transition from HR_AWAITNOCOMINIT to HR_CAILBRATE
logic               hr_cailbrate2hr_comwake             ;   // Transition from HR_CAILBRATE to HR_COMWAKE
logic               hr_comwake2hr_awaitcomwake          ;   // Transition from HR_COMWAKE to HR_AWAITCOMWAKE
logic               hr_comwake2hr_awaitnocomwake        ;   // Transition from HR_COMWAKE to HR_AWAITNOCOMWAKE
logic               hr_awaitcomwake2hr_awaitnocomwake   ;   // Transition from HR_AWAITCOMWAKE to HR_AWAITNOCOMWAKE
logic               hr_awaitcomwake2hr_comwake2hr       ;   // Transition from HR_AWAITCOMWAKE to HR_COMWAKE
logic               hr_awaitnocomwake2Hr_awaitalign     ;   // Transition from HR_AWAITNOCOMWAKE to HR_AWAITALIGN
logic               hr_awaitalign2hr_adjustspeed        ;   // Transition from HR_AWAITALIGN to HR_ADJUSTSPEED
logic               hr_awaitalign2hr_reset              ;   // Transition from HR_AWAITALIGN to HR_RESET
logic               hr_adjustspeed2hr_sendalign         ;   // Transition from HR_ADJUSTSPEED to HR_SENDALIGN
logic               hr_sendalign2hr_ready               ;   // Transition from HR_SENDALIGN to HR_READY
logic               hr_ready2partial                    ;   // Transition from HR_READY to HR_PARTIAL
logic               hr_ready2slumber                    ;   // Transition from HR_READY to HR_SLUMBER

// Control signals for out-of-band signaling
logic               send_comreset                       ;   // Send COMRESET sequence
logic               end_send_comreset                   ;   // End of COMRESET sequence
logic               send_comwake                        ;   // Send COMWAKE sequence
logic               end_send_comwake                    ;   // End of COMWAKE sequence

// Signal detection and decoding
logic               dec_align_code                      ;   // Decode ALIGN primitive
logic               dec_sync_code                       ;   // Decode SYNC primitive
logic               rev_align_seq                       ;   // Receive ALIGN sequence

// Counter signals for various timing functions
logic [2    -1:0]   cnt_alignp                          ;   // ALIGN primitive counter
logic               add_cnt_alignp                      ;   // Increment ALIGN counter
logic               end_cnt_alignp                      ;   // End of ALIGN counter

logic [8    -1:0]   cnt_us                              ;   // Microsecond timer counter
logic               add_cnt_us                          ;   // Increment microsecond counter
logic               end_cnt_us                          ;   // End of microsecond counter

logic [10   -1:0]   cnt_atimer                          ;   // ALIGN timer counter
logic               add_cnt_atimer                      ;   // Increment ALIGN timer
logic               end_cnt_atimer                      ;   // End of ALIGN timer

logic [32   -1:0]   cnt_timeout                         ;   // Timeout counter
logic               add_cnt_timeout                     ;   // Increment timeout counter
logic               end_cnt_timeout                     ;   // End of timeout counter

logic [32   -1:0]   cnt_com                             ;   // COM sequence counter
logic               add_cnt_com                         ;   // Increment COM counter
logic               end_cnt_com                         ;   // End of COM counter

localparam STATE_W = 13;

// State bit positions in the state machine
localparam      S0_BIT      = 'd0  ,
                S1_BIT      = 'd1  ,
                S2_BIT      = 'd2  ,
                S3_BIT      = 'd3  ,
                S4_BIT      = 'd4  ,
                S5_BIT      = 'd5  ,
                S6_BIT      = 'd6  ,
                S7_BIT      = 'd7  ,
                S8_BIT      = 'd8  ,
                S9_BIT      = 'd9  ,
                S10_BIT     = 'd10 ,
                S11_BIT     = 'd11 ,
                S12_BIT     = 'd12 ;

// SATA link initialization state machine definition
typedef enum logic [STATE_W-1:0]{
    HR_RESET            = STATE_W'(1) << S0_BIT  ,   // Hard reset state
    HR_AWAITCOMINIT     = STATE_W'(1) << S1_BIT  ,   // Await COMINIT state
    HR_AWAITNOCOMINIT   = STATE_W'(1) << S2_BIT  ,   // Await no COMINIT state
    HR_CAILBRATE        = STATE_W'(1) << S3_BIT  ,   // Calibration state
    HR_COMWAKE          = STATE_W'(1) << S4_BIT  ,   // COMWAKE transmission state
    HR_AWAITCOMWAKE     = STATE_W'(1) << S5_BIT  ,   // Await COMWAKE state
    HR_AWAITNOCOMWAKE   = STATE_W'(1) << S6_BIT  ,   // Await no COMWAKE state
    HR_AWAITALIGN       = STATE_W'(1) << S7_BIT  ,   // Await ALIGN primitive state
    HR_ADJUSTSPEED      = STATE_W'(1) << S8_BIT  ,   // Speed adjustment state
    HR_SENDALIGN        = STATE_W'(1) << S9_BIT  ,   // Send ALIGN primitive state
    HR_READY            = STATE_W'(1) << S10_BIT ,   // Link ready state
    HR_PARTIAL          = STATE_W'(1) << S11_BIT ,   // Partial power mode state
    HR_SLUMBER          = STATE_W'(1) << S12_BIT     // Slumber power mode state
}state_t;

state_t state_c;    // Current state register
state_t state_n;    // Next state register

// State register update (synchronous)
always_ff@(posedge rx_clk or negedge rst_n)begin
    if(!rst_n)
        state_c <= HR_RESET;
    else
        state_c <= state_n;
end

// Next state logic (combinational)
always_comb begin
    case (1)
        state_c[S0_BIT]:begin//HR_RESET
            if(hr_reset2hr_awaitcominit)
                state_n = HR_AWAITCOMINIT;
            else
                state_n = state_c;
        end
        state_c[S1_BIT]:begin//HR_AWAITCOMINIT
            if(hr_awaitcominit2hr_awaitnocominit)
                state_n = HR_AWAITNOCOMINIT;
            else if(hr_awaitcominit2hr_reset)
                state_n = HR_RESET;
            else
                state_n = state_c;
        end
        state_c[S2_BIT]:begin//HR_AWAITNOCOMINIT
            if(hr_awaitnocominit2hr_cailbrate)
                state_n = HR_CAILBRATE;
            else
                state_n = state_c;
        end
        state_c[S3_BIT]:begin//HR_CAILBRATE
            if(hr_cailbrate2hr_comwake)
                state_n = HR_COMWAKE;
            else
                state_n = state_c;
        end
        state_c[S4_BIT]:begin//HR_COMWAKE
            if(hr_comwake2hr_awaitcomwake)
                state_n = HR_AWAITCOMWAKE;
            else if(hr_comwake2hr_awaitnocomwake)
                state_n = HR_AWAITNOCOMWAKE;
            else 
                state_n = state_c;
        end
        state_c[S5_BIT]:begin//HR_AWAITCOMWAKE
            if(hr_awaitcomwake2hr_awaitnocomwake)
                state_n = HR_AWAITNOCOMWAKE;
            else if(hr_awaitcomwake2hr_comwake2hr)
                state_n = HR_COMWAKE;
            else
                state_n = state_c;
        end
        state_c[S6_BIT]:begin//HR_AWAITNOCOMWAKE
            if(hr_awaitnocomwake2Hr_awaitalign)
                state_n = HR_AWAITALIGN;
            else
                state_n = state_c;
        end
        state_c[S7_BIT]:begin//HR_AWAITALIGN
            if(hr_awaitalign2hr_adjustspeed)
                state_n = HR_ADJUSTSPEED;
            else if(hr_awaitalign2hr_reset)
                state_n = HR_RESET;
            else
                state_n = state_c;
        end
        state_c[S8_BIT]:begin//HR_ADJUSTSPEED
            if(hr_adjustspeed2hr_sendalign)
                state_n = HR_SENDALIGN;
            else
                state_n = state_c;
        end
        state_c[S9_BIT]:begin//HR_SENDALIGN
            if(hr_sendalign2hr_ready)
                state_n = HR_READY;
            else
                state_n = state_c;
        end
        state_c[S10_BIT]:begin//HR_READY
            if(hr_ready2partial)
                state_n = HR_PARTIAL;
            else if(hr_ready2slumber)
                state_n = HR_SLUMBER;
            else
                state_n = state_c;
        end
        state_c[S11_BIT]:begin//HR_PARTIAL
            state_n = state_c;//reserve
        end
        state_c[S12_BIT]:begin//HR_SLUMBER
            state_n = state_c;//reserve
        end
        default: begin
            state_n = HR_RESET;
        end
    endcase
end

// State transition conditions
assign hr_reset2hr_awaitcominit            = state_c == HR_RESET          && (end_send_comreset);
assign hr_awaitcominit2hr_awaitnocominit   = state_c == HR_AWAITCOMINIT   && (rx_cominit       );
assign hr_awaitcominit2hr_reset            = state_c == HR_AWAITCOMINIT   && (end_cnt_timeout  );
assign hr_awaitnocominit2hr_cailbrate      = state_c == HR_AWAITNOCOMINIT && (~rx_cominit      );
assign hr_cailbrate2hr_comwake             = state_c == HR_CAILBRATE      && (1'b1             );
assign hr_comwake2hr_awaitcomwake          = state_c == HR_COMWAKE        && (~rx_comwake      ) && end_send_comwake;
assign hr_comwake2hr_awaitnocomwake        = state_c == HR_COMWAKE        && (rx_comwake       );
assign hr_awaitcomwake2hr_awaitnocomwake   = state_c == HR_AWAITCOMWAKE   && (rx_comwake       );
assign hr_awaitcomwake2hr_comwake2hr       = state_c == HR_AWAITCOMWAKE   && (end_cnt_timeout  );
assign hr_awaitnocomwake2Hr_awaitalign     = state_c == HR_AWAITNOCOMWAKE && (~rx_comwake      );
assign hr_awaitalign2hr_adjustspeed        = state_c == HR_AWAITALIGN     && (dec_align_code   );
assign hr_awaitalign2hr_reset              = state_c == HR_AWAITALIGN     &&  end_cnt_atimer    ;
assign hr_adjustspeed2hr_sendalign         = state_c == HR_ADJUSTSPEED    && (1'b1             );
assign hr_sendalign2hr_ready               = state_c == HR_SENDALIGN      && (rev_align_seq    );
assign hr_ready2partial                    = state_c == HR_READY          &&  partial           ;
assign hr_ready2slumber                    = state_c == HR_READY          &&  slumber           ;

//--------------------------- COMPULSE ---------------------------//
// COM sequence counter for COMINIT/COMWAKE transmission
always_ff @(posedge rx_clk or negedge rst_n)begin
    if(!rst_n)begin
        cnt_com <= 'd0;
    end
    else if(add_cnt_com)begin
        if(end_cnt_com)
            cnt_com <= 'd0;
        else
            cnt_com <= cnt_com + 1'b1;
    end
end
assign add_cnt_com = (state_c == HR_RESET) || (state_c == HR_COMWAKE);
assign end_cnt_com = add_cnt_com && cnt_com == ((state_c == HR_RESET) ? 1000 : 200) - 1 ;

//--------------------------- HR_RESET ---------------------------//
// COMINIT signal generation during reset state
assign send_comreset     = (state_c == HR_RESET);
assign end_send_comreset = end_cnt_com;
assign tx_cominit        = send_comreset;

//--------------------------- HR_COMWAKE ---------------------------//
// COMWAKE signal generation
assign send_comwake      = (state_c == HR_COMWAKE);
assign end_send_comwake  = end_cnt_com           ;
assign tx_comwake        = send_comwake           ;

// Primitive decoding logic
assign dec_align_code = (rx_charisk == 4'b1000) && rx_data == 32'hBC4A4A7B;  // ALIGN primitive detection
assign dec_sync_code  = (rx_charisk == 4'b1000) && rx_data == 32'h7C95B5B5;  // SYNC primitive detection

// Hard reset generation based on ALIGN/SYNC detection
always_ff @(posedge rx_clk or negedge rst_n)begin
    if(!rst_n)
        hr_reset <= 'd0;
    else if((state_c == HR_SENDALIGN) && (~dec_align_code) && (~dec_sync_code))
        hr_reset <= 'd1;
end

// ALIGN primitive counter for sequence verification
always_ff @(posedge rx_clk or negedge rst_n)begin
    if(!rst_n)begin
        cnt_alignp <= 'd0;
    end
    else if(add_cnt_alignp)begin
        if(end_cnt_alignp)
            cnt_alignp <= 'd0;
        else
            cnt_alignp <= cnt_alignp + 1'b1;
    end
    else begin
        cnt_alignp <= 'd0;
    end
end
assign add_cnt_alignp = (state_c == HR_SENDALIGN) && dec_sync_code;
assign end_cnt_alignp = add_cnt_alignp && cnt_alignp ==  3 - 1;

assign rev_align_seq  = end_cnt_alignp;

//--------------------------- RECV TIMEOUT ---------------------------//
// Timeout counter for link state transitions
always_ff @(posedge rx_clk or negedge rst_n)begin
    if(!rst_n)begin
        cnt_timeout <= 'd0;
    end
    else if(add_cnt_timeout)begin
        if(end_cnt_timeout)
            cnt_timeout <= 'd0;
        else
            cnt_timeout <= cnt_timeout + 1'b1;
    end
    else begin
        cnt_timeout <= 'd0;
    end
end
assign add_cnt_timeout = (state_c == HR_AWAITCOMINIT) || (state_c == HR_AWAITCOMWAKE);
assign end_cnt_timeout = add_cnt_timeout && cnt_timeout == timeout_time - 1;

//--------------------------- HR_AWAITALIGN ---------------------------//
// Microsecond timer for ALIGN detection window
always_ff @(posedge rx_clk or negedge rst_n)begin
    if(!rst_n)begin
        cnt_us <= 'd0;
    end
    else if(add_cnt_us)begin
        if(end_cnt_us)
            cnt_us <= 'd0;
        else
            cnt_us <= cnt_us + 1'b1;
    end
    else begin
        cnt_us <= 'd0;
    end
end
assign add_cnt_us = (state_c == HR_AWAITALIGN);
assign end_cnt_us = add_cnt_us && cnt_us == US_CYCLE- 1;


// ALIGN timer for synchronization sequence
always_ff @(posedge rx_clk or negedge rst_n)begin
    if(!rst_n)begin
        cnt_atimer <= 'd0;
    end
    else if(add_cnt_atimer)begin
        if(end_cnt_atimer)
            cnt_atimer <= 'd0;
        else
            cnt_atimer <= cnt_atimer + 1'b1;
    end
end
assign add_cnt_atimer = (state_c == HR_AWAITALIGN) && end_cnt_us;
assign end_cnt_atimer = add_cnt_atimer && cnt_atimer == 874 - 1;

// State tracking signals for receive domain
logic rx_state_c_hr_awaitalign;
logic rx_state_c_hr_sendalign;
logic [1:0]tx_state_c_hr_awaitalign;
logic [1:0]tx_state_c_hr_sendalign;


always_ff @(posedge rx_clk or negedge rst_n)begin
    if(!rst_n)
        rx_state_c_hr_awaitalign <= 'd0;
    else if((state_c == HR_AWAITALIGN) || (state_c == HR_ADJUSTSPEED))
        rx_state_c_hr_awaitalign <= 'd1;
    else
        rx_state_c_hr_awaitalign <= 'd0;
end

always_ff @(posedge rx_clk or negedge rst_n)begin
    if(!rst_n)
        rx_state_c_hr_sendalign <= 'd0;
    else if(state_c == HR_SENDALIGN)
        rx_state_c_hr_sendalign <= 'd1;
    else
        rx_state_c_hr_sendalign <= 'd0;
end

//--------------------------- TX DOMAIN ---------------------------//
// Transmit domain state tracking for clock domain crossing
always_ff @(posedge tx_clk or negedge rst_n)begin
    if(!rst_n)
        tx_state_c_hr_awaitalign <= 'd0;
    else
        tx_state_c_hr_awaitalign <= {tx_state_c_hr_awaitalign[0],state_c[S7_BIT]};
end

always_ff @(posedge tx_clk or negedge rst_n)begin
    if(!rst_n)
        tx_state_c_hr_sendalign <= 'd0;
    else
        tx_state_c_hr_sendalign <= {tx_state_c_hr_sendalign[0],state_c[S8_BIT] || state_c[S9_BIT]};
end


// Transmit data generation based on current state
always_comb begin
    if(tx_state_c_hr_awaitalign[1])begin //transmit D10.2
        tx_charisk <= 4'b0000;
        tx_data    <= 32'h4A4A4A4A;//D10.2 primitive for ALIGN detection
    end
    else if(tx_state_c_hr_sendalign[1])begin //send ALIGNp
        tx_charisk <= 4'b1000;
        tx_data    <= 32'hBC4A4A7B;//K,D,D,D ALIGN primitive
    end
    else begin
        tx_charisk <=  datchar_i;
        tx_data    <=  dat_i    ;
    end
end

//--------------------------- LINK ---------------------------//
//function :phy to link pin
//output   :
//describe :

// PHY ready signal generation
always_ff @(posedge rx_clk or negedge rst_n)begin
    if(!rst_n)
        phyrdy <= 'd0;
    else if(state_c == HR_READY)
        phyrdy <= 'd1;
    else
        phyrdy <= 'd0;
end


// Link layer interface signals
assign dat_o         = rx_data          ;   // Pass received data to link layer
assign datchar_o     = rx_charisk       ;   // Pass received character info to link layer
assign cominit       = rx_cominit       ;   // Pass COMINIT detection to link layer
assign comwake       = rx_comwake       ;   // Pass COMWAKE detection to link layer
assign comma         = dec_align_code   ;   // Pass comma detection to link layer
assign device_detect = rx_eleidle       ;   // Pass device detection to link layer

assign rxclock = rx_clk;                    // Output receive clock

// Unused signals with default assignments
assign spdmode = 'd0;
assign phy_internal_err = 'd0;

endmodule