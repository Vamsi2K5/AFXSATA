/******************************************Copyright@2025**************************************
                                    AdriftXCore  ALL rights reserved
                        https://github.com/AdriftXCore https://gitee.com/adriftxcore
=========================================FILE INFO.============================================
FILE Name       : sata_transport_packet.sv
Last Update     : 2025/09/08 23:12:50
Latest Versions : 1.0
========================================AUTHOR INFO.===========================================
Created by      : zhanghx
Create date     : 2025/09/08 23:12:50
Version         : 1.0
Description     : SATA Transport Packet Module - Handles packet processing in the SATA transport 
                  layer. This module manages data flow between the link layer and transport layer,
                  including buffering, packet formation, and data stream control for DMA operations.
=======================================UPDATE HISTPRY==========================================
Modified by     : 
Modified date   : 
Version         : 
Description     : 
******************************Licensed under the GPL-3.0 License******************************/
module sata_transport_packet #(
    parameter USER_W = 8,               // User data width for AXI Stream interface
    parameter MBUFFER_W = 32 + USER_W + 1, // Master buffer width (data + user signals + valid flag)
    parameter SBUFFER_W = 32 + USER_W   // Slave buffer width (data + user signals)
)(
    input    logic                     clk                  ,   // Clock signal
    input    logic                     rst_n                ,   // Reset signal (active low)

    // Slave AXI Stream interface (from link layer)
    input    logic  [31         :0]    s_aixs_link_tdata    ,   // Slave data payload
    input    logic  [USER_W   -1:0]    s_aixs_link_tuser    ,   // Slave user signals {drop,err,keep[3:0],sop,eop}
    input    logic                     s_aixs_link_tvalid   ,   // Slave data valid signal
    output   logic                     s_aixs_link_tready   ,   // Slave ready signal

    // Master AXI Stream interface (to link layer)
    output   logic  [31         :0]    m_aixs_link_tdata    ,   // Master data payload
    output   logic  [USER_W   -1:0]    m_aixs_link_tuser    ,   // Master user signals {drop,err,keep[3:0],sop,eop}
    output   logic                     m_aixs_link_tvalid   ,   // Master data valid signal
    input    logic                     m_aixs_link_tready   ,   // Master ready signal

    /****** data-stream ******/
    // Data stream interface (to/from user application)
    input    logic  [31         :0]    s_aixs_trans_tdata   ,   // Slave data payload
    input    logic  [USER_W   -1:0]    s_aixs_trans_tuser   ,   // Slave user signals {drop,err,keep[3:0],sop,eop}
    input    logic                     s_aixs_trans_tvalid  ,   // Slave data valid signal
    output   logic                     s_aixs_trans_tready  ,   // Slave ready signal

    // Master data stream interface
    output   logic  [31         :0]    m_aixs_trans_tdata   ,   // Master data payload
    output   logic  [USER_W   -1:0]    m_aixs_trans_tuser   ,   // Master user signals {drop,err,keep[3:0],sop,eop}
    output   logic                     m_aixs_trans_tvalid  ,   // Master data valid signal
    input    logic                     m_aixs_trans_tready      // Master ready signal
);

// Internal signal declarations
logic                   s_link_sop              ;   // Start of packet flag for link interface
logic                   s_link_valid_mask       ;   // Valid mask for link data
logic                   s_link_valid            ;   // Valid signal for link data

logic                   slice_buffer_full       ;   // Slice buffer full flag
logic                   slice_buffer_empty      ;   // Slice buffer empty flag

logic  [31         :0]  s_aixs_trans_tdata_r    ;   // Registered transaction data
logic                   s_aixs_trans_tvalid_r   ;   // Registered transaction valid
logic  [USER_W   -1:0]  s_aixs_trans_tuser_r    ;   // Registered transaction user signals

// Slice buffer signals for master transaction interface
logic  [SBUFFER_W-1:0]  slice_buffer_mtrans_din  ;   // Slice buffer data input
logic                   slice_buffer_mtrans_push ;   // Slice buffer push signal
logic                   slice_buffer_mtrans_pop  ;   // Slice buffer pop signal
logic                   slice_buffer_mtrans_full ;   // Slice buffer full flag
logic                   slice_buffer_mtrans_empty;   // Slice buffer empty flag
logic  [SBUFFER_W-1:0]  slice_buffer_mtrans_dout ;   // Slice buffer data output

