/******************************************Copyright@2025**************************************
                                    AdriftXCore  ALL rights reserved
                        https://github.com/AdriftXCore https://gitee.com/adriftxcore
=========================================FILE INFO.============================================
FILE Name       : sata_bist_lfsr.v
Last Update     : 2025/11/25 22:34:24
Latest Versions : 1.0
========================================AUTHOR INFO.===========================================
Created by      : zhanghx
Create date     : 2025/11/25 22:34:24
Version         : 1.0
Description     : Linear Feedback Shift Register for BIST (Built-In Self-Test) used in SATA interface.
=======================================UPDATE HISTPRY==========================================
Modified by     : 
Modified date   : 
Version         : 
Description     : 
******************************Licensed under the GPL-3.0 License******************************/

module sata_bist_lfsr #(
    parameter SEED  = 32'hA54455D5 
)
(
    input   logic               clk           ,
    input   logic               rst_n         ,
    output  logic               pulse         ,
    input   logic   [31:0]      level         
);

logic     [31:0]              lfsr          ;

always_ff @ (posedge clk or negedge rst_n)begin
    if (!rst_n)begin
        lfsr <= SEED;
    end
    else begin
            lfsr[0]  <= lfsr[31];
            lfsr[1]  <= lfsr[0] ^ lfsr[31];
            lfsr[2]  <= lfsr[1] ^ lfsr[31];
            lfsr[3]  <= lfsr[2] ^ lfsr[31];
            lfsr[4]  <= lfsr[3];
            lfsr[5]  <= lfsr[4] ^ lfsr[31];
            lfsr[6]  <= lfsr[5];
            lfsr[7]  <= lfsr[6] ^ lfsr[31];
            lfsr[8]  <= lfsr[7];
            lfsr[9]  <= lfsr[8];
            lfsr[10] <= lfsr[9];
            lfsr[11] <= lfsr[10];
            lfsr[12] <= lfsr[11];
            lfsr[13] <= lfsr[12];
            lfsr[14] <= lfsr[13];
            lfsr[15] <= lfsr[14];
            lfsr[16] <= lfsr[15];
            lfsr[17] <= lfsr[16];
            lfsr[18] <= lfsr[17];
            lfsr[19] <= lfsr[18];
            lfsr[20] <= lfsr[19];
            lfsr[21] <= lfsr[20];
            lfsr[22] <= lfsr[21];
            lfsr[23] <= lfsr[22];
            lfsr[24] <= lfsr[23];
            lfsr[25] <= lfsr[24];
            lfsr[26] <= lfsr[25];
            lfsr[27] <= lfsr[26];
            lfsr[28] <= lfsr[27];
            lfsr[29] <= lfsr[28];
            lfsr[30] <= lfsr[29];
            lfsr[31] <= lfsr[30];
    end
end

always_ff @ (posedge clk or negedge rst_n)begin
    if (!rst_n)
        pulse <= 1'b1;
    else if(lfsr >= level)
        pulse <= 1'b1;
    else
        pulse <= 1'b0;
end

endmodule
