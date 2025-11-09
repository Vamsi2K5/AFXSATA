/******************************************Copyright@2025**************************************
                                    AdriftXCore  ALL rights reserved
                        https://github.com/AdriftXCore https://gitee.com/adriftxcore
=========================================FILE INFO.============================================
FILE Name       : sata_command_dma_ctrl.sv
Last Update     : 2025/09/03 23:19:03
Latest Versions : 1.0
========================================AUTHOR INFO.===========================================
Created by      : zhanghx
Create date     : 2025/09/03 23:19:03
Version         : 1.0
Description     : SATA Command and DMA Controller - Manages SATA command processing and DMA 
                  data transfer operations. Handles read/write command execution, data buffering,
                  and interface control between user logic and SATA transport layer.
=======================================UPDATE HISTPRY==========================================
Modified by     : 
Modified date   : 
Version         : 
Description     : 
******************************Licensed under the GPL-3.0 License******************************/
`include "sata_wrapper_define.svh"

// SATA Command and DMA Controller Module
// This module handles SATA command processing and DMA data transfers. It manages the flow of
// commands and data between the user interface and the SATA transport layer, implementing
// read and write operations with proper buffering and flow control.
module sata_command_dma_ctrl #(
    parameter TIMER  = 15   ,           // Timer value for initial delay
    parameter NULL   = 32'd0,           // Null value constant
    parameter USER_W = 8                // User data width
)(
    input    logic                     clk                  ,   // Clock signal
    input    logic                     rst_n                ,   // Reset signal (active low)

    /****** user interface ******/
    input    logic  [2        -1:0]    ctrl                 ,   // Control signals

    /****** trans-data-stream interface ******/
    input    logic  [31         :0]    s_aixs_trans_tdata   ,   // Transaction data input
    input    logic  [USER_W   -1:0]    s_aixs_trans_tuser   ,   // Transaction user signals {drop,err,keep[3:0],sop,eop}
    input    logic                     s_aixs_trans_tvalid  ,   // Transaction data valid
    output   logic                     s_aixs_trans_tready  ,   // Transaction ready signal

    output   logic  [31         :0]    m_aixs_trans_tdata   ,   // Transaction data output
    output   logic  [USER_W   -1:0]    m_aixs_trans_tuser   ,   // Transaction user signals output {drop,err,keep[3:0],sop,eop}
    output   logic                     m_aixs_trans_tvalid  ,   // Transaction data valid output
    input    logic                     m_aixs_trans_tready  ,   // Transaction ready input

    /****** command data stream interface ******/
    input    app_cmd_t                 cmd                  ,   // Application command input
    output   logic                     cmd_ack              ,   // Command acknowledge output
    output   logic  [16       -1:0]    read_count           ,   // Read sector count

    input    logic  [31         :0]    s_aixs_cmd_tdata     ,   // Command data input
    input    logic  [USER_W   -1:0]    s_aixs_cmd_tuser     ,   // Command user signals {drop,err,keep[3:0],sop,eop}
    input    logic                     s_aixs_cmd_tvalid    ,   // Command data valid
    output   logic                     s_aixs_cmd_tready    ,   // Command ready signal

    output   logic  [31         :0]    m_aixs_cmd_tdata     ,   // Command data output
    output   logic  [USER_W   -1:0]    m_aixs_cmd_tuser     ,   // Command user signals output {drop,err,keep[3:0],sop,eop}
    output   logic                     m_aixs_cmd_tvalid    ,   // Command data valid output
    input    logic                     m_aixs_cmd_tready    ,   // Command ready input

    /****** command interface ******/
    output   cmd_t                     m_cmd                ,   // Master command output
    output   logic                     m_req                ,   // Master request output
    input    logic                     m_ack                ,   // Master acknowledge input

    input    cmd_t                     s_cmd                ,   // Slave command input
    input    logic                     s_req                ,   // Slave request input
    output   logic                     s_ack                ,   // Slave acknowledge output

    output   logic  [31          :0]   wr_err_cnt           ,   // Write error counter
    output   logic  [31          :0]   rd_err_cnt           ,   // Read error counter

    /****** dma interface ******/
    input    logic                     dma_active           ,   // DMA active signal

    /****** pio interface ******/
    input    logic                     pio_setup             // PIO setup signal
);

// Signal declarations
logic                en                 ;   // Enable signal
logic                reset              ;   // Reset signal

logic                rx_sop_vld         ;   // Receive start of packet valid
logic                rx_eop_vld         ;   // Receive end of packet valid

logic [47       :0]  lba                ;   // Logical block address
logic [15       :0]  count              ;   // Sector count
logic [47       :0]  r_lba              ;   // Registered logical block address
logic [15       :0]  r_count            ;   // Registered sector count
logic [1        :0]  sector_size_sel    ;   // Sector size selection: 0=512 bytes, 1=4096 bytes

logic [1        :0]  end_dw             ;   // End data word indicator
logic [1        :0]  r_end_dw           ;   // Registered end data word

logic [48     -1:0]  cnt_r              ;   // Read counter
logic                add_cnt_r          ;   // Add to read counter
logic                end_cnt_r          ;   // End of read counter

logic                w_vld              ;   // Write valid signal
logic                r_vld              ;   // Read valid signal

logic [48     -1:0]  start_sector       ;   // Start sector address
logic [48     -1:0]  end_sector         ;   // End sector address
logic [48     -1:0]  start_vld          ;   // Start valid address
logic [48     -1:0]  end_vld            ;   // End valid address
logic [48     -1:0]  r_start_sector     ;   // Registered start sector
logic [48     -1:0]  r_end_sector       ;   // Registered end sector
logic [48     -1:0]  r_start_vld        ;   // Registered start valid
logic [48     -1:0]  r_end_vld          ;   // Registered end valid

logic [48     -1:0]  cnt_w              ;   // Write counter
logic                add_cnt_w          ;   // Add to write counter
logic                end_cnt_w          ;   // End of write counter

logic [11     -1:0]  cnt_act            ;   // Active counter
logic                add_cnt_act        ;   // Add to active counter
logic                end_cnt_act        ;   // End of active counter

logic [7      -1:0]  cnt_info           ;   // Info counter
logic                add_cnt_info       ;   // Add to info counter
logic                end_cnt_info       ;   // End of info counter

logic [16     -1:0]  logic_size_f       ;   // Logical size field
logic [32     -1:0]  logic_size         ;   // Logical size

logic                m_trans_sop        ;   // Transmit start of packet
logic                m_trans_eop        ;   // Transmit end of packet
logic [48     -1:0]  true_end_addr      ;   // True end address

logic [32     -1:0]  cnt_timer          ;   // Timer counter
logic                add_cnt_timer      ;   // Add to timer counter
logic                end_cnt_timer      ;   // End of timer counter

logic [23       :0]  dma_len            ;   // DMA length

// Registered AXI stream signals for command interface
logic [31       :0]  r_m_aixs_cmd_tdata ;   // Registered command data
logic [USER_W -1:0]  r_m_aixs_cmd_tuser ;   // Registered command user signals {drop,err,keep[3:0],sop,eop}
logic                r_m_aixs_cmd_tvalid;   // Registered command valid
logic                r_m_aixs_cmd_tready;   // Registered command ready

// Registered AXI stream signals for transaction interface
logic [31       :0]  r_m_aixs_trans_tdata  ;   // Registered transaction data
logic [USER_W -1:0]  r_m_aixs_trans_tuser  ;   // Registered transaction user signals {drop,err,keep[3:0],sop,eop}
logic                r_m_aixs_trans_tvalid ;   // Registered transaction valid
logic                r_m_aixs_trans_tready ;   // Registered transaction ready

// Assignments for packet detection
assign rx_sop_vld = s_aixs_trans_tvalid && s_aixs_trans_tready && s_aixs_trans_tuser[1];  // Start of packet detection
assign rx_eop_vld = s_aixs_trans_tvalid && s_aixs_trans_tready && s_aixs_trans_tuser[0];  // End of packet detection

// Control signal extraction
assign {reset,en} = ctrl;

// State machine width definition
localparam STATE_W = 16;

// State bit positions
localparam  IDLE_BIT    = 'd0  ,        // Idle state bit
            S1_BIT      = 'd1  ,        // State 1 bit (INIT_READ_ID)
            S2_BIT      = 'd2  ,        // State 2 bit (INIT_PIO_SETUP)
            S3_BIT      = 'd3  ,        // State 3 bit (INIT_PIO_DATA)
            S4_BIT      = 'd4  ,        // State 4 bit (RW_ARBT)
            S5_BIT      = 'd5  ,        // State 5 bit (READ_REQ)
            S6_BIT      = 'd6  ,        // State 6 bit (RECIEVE_RDATA)
            S7_BIT      = 'd7  ,        // State 7 bit (WAITREAD_ACK)
            S8_BIT      = 'd8  ,        // State 8 bit (WRITE_REQ)
            S9_BIT      = 'd9  ,        // State 9 bit (RECIEVE_DMA_ACTIVE)
            S10_BIT     = 'd10 ,        // State 10 bit (SEND_WDATA)
            S11_BIT     = 'd11 ;        // State 11 bit (WAITWRITE_ACK)

// State machine type definition
typedef enum logic [STATE_W -1:0]{
    IDLE                = STATE_W'(1) << IDLE_BIT  ,   // Idle state
    INIT_READ_ID        = STATE_W'(1) << S1_BIT    ,   // Initialize read ID state
    INIT_PIO_SETUP      = STATE_W'(1) << S2_BIT    ,   // Initialize PIO setup state
    INIT_PIO_DATA       = STATE_W'(1) << S3_BIT    ,   // Initialize PIO data state
    RW_ARBT             = STATE_W'(1) << S4_BIT    ,   // Read/Write arbitration state
    READ_REQ            = STATE_W'(1) << S5_BIT    ,   // Read request state
    RECIEVE_RDATA       = STATE_W'(1) << S6_BIT    ,   // Receive read data state
    WAITREAD_ACK        = STATE_W'(1) << S7_BIT    ,   // Wait for read acknowledge state
    WRITE_REQ           = STATE_W'(1) << S8_BIT    ,   // Write request state
    RECIEVE_DMA_ACTIVE  = STATE_W'(1) << S9_BIT    ,   // Receive DMA active state
    SEND_WDATA          = STATE_W'(1) << S10_BIT   ,   // Send write data state
    WAITWRITE_ACK       = STATE_W'(1) << S11_BIT       // Wait for write acknowledge state
}state_t;

// State machine signals
state_t state_c;    // Current state
state_t state_n;    // Next state

// State transition control signals
logic idl2init_read_id_start             ;   // Transition from IDLE to INIT_READ_ID
logic init_read_id2init_pio_setup_start  ;   // Transition from INIT_READ_ID to INIT_PIO_SETUP
logic init_pio_setup2init_pio_data_start ;   // Transition from INIT_PIO_SETUP to INIT_PIO_DATA
logic init_pio_data2rw_arbt_start        ;   // Transition from INIT_PIO_DATA to RW_ARBT
logic rw_arbt2read_req_start             ;   // Transition from RW_ARBT to READ_REQ
logic rw_arbt2write_req_start            ;   // Transition from RW_ARBT to WRITE_REQ
logic read_req2recieve_rdata_start       ;   // Transition from READ_REQ to RECIEVE_RDATA
logic recieve_rdata2waitread_ack_start   ;   // Transition from RECIEVE_RDATA to WAITREAD_ACK
logic waitread_ack2rw_arbt_start         ;   // Transition from WAITREAD_ACK to RW_ARBT
logic write_req2recieve_dma_active_start ;   // Transition from WRITE_REQ to RECIEVE_DMA_ACTIVE
logic recieve_dma_active2send_wdata_start;   // Transition from RECIEVE_DMA_ACTIVE to SEND_WDATA
logic send_wdata2write_ack_start         ;   // Transition from SEND_WDATA to WAITWRITE_ACK
logic send_wdata2recieve_dma_active_start;   // Transition from SEND_WDATA to RECIEVE_DMA_ACTIVE
logic write_ack2rw_arbt_start            ;   // Transition from WAITWRITE_ACK to RW_ARBT

// State register - synchronous with clock and reset
always_ff@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        state_c <= IDLE;
    else if(reset)
        state_c <= IDLE;
    else
        state_c <= state_n;
end

// Next state logic - combinational
always_comb begin
    case (1)
        state_c[IDLE_BIT]:begin
            if(idl2init_read_id_start)
                state_n = INIT_READ_ID;
            else
                state_n = state_c;
        end
        state_c[S1_BIT]:begin //INIT_READ_ID
            if(init_read_id2init_pio_setup_start)
                state_n = INIT_PIO_SETUP;
            else
                state_n = state_c;
        end
        state_c[S2_BIT]:begin //INIT_PIO_SETUP
            if(init_pio_setup2init_pio_data_start)
                state_n = INIT_PIO_DATA;
            else
                state_n = state_c;
        end
        state_c[S3_BIT]:begin //INIT_PIO_DATA
            if(init_pio_data2rw_arbt_start)
                state_n = RW_ARBT;
            else
                state_n = state_c;
        end
        state_c[S4_BIT]:begin //RW_ARBT
            if(rw_arbt2read_req_start)
                state_n = READ_REQ;
            else if(rw_arbt2write_req_start)
                state_n = WRITE_REQ;
            else
                state_n = state_c;
        end
        state_c[S5_BIT]:begin //READ_REQ
            if(read_req2recieve_rdata_start)
                state_n = RECIEVE_RDATA;
            else
                state_n = state_c;
        end
        state_c[S6_BIT]:begin //RECIEVE_RDATA
            if(recieve_rdata2waitread_ack_start)
                state_n = WAITREAD_ACK;
            else
                state_n = state_c;
        end
        state_c[S7_BIT]:begin //WAITREAD_ACK
            if(waitread_ack2rw_arbt_start)
                state_n = RW_ARBT;
            else
                state_n = state_c;
        end
        state_c[S8_BIT]:begin //WRITE_REQ
            if(write_req2recieve_dma_active_start)
                state_n = RECIEVE_DMA_ACTIVE;
            else
                state_n = state_c;
        end
        state_c[S9_BIT]:begin //RECIEVE_DMA_ACTIVE
            if(recieve_dma_active2send_wdata_start)
                state_n = SEND_WDATA;
            else
                state_n = state_c;
        end
        state_c[S10_BIT]:begin //SEND_WDATA
            if(send_wdata2write_ack_start)
                state_n = WAITWRITE_ACK;
            else if(send_wdata2recieve_dma_active_start)
                state_n = RECIEVE_DMA_ACTIVE;
            else
                state_n = state_c;
        end
        state_c[S11_BIT]:begin //WAITWRITE_ACK
            if(write_ack2rw_arbt_start)
                state_n = RW_ARBT;
            else
                state_n = state_c;
        end
        default:begin
            state_n = IDLE;
        end
    endcase
end

// State transition conditions
assign idl2init_read_id_start              = (state_c == IDLE                ) && end_cnt_timer                            ;
assign init_read_id2init_pio_setup_start   = (state_c == INIT_READ_ID        ) && m_ack                                    ;
assign init_pio_setup2init_pio_data_start  = (state_c == INIT_PIO_SETUP      ) && pio_setup                                ;
assign init_pio_data2rw_arbt_start         = (state_c == INIT_PIO_DATA       ) && rx_eop_vld                               ;
assign rw_arbt2read_req_start              = (state_c == RW_ARBT             ) && cmd_ack &&  cmd.req &&   cmd.rw          ;
assign rw_arbt2write_req_start             = (state_c == RW_ARBT             ) && cmd_ack &&  cmd.req && (~cmd.rw)         ;
assign read_req2recieve_rdata_start        = (state_c == READ_REQ            ) && m_ack                                    ;
assign recieve_rdata2waitread_ack_start    = (state_c == RECIEVE_RDATA       ) && end_cnt_r                                ;
assign waitread_ack2rw_arbt_start          = (state_c == WAITREAD_ACK        ) && s_req                                    ;
assign write_req2recieve_dma_active_start  = (state_c == WRITE_REQ           ) && m_ack                                    ;
assign recieve_dma_active2send_wdata_start = (state_c == RECIEVE_DMA_ACTIVE  ) && dma_active                               ;
assign send_wdata2write_ack_start          = (state_c == SEND_WDATA          ) && end_cnt_w                                ;
assign send_wdata2recieve_dma_active_start = (state_c == SEND_WDATA          ) && end_cnt_act                              ;
assign write_ack2rw_arbt_start             = (state_c == WAITWRITE_ACK       ) && s_req                                    ;

// Slave acknowledge generation
assign s_ack = (state_c == WAITREAD_ACK  ) || (state_c == WAITWRITE_ACK) || (state_c == WRITE_REQ) || (state_c == READ_REQ);

// Command acknowledge logic
always_ff@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        cmd_ack <= 'd0;
    else if(reset)
        cmd_ack <= 'd0;
    else if(cmd_ack)
        cmd_ack <= 'd0;
    else if((state_c == RW_ARBT) && cmd.req)
        cmd_ack <= 'd1;
end

// Master command and request generation
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        m_cmd <= 'd0;
        m_req <= 'd0;
    end
    else if(reset)begin
        m_cmd <= 'd0;
        m_req <= 'd0;
    end
    else if(idl2init_read_id_start)begin
        m_cmd.h2d.cmd   <= 8'hec;       // IDENTIFY DEVICE command
        m_req           <= 'd1  ;
    end
    else if(rw_arbt2write_req_start || ((state_c == WRITE_REQ) && (s_req && s_ack)))begin
        m_cmd.h2d.cmd   <= 8'h35;       // WRITE DMA command
        m_cmd.h2d.lba   <= lba  ;       // Logical block address
        m_cmd.h2d.count <= count;       // Sector count
        m_req           <= 'd1  ;
    end
    else if(rw_arbt2read_req_start  || ((state_c == READ_REQ ) && (s_req && s_ack)))begin
        m_cmd.h2d.cmd   <= 8'h25;       // READ DMA command
        m_cmd.h2d.lba   <= lba  ;       // Logical block address
        m_cmd.h2d.count <= count;       // Sector count
        m_req           <= 'd1  ;
    end
    else if(m_ack)begin
        m_cmd <= 'd0;
        m_req <= 'd0;
    end
end

// Write error counter
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        wr_err_cnt <= 'd0;
    else if((state_c == WRITE_REQ) && (s_req && s_ack))
        wr_err_cnt <= wr_err_cnt + 1'b1;
end

// Read error counter
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        rd_err_cnt <= 'd0;
    else if((state_c == READ_REQ ) && (s_req && s_ack))
        rd_err_cnt <= rd_err_cnt + 1'b1;
end

// DMA length and address calculations
assign dma_len = (cmd.len == 0) ? ({1'b1,cmd.len}) : {1'b0,cmd.len};
assign true_end_addr = cmd.addr + dma_len -1;
assign r_lba   = {9'd0,cmd.addr[47:9]}; 
assign r_count = ((dma_len + cmd.addr[8:0] - 1) >> 9) + 1;
assign r_end_dw = cmd.addr[1:0] + dma_len[1:0];
assign r_start_sector = {2'd0,cmd.addr[47:9],7'd0};
assign r_end_sector   = {{true_end_addr[47:9] + 1'b1},7'd0};
assign r_start_vld = {2'd0,cmd.addr[47:2]};
assign r_end_vld = {2'd0,true_end_addr[47:2]};

// LBA, count and sector address registers
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        lba          <= 'd0; 
        count        <= 'd0;
        end_dw     <= 'd0;
        start_vld <= 'd0;
        end_vld   <= 'd0;
        start_sector <= 'd0;
        end_sector <= 'd0;
    end
    else if(reset)begin
        lba          <= 'd0; 
        count        <= 'd0;
        end_dw     <= 'd0;
        start_vld <= 'd0;
        end_vld   <= 'd0;
        start_sector <= 'd0;
        end_sector <= 'd0;
    end
    else if((state_c == RW_ARBT) && cmd.req)begin
        case(sector_size_sel)
            0:begin
                lba             <= r_lba         ; 
                count           <= r_count       ;
                end_dw          <= r_end_dw      ;
                start_sector    <= r_start_sector;
                end_sector      <= r_end_sector  ;
                start_vld       <= r_start_vld   ;
                end_vld         <= r_end_vld     ;
            end
            default:begin
                lba             <= r_lba         ; 
                count           <= r_count       ;
                end_dw          <= r_end_dw      ;
                start_sector    <= r_start_sector;
                end_sector      <= r_end_sector  ;
                start_vld       <= r_start_vld   ;
                end_vld         <= r_end_vld     ;
            end
        endcase
    end
end

// Command AXI stream assignment and control
assign r_m_aixs_cmd_tdata              = s_aixs_trans_tdata;
assign r_m_aixs_cmd_tuser[1:0]         = {cnt_r == start_vld,cnt_r == end_vld};
assign r_m_aixs_cmd_tuser[USER_W -1:6] = s_aixs_trans_tuser[USER_W -1:6];
assign r_m_aixs_cmd_tvalid             = (state_c == RECIEVE_RDATA) ? (r_vld && s_aixs_trans_tvalid && (~s_aixs_trans_tuser[0])) : 1'b0;
assign s_aixs_trans_tready           = (state_c == RECIEVE_RDATA) ? r_m_aixs_cmd_tready   : 1'b1;

// End data word handling for command stream
always_comb begin
    if(r_m_aixs_cmd_tuser[0])begin
        case(end_dw)
            2'd0:r_m_aixs_cmd_tuser[2+:4] = 4'b1111;
            2'd1:r_m_aixs_cmd_tuser[2+:4] = 4'b0001;
            2'd2:r_m_aixs_cmd_tuser[2+:4] = 4'b0011;
            2'd3:r_m_aixs_cmd_tuser[2+:4] = 4'b0111;
            default:r_m_aixs_cmd_tuser[2+:4] = 4'b1111;
        endcase
    end
    else begin
        r_m_aixs_cmd_tuser[2+:4] = 4'b1111;
    end
end

// Skid buffer for command RX interface
afx_skid_buffer_axis #(
    .DATA_W(40)
)
u0_afx_skid_buffer_axis_rx(
    .clk          (clk),
    .rst_n        (rst_n),
    .s_aixs_tdata ({r_m_aixs_cmd_tuser,r_m_aixs_cmd_tdata}),
    .s_aixs_tvalid(r_m_aixs_cmd_tvalid),
    .s_aixs_tready(r_m_aixs_cmd_tready),
    .m_aixs_tdata ({m_aixs_cmd_tuser,m_aixs_cmd_tdata}),
    .m_aixs_tvalid(m_aixs_cmd_tvalid),
    .m_aixs_tready(m_aixs_cmd_tready) 
);

// Read counter logic
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        cnt_r <= 'd0;
    end
    else if(reset)begin
        cnt_r <= 'd0;
    end
    else if(cmd.req &&  cmd.rw && cmd_ack)begin
        cnt_r <= start_sector;
    end
    else if(add_cnt_r)begin
        if(end_cnt_r)
            cnt_r <= 'd0;
        else
            cnt_r <= cnt_r + 1'b1;
    end
end
assign add_cnt_r = (state_c == RECIEVE_RDATA) && s_aixs_trans_tvalid && s_aixs_trans_tready && (~s_aixs_trans_tuser[0]);
assign end_cnt_r = add_cnt_r && cnt_r == end_sector - 1;

// Read sector counter
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        read_count <= 'd0;
    else if(reset)
        read_count <= 'd0;
    else if(state_c == RW_ARBT)
        read_count <= 'd0;
    else if((state_c == RECIEVE_RDATA) && (cnt_r[6:0] == {7{1'b0}}) && add_cnt_r)
        read_count <= read_count + 1;
end

// Read valid signal generation
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        r_vld <= 'd0;
    else if(reset)
        r_vld <= 'd0;
    else if(read_req2recieve_rdata_start && (start_vld == start_sector))
        r_vld <= 'd1;
    else if(add_cnt_r && (cnt_r == start_vld - 1))
        r_vld <= 'd1;
    else if(add_cnt_r && (cnt_r == end_vld))
        r_vld <= 'd0;
end

// Write counter logic
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        cnt_w <= 'd0;
    end
    else if(reset)begin
        cnt_w <= 'd0;
    end
    else if(cmd.req && (~cmd.rw) && cmd_ack)begin
        cnt_w <= start_sector;
    end
    else if(add_cnt_w)begin
        if(end_cnt_w)
            cnt_w <= 'd0;
        else
            cnt_w <= cnt_w + 1'b1;
    end
end
assign add_cnt_w = r_m_aixs_trans_tvalid && r_m_aixs_trans_tready;
assign end_cnt_w = add_cnt_w && cnt_w == end_sector - 1;

// Active counter logic
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        cnt_act <= 'd0;
    end
    else if(reset)begin
        cnt_act <= 'd0;
    end
    else if(state_c == WRITE_REQ)begin
        cnt_act <= 'd0;
    end
    else if(add_cnt_act)begin
        if(end_cnt_act)
            cnt_act <= 'd0;
        else
            cnt_act <= cnt_act + 1'b1;
    end
end
assign add_cnt_act = r_m_aixs_trans_tvalid && r_m_aixs_trans_tready;
assign end_cnt_act = add_cnt_act && cnt_act == 2048 - 1;

// Write valid signal generation
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        w_vld <= 'd0;
    else if(reset)
        w_vld <= 'd0;
    else if(recieve_dma_active2send_wdata_start && (start_vld == start_sector))
        w_vld <= 'd1;
    else if(add_cnt_w && (cnt_w == start_vld - 1))
        w_vld <= 'd1;
    else if(add_cnt_w && (cnt_w == end_vld))
        w_vld <= 'd0;
end

// Command stream interface assignments
assign s_aixs_cmd_tready   = w_vld ? r_m_aixs_trans_tready && (state_c == SEND_WDATA) : 1'b0;
assign r_m_aixs_trans_tdata  = w_vld ? s_aixs_cmd_tdata    : 'd0;
assign r_m_aixs_trans_tvalid = w_vld ? s_aixs_cmd_tvalid   && (state_c == SEND_WDATA) : (state_c == SEND_WDATA);
assign r_m_aixs_trans_tuser  = {s_aixs_cmd_tuser[USER_W-1:2],cnt_w==start_sector,end_cnt_w};

// Skid buffer for transaction TX interface
afx_skid_buffer_axis #(
    .DATA_W(40)
)
u1_afx_skid_buffer_axis_tx(
    .clk          (clk),
    .rst_n        (rst_n),
    .s_aixs_tdata ({r_m_aixs_trans_tuser,r_m_aixs_trans_tdata}),
    .s_aixs_tvalid(r_m_aixs_trans_tvalid),
    .s_aixs_tready(r_m_aixs_trans_tready),
    .m_aixs_tdata ({m_aixs_trans_tuser,m_aixs_trans_tdata}),
    .m_aixs_tvalid(m_aixs_trans_tvalid),
    .m_aixs_tready(m_aixs_trans_tready) 
);

// Info counter for PIO data processing
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        cnt_info <= 'd0;
    end
    else if(reset)begin
        cnt_info <= 'd0;
    end
    else if(add_cnt_info)begin
        if(end_cnt_info)
            cnt_info <= 'd0;
        else
            cnt_info <= cnt_info + 1'b1;
    end
end
assign add_cnt_info = (state_c == INIT_PIO_DATA) && s_aixs_trans_tvalid && s_aixs_trans_tready;
assign end_cnt_info = add_cnt_info && cnt_info == 127;

// Logical size field extraction
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        logic_size_f <= 'd0;
    else if(reset)
        logic_size_f <= 'd0;
    else if(add_cnt_info && (cnt_info == 53))
        logic_size_f <= s_aixs_trans_tdata[0 +: 16];
end

// Logical size extraction
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        logic_size <= 'd0;
    else if(reset)
        logic_size <= 'd0;
    else if(add_cnt_info && (cnt_info == 58))
        logic_size[15: 0] <= s_aixs_trans_tdata[16 +: 16];
    else if(add_cnt_info && (cnt_info == 59))
        logic_size[31:16] <= s_aixs_trans_tdata[0  +: 16];
end

// Sector size selection logic
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        sector_size_sel <= 'd0;
    else if(reset)
        sector_size_sel <= 'd0;
    else if(logic_size_f[12] == 0)
        sector_size_sel <= 'd0;
    else if((logic_size_f[12] == 1) && (logic_size == 256))
        sector_size_sel <= 'd1;
end

// Timer counter for initial delay
always_ff @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        cnt_timer <= 0;
    end
    else if(reset)begin
        cnt_timer <= 0;
    end
    else if(add_cnt_timer)begin
        if(end_cnt_timer)
            cnt_timer <= 0;
        else
            cnt_timer <= cnt_timer + 1'b1;
    end
end
assign add_cnt_timer = (state_c == IDLE) && en;
assign end_cnt_timer = add_cnt_timer && cnt_timer == TIMER - 1;

endmodule