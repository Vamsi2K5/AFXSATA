`ifndef __SATA_WRAPPER_DEFINE_SVH
`define __SATA_WRAPPER_DEFINE_SVH 1

`define LINK_USER_W 8

`define ALIGNp   32'hBC4A4A7B
`define CONTp    32'h7CAA9999
`define DMATp    32'h7CB53636
`define EOFp     32'h7CB5D5D5
`define HOLDp    32'h7CAAD5D5
`define HOLDAp   32'h7CAA9595
`define PMACKp   32'h7C959595
`define PMNAKp   32'h7C95F5F5
`define PMREQ_Pp 32'h7CB51717
`define PMREQ_Sp 32'h7C957575
`define R_ERRp   32'h7CB55656
`define R_IPp    32'h7CB55555
`define R_OKp    32'h7CB53535
`define R_RDYp   32'h7C954A4A
`define SOFp     32'h7CB53737
`define SYNCp    32'h7C95B5B5
`define WTRMp    32'h7CB55858
`define X_RDYp   32'h7CB55757

typedef enum logic [4 :0]{
    align   = 5'd1 ,
    cont    = 5'd2 ,
    dmat    = 5'd3 ,
    eof     = 5'd4 ,
    hold    = 5'd5 ,
    holda   = 5'd6 ,
    pmack   = 5'd7 ,
    pmnak   = 5'd8 ,
    pmreq_p = 5'd9 ,
    pmreq_s = 5'd10,
    r_err   = 5'd11,
    r_ip    = 5'd12,
    r_ok    = 5'd13,
    r_rdy   = 5'd14,
    sof     = 5'd15,
    sync    = 5'd16,
    wtrm    = 5'd17,
    x_rdy   = 5'd18,
    is_dat  = 5'd0 ,
    is_crc  = 5'd30,
    err     = 5'd31 
} sata_p_t;

typedef union packed{
    struct packed{
        logic  [7          :0]    cmd       ;
        logic  [47         :0]    lba       ;
        logic  [7          :0]    device    ;
        logic  [7          :0]    control   ;
        logic  [15         :0]    count     ;
    }h2d;
    struct packed{
        logic  [7          :0]    status    ;
        logic  [47         :0]    lba       ;
        logic  [7          :0]    device    ;
        logic  [7          :0]    error     ;
        logic  [15         :0]    count     ;
    }d2h;
}cmd_t;

typedef struct packed {
    logic             req;
    logic             rw ;
    logic  [23  -1:0] len;
    logic  [48  -1:0] addr;
}app_cmd_t;

`endif