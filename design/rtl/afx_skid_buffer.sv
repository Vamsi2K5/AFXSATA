/******************************************Copyright@2025**************************************
                                    AdriftXCore  ALL rights reserved
                        https://github.com/AdriftXCore https://gitee.com/adriftxcore
=========================================FILE INFO.============================================
FILE Name       : afx_skid_buffer.sv
Last Update     : 2025/03/07 14:17:52
Latest Versions : 1.0
========================================AUTHOR INFO.===========================================
Created by      : zhanghx
Create date     : 2025/03/07 14:17:52
Version         : 1.0
Description     : Skid Buffer Implementation - A parameterized skid buffer (also known as a 
                  "skid buffer" or "bubble FIFO") that provides flow control between pipeline 
                  stages. This module implements a simple buffer with programmable depth to 
                  handle backpressure in digital designs.
=======================================UPDATE HISTPRY==========================================
Modified by     : 
Modified date   : 
Version         : 
Description     : 
******************************Licensed under the GPL-3.0 License******************************/
module afx_skid_buffer #(
    parameter DW   = 32,              // Data Width - width of the data bus in bits
    parameter DP   = 4 ,              // Depth Parameter - number of buffer stages (buffer depth)
    parameter PROG = DP - 2           // Programmable Full Threshold - level at which afull is asserted
)(
    input  logic                 clk    ,   // Clock signal
    input  logic                 rst_n  ,   // Active-low reset signal
    input  logic [DW     -1:0]   din    ,   // Data input bus
    input  logic                 push   ,   // Push signal - when asserted, data is written to the buffer
    input  logic                 pop    ,   // Pop signal - when asserted, data is read from the buffer
    output logic                 full   ,   // Full flag - asserted when buffer is completely full
    output logic                 afull  ,   // Almost full flag - asserted when buffer reaches programmable threshold
    output logic [DW    -1:0]    dout   ,   // Data output bus
    output logic                 empty      // Empty flag - asserted when buffer is empty
);

logic [DW -1:0] slice [DP -1:0];logic [DP -1:0] dsf;generate assign full  = dsf[DP-1];assign empty = ~dsf[0];assign dout  = slice[0];assign afull = dsf[PROG];always_ff @(posedge clk or negedge rst_n)begin if(!rst_n) dsf <= 'd0;else case({push,pop})2'b01:dsf <= {1'b0,dsf[DP-1:1]};2'b10:dsf <= {dsf[DP-2:0],1'b1};default:dsf <= dsf;endcase end for(genvar i = 0;i < DP;i = i + 1)begin:AFX_DELAY_LINE always_ff @(posedge clk or negedge rst_n)begin if(!rst_n)begin slice[i] <= 'd0;end else case({push,pop})2'b00:slice[i] <= slice[i];2'b01:slice[i] <= (i == DP-1) ? '0 : slice[i+1];2'b10:slice[i] <= (~dsf[i] && ((i==0)?1:dsf[i-1])) ? din : slice[i];2'b11:begin if(i == 0) slice[i] <= (dsf[1] && dsf[0]) ? slice[1] : din;else if(i == DP -1)slice[i] <= dsf[DP-1] ? din : slice[DP-1];else slice[i] <= (~dsf[i+1] && dsf[i]) ? din : slice[i+1];end endcase end end endgenerate

endmodule