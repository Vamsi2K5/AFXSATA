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
Description     : sata_link_arbt.sv
=======================================UPDATE HISTPRY==========================================
Modified by     : 
Modified date   : 
Version         : 
Description     : 
******************************Licensed under the GPL-3.0 License******************************/
`include "sata_wrapper_define.svh"

module sata_link_arbt_dev(
    /**** clk/rst ****/
    input   logic                    clk         ,
    input   logic                    rst_n       ,

    /**** transport ****/
    input   logic                    rx_req      ,

    /**** link ****/
    input   sata_p_t                 rx_dat_type ,

    /**** phy ****/
    input   logic                    phyrdy      ,

    /**** arbt ****/
    input   logic                    roll_insert ,

    output  logic                    wr_req      ,
    input   logic                    wr_cpl      ,
    input   logic                    wr_no_busy  ,
    output  logic                    rd_req      ,
    input   logic                    rd_cpl      ,
    input   logic                    rd_no_busy   
);



// sate mechine signal
localparam STATE_W =  3;


localparam  IDLE_BIT    = 'd0 ,
            S1_BIT      = 'd1 ,
            S2_BIT      = 'd2 ;

typedef enum logic [STATE_W-1:0]{
    IDLE    = STATE_W'(1) << IDLE_BIT,
    WR      = STATE_W'(1) << S1_BIT  ,
    RD      = STATE_W'(1) << S2_BIT   
}state_t;

state_t state_c;
state_t state_n;

logic               idl2wr              ;
logic               idl2rd              ;
logic               wr2idl              ; 
logic               wr2rd               ;
logic               rd2idl              ;

// timer
logic [32     -1:0] cnt_timer           ;
logic               add_cnt_timer       ;
logic               end_cnt_timer       ;
logic               start_arbt          ;

logic               roll_insert_r       ;
logic               roll_insert_pause   ;

assign roll_insert_pause   =  roll_insert    || roll_insert_r;

always_ff@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        state_c <= IDLE;
    else
        state_c <= state_n;
end

always_comb begin
    case (1)
        state_c[IDLE_BIT]:begin//IDLE
            if(idl2wr)
                state_n = WR;
            else if(idl2rd)
                state_n = RD;
            else
                state_n = state_c;
        end
        state_c[S1_BIT]:begin//WR
            if(wr2rd)
                state_n = RD;
            else if(wr2idl)
                state_n = IDLE;
            else 
                state_n = state_c;

        end
        state_c[S2_BIT]:begin//RD
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

assign idl2wr = (state_c == IDLE) && (~roll_insert_pause) && start_arbt && phyrdy && rx_req                ; //Transport layer requests frame transmission and PHYRDY
assign idl2rd = (state_c == IDLE) && (~roll_insert_pause) && start_arbt && phyrdy && (rx_dat_type == x_rdy); //Transport layer requests frame transmission and 
assign wr2rd  = (state_c == WR  ) && wr_no_busy;
assign wr2idl = (state_c == WR  ) && wr_cpl;
assign rd2idl = (state_c == RD  ) && rd_cpl;

assign wr_req = (state_c == WR);
assign rd_req = (state_c == RD);

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
assign add_cnt_timer = !start_arbt;
assign end_cnt_timer = add_cnt_timer && cnt_timer == 150 - 1;

always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        start_arbt <= 'd0;
    else if(end_cnt_timer)
        start_arbt <= 'd1;
end

always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        roll_insert_r  <= 'd0;
    end
    else begin
        roll_insert_r  <= roll_insert  ;
    end
end

endmodule