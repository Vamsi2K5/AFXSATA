/******************************************Copyright@2025**************************************
                                    AdriftXCore  ALL rights reserved
                        https://github.com/AdriftXCore https://gitee.com/adriftxcore
=========================================FILE INFO.============================================
FILE Name       : sata_bist.sv
Last Update     : 2025/11/25 11:54:28
Latest Versions : 1.0
========================================AUTHOR INFO.===========================================
Created by      : zhanghx
Create date     : 2025/11/25 11:54:28
Version         : 1.0
Description     : SATA Built-In Self-Test module for generating test patterns and verifying data integrity
=======================================UPDATE HISTPRY==========================================
Modified by     : 
Modified date   : 
Version         : 
Description     : 
******************************Licensed under the GPL-3.0 License******************************/
module sata_bist #(
    parameter CYCLE = 150000000
)(
    input   logic                           clk                 ,
    input   logic                           rst_n               ,

    input   logic  [32               -1:0]  level               ,
    input   logic  [2                -1:0]  speed_test          ,//0,no_speed_test;1,write test;2,read test
    input   logic                           mode                ,//0,normal 1,trig
    input   logic                           tirg                ,
    input   logic  [32               -1:0]  cycle               ,
    input   logic  [22               -1:0]  num                 ,//dw
    input   logic  [48               -1:0]  addr                ,
    input   logic                           enable              ,

    output  logic  [31                 :0]  second_timer        ,

    output  logic  [31                 :0]  err_cnt             ,
    output  logic  [31                 :0]  wr_cnt_sop          ,
    output  logic  [31                 :0]  wr_cnt_eop          ,
    output  logic  [31                 :0]  rd_cnt_sop          ,
    output  logic  [31                 :0]  rd_cnt_eop          ,

    output  logic  [71               -1:0]  cmd_dat             ,
    output  logic                           cmd_wr              ,
    output  logic                           cmd_req             ,
    input   logic                           cmd_ack             ,

    input   logic  [31                 :0]  s_axis_sbt_tdata    ,//{RW,len[15:0],addr[47:0]}
    input   logic  [8                -1:0]  s_axis_sbt_tuser    ,//{drop,err,keep[3:0],sop,eop}
    input   logic                           s_axis_sbt_tvalid   ,
    output  logic                           s_axis_sbt_tready   ,

    output  logic  [31                 :0]  m_axis_sbt_tdata    ,
    output  logic  [8                -1:0]  m_axis_sbt_tuser    ,//{drop,err,keep[3:0],sop,eop}
    output  logic                           m_axis_sbt_tvalid   ,
    input   logic                           m_axis_sbt_tready    
);

logic [32   -1:0]   cnt_w       ;
logic               add_cnt_w   ;
logic               end_cnt_w   ;

logic [32   -1:0]   cnt_wc      ;
logic               add_cnt_wc  ;
logic               end_cnt_wc  ;

logic [32   -1:0]   cnt_r       ;
logic               add_cnt_r   ;
logic               end_cnt_r   ;

logic [32   -1:0]   cnt_rc      ;
logic               add_cnt_rc  ;
logic               end_cnt_rc  ;

logic               w_done      ;
logic               r_done      ;

logic [32   -1:0]   cycle_r     ;
logic [22   -1:0]   num_r       ;//dw
logic               enable_r    ;
logic [48   -1:0]   addr_r      ;
logic [48   -1:0]   waddr_c     ;
logic [48   -1:0]   raddr_c     ;
logic [32   -1:0]   wdata_t     ;
logic [32   -1:0]   rdata_t     ;

logic [23   -1:0]   len         ;
logic               check_err   ;

logic               tirg_r      ;
logic [32   -1:0]   timer       ;

logic               press       ;
logic               pause       ;

