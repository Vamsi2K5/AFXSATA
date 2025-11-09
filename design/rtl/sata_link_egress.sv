/******************************************Copyright@2025**************************************
                                    AdriftXCore  ALL rights reserved
                        https://github.com/AdriftXCore https://gitee.com/adriftxcore
=========================================FILE INFO.============================================
FILE Name       : sata_link_egress.sv
Last Update     : 2025/04/17 00:01:42
Latest Versions : 1.0
========================================AUTHOR INFO.===========================================
Created by      : zhanghx
Create date     : 2025/04/17 00:01:42
Version         : 1.0
Description     : SATA Link Egress Module - Handles data transmission from internal logic to 
                  SATA interface. This module acts as a buffer between the user logic and the 
                  SATA transport layer, managing data flow control and buffering.
=======================================UPDATE HISTPRY==========================================
Modified by     : 
Modified date   : 
Version         : 
Description     : 
******************************Licensed under the GPL-3.0 License******************************/
module sata_link_egress #(
    parameter USER_W  = 8,              // User data width

    parameter FIFO_D  = 128,            // FIFO depth
    parameter FIFO_W  = 32 + USER_W,    // FIFO data width (32-bit data + user data)
    parameter FIFO_AW = 7               // FIFO address width
)
(
    input  logic                            clk             ,   // Clock signal
    input  logic                            rst_n           ,   // Reset signal, active low

    // Slave AXI Stream interface - Data input
    input   logic       [31         :0]     s_aixs_tdata    ,   // Data payload (32 bits)
    input   logic       [USER_W   -1:0]     s_aixs_tuser    ,   // User signals {drop,err,keep[3:0],sop,eop}
    input   logic                           s_aixs_tvalid   ,   // Data valid signal
    output  logic                           s_aixs_tready   ,   // Receiver ready signal

    // Master AXI Stream interface - Data output
    output  logic       [31         :0]     m_aixs_tdata    ,   // Data payload output (32 bits)
    output  logic       [USER_W   -1:0]     m_aixs_tuser    ,   // User signal output {drop,err,keep[3:0],sop,eop}
    output  logic                           m_aixs_tvalid   ,   // Data valid output signal
    input   logic                           m_aixs_tready   ,   // Output ready signal

    // Status indication signals
    output  logic                           buffer_full         // Buffer full signal      
);

// FIFO interface signal declarations
logic               fifo_wr_en      ;   // FIFO write enable signal
logic               fifo_rd_en      ;   // FIFO read enable signal
logic [FIFO_W-1:0]  fifo_din        ;   // FIFO data input
logic [FIFO_W-1:0]  fifo_dout       ;   // FIFO data output
logic               fifo_empty      ;   // FIFO empty flag
logic               fifo_full       ;   // FIFO full flag
logic               fifo_prog_full  ;   // FIFO programmable full flag (programmable threshold)

// Instantiate FIFO module for data buffering
// This FIFO acts as a buffer between the input and output interfaces to handle
// differences in data rates and provide flow control
afx_fifo_wrapper #(
    .DEVICE            	("XILINX"  ),       // Device type
    .CLOCK_MODE        	("sync"    ),       // Clock mode: synchronous
    .DEPTH             	(FIFO_D    ),       // FIFO depth
    .DW                	(FIFO_W    ),       // Data width
    .READ_MODE         	("fwft"    ),       // Read mode: first word fall through
    .READ_LATENCY      	(1         ),       // Read latency cycles
    .MEMORY_TYPE       	("auto"    ),       // Memory type: auto selection
    .PROG_EMPTY_THRESH 	(64        ),       // Programmable empty threshold
    .PROG_FULL_THRESH  	(64        ),       // Programmable full threshold
    .AW                	(FIFO_AW   )        // Address width
)
u_fifo_wrapper(
    .clk           	(clk            ),      // Clock
    .rst_n         	(rst_n          ),      // Reset
    .wr_en         	(fifo_wr_en     ),      // Write enable
    .din           	(fifo_din       ),      // Data input
    .rd_en         	(fifo_rd_en     ),      // Read enable
    .dout          	(fifo_dout      ),      // Data output
    .empty         	(fifo_empty     ),      // Empty flag
    .full          	(fifo_full      ),      // Full flag
    .prog_empty    	(               ),      // Programmable empty flag (not connected)
    .prog_full     	(fifo_prog_full ),      // Programmable full flag
    .rd_data_count 	(               ),      // Read data count (not connected)
    .wr_data_count 	(               )       // Write data count (not connected)
);

// Input interface control logic
// When input data is valid and FIFO is not full, allow writing to FIFO
assign fifo_wr_en = s_aixs_tvalid && (~fifo_full);
// Combine input data and user signals then write to FIFO
assign fifo_din   = {s_aixs_tdata,s_aixs_tuser};
// When FIFO is not full, indicate ready to receive data
assign s_aixs_tready = ~fifo_full;

// Output interface control logic
// Separate FIFO output data into data payload and user signals
assign {m_aixs_tdata,m_aixs_tuser} = fifo_dout;
// When FIFO is not empty, output data is valid
assign m_aixs_tvalid = ~fifo_empty;
// When output is ready to receive data and FIFO is not empty, allow reading from FIFO
assign fifo_rd_en    = m_aixs_tready && (~fifo_empty);

// Status indication signal output
// When FIFO reaches programmable full threshold, indicate buffer full
assign buffer_full = fifo_prog_full;

endmodule