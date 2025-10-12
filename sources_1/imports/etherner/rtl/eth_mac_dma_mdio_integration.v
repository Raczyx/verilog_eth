/*

以太网MAC、DMA和MDIO集成模块
集成 eth_mac_1g_rgmii_fifo, axi_dma 和 eth_miim 模块

增强功能：
- 包含MDIO控制器用于PHY管理
- 可以配置和监控PHY芯片
- 读取链路状态和速度

Copyright (c) 2024

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * 以太网MAC、DMA与MDIO集成模块
 * 
 * 功能：
 * - DMA读取通道 -> 以太网MAC发送 (TX路径)
 * - 以太网MAC接收 -> DMA写入通道 (RX路径)
 * - MDIO控制器 -> PHY配置和状态读取
 */
module eth_mac_dma_mdio_integration #
(
    // MAC参数
    parameter TARGET = "GENERIC",
    parameter IODDR_STYLE = "IODDR2",
    parameter CLOCK_INPUT_STYLE = "BUFG",
    parameter USE_CLK90 = "TRUE",
    parameter ENABLE_PADDING = 1,
    parameter MIN_FRAME_LENGTH = 64,
    parameter TX_FIFO_DEPTH = 4096,
    parameter TX_FIFO_RAM_PIPELINE = 1,
    parameter TX_FRAME_FIFO = 1,
    parameter TX_DROP_OVERSIZE_FRAME = TX_FRAME_FIFO,
    parameter TX_DROP_BAD_FRAME = TX_DROP_OVERSIZE_FRAME,
    parameter TX_DROP_WHEN_FULL = 0,
    parameter RX_FIFO_DEPTH = 4096,
    parameter RX_FIFO_RAM_PIPELINE = 1,
    parameter RX_FRAME_FIFO = 1,
    parameter RX_DROP_OVERSIZE_FRAME = RX_FRAME_FIFO,
    parameter RX_DROP_BAD_FRAME = RX_DROP_OVERSIZE_FRAME,
    parameter RX_DROP_WHEN_FULL = RX_DROP_OVERSIZE_FRAME,
    
    // DMA参数
    parameter AXI_DATA_WIDTH = 32,
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    parameter AXI_ID_WIDTH = 8,
    parameter AXI_MAX_BURST_LEN = 16,
    parameter AXIS_DATA_WIDTH = 32,
    parameter AXIS_KEEP_ENABLE = (AXIS_DATA_WIDTH>8),
    parameter AXIS_KEEP_WIDTH = (AXIS_DATA_WIDTH/8),
    parameter AXIS_LAST_ENABLE = 1,
    parameter AXIS_ID_ENABLE = 0,
    parameter AXIS_ID_WIDTH = 8,
    parameter AXIS_DEST_ENABLE = 0,
    parameter AXIS_DEST_WIDTH = 8,
    parameter AXIS_USER_ENABLE = 1,
    parameter AXIS_USER_WIDTH = 1,
    parameter LEN_WIDTH = 20,
    parameter TAG_WIDTH = 8,
    parameter ENABLE_SG = 0,
    parameter ENABLE_UNALIGNED = 0
)
(
    /*
     * 时钟和复位信号
     */
    input  wire                       clk,
    input  wire                       rst,
    input  wire                       gtx_clk,
    input  wire                       gtx_clk90,
    input  wire                       gtx_rst,
    
    /*
     * DMA读取描述符输入 (用于TX - 从内存读取数据并通过以太网发送)
     */
    input  wire [AXI_ADDR_WIDTH-1:0]  s_axis_read_desc_addr,
    input  wire [LEN_WIDTH-1:0]       s_axis_read_desc_len,
    input  wire [TAG_WIDTH-1:0]       s_axis_read_desc_tag,
    input  wire [AXIS_ID_WIDTH-1:0]   s_axis_read_desc_id,
    input  wire [AXIS_DEST_WIDTH-1:0] s_axis_read_desc_dest,
    input  wire [AXIS_USER_WIDTH-1:0] s_axis_read_desc_user,
    input  wire                       s_axis_read_desc_valid,
    output wire                       s_axis_read_desc_ready,
    
    /*
     * DMA读取描述符状态输出
     */
    output wire [TAG_WIDTH-1:0]       m_axis_read_desc_status_tag,
    output wire [3:0]                 m_axis_read_desc_status_error,
    output wire                       m_axis_read_desc_status_valid,
    
    /*
     * DMA写入描述符输入 (用于RX - 从以太网接收数据并写入内存)
     */
    input  wire [AXI_ADDR_WIDTH-1:0]  s_axis_write_desc_addr,
    input  wire [LEN_WIDTH-1:0]       s_axis_write_desc_len,
    input  wire [TAG_WIDTH-1:0]       s_axis_write_desc_tag,
    input  wire                       s_axis_write_desc_valid,
    output wire                       s_axis_write_desc_ready,
    
    /*
     * DMA写入描述符状态输出
     */
    output wire [LEN_WIDTH-1:0]       m_axis_write_desc_status_len,
    output wire [TAG_WIDTH-1:0]       m_axis_write_desc_status_tag,
    output wire [AXIS_ID_WIDTH-1:0]   m_axis_write_desc_status_id,
    output wire [AXIS_DEST_WIDTH-1:0] m_axis_write_desc_status_dest,
    output wire [AXIS_USER_WIDTH-1:0] m_axis_write_desc_status_user,
    output wire [3:0]                 m_axis_write_desc_status_error,
    output wire                       m_axis_write_desc_status_valid,
    
    /*
     * RGMII接口
     */
    input  wire                       rgmii_rx_clk,
    input  wire [3:0]                 rgmii_rxd,
    input  wire                       rgmii_rx_ctl,
    output wire                       rgmii_tx_clk,
    output wire [3:0]                 rgmii_txd,
    output wire                       rgmii_tx_ctl,
    
    /*
     * MDIO接口
     */
    output wire                       mdc,
    output wire                       mdio_o,
    output wire                       mdio_oe,
    input  wire                       mdio_i,
    
    /*
     * MDIO控制接口
     */
    input  wire [7:0]                 mdio_divider,
    input  wire                       mdio_no_preamble,
    input  wire [15:0]                mdio_ctrl_data,
    input  wire [4:0]                 mdio_reg_addr,
    input  wire [4:0]                 mdio_phy_addr,
    input  wire                       mdio_write_req,
    input  wire                       mdio_read_req,
    input  wire                       mdio_scan_req,
    output wire                       mdio_busy,
    output wire [15:0]                mdio_read_data,
    output wire                       mdio_link_fail,
    output wire                       mdio_data_valid,
    
    /*
     * AXI主接口 (DMA使用)
     */
    output wire [AXI_ID_WIDTH-1:0]    m_axi_awid,
    output wire [AXI_ADDR_WIDTH-1:0]  m_axi_awaddr,
    output wire [7:0]                 m_axi_awlen,
    output wire [2:0]                 m_axi_awsize,
    output wire [1:0]                 m_axi_awburst,
    output wire                       m_axi_awlock,
    output wire [3:0]                 m_axi_awcache,
    output wire [2:0]                 m_axi_awprot,
    output wire                       m_axi_awvalid,
    input  wire                       m_axi_awready,
    output wire [AXI_DATA_WIDTH-1:0]  m_axi_wdata,
    output wire [AXI_STRB_WIDTH-1:0]  m_axi_wstrb,
    output wire                       m_axi_wlast,
    output wire                       m_axi_wvalid,
    input  wire                       m_axi_wready,
    input  wire [AXI_ID_WIDTH-1:0]    m_axi_bid,
    input  wire [1:0]                 m_axi_bresp,
    input  wire                       m_axi_bvalid,
    output wire                       m_axi_bready,
    output wire [AXI_ID_WIDTH-1:0]    m_axi_arid,
    output wire [AXI_ADDR_WIDTH-1:0]  m_axi_araddr,
    output wire [7:0]                 m_axi_arlen,
    output wire [2:0]                 m_axi_arsize,
    output wire [1:0]                 m_axi_arburst,
    output wire                       m_axi_arlock,
    output wire [3:0]                 m_axi_arcache,
    output wire [2:0]                 m_axi_arprot,
    output wire                       m_axi_arvalid,
    input  wire                       m_axi_arready,
    input  wire [AXI_ID_WIDTH-1:0]    m_axi_rid,
    input  wire [AXI_DATA_WIDTH-1:0]  m_axi_rdata,
    input  wire [1:0]                 m_axi_rresp,
    input  wire                       m_axi_rlast,
    input  wire                       m_axi_rvalid,
    output wire                       m_axi_rready,
    
    /*
     * 状态输出
     */
    output wire                       tx_error_underflow,
    output wire                       tx_fifo_overflow,
    output wire                       tx_fifo_bad_frame,
    output wire                       tx_fifo_good_frame,
    output wire                       rx_error_bad_frame,
    output wire                       rx_error_bad_fcs,
    output wire                       rx_fifo_overflow,
    output wire                       rx_fifo_bad_frame,
    output wire                       rx_fifo_good_frame,
    output wire [1:0]                 speed,
    
    /*
     * 配置
     */
    input  wire [7:0]                 cfg_ifg,
    input  wire                       cfg_tx_enable,
    input  wire                       cfg_rx_enable,
    input  wire                       dma_read_enable,
    input  wire                       dma_write_enable,
    input  wire                       dma_write_abort
);