logic                   gearbox                  ;   // Gearbox control signal

logic  [32       -1:0]  cnt_mtrans               ;   // Master transaction counter
logic                   add_cnt_mtrans           ;   // Add to master transaction counter
logic                   end_cnt_mtrans           ;   // End of master transaction counter

logic                   strans_slice_sop         ;   // Start of packet for sliced transaction
logic                   strans_slice_eop         ;   // End of packet for sliced transaction

logic                   buff_rdy                 ;   // Buffer ready signal

// Master transaction counter logic
// Counts the number of transaction words processed
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        cnt_mtrans <= 0;
    end
    else if(add_cnt_mtrans)begin
        if(end_cnt_mtrans)
            cnt_mtrans <= 0;
        else
            cnt_mtrans <= cnt_mtrans + 1'b1;
    end
end
assign add_cnt_mtrans = s_aixs_trans_tvalid && s_aixs_trans_tready;  // Increment counter when transaction data is transferred
assign end_cnt_mtrans = add_cnt_mtrans && s_aixs_trans_tuser[0];     // End counter when end of packet is reached

// Detect start and end of sliced transaction packets
assign strans_slice_sop = (cnt_mtrans[10:0] == 'd0   ) && add_cnt_mtrans;   // Start of sliced packet
assign strans_slice_eop = (cnt_mtrans[10:0] == 'd2047) && add_cnt_mtrans;   // End of sliced packet

// Link start of packet detection
// Detects and tracks the start of packet condition on the link interface
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        s_link_sop <= 'd0;
    else if(s_aixs_link_tvalid && s_aixs_link_tready &&   s_aixs_link_tuser[1] )
        s_link_sop <= 'd1;  // Set SOP flag when start of packet is detected
    else if(s_aixs_link_tvalid && s_aixs_link_tready && (~s_aixs_link_tuser[1]))
        s_link_sop <= 'd0;  // Clear SOP flag when processing continues
end

// Link valid mask generation
// Creates a mask to track valid data within a packet
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        s_link_valid_mask <= 'd0;
    else if(s_aixs_link_tvalid && s_aixs_link_tready &&   s_aixs_link_tuser[1] )
        s_link_valid_mask <= 'd1;  // Set valid mask at start of packet
    else if(s_aixs_link_tvalid && s_aixs_link_tready &&   s_aixs_link_tuser[0] )
        s_link_valid_mask <= 'd0;  // Clear valid mask at end of packet
end

// Link valid signal generation
// Combines the valid mask with the actual valid signal
assign s_link_valid = s_link_valid_mask && s_aixs_link_tvalid;

// Master transaction buffer
// Skid buffer for the master transaction interface to handle flow control
afx_skid_buffer #(
    .DW   (MBUFFER_W     ),    // Data width: data + user signals + valid flag
    .DP   (2             )     // Pipeline depth
)
u_afx_skid_buffer_mtrans(
    .clk        (clk                                                                        ),
    .rst_n      (rst_n                                                                      ),
    .din       ({s_link_valid,s_aixs_link_tuser[USER_W-1:2],s_link_sop,s_aixs_link_tuser[0],s_aixs_link_tdata}  ),
    .push       (~slice_buffer_full                                                         ),  // Push when buffer is not full
    .pop        (m_aixs_trans_tready && (~slice_buffer_empty)                               ),  // Pop when downstream is ready and buffer is not empty
    .full       (slice_buffer_full                                                          ),  // Buffer full flag
    .afull      (                                                                           ),  // Not used
    .dout       ({m_aixs_trans_tvalid,m_aixs_trans_tuser    ,m_aixs_trans_tdata}            ),  // Output data
    .empty      (slice_buffer_empty                                                         )   // Buffer empty flag
);

// Link interface ready signal
// Ready to accept data when buffer is not full
assign s_aixs_link_tready = ~slice_buffer_full;

// Transaction data registration
// Registers transaction data for pipeline stages
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        s_aixs_trans_tdata_r <= 'd0;
    else if(s_aixs_trans_tvalid && buff_rdy)
        s_aixs_trans_tdata_r <= s_aixs_trans_tdata;
end

// Transaction valid signal registration
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        s_aixs_trans_tvalid_r <= 'd0;
    else if(buff_rdy)
        s_aixs_trans_tvalid_r <= s_aixs_trans_tvalid;
end

// Transaction user signals registration
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        s_aixs_trans_tuser_r[USER_W-1:2] <= 'd0;
    else if(s_aixs_trans_tvalid & buff_rdy)
        s_aixs_trans_tuser_r[USER_W-1:2] <= s_aixs_trans_tuser[USER_W-1:2];
end

// Transaction end of packet handling
// Manages end of packet signals for sliced transactions
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        s_aixs_trans_tuser_r[0] <= 'd0;  // End of packet flag
        s_aixs_trans_tuser_r[1] <= 'd0;  // Start of packet flag
    end
    else if(s_aixs_trans_tvalid & buff_rdy)begin
        s_aixs_trans_tuser_r[0] <= s_aixs_trans_tuser[0] | strans_slice_eop;  // Combine original EOP with sliced EOP
        s_aixs_trans_tuser_r[1] <= 'd0;
    end
end 

// Slice buffer data input assignment
// Formats data for the slice buffer based on packet boundaries
assign slice_buffer_mtrans_din  = (s_aixs_trans_tvalid && (m_aixs_trans_tuser[1] || strans_slice_sop)) ? 
                                  {{8'h46,8'd0,16'd0},{m_aixs_trans_tuser[USER_W-1:2],2'b10}} : 
                                  {s_aixs_trans_tdata_r,s_aixs_trans_tuser_r};
                                  
// Slice buffer push signal generation
// Controls when data is pushed into the slice buffer
assign slice_buffer_mtrans_push = (s_aixs_trans_tvalid && (m_aixs_trans_tuser[1] || strans_slice_sop)) ? 
                                  s_aixs_trans_tready : 
                                  (s_aixs_trans_tvalid_r & (~slice_buffer_mtrans_full));
                                  
// Slice buffer pop signal generation
// Controls when data is popped from the slice buffer
assign slice_buffer_mtrans_pop  = m_aixs_link_tready && (~slice_buffer_mtrans_empty);

// Transaction interface ready signal
// Ready to accept transaction data when buffer is ready and gearbox allows
assign s_aixs_trans_tready      = buff_rdy && gearbox;

// Buffer ready signal generation
// Buffer is ready when it's not full
assign buff_rdy                 = (~slice_buffer_mtrans_full);

// Gearbox control logic
// Manages the gearbox mechanism for data flow control
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        gearbox <= 'd1;
    else if(s_aixs_trans_tvalid && s_aixs_trans_tready && (s_aixs_trans_tuser[0] || strans_slice_eop))
        gearbox <= 'd0;  // Disable gearbox at end of packet or sliced packet
    else if(buff_rdy)
        gearbox <= 'd1;  // Enable gearbox when buffer is ready
end

// Slave transaction buffer
// Skid buffer for the slave transaction interface to handle flow control
afx_skid_buffer #(
    .DW   (SBUFFER_W    ),    // Data width: data + user signals
    .DP   (3            )     // Pipeline depth
)
u_afx_skid_buffer_strans(
    .clk        (clk                                            ),      // Clock signal
    .rst_n      (rst_n                                          ),      // Reset signal
    .din        (slice_buffer_mtrans_din                        ),      // Data input
    .push       (slice_buffer_mtrans_push                       ),      // Push signal
    .pop        (slice_buffer_mtrans_pop                        ),      // Pop signal
    .full       (                                               ),      // Not used
    .afull      (slice_buffer_mtrans_full                       ),      // Almost full flag
    .dout       (slice_buffer_mtrans_dout                       ),      // Data output
    .empty      (slice_buffer_mtrans_empty                      )       // Empty flag
);

// Link interface output assignment
// Connects the slice buffer output to the link interface
assign {m_aixs_link_tdata,m_aixs_link_tuser} = slice_buffer_mtrans_dout;
assign m_aixs_link_tvalid = ~slice_buffer_mtrans_empty;  // Valid when buffer is not empty

endmodule