/******************************************Copyright@2025**************************************
                                    AdriftXCore  ALL rights reserved
                        https://github.com/AdriftXCore https://gitee.com/adriftxcore
=========================================FILE INFO.============================================
FILE Name       : sata_transport_dma.sv
Last Update     : 2025/09/08 23:02:23
Latest Versions : 1.0
========================================AUTHOR INFO.===========================================
Created by      : zhanghx
Create date     : 2025/09/08 23:02:23
Version         : 1.0
Description     : SATA Transport DMA Module - Detects DMA activation requests from the link 
                  layer and generates appropriate DMA active signals. This module monitors 
                  incoming FIS packets to identify DMA setup commands and asserts the DMA 
                  active signal when a DMA transfer is initiated.
=======================================UPDATE HISTPRY==========================================
Modified by     : 
Modified date   : 
Version         : 
Description     : 
******************************Licensed under the GPL-3.0 License******************************/
module sata_transport_dma  #(
    parameter USER_W = 8               // User data width for AXI Stream interface
)(
    input    logic                     clk                  ,   // Clock signal
    input    logic                     rst_n                ,   // Reset signal (active low)

    // Slave AXI Stream interface (from link layer)
    input    logic  [31         :0]    s_aixs_link_tdata    ,   // Slave data payload
    input    logic  [USER_W   -1:0]    s_aixs_link_tuser    ,   // Slave user signals {drop,err,keep[3:0],sop,eop}
    input    logic                     s_aixs_link_tvalid   ,   // Slave data valid signal
    output   logic                     s_aixs_link_tready   ,   // Slave ready signal

    // DMA control signals
    output   logic                     dma_active             // DMA active signal output
);

// DMA activation detection logic
// This block monitors incoming FIS packets and asserts dma_active when:
// 1. A start of packet (SOP) is detected
// 2. The link interface is ready and data is valid
// 3. The FIS type indicates a DMA setup FIS (FIS type 0x39)
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        dma_active <= 'd0;                                  // Reset DMA active signal
    else if(s_aixs_link_tuser[1] && s_aixs_link_tready && s_aixs_link_tvalid && (s_aixs_link_tdata[24+:8] == 8'h39))
        dma_active <= 'd1;                                  // Assert DMA active for DMA setup FIS
    else
        dma_active <= 'd0;                                  // Deassert DMA active
end

// Link interface ready signal
// Always ready to accept data since this module only monitors packets
assign s_aixs_link_tready = 1;                              // Always ready

endmodule