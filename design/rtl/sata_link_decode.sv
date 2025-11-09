/******************************************Copyright@2025**************************************
                                    AdriftXCore  ALL rights reserved
                        https://github.com/AdriftXCore https://gitee.com/adriftxcore
=========================================FILE INFO.============================================
FILE Name       : sata_link_decode.v
Last Update     : 2025/04/07 18:11:44
Latest Versions : 1.0
========================================AUTHOR INFO.===========================================
Created by      : zhanghx
Create date     : 2025/04/07 18:11:44
Version         : 1.0
Description     : SATA Link Decode Module - Decodes incoming SATA primitives and data from the 
                  physical layer. This module identifies primitive types, handles data 
                  scrambling/descrambling, and provides decoded data to the upper layers.
=======================================UPDATE HISTPRY==========================================
Modified by     : 
Modified date   : 
Version         : 
Description     : 
******************************Licensed under the GPL-3.0 License******************************/
`include "sata_wrapper_define.svh"

// SATA Link Decode Module
// This module is responsible for decoding the incoming data stream from the SATA physical layer.
// It identifies SATA primitives, handles data descrambling, and classifies the data types for
// consumption by higher layers in the SATA stack.
module sata_link_decode(
    input  logic                    clk         ,   // Clock signal
    input  logic                    rst_n       ,   // Reset signal (active low)

    input  logic                    vld         ,   // Valid signal indicating PHY is ready
    input  logic    [31     :0]     dat_i       ,   // Input data from PHY layer
    input  logic    [3      :0]     datachar_i  ,   // Data character indicator from PHY

    output sata_p_t                 dat_type    ,   // Decoded data type (primitive or data)
    output logic    [3      :0]     char_o      ,   // Output character indicator
    output logic    [31     :0]     dat_o       ,   // Decoded output data

    output logic    [31     :0]     sop_cnt     ,   // Start of packet counter
    output logic    [31     :0]     eop_cnt       // End of packet counter
);

// Output declarations for LFSR module
logic [32   -1:0]     lfsr_o        ;   // LFSR output for data descrambling
logic                 lfsr_init     ;   // LFSR initialization signal
logic                 lfsr_en       ;   // LFSR enable signal

// Registered data signals for pipeline stages
logic [31     :0]     dat_r         ;   // Registered input data
logic [3      :0]     datachar_r    ;   // Registered data character indicator

// Temporary data signals for comparison
logic [31     :0]     dat_t         ;   // Temporary data storage
logic [3      :0]     datachar_t    ;   // Temporary character indicator

// Primitive continuation control signals
logic                 p_ctinue        ;   // Primitive continuation flag
logic                 p_ctinue_r      ;   // Registered primitive continuation flag
logic                 r_p_ctinue_valid;   // Registered primitive continuation valid
logic                 p_ctinue_valid  ;   // Primitive continuation valid flag
logic                 p_ctinue_unvld  ;   // Primitive continuation invalid
logic                 p_ctinue_vld    ;   // Primitive continuation valid
logic [31     :0]     p_ctinue_value  ;   // Value of continued primitive

// Detect if current primitive is a continuation of the previous one
assign r_p_ctinue_valid = (dat_i      == dat_t  ) && (datachar_i     == datachar_t) && (datachar_t == 4'b1000) && (dat_t != `ALIGNp) && (dat_t != `CONTp) && (dat_t != `DMATp) && (dat_t != `EOFp) && (dat_t != `PMACKp) && (dat_t != `PMNAKp) && (dat_t != `SOFp);

