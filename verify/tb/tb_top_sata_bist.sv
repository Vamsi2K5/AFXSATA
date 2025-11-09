module tb_top_sata_bist;

logic                           clk                 ;
logic                           rst_n               ;

logic                           mode                ;//0,normal 1,trig
logic  [2                -1:0]  speed_test          ;
logic                           tirg                ;
logic  [32               -1:0]  cycle               ;
logic  [16               -1:0]  num                 ;//dw
logic  [48               -1:0]  addr                ;
logic                           enable              ;

logic  [64               -1:0]  cmd_dat             ;
logic                           cmd_wr              ;
logic                           cmd_req             ;
logic                           cmd_ack             ;

logic  [31                 :0]  s_axis_usr_tdata    ;
logic  [8                -1:0]  s_axis_usr_tuser    ;//{drop,err,keep[3:0],sop,eop}
logic                           s_axis_usr_tvalid   ;
logic                           s_axis_usr_tready   ;

logic  [31                 :0]  m_axis_usr_tdata    ;
logic  [8                -1:0]  m_axis_usr_tuser    ;//{drop,err,keep[3:0],sop,eop}
logic                           m_axis_usr_tvalid   ;
logic                           m_axis_usr_tready   ;

logic  [31                 :0]  err_cnt             ;
logic  [31                 :0]  wr_cnt_sop          ;
logic  [31                 :0]  wr_cnt_eop          ;
logic  [31                 :0]  rd_cnt_sop          ;
logic  [31                 :0]  rd_cnt_eop          ;

sata_bist u_sata_bist(
    .clk                 (clk                   ),
    .rst_n               (rst_n                 ),

    .level               (32'h7fffffff          ),
    .speed_test          (speed_test            ),
    .mode                (mode                  ),//0,normal 1,trig
    .tirg                (tirg                  ),
    .cycle               (cycle                 ),
    .num                 (num                   ),//dw
    .addr                (addr                  ),
    .enable              (enable                ),

    .err_cnt             (err_cnt               ),
    .wr_cnt_sop          (wr_cnt_sop            ),
    .wr_cnt_eop          (wr_cnt_eop            ),
    .rd_cnt_sop          (rd_cnt_sop            ),
    .rd_cnt_eop          (rd_cnt_eop            ),

    .cmd_dat             (cmd_dat               ),
    .cmd_wr              (cmd_wr                ),
    .cmd_req             (cmd_req               ),
    .cmd_ack             (cmd_ack               ),

    .s_axis_sbt_tdata    (s_axis_usr_tdata      ),
    .s_axis_sbt_tuser    (s_axis_usr_tuser      ),//{drop,err,keep[3:0],sop,eop}
    .s_axis_sbt_tvalid   (s_axis_usr_tvalid     ),
    .s_axis_sbt_tready   (s_axis_usr_tready     ),

    .m_axis_sbt_tdata    (m_axis_usr_tdata      ),
    .m_axis_sbt_tuser    (m_axis_usr_tuser      ),//{drop,err,keep[3:0],sop,eop}
    .m_axis_sbt_tvalid   (m_axis_usr_tvalid     ),
    .m_axis_sbt_tready   (m_axis_usr_tready     ) 
);

initial begin
    $fsdbDumpfile("tb_top_sata_bist.fsdb");
    $fsdbDumpvars(0, tb_top_sata_bist,"+all");
end

endmodule
