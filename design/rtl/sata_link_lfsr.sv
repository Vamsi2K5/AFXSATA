/******************************************Copyright@2025**************************************
                                    AdriftXCore  ALL rights reserved
                        https://github.com/AdriftXCore https://gitee.com/adriftxcore
=========================================FILE INFO.============================================
FILE Name       : sata_link_lfsr.v
Last Update     : 2025/04/14 23:44:49
Latest Versions : 1.0
========================================AUTHOR INFO.===========================================
Created by      : zhanghx
Create date     : 2025/04/14 23:44:49
Version         : 1.0
Description     : context = 0xF0F6; the first Dword output of any implementation needs to equal 0xC2D2768D.G(X) = X16 + X15 + X13 + X4 + 1
=======================================UPDATE HISTPRY==========================================
Modified by     : 
Modified date   : 
Version         : 
Description     : 
******************************Licensed under the GPL-3.0 License******************************/
module sata_link_lfsr(
    input  logic                clk         ,
    input  logic                rst_n       ,
    input  logic                lfsr_init   ,
    input  logic                lfsr_en     ,
    output logic [32    -1:0]   lfsr_o       
);

logic [15:0] context_i;
logic [15:0] now;
logic [31:0] next;
logic [31:0] scrambler;

/* The following 16 assignments implement the matrix multiplication */ 
/* performed by the box labeled *M1. */ 
/* Notice that there are lots of shared terms in these assignments. */ 
assign next[31] = now[12] ^ now[10] ^ now[7] ^ now[3] ^ now[1] ^ now[0]; 
assign next[30] = now[15] ^ now[14] ^ now[12] ^ now[11] ^ now[9] ^ now[6] ^ now[3] ^ now[2] ^ now[0]; 
assign next[29] = now[15] ^ now[13] ^ now[12] ^ now[11] ^ now[10] ^ now[8] ^ now[5] ^ now[3] ^ now[2] ^ now[1]; 
assign next[28] = now[14] ^ now[12] ^ now[11] ^ now[10] ^ now[9] ^ now[7] ^ now[4] ^ now[2] ^ now[1] ^ now[0]; 
assign next[27] = now[15] ^ now[14] ^ now[13] ^ now[12] ^ now[11] ^ now[10] ^ now[9] ^ now[8] ^ now[6] ^ now[1] ^ now[0]; 
assign next[26] = now[15] ^ now[13] ^ now[11] ^ now[10] ^ now[9] ^ now[8] ^ now[7] ^ now[5] ^ now[3] ^ now[0]; 
assign next[25] = now[15] ^ now[10] ^ now[9] ^ now[8] ^ now[7] ^ now[6] ^ now[4] ^ now[3] ^ now[2]; 
assign next[24] = now[14] ^ now[9] ^ now[8] ^ now[7] ^ now[6] ^ now[5] ^ now[3] ^ now[2] ^ now[1]; 
assign next[23] = now[13] ^ now[8] ^ now[7] ^ now[6] ^ now[5] ^ now[4] ^ now[2] ^ now[1] ^ now[0]; 
assign next[22] = now[15] ^ now[14] ^ now[7] ^ now[6] ^ now[5] ^ now[4] ^ now[1] ^ now[0]; 
assign next[21] = now[15] ^ now[13] ^ now[12] ^ now[6] ^ now[5] ^ now[4] ^ now[0]; 
assign next[20] = now[15] ^ now[11] ^ now[5] ^ now[4]; 
assign next[19] = now[14] ^ now[10] ^ now[4] ^ now[3]; 
assign next[18] = now[13] ^ now[9] ^ now[3] ^ now[2]; 
assign next[17] = now[12] ^ now[8] ^ now[2] ^ now[1]; 
assign next[16] = now[11] ^ now[7] ^ now[1] ^ now[0]; 
/* The following 16 assignments implement the matrix multiplication */ 
/* performed by the box labeled *M2. */ 
assign next[15] = now[15] ^ now[14] ^ now[12] ^ now[10] ^ now[6] ^ now[3] ^ now[0]; 
assign next[14] = now[15] ^ now[13] ^ now[12] ^ now[11] ^ now[9] ^ now[5] ^ now[3] ^ now[2]; 
assign next[13] = now[14] ^ now[12] ^ now[11] ^ now[10] ^ now[8] ^ now[4] ^ now[2] ^ now[1]; 
assign next[12] = now[13] ^ now[11] ^ now[10] ^ now[9] ^ now[7] ^ now[3] ^ now[1] ^ now[0]; 
assign next[11] = now[15] ^ now[14] ^ now[10] ^ now[9] ^ now[8] ^ now[6] ^ now[3] ^ now[2] ^ now[0]; 
assign next[10] = now[15] ^ now[13] ^ now[12] ^ now[9] ^ now[8] ^ now[7] ^ now[5] ^ now[3] ^ now[2] ^ now[1]; 
assign next[9] = now[14] ^ now[12] ^ now[11] ^ now[8] ^ now[7] ^ now[6] ^ now[4] ^ now[2] ^ now[1] ^ now[0]; 
assign next[8] = now[15] ^ now[14] ^ now[13] ^ now[12] ^ now[11] ^ now[10] ^ now[7] ^ now[6] ^ now[5] ^ now[1] ^ now[0]; 
assign next[7] = now[15] ^ now[13] ^ now[11] ^ now[10] ^ now[9] ^ now[6] ^ now[5] ^ now[4] ^ now[3] ^ now[0]; 
assign next[6] = now[15] ^ now[10] ^ now[9] ^ now[8] ^ now[5] ^ now[4] ^ now[2]; 
assign next[5] = now[14] ^ now[9] ^ now[8] ^ now[7] ^ now[4] ^ now[3] ^ now[1]; 
assign next[4] = now[13] ^ now[8] ^ now[7] ^ now[6] ^ now[3] ^ now[2] ^ now[0]; 
assign next[3] = now[15] ^ now[14] ^ now[7] ^ now[6] ^ now[5] ^ now[3] ^ now[2] ^ now[1]; 
assign next[2] = now[14] ^ now[13] ^ now[6] ^ now[5] ^ now[4] ^ now[2] ^ now[1] ^ now[0]; 
assign next[1] = now[15] ^ now[14] ^ now[13] ^ now[5] ^ now[4] ^ now[1] ^ now[0]; 
assign next[0] = now[15] ^ now[13] ^ now[4] ^ now[0]; 


assign now       = context_i;
assign scrambler = next;

always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        context_i <= 16'hf0f6;
    else if(lfsr_init)
        context_i <= 16'hf0f6;
    else
        context_i <= lfsr_en ? scrambler[31:16] : context_i;
end

assign lfsr_o = {scrambler[0+:8],scrambler[8+:8],scrambler[16+:8],scrambler[24+:8]};

endmodule