// Detect invalid primitive continuation
assign p_ctinue_unvld   = (datachar_i == 4'b1000) && p_ctinue && (dat_i != `CONTp);

// Detect valid primitive continuation
assign p_ctinue_vld = p_ctinue_valid &&  (datachar_i == 4'b1000) && (dat_i == `CONTp);

// Register the primitive continuation validity
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        p_ctinue_valid <= 'd0;
    else
        p_ctinue_valid <= r_p_ctinue_valid;
end

// Register input data and character indicator
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        dat_r      <= 'd0;
        datachar_r <= 'd0;
    end
    else if(vld)begin
        dat_r      <= dat_i;
        datachar_r <= datachar_i;
    end
    else begin
        dat_r      <= 'd0;
        datachar_r <= 'd0;
    end
end

// Store temporary data and character indicator
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        dat_t      <= 'd0;
        datachar_t <= 'd0;
    end
    else begin
        dat_t      <= dat_i;
        datachar_t <= datachar_i;
    end
end

// Store the value of a continued primitive
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        p_ctinue_value <= 'd0;
    else if(p_ctinue_vld)
        p_ctinue_value <= dat_t;
end

// Control the primitive continuation flag
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        p_ctinue <= 'd0;
    else if(p_ctinue_vld)
        p_ctinue <= 'd1;
    else if(p_ctinue_unvld)
        p_ctinue <= 'd0;
end

// Register the primitive continuation flag
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        p_ctinue_r <= 'd0;
    else
        p_ctinue_r <= p_ctinue;
end

// Determine the data type based on the received data
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        dat_type <= align;
    else if(p_ctinue)begin
        // If in continuation mode, use the stored primitive value
        unique case(p_ctinue_value)
            `ALIGNp  :dat_type <= align  ;
            `CONTp   :dat_type <= cont   ;
            `DMATp   :dat_type <= dmat   ;
            `EOFp    :dat_type <= eof    ;
            `HOLDp   :dat_type <= hold   ;
            `HOLDAp  :dat_type <= holda  ;
            `PMACKp  :dat_type <= pmack  ;
            `PMNAKp  :dat_type <= pmnak  ;
            `PMREQ_Pp:dat_type <= pmreq_p;
            `PMREQ_Sp:dat_type <= pmreq_s;
            `R_ERRp  :dat_type <= r_err  ;
            `R_IPp   :dat_type <= r_ip   ;
            `R_OKp   :dat_type <= r_ok   ;
            `R_RDYp  :dat_type <= r_rdy  ;
            `SOFp    :dat_type <= sof    ;
            `SYNCp   :dat_type <= sync   ;
            `WTRMp   :dat_type <= wtrm   ;
            `X_RDYp  :dat_type <= x_rdy  ;
            default  :dat_type <= err    ;
        endcase
    end
    else if(datachar_r == 4'b1000)begin
        // If K-character detected, classify the primitive type
        unique case(dat_r)
            `ALIGNp  :dat_type <= align  ;
            `CONTp   :dat_type <= cont   ;
            `DMATp   :dat_type <= dmat   ;
            `EOFp    :dat_type <= eof    ;
            `HOLDp   :dat_type <= hold   ;
            `HOLDAp  :dat_type <= holda  ;
            `PMACKp  :dat_type <= pmack  ;
            `PMNAKp  :dat_type <= pmnak  ;
            `PMREQ_Pp:dat_type <= pmreq_p;
            `PMREQ_Sp:dat_type <= pmreq_s;
            `R_ERRp  :dat_type <= r_err  ;
            `R_IPp   :dat_type <= r_ip   ;
            `R_OKp   :dat_type <= r_ok   ;
            `R_RDYp  :dat_type <= r_rdy  ;
            `SOFp    :dat_type <= sof    ;
            `SYNCp   :dat_type <= sync   ;
            `WTRMp   :dat_type <= wtrm   ;
            `X_RDYp  :dat_type <= x_rdy  ;
            default  :dat_type <= err    ;
        endcase
    end
    else if(datachar_r == 4'b0000)begin
        // If regular data, mark as data type
        dat_type <= is_dat;
    end
    else begin
        // Otherwise, mark as error
        dat_type <= err;
    end
end

// Output decoded data with descrambling applied
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        dat_o <= 'd0;
    else if(datachar_r == 4'b0000)
        dat_o <= dat_r ^ lfsr_o;  // Descramble data using LFSR output
end

// Output character indicator
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        char_o <= 'd0;
    else
        char_o <= datachar_r;
end

// Instantiate LFSR module for data descrambling
sata_link_lfsr u_sata_link_lfsr(
    .clk       	(clk        ),      // Clock signal
    .rst_n     	(rst_n      ),      // Reset signal
    .lfsr_init 	(lfsr_init  ),      // LFSR initialization
    .lfsr_en   	(lfsr_en    ),      // LFSR enable
    .lfsr_o    	(lfsr_o     )       // LFSR output
);

// Control LFSR initialization and enable
assign lfsr_init = (datachar_r == 4'b1000) && (dat_r == `SOFp);  // Initialize LFSR on SOF primitive
assign lfsr_en   = (datachar_r == 4'b0000) && (~p_ctinue_r);     // Enable LFSR for data descrambling

// Count start of packet occurrences
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        sop_cnt <= 'd0;
    else if(dat_type == sof)
        sop_cnt <= sop_cnt + 1'b1;
end

// Count end of packet occurrences
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        eop_cnt <= 'd0;
    else if(dat_type == eof)
        eop_cnt <= eop_cnt + 1'b1;
end

endmodule