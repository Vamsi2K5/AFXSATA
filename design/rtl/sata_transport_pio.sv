/******************************************Copyright@2025**************************************
                                    AdriftXCore  ALL rights reserved
                        https://github.com/AdriftXCore https://gitee.com/adriftxcore
=========================================FILE INFO.============================================
FILE Name       : sata_transport_pio.sv
Last Update     : 2025/09/08 23:07:56
Latest Versions : 1.0
========================================AUTHOR INFO.===========================================
Created by      : zhanghx
Create date     : 2025/09/08 23:07:56
Version         : 1.0
Description     : SATA Transport PIO Module - Detects PIO setup requests from the link layer
                  and generates appropriate PIO setup signals. This module monitors incoming
                  FIS packets to identify PIO setup commands and asserts the PIO setup signal
                  when a PIO transfer is initiated.
=======================================UPDATE HISTPRY==========================================
Modified by     : 
Modified date   : 
Version         : 
Description     : 
******************************Licensed under the GPL-3.0 License******************************/
module sata_transport_pio #(
    parameter USER_W = 8               // User data width for AXI Stream interface
)( 
    input    logic                     clk                  ,   // Clock signal
    input    logic                     rst_n                ,   // Reset signal (active low)

    // Slave AXI Stream interface (from link layer)
    input    logic  [31         :0]    s_aixs_link_tdata    ,   // Slave data payload
    input    logic  [USER_W   -1:0]    s_aixs_link_tuser    ,   // Slave user signals {drop,err,keep[3:0],sop,eop}
    input    logic                     s_aixs_link_tvalid   ,   // Slave data valid signal
    output   logic                     s_aixs_link_tready   ,   // Slave ready signal

    // PIO control signals
    output   logic                     pio_setup              // PIO setup signal output
);

// PIO setup detection logic
// This block monitors incoming FIS packets and asserts pio_setup when:
// 1. A start of packet (SOP) is detected
// 2. The link interface is ready and data is valid
// 3. The FIS type indicates a PIO setup FIS (FIS type 0x5F)
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        pio_setup <= 'd0;                                   // Reset PIO setup signal
    else if(s_aixs_link_tuser[1] && s_aixs_link_tready && s_aixs_link_tvalid && (s_aixs_link_tdata[24+:8] == 8'h5F))
        pio_setup <= 'd1;                                   // Assert PIO setup for PIO setup FIS
    else
        pio_setup <= 'd0;                                   // Deassert PIO setup
end

// Link interface ready signal
// Always ready to accept data since this module only monitors packets
assign s_aixs_link_tready = 1'b1;                           // Always ready

endmodule