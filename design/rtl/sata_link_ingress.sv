/******************************************Copyright@2025**************************************
                                    AdriftXCore  ALL rights reserved
                        https://github.com/AdriftXCore https://gitee.com/adriftxcore
=========================================FILE INFO.============================================
FILE Name       : sata_link_ingress.sv
Last Update     : 2025/04/17 00:01:42
Latest Versions : 1.0
========================================AUTHOR INFO.===========================================
Created by      : zhanghx
Create date     : 2025/04/17 00:01:42
Version         : 1.0
Description     : SATA Link Ingress Module - Handles data flow from the transport layer to the 
                  link layer for write operations. This module provides buffering capabilities 
                  and flow control between layers.
=======================================UPDATE HISTPRY==========================================
Modified by     : 
Modified date   : 
Version         : 
Description     : 
******************************Licensed under the GPL-3.0 License******************************/
module sata_link_ingress #(
    parameter USER_W    = 8,              // User data width for AXI Stream interface
    parameter NO_BUFFER = 0,              // Buffer enable flag: 1=disable buffer, 0=enable buffer

    parameter BUFFER_W  = 32 + USER_W     // Buffer width (data + user signals)
)(
    input   logic                           clk             ,   // Clock signal
    input   logic                           rst_n           ,   // Reset signal (active low)

    // Slave AXI Stream interface (from transport layer)
    input   logic       [31         :0]     s_aixs_tdata    ,   // Slave data payload
    input   logic       [USER_W   -1:0]     s_aixs_tuser    ,   // Slave user signals {drop,err,keep[3:0],sop,eop}
    input   logic                           s_aixs_tvalid   ,   // Slave data valid signal
    output  logic                           s_aixs_tready   ,   // Slave ready signal

    // Master AXI Stream interface (to link layer)
    output  logic       [31         :0]     m_aixs_tdata    ,   // Master data payload
    output  logic       [USER_W   -1:0]     m_aixs_tuser    ,   // Master user signals {drop,err,keep[3:0],sop,eop}
    output  logic                           m_aixs_tvalid   ,   // Master data valid signal
    input   logic                           m_aixs_tready       // Master ready signal
);

// Generate block for buffer selection
generate
// When NO_BUFFER is 1, directly connect input to output without buffering
if(NO_BUFFER == 1)begin:NO_BUFFER_BLOCK
    assign m_aixs_tdata   = s_aixs_tdata ;   // Direct data connection
    assign m_aixs_tuser   = s_aixs_tuser ;   // Direct user signals connection
    assign m_aixs_tvalid  = s_aixs_tvalid;   // Direct valid signal connection
    assign s_aixs_tready  = m_aixs_tready;   // Direct ready signal connection
end
// When NO_BUFFER is 0, instantiate a skid buffer for flow control
else if(NO_BUFFER == 0)begin:SLICE_BUFFER_BLOCK
    // Instantiate skid buffer to provide buffering and flow control
    afx_skid_buffer_axis #(
        .DATA_W 	(BUFFER_W  ),           // Data width: data + user signals
        .PIPE   	(2         ),           // Pipeline depth
        .BF         (1         )            // Enable backpressure
    )
    u_afx_skid_buffer_axis(
        .clk           	(clk                        ),      // Clock signal
        .rst_n         	(rst_n                      ),      // Reset signal
        .s_aixs_tdata  	({s_aixs_tdata,s_aixs_tuser}),      // Combine data and user signals for input
        .s_aixs_tvalid 	(s_aixs_tvalid              ),      // Input valid signal
        .s_aixs_tready 	(s_aixs_tready              ),      // Input ready signal
        .m_aixs_tdata  	({m_aixs_tdata,m_aixs_tuser}),      // Separate data and user signals for output
        .m_aixs_tvalid 	(m_aixs_tvalid              ),      // Output valid signal
        .m_aixs_tready 	(m_aixs_tready              )       // Output ready signal
    );
end
endgenerate

endmodule