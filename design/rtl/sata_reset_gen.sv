/******************************************Copyright@2025**************************************
                                    AdriftXCore  ALL rights reserved
                        https://github.com/AdriftXCore https://gitee.com/adriftxcore
=========================================FILE INFO.============================================
FILE Name       : sata_reset_gen.sv
Last Update     : 2025/02/01 18:11:44
Latest Versions : 1.0
========================================AUTHOR INFO.===========================================
Created by      : zhanghx
Create date     : 2025/02/01 18:11:44
Version         : 1.0
Description     : SATA Reset Generator - Generates a reset signal for SATA modules based on 
                  input conditions and timing parameters. This module ensures proper reset 
                  assertion and deassertion for reliable SATA operation.
=======================================UPDATE HISTPRY==========================================
Modified by     : 
Modified date   : 
Version         : 
Description     : 
******************************Licensed under the GPL-3.0 License******************************/
module sata_reset_gen#(
    parameter CYCLE  = 100,     // Reset duration in clock cycles
    parameter POLARI = 0        // Reset polarity: 0=active low, 1=active high
)
(
    input   logic clk ,         // Clock signal
    input   logic din ,         // Input data/control signal

    output  logic rst_o         // Generated reset output
);

logic [32 -1:0] cnt_rgen    ;   // Reset generation counter
logic           add_cnt_rgen;   // Counter increment enable
logic           end_cnt_rgen;   // Counter end condition
logic           rst_flag    ;   // Reset flag to indicate completion

// Counter for reset duration timing
always_ff @(posedge clk)begin
    if(add_cnt_rgen)begin
        if(end_cnt_rgen)
            cnt_rgen <= 0;
        else
            cnt_rgen <= cnt_rgen + 1'b1;
    end
end

// Enable counter when reset is not flagged
assign add_cnt_rgen = ~rst_flag;

// End counter when reaching specified cycle count
assign end_cnt_rgen = add_cnt_rgen && cnt_rgen == CYCLE - 1;

// Set reset flag when counter completes
always_ff @(posedge clk)begin
    if(end_cnt_rgen)
        rst_flag <= 'd1;
end

// Generate reset output based on polarity and input conditions
always_ff @(posedge clk)begin
    if(rst_flag) 
        rst_o <= POLARI && din;  // Active based on polarity and input
    else
        rst_o <= (~POLARI);      // Default state based on polarity
end

endmodule