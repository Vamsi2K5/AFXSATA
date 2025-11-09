/******************************************Copyright@2025**************************************
                                    AdriftXCore  ALL rights reserved
                        https://github.com/AdriftXCore https://gitee.com/adriftxcore
=========================================FILE INFO.============================================
FILE Name       : sata_link_encode.v
Last Update     : 2025/04/16 00:18:18
Latest Versions : 1.0
========================================AUTHOR INFO.===========================================
Created by      : zhanghx
Create date     : 2025/04/16 00:18:18
Version         : 1.0
Description     : SATA Link Encode Module - Encodes data and primitives from the transport layer
                  into the format required by the physical layer. This module handles data 
                  scrambling, primitive continuation, and ALIGN insertion for SATA communication.
=======================================UPDATE HISTPRY==========================================
Modified by     : 
Modified date   : 
Version         : 
Description     : 
******************************Licensed under the GPL-3.0 License******************************/
`include "sata_wrapper_define.svh"

// SATA Link Encode Module
// This module is responsible for encoding data from the transport layer into the format
// required by the physical layer. It handles data scrambling using LFSR, primitive 
// continuation for repeated primitives, and periodic ALIGN primitive insertion.
module sata_link_encode(
    input  logic                    clk         ,   // Clock signal
    input  logic                    rst_n       ,   // Reset signal (active low)

    input  logic                    phyrdy      ,   // PHY ready signal

    output logic                    vld         ,   // Valid signal indicating encoded data is ready
    output logic    [31     :0]     dat_o       ,   // Encoded output data
    output logic    [3      :0]     datachar_o  ,   // Data character identifier (K-char)

    output logic                    roll_insert ,   // Roll insertion request for ALIGN primitives


    input  logic                    wr_req      ,   // Write request from transport layer
    input  sata_p_t                 wr_dat_type ,   // Write data type (primitive or data)
    input  logic    [3      :0]     wr_char_i   ,   // Write character identifier
    input  logic    [31     :0]     wr_dat_i    ,   // Write data input

    input  logic                    rd_req      ,   // Read request from transport layer
    input  sata_p_t                 rd_dat_type ,   // Read data type (primitive or data)
    input  logic    [3      :0]     rd_char_i   ,   // Read character identifier
    input  logic    [31     :0]     rd_dat_i    ,   // Read data input

    output logic    [31     :0]     sop_cnt     ,   // Start of packet counter
    output logic    [31     :0]     eop_cnt       // End of packet counter
);

// Output declarations for LFSR modules
logic    [32   -1:0]  wr_lfsr_o             ;   // LFSR output for write data scrambling
logic                 wr_lfsr_init          ;   // LFSR initialization for write path
logic                 wr_lfsr_en            ;   // LFSR enable for write path

// Write primitive continuation control signals
logic                 wr_p_ctinue           ;   // Write primitive continuation flag
logic                 wr_p_ctinue_valid     ;   // Write primitive continuation valid
logic                 wr_p_ctinue_valid_r   ;   // Registered write primitive continuation valid
logic                 wr_p_ctinue_valid_rr  ;   // Double registered write primitive continuation valid
logic                 wr_p_ctinue_unvld     ;   // Write primitive continuation invalid
sata_p_t              wr_p_ctinue_value     ;   // Value of continued write primitive
logic    [32   -1:0]  wr_p_ctinue_charvalue ;   // Character value of continued write primitive

// Read primitive continuation control signals
logic                 rd_p_ctinue           ;   // Read primitive continuation flag
logic                 rd_p_ctinue_valid     ;   // Read primitive continuation valid
logic                 rd_p_ctinue_valid_r   ;   // Registered read primitive continuation valid
logic                 rd_p_ctinue_valid_rr  ;   // Double registered read primitive continuation valid
logic                 rd_p_ctinue_unvld     ;   // Read primitive continuation invalid
sata_p_t              rd_p_ctinue_value     ;   // Value of continued read primitive
logic    [32   -1:0]  rd_p_ctinue_charvalue ;   // Character value of continued read primitive

// Registered write and read request signals
logic                 wr_req_t              ;   // Registered write request
sata_p_t              wr_dat_type_t         ;   // Registered write data type
logic    [3      :0]  wr_char_t             ;   // Registered write character
logic    [31     :0]  wr_dat_t              ;   // Registered write data

logic                 rd_req_t              ;   // Registered read request
sata_p_t              rd_dat_type_t         ;   // Registered read data type
logic    [3      :0]  rd_char_t             ;   // Registered read character
logic    [31     :0]  rd_dat_t              ;   // Registered read data

// LFSR output for CONT primitive scrambling
logic    [32   -1:0]  cont_lfsr_o           ;   // LFSR output for CONT primitive

// Counter for roll insertion timing
logic    [8    -1:0]  cnt_roll              ;   // Counter for roll insertion

// Roll insertion control signals
logic                 roll_insert_r         ;   // Registered roll insert signal
logic                 roll_insert_pause     ;   // Roll insertion pause flag

// Registered output data signals
logic     [32   -1:0] r_dat_o               ;   // Registered output data
logic     [4    -1:0] r_datachar_o          ;   // Registered output character
logic                 cont_res_flag         ;   // CONT primitive resume flag

// Value for CONT primitive
logic     [32   -1:0] cont_value            ;   // CONT primitive value


// Roll insertion counter - counts up when PHY is ready
// Used to determine when to insert ALIGN primitives periodically
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        cnt_roll <= 'd0;
    else if(phyrdy)
        cnt_roll <= cnt_roll + 1'b1;
    else
        cnt_roll <= 'd0;
end

// Generate roll_insert signal when counter reaches 252
// This triggers periodic ALIGN primitive insertion
assign roll_insert = (cnt_roll == 252);

// Register the roll_insert signal for pause detection
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        roll_insert_r  <= 'd0;
    end
    else begin
        roll_insert_r  <= roll_insert  ;
    end
end

// Roll insertion pause logic - pause operations during roll insertion
assign roll_insert_pause   =  roll_insert    || roll_insert_r;

// Register write request signals for primitive continuation detection
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        wr_req_t       <= 'd0;
        wr_dat_type_t  <= align;
        wr_char_t      <= 'd0;
        wr_dat_t       <= 'd0;
    end
    else if(wr_req)begin
        wr_req_t       <= wr_req;
        wr_dat_type_t  <= wr_dat_type;
        wr_char_t      <= wr_char_i;
        wr_dat_t       <= wr_dat_i;
    end
end

// Register read request signals for primitive continuation detection
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        rd_req_t       <= 'd0;
        rd_dat_type_t  <= align;
        rd_char_t      <= 'd0;
        rd_dat_t       <= 'd0;
    end
    else if(rd_req)begin
        rd_req_t       <= rd_req;
        rd_dat_type_t  <= rd_dat_type;
        rd_char_t      <= rd_char_i;
        rd_dat_t       <= rd_dat_i;
    end
end

// Detect valid write primitive continuation
// Checks if current and previous primitives are the same and eligible for continuation
assign wr_p_ctinue_valid = wr_req && (wr_char_t == 4'b1000) && (wr_char_t == wr_char_i) && (wr_dat_type_t == wr_dat_type) && (wr_dat_type_t != align) && (wr_dat_type_t != cont) && (wr_dat_type_t != dmat) && (wr_dat_type_t != eof) && (wr_dat_type_t != pmack) && (wr_dat_type_t != pmnak) && (wr_dat_type_t != sof);

// Detect valid read primitive continuation
// Checks if current and previous primitives are the same and eligible for continuation
assign rd_p_ctinue_valid = rd_req && (rd_char_t == 4'b1000) && (rd_char_t == wr_char_i) && (rd_dat_type_t == wr_dat_type) && (rd_dat_type_t != align) && (rd_dat_type_t != cont) && (rd_dat_type_t != dmat) && (rd_dat_type_t != eof) && (rd_dat_type_t != pmack) && (rd_dat_type_t != pmnak) && (rd_dat_type_t != sof);

// Register write primitive continuation validity
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        wr_p_ctinue_valid_r <= 'd0;
    else
        wr_p_ctinue_valid_r <= wr_p_ctinue_valid;
end

// Double register write primitive continuation validity
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        wr_p_ctinue_valid_rr <= 'd0;
    else
        wr_p_ctinue_valid_rr <= wr_p_ctinue_valid_r;
end

// Register read primitive continuation validity
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        rd_p_ctinue_valid_r <= 'd0;
    else
        rd_p_ctinue_valid_r <= rd_p_ctinue_valid;
end

// Double register read primitive continuation validity
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        rd_p_ctinue_valid_rr <= 'd0;
    else
        rd_p_ctinue_valid_rr <= rd_p_ctinue_valid_r;
end

// Store the value of continued write primitive
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        wr_p_ctinue_value <= align;
    else if(wr_p_ctinue_valid)
        wr_p_ctinue_value <= wr_dat_type_t;
end

// Store the value of continued read primitive
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        rd_p_ctinue_value <= align;
    else if(wr_p_ctinue_valid)
        rd_p_ctinue_value <= rd_dat_type_t;
end

// Store the character value of continued write primitive
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        wr_p_ctinue_charvalue <= 'd0;
    else if(wr_p_ctinue_valid)
        wr_p_ctinue_charvalue <= wr_dat_t;
end

// Store the character value of continued read primitive
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        rd_p_ctinue_charvalue <= 'd0;
    else if(wr_p_ctinue_valid)
        rd_p_ctinue_charvalue <= rd_dat_t;
end

// Detect invalid write primitive continuation
assign wr_p_ctinue_unvld = (wr_p_ctinue_value != wr_dat_type);

// Detect invalid read primitive continuation
assign rd_p_ctinue_unvld = (rd_p_ctinue_value != rd_dat_type);

// Control the write primitive continuation flag
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        wr_p_ctinue <= 'd0;
    else if(wr_p_ctinue_valid)
        wr_p_ctinue <= 'd1;
    else if(wr_p_ctinue_unvld)
        wr_p_ctinue <= 'd0;
end

// Control the read primitive continuation flag
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        rd_p_ctinue <= 'd0;
    else if(wr_p_ctinue_valid)
        rd_p_ctinue <= 'd1;
    else if(wr_p_ctinue_unvld)
        rd_p_ctinue <= 'd0;
end

// Main encoding logic - determines what data to output based on requests and conditions
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        vld        <= 'd1;
        r_dat_o      <= `SYNCp;
        r_datachar_o <= 4'b1000;
    end
    else if(wr_req)begin
        // Handle write data and CRC with scrambling
        if((wr_dat_type == is_crc) || (wr_dat_type == is_dat))begin
            vld        <= 'd1;
            r_dat_o      <= wr_dat_i ^ wr_lfsr_o;  // Scramble data using LFSR
            r_datachar_o <= wr_char_i;
        end
        // Handle primitive continuation - insert CONT primitive
        else if({wr_p_ctinue_unvld,wr_p_ctinue_valid_rr,wr_p_ctinue_valid_r} == 3'b001)begin
            vld        <= 'd1;
            r_dat_o      <= `CONTp;
            r_datachar_o <= 4'b1000;
        end
        // Handle continued primitives - output scrambled data
        else if(wr_p_ctinue)begin
            if(wr_p_ctinue_unvld)begin
                vld        <= 'd1;
                r_dat_o      <= wr_dat_i;
                r_datachar_o <= wr_char_i;
            end
            else begin
                vld        <= 'd1;
                r_dat_o      <= cont_lfsr_o;  // Scrambled CONT data
                r_datachar_o <= 4'b0000;
            end
        end
        // Handle regular primitives
        else begin
            vld        <= 'd1;
            r_dat_o      <= wr_dat_i;
            r_datachar_o <= wr_char_i;
        end
    end
    else if(rd_req)begin
        // Handle read data
        if((rd_dat_type == is_crc) || (rd_dat_type == is_dat))begin
            vld        <= 'd1;
            r_dat_o      <= rd_dat_i;
            r_datachar_o <= rd_char_i;
        end
        // Handle primitive continuation - insert CONT primitive
        else if({rd_p_ctinue_unvld,rd_p_ctinue_valid_rr,rd_p_ctinue_valid_r} == 3'b001)begin
            vld        <= 'd1;
            r_dat_o      <= `CONTp;
            r_datachar_o <= 4'b1000;
        end
        // Handle continued primitives - output scrambled data
        else if(rd_p_ctinue)begin
            if(rd_p_ctinue_unvld)begin
                vld        <= 'd1;
                r_dat_o      <= rd_dat_i;
                r_datachar_o <= rd_char_i;
            end
            else begin
                vld        <= 'd1;
                r_dat_o      <= cont_lfsr_o;  // Scrambled CONT data
                r_datachar_o <= 4'b0000;
            end
        end
        // Handle regular primitives
        else begin
            vld        <= 'd1;
            r_dat_o      <= rd_dat_i;
            r_datachar_o <= rd_char_i;
        end
    end
    // Handle roll insertion - output ALIGN primitive
    else if(roll_insert_pause)begin
        vld        <= 'd1;
        r_dat_o      <= `ALIGNp;
        r_datachar_o <= 4'b1000;
    end
    // Default case - output SYNC primitive
    else begin
        vld        <= 'd1;
        r_dat_o      <= `SYNCp;
        r_datachar_o <= 4'b1000;
    end
end

// CONT primitive resume flag and output selection
assign cont_res_flag = (wr_p_ctinue && wr_p_ctinue_unvld && wr_req && wr_p_ctinue_valid_rr);
assign dat_o         = cont_res_flag ? cont_value: r_dat_o;
assign datachar_o    = cont_res_flag ? 4'b1000  : r_datachar_o;


// Instantiate LFSR module for write data scrambling
sata_link_lfsr u_sata_link_lfsr_wr(
    .clk       	(clk           ),      // Clock signal
    .rst_n     	(rst_n         ),      // Reset signal
    .lfsr_init 	(wr_lfsr_init  ),      // LFSR initialization
    .lfsr_en   	(wr_lfsr_en    ),      // LFSR enable
    .lfsr_o    	(wr_lfsr_o     )       // LFSR output
);

// Control LFSR for write path
assign wr_lfsr_en   = (wr_dat_type == is_crc) || (wr_dat_type == is_dat);  // Enable for data and CRC
assign wr_lfsr_init = (wr_dat_type == sof);                               // Initialize on SOF

// Instantiate LFSR module for CONT primitive scrambling
sata_link_lfsr u_sata_link_lfsr_cont(
    .clk       	(clk        ),         // Clock signal
    .rst_n     	(rst_n      ),         // Reset signal
    .lfsr_init 	(1'b0       ),         // No initialization
    .lfsr_en   	(1'b1       ),         // Always enabled
    .lfsr_o    	(cont_lfsr_o)          // LFSR output
);

// Store CONT primitive value for resume
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        cont_value <= 'd0;
    else if({wr_p_ctinue_unvld,wr_p_ctinue_valid_rr,wr_p_ctinue_valid_r} == 3'b001)
        cont_value <= r_dat_o;
end

// Count start of packet occurrences
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        sop_cnt <= 'd0;
    else if(wr_dat_type == sof)
        sop_cnt <= sop_cnt + 1'b1;
end

// Count end of packet occurrences
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        eop_cnt <= 'd0;
    else if(wr_dat_type == eof)
        eop_cnt <= eop_cnt + 1'b1;
end

endmodule