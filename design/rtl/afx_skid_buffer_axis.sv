/******************************************Copyright@2025**************************************
                                    AdriftXCore  ALL rights reserved
                        https://github.com/AdriftXCore https://gitee.com/adriftxcore
=========================================FILE INFO.============================================
FILE Name       : afx_skid_buffer_axis.sv
Last Update     : 2025/03/08 00:00:27
Latest Versions : 1.0
========================================AUTHOR INFO.===========================================
Created by      : Zhanghx
Create date     : 2025/03/08 00:00:27
Version         : 1.0
Description     : AXI Stream Skid Buffer - Implements a skid buffer for AXI Stream interfaces 
                  to handle flow control between master and slave components. This module 
                  provides buffering capabilities with programmable depth and backpressure 
                  handling to ensure reliable data transfer.
=======================================UPDATE HISTPRY==========================================
Modified by     : 
Modified date   : 
Version         : 
Description     : 
******************************Licensed under the GPL-3.0 License******************************/
module afx_skid_buffer_axis #(
    parameter DATA_W = 32,              // Data width in bits
    parameter PIPE   = 2 ,              // Pipeline depth (buffer stages)
    parameter BF     = 0                // Backpressure flag: 1=enable backpressure, 0=disable
)
(
    input  logic                         clk               ,   // Clock signal
    input  logic                         rst_n             ,   // Reset signal (active low)

    input  logic [DATA_W    -1:0]        s_aixs_tdata      ,   // Slave AXI Stream data input
    input  logic                         s_aixs_tvalid     ,   // Slave AXI Stream valid signal
    output logic                         s_aixs_tready     ,   // Slave AXI Stream ready signal

    output logic [DATA_W    -1:0]        m_aixs_tdata      ,   // Master AXI Stream data output
    output logic                         m_aixs_tvalid     ,   // Master AXI Stream valid signal
    input  logic                         m_aixs_tready       // Master AXI Stream ready signal
);

// Internal signal declarations
logic                   push  ;         // Push data into buffer
logic                   pop   ;         // Pop data from buffer
logic                   full  ;         // Buffer full flag
logic                   empty ;         // Buffer empty flag

// Instantiate the generic skid buffer with AXI Stream data + valid signal
// The buffer stores DATA_W+1 bits to accommodate both data and valid signal
afx_skid_buffer #(
    .DW     	(DATA_W + 1  ),         // Data width: data + valid bit
    .DP      	(PIPE        )          // Pipeline depth
)
u_afx_skid_buffer(
    .clk        	(clk                            ),      // Clock
    .rst_n      	(rst_n                          ),      // Reset (active low)
    .din          	({s_aixs_tdata,s_aixs_tvalid}   ),      // Input data with valid flag
    .push       	(push                           ),      // Push control signal
    .pop        	(pop                            ),      // Pop control signal
    .full       	(full                           ),      // Buffer full indicator
    .dout        	({m_aixs_tdata,m_aixs_tvalid}   ),      // Output data with valid flag
    .empty      	(empty                          )       // Buffer empty indicator
);

// Push control logic: determine when to push data into the buffer
// If BF=1, only push when input is valid and buffer is not full (flow control enabled)
// If BF=0, push whenever buffer is not full (flow control disabled)
assign push          = BF ? (s_aixs_tvalid && (~full)) : ~full;

// Pop control logic: pop data when downstream is ready and buffer is not empty
assign pop           = m_aixs_tready && (~empty);

// Ready signal to upstream: ready when buffer is not full
assign s_aixs_tready = ~full;

endmodule