// 内部AXI Stream信号 - TX路径 (DMA读取 -> MAC发送)
wire [AXIS_DATA_WIDTH-1:0] tx_axis_tdata;
wire [AXIS_KEEP_WIDTH-1:0] tx_axis_tkeep;
wire                       tx_axis_tvalid;
wire                       tx_axis_tready;
wire                       tx_axis_tlast;
wire [AXIS_ID_WIDTH-1:0]   tx_axis_tid;
wire [AXIS_DEST_WIDTH-1:0] tx_axis_tdest;
wire [AXIS_USER_WIDTH-1:0] tx_axis_tuser;

// 内部AXI Stream信号 - RX路径 (MAC接收 -> DMA写入)
wire [AXIS_DATA_WIDTH-1:0] rx_axis_tdata;
wire [AXIS_KEEP_WIDTH-1:0] rx_axis_tkeep;
wire                       rx_axis_tvalid;
wire                       rx_axis_tready;
wire                       rx_axis_tlast;
wire [AXIS_ID_WIDTH-1:0]   rx_axis_tid;
wire [AXIS_DEST_WIDTH-1:0] rx_axis_tdest;
wire [AXIS_USER_WIDTH-1:0] rx_axis_tuser;

// MDIO内部信号
wire mdio_write_start;
wire mdio_read_start;
wire mdio_update_reg;