assign len = {num_r[20:0],2'd0};

always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        enable_r <= 'd0;
    else
        enable_r <= enable;
end

always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        tirg_r <= 'd0;
    else
        tirg_r <= tirg;
end

always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        cycle_r  <= 'd0;
        num_r    <= 'd0;
        addr_r   <= 'd0;
    end
    else if({enable_r,enable} == 2'b01)begin
        cycle_r  <= (cycle==0) ? 32'd1 : cycle ;
        num_r    <= (num==0  ) ? 16'd1 : num   ;
        addr_r   <= addr;
    end
end

localparam STATE_W = 8;

localparam  S0_BIT      = 'd0  ,
            S1_BIT      = 'd1  ,
            S2_BIT      = 'd2  ,
            S3_BIT      = 'd3  ,
            S4_BIT      = 'd4  ;

typedef enum logic [STATE_W -1:0]{
    IDLE             = STATE_W'(1) << S0_BIT    ,
    WRITE_DMA        = STATE_W'(1) << S1_BIT    ,
    READ_DMA         = STATE_W'(1) << S2_BIT    ,
    WRITE_REQ        = STATE_W'(1) << S3_BIT    ,
    READ_REQ         = STATE_W'(1) << S4_BIT     
}state_t;

state_t state_c;
state_t state_n;

always_ff@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        state_c <= IDLE;
    else
        state_c <= state_n;
end

always_comb begin
    case(1)
        state_c[S0_BIT]:begin //IDLE
            if(enable && (speed_test==2))
                state_n = READ_REQ;
            else if(enable && (~mode))
                state_n = WRITE_REQ;
            else if(enable && mode && ({tirg_r,tirg} == 2'b01))
                state_n = WRITE_REQ;
            else
                state_n = state_c;
        end
        state_c[S1_BIT]:begin //WRITE_DMA
            if((speed_test == 2'd1) && w_done)
                state_n = WRITE_REQ;
            else if((speed_test == 2'd0) && w_done)
                state_n = READ_REQ;
            else if(end_cnt_w)
                state_n = WRITE_REQ;
            else
                state_n = state_c;
        end
        state_c[S2_BIT]:begin //READ_DMA
            if((speed_test == 2'd2) && r_done)
                state_n = READ_REQ;
            else if((speed_test == 2'd0) && r_done)
                state_n = IDLE;
            else if(end_cnt_r)
                state_n = READ_REQ;
            else
                state_n = state_c;
        end
        state_c[S3_BIT]:begin //WRITE_REQ
            if(cmd_req && cmd_ack)
                state_n = WRITE_DMA;
            else
                state_n = state_c;
        end
        state_c[S4_BIT]:begin //READ_REQ
            if(cmd_req && cmd_ack)
                state_n = READ_DMA;
            else
                state_n = state_c;
        end
    endcase
end

always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        cnt_w <= 0;
    end
    else if(add_cnt_w)begin
        if(end_cnt_w)
            cnt_w <= 0;
        else
            cnt_w <= cnt_w + 1'b1;
    end
end
assign add_cnt_w = (state_c == WRITE_DMA) && m_axis_sbt_tvalid && m_axis_sbt_tready;
assign end_cnt_w = add_cnt_w && cnt_w == num_r - 1'b1;

always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        cnt_wc <= 0;
    end
    else if(add_cnt_wc)begin
        if(end_cnt_wc)
            cnt_wc <= 0;
        else
            cnt_wc <= cnt_wc + 1'b1;
    end
end
assign add_cnt_wc = end_cnt_w;
assign end_cnt_wc = add_cnt_wc && cnt_wc == cycle_r - 1'b1;

assign w_done = end_cnt_wc;

always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        waddr_c <= 'd0;
    else if({enable_r,enable} == 2'b01)
        waddr_c <= addr;
    else if(end_cnt_wc)
        waddr_c <= addr_r;
    else if(end_cnt_w)
        waddr_c <= waddr_c + ((len==0) ? {1'b1,len} : len);
end

always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        cnt_r <= 0;
    end
    else if(add_cnt_r)begin
        if(end_cnt_r)
            cnt_r <= 0;
        else
            cnt_r <= cnt_r + 1'b1;
    end
end
assign add_cnt_r = (state_c == READ_DMA) && s_axis_sbt_tvalid && s_axis_sbt_tready;
assign end_cnt_r = add_cnt_r && cnt_r == num_r - 1'b1;


always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        cnt_rc <= 0;
    end
    else if(add_cnt_rc)begin
        if(end_cnt_rc)
            cnt_rc <= 0;
        else
            cnt_rc <= cnt_rc + 1'b1;
    end
end
assign add_cnt_rc = end_cnt_r;
assign end_cnt_rc = add_cnt_rc && cnt_rc == cycle_r - 1;

assign r_done = end_cnt_rc;

always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        raddr_c <= 'd0;
    else if({enable_r,enable} == 2'b01)
        raddr_c <= addr;
    else if(end_cnt_rc)
        raddr_c <= addr_r;
    else if(end_cnt_r)
        raddr_c <= raddr_c + ((len==0) ? {1'b1,len} : len);
end

always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        cmd_dat <= 'd0;
        cmd_wr  <= 'd0;
        cmd_req <= 'd0;
    end
    else if(state_c == WRITE_REQ)begin
        if(cmd_req && cmd_ack)begin
            cmd_dat <= 'd0;
            cmd_wr  <= 'd0;
            cmd_req <= 'd0;
        end
        else begin
            cmd_dat <= {len,waddr_c};
            cmd_wr  <= 'd0;
            cmd_req <= 'd1;
        end
    end
    else if(state_c == READ_REQ)begin
        if(cmd_req && cmd_ack)begin
            cmd_dat <= 'd0;
            cmd_wr  <= 'd0;
            cmd_req <= 'd0;
        end
        else begin
            cmd_dat <= {len,raddr_c};
            cmd_wr  <= 'd1;
            cmd_req <= 'd1;
        end
    end
end

assign wdata_t = cnt_w + cnt_wc;
assign m_axis_sbt_tdata     = {16'ha5a5,wdata_t[15:0]};
assign m_axis_sbt_tvalid    = (state_c == WRITE_DMA) && pause;
assign m_axis_sbt_tuser[1]  = (cnt_w == 0);
assign m_axis_sbt_tuser[0]  =  end_cnt_w;
assign m_axis_sbt_tuser[2+:4]= 4'b1111;
assign m_axis_sbt_tuser[6+:2]= 2'b00;

assign rdata_t = cnt_r + cnt_rc;
assign s_axis_sbt_tready = (state_c == READ_DMA) && press;

always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        check_err <= 'd0;
    else if(s_axis_sbt_tvalid && s_axis_sbt_tready && (s_axis_sbt_tdata != {16'ha5a5,rdata_t[15:0]}))
        check_err <= 'd1;
    else
        check_err <= 'd0;
end

always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        err_cnt <= 'd0;
    else if({enable_r,enable} == 2'b01)
        err_cnt <= 'd0;
    else if(check_err && (speed_test == 0))
        err_cnt <= err_cnt + 1'b1;
end

always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        wr_cnt_sop <= 'd0;
    else if({enable_r,enable} == 2'b01)
        wr_cnt_sop <= 'd0;
    else if(m_axis_sbt_tvalid && m_axis_sbt_tready && m_axis_sbt_tuser[1])
        wr_cnt_sop <= wr_cnt_sop + 1'b1;
end

always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        wr_cnt_eop <= 'd0;
    else if({enable_r,enable} == 2'b01)
        wr_cnt_eop <= 'd0;
    else if(m_axis_sbt_tvalid && m_axis_sbt_tready && m_axis_sbt_tuser[0])
        wr_cnt_eop <= wr_cnt_eop + 1'b1;
end

always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        rd_cnt_sop <= 'd0;
    else if({enable_r,enable} == 2'b01)
        rd_cnt_sop <= 'd0;
    else if(s_axis_sbt_tvalid && s_axis_sbt_tready && s_axis_sbt_tuser[1])
        rd_cnt_sop <= rd_cnt_sop + 1'b1;
end

always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        rd_cnt_eop <= 'd0;
    else if({enable_r,enable} == 2'b01)
        rd_cnt_eop <= 'd0;
    else if(s_axis_sbt_tvalid && s_axis_sbt_tready && s_axis_sbt_tuser[0])
        rd_cnt_eop <= rd_cnt_eop + 1'b1;
end

always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        timer <= 'd0;
    else if({enable_r,enable} == 2'b01)
        timer <= 'd0;
    else if(timer == CYCLE - 1)
        timer <= 'd0;
    else if(enable)
        timer <= timer + 1'b1;
end

always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        second_timer <= 'd0;
    else if({enable_r,enable} == 2'b01)
        second_timer <= 'd0;
    else if(timer == CYCLE - 1)
        second_timer <= second_timer + 1;
end

sata_bist_lfsr  #(
    .SEED(32'hA54455D5 )
)
u_sata_bist_lfsr_press(
    .clk  (clk),
    .rst_n(rst_n),
    .pulse(press),
    .level(level)
);

sata_bist_lfsr  #(
    .SEED(32'h7545A536 )
)
u_sata_bist_lfsr_pause(
    .clk  (clk),
    .rst_n(rst_n),
    .pulse(pause),
    .level(level)
);


endmodule
