/******************************************Copyright@2025**************************************
                                    AdriftXCore  ALL rights reserved
                        https://github.com/AdriftXCore https://gitee.com/adriftxcore
=========================================FILE INFO.============================================
FILE Name       : sata_transport_commond.sv
Last Update     : 2025/09/07 23:48:21
Latest Versions : 1.0
========================================AUTHOR INFO.===========================================
Created by      : zhanghx
Create date     : 2025/09/07 23:48:21
Version         : 1.0
Description     : SATA Transport Command Module - Handles command transmission and reception 
                  between the host and device. This module formats outgoing commands (H2D) and 
                  parses incoming responses (D2H) over the SATA transport layer.
=======================================UPDATE HISTPRY==========================================
Modified by     : 
Modified date   : 
Version         : 
Description     : 
******************************Licensed under the GPL-3.0 License******************************/
`include "sata_wrapper_define.svh"

// SATA Transport Command Module
// This module handles the transport layer command interface for SATA communications.
// It processes outgoing host-to-device (H2D) commands and incoming device-to-host (D2H) responses.
module sata_transport_command #(
    parameter USER_W   = 8,              // User data width for AXI Stream interface
    parameter BUFFER_W = 32 + USER_W     // Buffer width (data + user signals)
)(
    input    logic                     clk                  ,   // Clock signal
    input    logic                     rst_n                ,   // Reset signal (active low)


    input    logic  [31         :0]    s_aixs_link_tdata    ,   // Slave AXI Stream data input (link interface)
    input    logic  [USER_W   -1:0]    s_aixs_link_tuser    ,   // Slave AXI Stream user signals {drop,err,keep[3:0],sop,eop}
    input    logic                     s_aixs_link_tvalid   ,   // Slave AXI Stream valid signal
    output   logic                     s_aixs_link_tready   ,   // Slave AXI Stream ready signal

    output   logic  [31         :0]    m_aixs_link_tdata    ,   // Master AXI Stream data output (link interface)
    output   logic  [USER_W   -1:0]    m_aixs_link_tuser    ,   // Master AXI Stream user signals {drop,err,keep[3:0],sop,eop}
    output   logic                     m_aixs_link_tvalid   ,   // Master AXI Stream valid signal
    input    logic                     m_aixs_link_tready   ,   // Master AXI Stream ready signal

    input    cmd_t                     m_cmd                ,   // Master command input (H2D format)
    input    logic                     m_req                ,   // Master command request
    output   logic                     m_ack                ,   // Master command acknowledge

    output   cmd_t                     s_cmd                ,   // Slave command output (D2H format)
    output   logic                     s_req                ,   // Slave command request
    input    logic                     s_ack                 // Slave command acknowledge
);

// MFIS (Memory FIS) counter and control signals
logic  [3        -1:0]    cnt_mfis             ;   // Counter for MFIS words (0-4)
logic                     add_cnt_mfis         ;   // Increment MFIS counter
logic                     end_cnt_mfis         ;   // End of MFIS transmission

// SFIS (Status FIS) counter and control signals
logic  [3        -1:0]    cnt_sfis             ;   // Counter for SFIS words (0-3)
logic                     add_cnt_sfis         ;   // Increment SFIS counter
logic                     end_cnt_sfis         ;   // End of SFIS reception

// Registered AXI Stream signals for command transmission
logic  [31         :0]    r_m_aixs_link_tdata  ;   // Registered transmit data
logic  [USER_W   -1:0]    r_m_aixs_link_tuser  ;   // Registered transmit user signals {drop,err,keep[3:0],sop,eop}
logic                     r_m_aixs_link_tvalid ;   // Registered transmit valid signal

// Buffer status signals
logic                     slice_buffer_full    ;   // Buffer full flag
logic                     slice_buffer_tfull   ;   // Buffer almost full flag
logic                     slice_buffer_empty   ;   // Buffer empty flag

// MFIS counter logic
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        cnt_mfis <= 'd0;
    end
    else if(add_cnt_mfis)begin
        if(end_cnt_mfis)
            cnt_mfis <= 'd0;
        else
            cnt_mfis <= cnt_mfis + 1'b1;
    end
end
assign add_cnt_mfis = m_req && (~slice_buffer_full);
assign end_cnt_mfis = add_cnt_mfis && cnt_mfis == 5 - 1;

assign m_ack = end_cnt_mfis;

// Register valid signal for command transmission
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        r_m_aixs_link_tvalid <= 'd0;
    else
        r_m_aixs_link_tvalid <= add_cnt_mfis;
end

// Command data formatting based on MFIS counter
// Each case corresponds to one of the 5 DWORDs in a Host to Device Register FIS
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        r_m_aixs_link_tdata <= 'd0;
    end
    else case(cnt_mfis)
        // DWORD 0: FIS type, PM port, command, features
        3'd0:begin r_m_aixs_link_tdata <= {8'h27,8'h80,m_cmd.h2d.cmd,8'd0}                                                 ;r_m_aixs_link_tuser <= 'd2; end
        // DWORD 1: LBA low, LBA mid, LBA high, device register
        3'd1:begin r_m_aixs_link_tdata <= {m_cmd.h2d.lba[7: 0],m_cmd.h2d.lba[15: 8],m_cmd.h2d.lba[23: 16],m_cmd.h2d.device};r_m_aixs_link_tuser <= 'd0; end
        // DWORD 2: LBA extended, reserved
        3'd2:begin r_m_aixs_link_tdata <= {m_cmd.h2d.lba[31:24],m_cmd.h2d.lba[39:32],m_cmd.h2d.lba[47:40],8'd0            };r_m_aixs_link_tuser <= 'd0; end
        // DWORD 3: sector count, control register
        3'd3:begin r_m_aixs_link_tdata <= {m_cmd.h2d.count[7:0],m_cmd.h2d.count[15:8],8'd0,m_cmd.h2d.control              };r_m_aixs_link_tuser <= 'd0; end
        // DWORD 4: reserved (end of FIS)
        3'd4:begin r_m_aixs_link_tdata <= 32'd0                                                                            ;r_m_aixs_link_tuser <= 'd1; end
    endcase
end

// Skid buffer for command transmission
// This buffer helps with flow control between this module and the link layer
afx_skid_buffer #(
    .DW   (BUFFER_W      ),     // Data width: 32-bit data + user signals
    .DP   (3             )      // Depth parameter
)
u_afx_skid_buffer(
    .clk        (clk                                            ),      // Clock
    .rst_n      (rst_n                                          ),      // Reset (active low)
    .din        ({r_m_aixs_link_tdata,r_m_aixs_link_tuser}      ),      // Input data
    .push       (r_m_aixs_link_tvalid && (~slice_buffer_tfull)  ),      // Push data when valid and buffer not almost full
    .pop        (m_aixs_link_tready && (~slice_buffer_empty)    ),      // Pop data when downstream ready and buffer not empty
    .full       (slice_buffer_tfull                             ),      // Buffer almost full flag
    .afull      (slice_buffer_full                              ),      // Buffer full flag
    .dout       ({m_aixs_link_tdata,m_aixs_link_tuser}          ),      // Output data
    .empty      (slice_buffer_empty                             )       // Buffer empty flag
);

assign m_aixs_link_tvalid = ~slice_buffer_empty;

// SFIS counter logic for response processing
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        cnt_sfis <= 'd0;
    end
    else if(add_cnt_sfis)begin
        if(end_cnt_sfis)
            cnt_sfis <= 'd0;
        else
            cnt_sfis <= cnt_sfis + 1'b1;
    end
end
assign add_cnt_sfis = s_aixs_link_tvalid && s_aixs_link_tready;
assign end_cnt_sfis = add_cnt_sfis && s_aixs_link_tuser[0];

// Response data parsing based on SFIS counter
// Each case corresponds to one of the 4 DWORDs in a Device to Host Register FIS
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        s_cmd <= 'd0;
    else case(cnt_sfis)
        // DWORD 0: Status and error information
        3'd0:{s_cmd.d2h.status,s_cmd.d2h.error                                                } <= s_aixs_link_tdata[0 +: 16];
        // DWORD 1: LBA low, LBA mid, LBA high, device register
        3'd1:{s_cmd.d2h.lba[7 : 0],s_cmd.d2h.lba[15: 8],s_cmd.d2h.lba[23: 16],s_cmd.d2h.device} <= s_aixs_link_tdata;
        // DWORD 2: Extended LBA, reserved bits
        3'd2:{s_cmd.d2h.lba[31:24],s_cmd.d2h.lba[39:32],s_cmd.d2h.lba[47:40]                  } <= s_aixs_link_tdata[ 8 +: 24];
        // DWORD 3: Sector count
        3'd3:{s_cmd.d2h.count[7:0],s_cmd.d2h.count[15:8]                                      } <= s_aixs_link_tdata[16 +: 16];
    endcase
end

// Request signal generation for processed response
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        s_req <= 'd0;
    else if(end_cnt_sfis)
        s_req <= 'd1;
    else if(s_ack)
        s_req <= 'd0;
end

// Ready signal control for response reception
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        s_aixs_link_tready <= 'd1;
    else if(end_cnt_sfis)
        s_aixs_link_tready <= 'd0;
    else if(s_ack)
        s_aixs_link_tready <= 'd1;
end



endmodule