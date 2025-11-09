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
Description     : This module implements the write data path control logic for a SATA link layer. 
                  It handles the state machine for write operations, including SOF, data transfer, 
                  CRC calculation, EOF, and wait states. The module interfaces with the PHY layer 
                  for data transfer and with the arbiter for write request and completion signaling.
=======================================UPDATE HISTPRY==========================================
Modified by     : 
Modified date   : 
Version         : 
Description     : 
******************************Licensed under the GPL-3.0 License******************************/
`include "sata_wrapper_define.svh"

module sata_link_wrmod_dev #(
    parameter USER_W = 8
)(
    /**** clk/rst ****/
    input   logic                           clk             ,
    input   logic                           rst_n           ,

    /**** phy ****/
    input   logic                           phyrdy          ,

    /**** arbiter ****/
    input   logic                           wr_req          ,
    output  logic                           wr_cpl          ,
    output  logic                           wr_no_busy      ,

    input   logic                           roll_insert     ,

    input   logic       [31         :0]     s_aixs_tdata    ,
    input   logic       [USER_W   -1:0]     s_aixs_tuser    ,//{drop,err,keep[3:0],sop,eop}
    input   logic                           s_aixs_tvalid   ,
    output  logic                           s_aixs_tready   ,                   

    /**** rx link dat ****/
    input   sata_p_t                        rx_dat_type     ,
    input   logic       [32       -1:0]     rx_dat          ,
    input   logic       [4        -1:0]     rx_char         ,

    /**** tx link dat ****/
    output  sata_p_t                        tx_dat_type     ,
    output  logic       [32       -1:0]     tx_dat          ,
    output  logic       [4        -1:0]     tx_char          
);

logic                 dat_unvld           ;
logic                 dat_vld             ;
logic                 nocommerr           ;
logic                 sync_idle           ;
logic                 link_ignor_p        ;

logic                 end_write           ;

logic [32       -1:0] crc_result          ;

logic                 roll_insert_r       ;
logic                 roll_insert_pause   ;

logic                 idl2dl_send_ck_s    ;
logic                 dl_send_ck2sof_s    ;
logic                 dl_send_ck2idle_s   ;
logic                 sendsof2senddata_s  ;
logic                 sendsof2idl_s       ;
logic                 senddat2rcvrhold_s  ;
logic                 senddat2sendhold_s  ;
logic                 senddat2sendcrc_s   ;
logic                 senddat2idl_s       ;
logic                 rcvrhold2senddat_s  ;
logic                 rcvrhold2idl_s      ;
logic                 sendhold2senddat_s  ;   
logic                 sendhold2rcvrhold_s ;
logic                 sendhold2sendcrc_s  ;
logic                 sendhold2idl_s      ;
logic                 sendcrc2sendeof_s   ;    
logic                 sendcrc2idl_s       ;
logic                 sendeof2wait_s      ;
logic                 sendeof2idl_s       ;
logic                 wait2idl_s          ;

// output declaration of module sata_link_crc
logic [32       -1:0] crc_data_in         ;
logic                 crc_init            ;
logic                 crc_en              ;
logic [32       -1:0] crc_out             ;

localparam STATE_W = 9;

localparam  S0_BIT      = 'd0  ,
            S1_BIT      = 'd1  ,
            S2_BIT      = 'd2  ,
            S3_BIT      = 'd3  ,
            S4_BIT      = 'd4  ,
            S5_BIT      = 'd5  ,
            S6_BIT      = 'd6  ,
            S7_BIT      = 'd7  ,
            S8_BIT      = 'd8  ;

typedef enum logic [STATE_W-1:0]{
    S0_IDLE             = STATE_W'(1) << S0_BIT    ,
    S1_LT3_SENDSOF      = STATE_W'(1) << S1_BIT    ,
    S2_LT4_SENDDATA     = STATE_W'(1) << S2_BIT    ,
    S3_LT5_RCVRHOLD     = STATE_W'(1) << S3_BIT    ,
    S4_LT6_SENDHOLD     = STATE_W'(1) << S4_BIT    ,
    S5_LT7_SENDCRC      = STATE_W'(1) << S5_BIT    ,
    S6_LT8_SENDEOF      = STATE_W'(1) << S6_BIT    ,
    S7_LT9_WAIT         = STATE_W'(1) << S7_BIT    ,
    S8_DL_SEND_CHK_RDY  = STATE_W'(1) << S8_BIT     
}state_t;

state_t state_c;
state_t state_n;

always_ff@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        state_c <= S0_IDLE;
    else
        state_c <= state_n;
end

always_comb begin
    case (1)
        state_c[S0_BIT]:begin //S0_IDLE
            if(idl2dl_send_ck_s)
                state_n = S8_DL_SEND_CHK_RDY;
            else
                state_n = state_c;
        end
        state_c[S8_BIT]:begin
            if(dl_send_ck2sof_s) //S8_DL_SEND_CHK_RDY
                state_n = S1_LT3_SENDSOF;
            else if(dl_send_ck2idle_s)
                state_n = S0_IDLE;
            else
                state_n = state_c;
        end
        state_c[S1_BIT]:begin //S1_LT3_SENDSOF
            if(sendsof2idl_s)
                state_n = S0_IDLE;
            else if(sendsof2senddata_s)
                state_n = S2_LT4_SENDDATA;
            else
                state_n = state_c;
        end
        state_c[S2_BIT]:begin //S2_LT4_SENDDATA
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
        state_c[S3_BIT]:begin //S3_LT5_RCVRHOLD
            if(rcvrhold2idl_s)
                state_n = S0_IDLE;
            else if(rcvrhold2senddat_s)
                state_n = S2_LT4_SENDDATA;
            else
                state_n = state_c;
        end
        state_c[S4_BIT]:begin //S4_LT6_SENDHOLD
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
        state_c[S5_BIT]:begin //S5_LT7_SENDCRC
            if(sendcrc2idl_s)
                state_n = S0_IDLE;
            else if(sendcrc2sendeof_s)
                state_n = S6_LT8_SENDEOF;
            else
                state_n = state_c;
        end
        state_c[S6_BIT]:begin //S6_LT8_SENDEOF
            if(sendeof2idl_s)
                state_n = S0_IDLE;
            else if(sendeof2wait_s)
                state_n = S7_LT9_WAIT;
            else
                state_n = state_c;
        end
        state_c[S7_BIT]:begin //S7_LT9_WAIT
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
assign idl2dl_send_ck_s     = (state_c == S0_IDLE        ) && wr_req;
assign dl_send_ck2sof_s     = (state_c == S8_DL_SEND_CHK_RDY) && wr_req && phyrdy && (rx_dat_type == r_rdy) && dat_vld;
assign dl_send_ck2idle_s    = (state_c == S8_DL_SEND_CHK_RDY) && (~phyrdy);
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

assign nocommerr    = (~phyrdy) && (state_c != S0_IDLE);
assign sync_idle    = (rx_dat_type == sync ) && (state_c != S0_IDLE);
assign link_ignor_p = (rx_dat_type == align) && (state_c == S0_IDLE);
assign dat_vld      =  s_aixs_tvalid;
assign dat_unvld    = (~s_aixs_tvalid);
assign end_write    = s_aixs_tvalid && s_aixs_tready && s_aixs_tuser[0];

assign roll_insert_pause   =  roll_insert    || roll_insert_r;

assign s_aixs_tready = ((state_c == S2_LT4_SENDDATA) && (rx_dat_type != hold)) && (~roll_insert_pause);

assign wr_no_busy    = (dl_send_ck2idle_s || sendsof2idl_s || senddat2idl_s || rcvrhold2idl_s || sendhold2idl_s || sendcrc2idl_s || sendeof2idl_s || wait2idl_s);

always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        tx_dat_type <=  x_rdy ;
        tx_dat      <= `X_RDYp;
        tx_char     <= 'b1000 ;
    end
    else if(roll_insert_pause)begin
        tx_dat_type <= align;
        tx_dat      <= `ALIGNp;
        tx_char     <= 'b1000;
    end
    else unique case(state_c)
        S0_IDLE:begin
            tx_dat_type <=  x_rdy ;
            tx_dat      <= `X_RDYp;
            tx_char     <= 'b1000 ;
        end
        S8_DL_SEND_CHK_RDY:begin
            tx_dat_type <=  x_rdy ;
            tx_dat      <= `X_RDYp;
            tx_char     <= 'b1000 ;
        end
        S1_LT3_SENDSOF:begin
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
        S2_LT4_SENDDATA:begin
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
        S3_LT5_RCVRHOLD:begin
            tx_dat_type <=  holda ;
            tx_dat      <= `HOLDAp;
            tx_char     <= 'b1000 ;
        end
        S4_LT6_SENDHOLD:begin
            tx_dat_type <=  hold  ;
            tx_dat      <= `HOLDp ;
            tx_char     <= 'b1000 ;
        end
        S5_LT7_SENDCRC:begin
            tx_dat_type <= is_crc     ;
            tx_dat      <= crc_result ;
            tx_char     <= 'b0000     ;
        end
        S6_LT8_SENDEOF:begin
            tx_dat_type <=  eof       ;
            tx_dat      <= `EOFp      ;
            tx_char     <= 'b1000     ;
        end
        S7_LT9_WAIT:begin
            tx_dat_type <=  wtrm      ;
            tx_dat      <= `WTRMp     ;
            tx_char     <= 'b1000     ;
        end
        default:begin
            tx_dat_type <=  sync ;
            tx_dat      <= `SYNCp;
            tx_char     <= 'b1000;
        end
    endcase
end

always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        wr_cpl <= 'd0;
    else if(wait2idl_s | ((nocommerr | sync_idle) && (state_c != S0_IDLE) && (state_c != S0_IDLE) && (state_c != S8_DL_SEND_CHK_RDY)))
        wr_cpl <= 'd1;
    else
        wr_cpl <= 'd0;
end

always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        roll_insert_r  <= 'd0;
    end
    else begin
        roll_insert_r  <= roll_insert  ;
    end
end

sata_link_crc u_sata_link_crc(
    .data_in  	(crc_data_in    ),
    .crc_init 	(crc_init       ),
    .crc_en   	(crc_en         ),
    .crc_out  	(crc_out        ),
    .rst_n    	(rst_n          ),
    .clk      	(clk            )
);

assign crc_data_in = s_aixs_tdata;
assign crc_en      = s_aixs_tvalid && s_aixs_tready;
assign crc_result  = crc_out;
assign crc_init    = (state_c == S1_LT3_SENDSOF );

endmodule