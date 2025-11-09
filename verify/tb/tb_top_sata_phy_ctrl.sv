`timescale 1ns/1ns

module tb_top_sata_phy_ctrl;

logic               clk             ;
logic               rst_n           ;
logic   [3   :0]    rx_charisk      ;
logic   [31  :0]    rx_data         ;
logic   [3   :0]    tx_charisk      ;
logic   [31  :0]    tx_data         ;
logic               rx_comwake      ;
logic               rx_cominit      ;
logic               rx_eleidle      ;
logic               tx_cominit      ;
logic               tx_comwake      ;
logic   [31  :0]    dat_i           ;
logic   [3   :0]    datchar_i       ;
logic               hreset          ;
logic               phyrdy          ;
logic               slumber         ;
logic               partial         ;
logic               nearafelb       ;
logic               farafelb        ;
logic               spdsedl         ;
logic               spdmode         ;
logic               device_detect   ;
logic               phy_internal_err;
logic  [31   :0]    dat_o           ;
logic  [3    :0]    datchar_o       ;
logic               rxclock         ;
logic               cominit         ;
logic               comwake         ;
logic               comma           ;

initial begin
    rst_n = 1;
    #1
    rst_n = 0;
    repeat(10) @(posedge clk) #1;
    rst_n = 1;
end

initial begin
    rx_charisk= 'd0;
    rx_data   = 'd0;
    rx_comwake= 'd0;
    rx_cominit= 'd0;
    rx_eleidle= 'd0;
    dat_i     = 32'hBC4A4A7B;
    datchar_i = 4'b1000;
    hreset    = 'd0;
    slumber   = 'd0;
    partial   = 'd0;
    nearafelb = 'd0;
    farafelb  = 'd0;
    spdsedl   = 'd0;
end

sata_phy_ctrl  u_sata_phy_ctrl(
    .rx_clk          (clk             ),
    .tx_clk          (clk             ),
    .rst_n           (rst_n           ),

    .timeout_time    (1000            ),

    .rx_charisk      (rx_charisk      ),
    .rx_data         (rx_data         ),

    .tx_charisk      (tx_charisk      ),
    .tx_data         (tx_data         ),
    .rx_comwake      (rx_comwake      ),
    .rx_cominit      (rx_cominit      ),
    .rx_eleidle      (rx_eleidle      ),

    .tx_cominit      (tx_cominit      ),
    .tx_comwake      (tx_comwake      ),

    .dat_i           (dat_i           ),
    .datchar_i       (datchar_i       ),
    .hreset          (hreset          ),
    .phyrdy          (phyrdy          ),
    .slumber         (slumber         ),
    .partial         (partial         ),
    .nearafelb       (nearafelb       ),
    .farafelb        (farafelb        ),
    .spdsedl         (spdsedl         ),
    .spdmode         (spdmode         ),
    .device_detect   (device_detect   ),
    .phy_internal_err(phy_internal_err),
    .dat_o           (dat_o           ),
    .datchar_o       (datchar_o       ),
    .rxclock         (rxclock         ),
    .cominit         (cominit         ),
    .comwake         (comwake         ),
    .comma           (comma           ) 
);

initial begin
    $fsdbDumpfile("tb_top_sata_phy_ctrl.fsdb");
    $fsdbDumpvars(0, tb_top_sata_phy_ctrl,"+all");
end


endmodule