/*
 * 以太网MAC模块实例
 */
eth_mac_1g_rgmii_fifo #(
    .TARGET(TARGET),
    .IODDR_STYLE(IODDR_STYLE),
    .CLOCK_INPUT_STYLE(CLOCK_INPUT_STYLE),
    .USE_CLK90(USE_CLK90),
    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
    .AXIS_KEEP_ENABLE(AXIS_KEEP_ENABLE),
    .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .ENABLE_PADDING(ENABLE_PADDING),
    .MIN_FRAME_LENGTH(MIN_FRAME_LENGTH),
    .TX_FIFO_DEPTH(TX_FIFO_DEPTH),
    .TX_FIFO_RAM_PIPELINE(TX_FIFO_RAM_PIPELINE),
    .TX_FRAME_FIFO(TX_FRAME_FIFO),
    .TX_DROP_OVERSIZE_FRAME(TX_DROP_OVERSIZE_FRAME),
    .TX_DROP_BAD_FRAME(TX_DROP_BAD_FRAME),
    .TX_DROP_WHEN_FULL(TX_DROP_WHEN_FULL),
    .RX_FIFO_DEPTH(RX_FIFO_DEPTH),
    .RX_FIFO_RAM_PIPELINE(RX_FIFO_RAM_PIPELINE),
    .RX_FRAME_FIFO(RX_FRAME_FIFO),
    .RX_DROP_OVERSIZE_FRAME(RX_DROP_OVERSIZE_FRAME),
    .RX_DROP_BAD_FRAME(RX_DROP_BAD_FRAME),
    .RX_DROP_WHEN_FULL(RX_DROP_WHEN_FULL)
)
eth_mac_inst (
    .gtx_clk(gtx_clk),
    .gtx_clk90(gtx_clk90),
    .gtx_rst(gtx_rst),
    .logic_clk(clk),
    .logic_rst(rst),
    
    // TX路径 - 从DMA接收数据发送
    .tx_axis_tdata(tx_axis_tdata),
    .tx_axis_tkeep(tx_axis_tkeep),
    .tx_axis_tvalid(tx_axis_tvalid),
    .tx_axis_tready(tx_axis_tready),
    .tx_axis_tlast(tx_axis_tlast),
    .tx_axis_tuser(tx_axis_tuser),
    
    // RX路径 - 接收的数据发送到DMA
    .rx_axis_tdata(rx_axis_tdata),
    .rx_axis_tkeep(rx_axis_tkeep),
    .rx_axis_tvalid(rx_axis_tvalid),
    .rx_axis_tready(rx_axis_tready),
    .rx_axis_tlast(rx_axis_tlast),
    .rx_axis_tuser(rx_axis_tuser),
    
    // RGMII接口
    .rgmii_rx_clk(rgmii_rx_clk),
    .rgmii_rxd(rgmii_rxd),
    .rgmii_rx_ctl(rgmii_rx_ctl),
    .rgmii_tx_clk(rgmii_tx_clk),
    .rgmii_txd(rgmii_txd),
    .rgmii_tx_ctl(rgmii_tx_ctl),
    
    // 状态信号
    .tx_error_underflow(tx_error_underflow),
    .tx_fifo_overflow(tx_fifo_overflow),
    .tx_fifo_bad_frame(tx_fifo_bad_frame),
    .tx_fifo_good_frame(tx_fifo_good_frame),
    .rx_error_bad_frame(rx_error_bad_frame),
    .rx_error_bad_fcs(rx_error_bad_fcs),
    .rx_fifo_overflow(rx_fifo_overflow),
    .rx_fifo_bad_frame(rx_fifo_bad_frame),
    .rx_fifo_good_frame(rx_fifo_good_frame),
    .speed(speed),
    
    // 配置
    .cfg_ifg(cfg_ifg),
    .cfg_tx_enable(cfg_tx_enable),
    .cfg_rx_enable(cfg_rx_enable)
);

