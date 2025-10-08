/*

以太网 MAC IP 使用示例

此示例展示如何在 FPGA 设计中实例化和使用 eth_mac_rgmii_axi 模块

Copyright (c) 2025

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

module eth_mac_example (
    // 系统时钟和复位
    input  wire         sys_clk,            // 系统时钟 (例如 100 MHz)
    input  wire         sys_rst,            // 系统复位
    
    // GTX 时钟 (125 MHz for Gigabit Ethernet)
    input  wire         gtx_clk,
    input  wire         gtx_clk90,
    
    // RGMII 接口 (连接到 PHY)
    input  wire         rgmii_rx_clk,
    input  wire [3:0]   rgmii_rxd,
    input  wire         rgmii_rx_ctl,
    output wire         rgmii_tx_clk,
    output wire [3:0]   rgmii_txd,
    output wire         rgmii_tx_ctl,
    
    // AXI Master 接口 (连接到系统总线/DDR控制器)
    output wire [7:0]   m_axi_awid,
    output wire [31:0]  m_axi_awaddr,
    output wire [7:0]   m_axi_awlen,
    output wire [2:0]   m_axi_awsize,
    output wire [1:0]   m_axi_awburst,
    output wire         m_axi_awlock,
    output wire [3:0]   m_axi_awcache,
    output wire [2:0]   m_axi_awprot,
    output wire         m_axi_awvalid,
    input  wire         m_axi_awready,
    output wire [63:0]  m_axi_wdata,
    output wire [7:0]   m_axi_wstrb,
    output wire         m_axi_wlast,
    output wire         m_axi_wvalid,
    input  wire         m_axi_wready,
    input  wire [7:0]   m_axi_bid,
    input  wire [1:0]   m_axi_bresp,
    input  wire         m_axi_bvalid,
    output wire         m_axi_bready,
    output wire [7:0]   m_axi_arid,
    output wire [31:0]  m_axi_araddr,
    output wire [7:0]   m_axi_arlen,
    output wire [2:0]   m_axi_arsize,
    output wire [1:0]   m_axi_arburst,
    output wire         m_axi_arlock,
    output wire [3:0]   m_axi_arcache,
    output wire [2:0]   m_axi_arprot,
    output wire         m_axi_arvalid,
    input  wire         m_axi_arready,
    input  wire [7:0]   m_axi_rid,
    input  wire [63:0]  m_axi_rdata,
    input  wire [1:0]   m_axi_rresp,
    input  wire         m_axi_rlast,
    input  wire         m_axi_rvalid,
    output wire         m_axi_rready,
    
    // AXI-Lite Slave 接口 (连接到处理器/控制总线)
    input  wire [15:0]  s_axil_awaddr,
    input  wire [2:0]   s_axil_awprot,
    input  wire         s_axil_awvalid,
    output wire         s_axil_awready,
    input  wire [31:0]  s_axil_wdata,
    input  wire [3:0]   s_axil_wstrb,
    input  wire         s_axil_wvalid,
    output wire         s_axil_wready,
    output wire [1:0]   s_axil_bresp,
    output wire         s_axil_bvalid,
    input  wire         s_axil_bready,
    input  wire [15:0]  s_axil_araddr,
    input  wire [2:0]   s_axil_arprot,
    input  wire         s_axil_arvalid,
    output wire         s_axil_arready,
    output wire [31:0]  s_axil_rdata,
    output wire [1:0]   s_axil_rresp,
    output wire         s_axil_rvalid,
    input  wire         s_axil_rready,
    
    // 中断输出
    output wire         eth_irq
);

// -------------------------------------------------------------------------
// 复位同步
// -------------------------------------------------------------------------

reg [3:0] gtx_rst_sync = 4'b1111;
reg [3:0] sys_rst_sync = 4'b1111;

always @(posedge gtx_clk or posedge sys_rst) begin
    if (sys_rst) begin
        gtx_rst_sync <= 4'b1111;
    end else begin
        gtx_rst_sync <= {gtx_rst_sync[2:0], 1'b0};
    end
end

always @(posedge sys_clk or posedge sys_rst) begin
    if (sys_rst) begin
        sys_rst_sync <= 4'b1111;
    end else begin
        sys_rst_sync <= {sys_rst_sync[2:0], 1'b0};
    end
end

wire gtx_rst_sync_n = gtx_rst_sync[3];
wire sys_rst_sync_n = sys_rst_sync[3];

// -------------------------------------------------------------------------
// 以太网 MAC 实例化
// -------------------------------------------------------------------------

eth_mac_rgmii_axi #(
    // 平台配置 - 根据实际 FPGA 平台修改
    .TARGET("XILINX"),
    .IODDR_STYLE("IODDR"),
    .CLOCK_INPUT_STYLE("BUFR"),
    .USE_CLK90("TRUE"),
    
    // AXI 配置
    .AXI_DATA_WIDTH(64),
    .AXI_ADDR_WIDTH(32),
    .AXI_ID_WIDTH(8),
    .AXI_MAX_BURST_LEN(256),
    
    // AXI-Lite 配置
    .AXIL_DATA_WIDTH(32),
    .AXIL_ADDR_WIDTH(16),
    
    // DMA 配置
    .DMA_LEN_WIDTH(20),
    .DMA_TAG_WIDTH(8),
    
    // FIFO 深度
    .TX_FIFO_DEPTH(4096),
    .RX_FIFO_DEPTH(4096),
    
    // 帧过滤器配置
    .ENABLE_MAC_FILTER(1),
    .ENABLE_VLAN_FILTER(0),
    .NUM_MAC_FILTERS(4),
    
    // ARP 配置
    .ARP_CACHE_ADDR_WIDTH(9),
    .ARP_REQUEST_RETRY_COUNT(4),
    .ARP_REQUEST_RETRY_INTERVAL(125000000*2),
    .ARP_REQUEST_TIMEOUT(125000000*30)
)
eth_mac_inst (
    // 时钟和复位
    .gtx_clk(gtx_clk),
    .gtx_clk90(gtx_clk90),
    .gtx_rst(gtx_rst_sync_n),
    .logic_clk(sys_clk),
    .logic_rst(sys_rst_sync_n),
    
    // RGMII 接口
    .rgmii_rx_clk(rgmii_rx_clk),
    .rgmii_rxd(rgmii_rxd),
    .rgmii_rx_ctl(rgmii_rx_ctl),
    .rgmii_tx_clk(rgmii_tx_clk),
    .rgmii_txd(rgmii_txd),
    .rgmii_tx_ctl(rgmii_tx_ctl),
    
    // AXI Master 接口 (DMA)
    .m_axi_awid(m_axi_awid),
    .m_axi_awaddr(m_axi_awaddr),
    .m_axi_awlen(m_axi_awlen),
    .m_axi_awsize(m_axi_awsize),
    .m_axi_awburst(m_axi_awburst),
    .m_axi_awlock(m_axi_awlock),
    .m_axi_awcache(m_axi_awcache),
    .m_axi_awprot(m_axi_awprot),
    .m_axi_awvalid(m_axi_awvalid),
    .m_axi_awready(m_axi_awready),
    .m_axi_wdata(m_axi_wdata),
    .m_axi_wstrb(m_axi_wstrb),
    .m_axi_wlast(m_axi_wlast),
    .m_axi_wvalid(m_axi_wvalid),
    .m_axi_wready(m_axi_wready),
    .m_axi_bid(m_axi_bid),
    .m_axi_bresp(m_axi_bresp),
    .m_axi_bvalid(m_axi_bvalid),
    .m_axi_bready(m_axi_bready),
    .m_axi_arid(m_axi_arid),
    .m_axi_araddr(m_axi_araddr),
    .m_axi_arlen(m_axi_arlen),
    .m_axi_arsize(m_axi_arsize),
    .m_axi_arburst(m_axi_arburst),
    .m_axi_arlock(m_axi_arlock),
    .m_axi_arcache(m_axi_arcache),
    .m_axi_arprot(m_axi_arprot),
    .m_axi_arvalid(m_axi_arvalid),
    .m_axi_arready(m_axi_arready),
    .m_axi_rid(m_axi_rid),
    .m_axi_rdata(m_axi_rdata),
    .m_axi_rresp(m_axi_rresp),
    .m_axi_rlast(m_axi_rlast),
    .m_axi_rvalid(m_axi_rvalid),
    .m_axi_rready(m_axi_rready),
    
    // AXI-Lite Slave 接口 (控制)
    .s_axil_awaddr(s_axil_awaddr),
    .s_axil_awprot(s_axil_awprot),
    .s_axil_awvalid(s_axil_awvalid),
    .s_axil_awready(s_axil_awready),
    .s_axil_wdata(s_axil_wdata),
    .s_axil_wstrb(s_axil_wstrb),
    .s_axil_wvalid(s_axil_wvalid),
    .s_axil_wready(s_axil_wready),
    .s_axil_bresp(s_axil_bresp),
    .s_axil_bvalid(s_axil_bvalid),
    .s_axil_bready(s_axil_bready),
    .s_axil_araddr(s_axil_araddr),
    .s_axil_arprot(s_axil_arprot),
    .s_axil_arvalid(s_axil_arvalid),
    .s_axil_arready(s_axil_arready),
    .s_axil_rdata(s_axil_rdata),
    .s_axil_rresp(s_axil_rresp),
    .s_axil_rvalid(s_axil_rvalid),
    .s_axil_rready(s_axil_rready),
    
    // 中断
    .irq(eth_irq)
);

// -------------------------------------------------------------------------
// 可选：添加 ILA 调试核心
// -------------------------------------------------------------------------

// 如果需要调试，可以在这里实例化 Xilinx ILA 核心
// 监控关键信号，如 RGMII 接口、AXI 事务等

endmodule

`resetall