/*
 * AXI DMA模块实例
 */
axi_dma #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN),
    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
    .AXIS_KEEP_ENABLE(AXIS_KEEP_ENABLE),
    .AXIS_KEEP_WIDTH(AXIS_KEEP_WIDTH),
    .AXIS_LAST_ENABLE(AXIS_LAST_ENABLE),
    .AXIS_ID_ENABLE(AXIS_ID_ENABLE),
    .AXIS_ID_WIDTH(AXIS_ID_WIDTH),
    .AXIS_DEST_ENABLE(AXIS_DEST_ENABLE),
    .AXIS_DEST_WIDTH(AXIS_DEST_WIDTH),
    .AXIS_USER_ENABLE(AXIS_USER_ENABLE),
    .AXIS_USER_WIDTH(AXIS_USER_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    .TAG_WIDTH(TAG_WIDTH),
    .ENABLE_SG(ENABLE_SG),
    .ENABLE_UNALIGNED(ENABLE_UNALIGNED)
)
axi_dma_inst (
    .clk(clk),
    .rst(rst),
    
    // DMA读取描述符 - 用于TX
    .s_axis_read_desc_addr(s_axis_read_desc_addr),
    .s_axis_read_desc_len(s_axis_read_desc_len),
    .s_axis_read_desc_tag(s_axis_read_desc_tag),
    .s_axis_read_desc_id(s_axis_read_desc_id),
    .s_axis_read_desc_dest(s_axis_read_desc_dest),
    .s_axis_read_desc_user(s_axis_read_desc_user),
    .s_axis_read_desc_valid(s_axis_read_desc_valid),
    .s_axis_read_desc_ready(s_axis_read_desc_ready),
    
    // DMA读取状态
    .m_axis_read_desc_status_tag(m_axis_read_desc_status_tag),
    .m_axis_read_desc_status_error(m_axis_read_desc_status_error),
    .m_axis_read_desc_status_valid(m_axis_read_desc_status_valid),
    
    // DMA读取数据输出 -> MAC TX输入
    .m_axis_read_data_tdata(tx_axis_tdata),
    .m_axis_read_data_tkeep(tx_axis_tkeep),
    .m_axis_read_data_tvalid(tx_axis_tvalid),
    .m_axis_read_data_tready(tx_axis_tready),
    .m_axis_read_data_tlast(tx_axis_tlast),
    .m_axis_read_data_tid(tx_axis_tid),
    .m_axis_read_data_tdest(tx_axis_tdest),
    .m_axis_read_data_tuser(tx_axis_tuser),
    
    // DMA写入描述符 - 用于RX
    .s_axis_write_desc_addr(s_axis_write_desc_addr),
    .s_axis_write_desc_len(s_axis_write_desc_len),
    .s_axis_write_desc_tag(s_axis_write_desc_tag),
    .s_axis_write_desc_valid(s_axis_write_desc_valid),
    .s_axis_write_desc_ready(s_axis_write_desc_ready),
    
    // DMA写入状态
    .m_axis_write_desc_status_len(m_axis_write_desc_status_len),
    .m_axis_write_desc_status_tag(m_axis_write_desc_status_tag),
    .m_axis_write_desc_status_id(m_axis_write_desc_status_id),
    .m_axis_write_desc_status_dest(m_axis_write_desc_status_dest),
    .m_axis_write_desc_status_user(m_axis_write_desc_status_user),
    .m_axis_write_desc_status_error(m_axis_write_desc_status_error),
    .m_axis_write_desc_status_valid(m_axis_write_desc_status_valid),
    
    // DMA写入数据输入 <- MAC RX输出
    .s_axis_write_data_tdata(rx_axis_tdata),
    .s_axis_write_data_tkeep(rx_axis_tkeep),
    .s_axis_write_data_tvalid(rx_axis_tvalid),
    .s_axis_write_data_tready(rx_axis_tready),
    .s_axis_write_data_tlast(rx_axis_tlast),
    .s_axis_write_data_tid(rx_axis_tid),
    .s_axis_write_data_tdest(rx_axis_tdest),
    .s_axis_write_data_tuser(rx_axis_tuser),
    
    // AXI主接口
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
    
    // 配置
    .read_enable(dma_read_enable),
    .write_enable(dma_write_enable),
    .write_abort(dma_write_abort)
);

/*
 * MDIO管理接口模块实例
 */
eth_miim mdio_ctrl (
    .Clk(clk),
    .Reset(rst),
    .Divider(mdio_divider),
    .NoPre(mdio_no_preamble),
    .CtrlData(mdio_ctrl_data),
    .Rgad(mdio_reg_addr),
    .Fiad(mdio_phy_addr),
    .WCtrlData(mdio_write_req),
    .RStat(mdio_read_req),
    .ScanStat(mdio_scan_req),
    .Mdo(mdio_o),
    .MdoEn(mdio_oe),
    .Mdi(mdio_i),
    .Mdc(mdc),
    .Busy(mdio_busy),
    .Prsd(mdio_read_data),
    .LinkFail(mdio_link_fail),
    .Nvalid(mdio_data_valid),
    .WCtrlDataStart(mdio_write_start),
    .RStatStart(mdio_read_start),
    .UpdateMIIRX_DATAReg(mdio_update_reg)
);

endmodule

`resetall

