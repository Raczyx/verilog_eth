/*

以太网 MAC Lite IP 模块 - 基于 RGMII 接口
简化版本：无 ARP 功能

特性：
- RGMII 物理接口（支持10/100/1000 Mbps）
- 可配置的帧过滤器（MAC地址、EtherType）
- 双通道 AXI DMA（独立的TX和RX）
- AXI-Lite 控制寄存器接口
- 中断支持
- 直接以太网帧处理（无IP/ARP协议栈）

适用场景：
- 自定义协议
- 简单的以太网通信
- 不需要IP/ARP的应用
- 资源受限的FPGA设计

Copyright (c) 2025

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

module eth_mac_lite #(
    // 目标平台
    parameter TARGET = "GENERIC",
    // IODDR 样式
    parameter IODDR_STYLE = "IODDR2",
    // 时钟输入样式
    parameter CLOCK_INPUT_STYLE = "BUFG",
    // 使用 90 度时钟用于 RGMII 发送
    parameter USE_CLK90 = "TRUE",
    
    // AXI 数据总线宽度
    parameter AXI_DATA_WIDTH = 256,
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    parameter AXI_ID_WIDTH = 8,
    parameter AXI_MAX_BURST_LEN = 256,
    
    // AXI-Lite 控制接口
    parameter AXIL_DATA_WIDTH = 32,
    parameter AXIL_ADDR_WIDTH = 16,
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    
    // DMA 配置
    parameter DMA_LEN_WIDTH = 20,
    parameter DMA_TAG_WIDTH = 8,
    
    // MAC FIFO 深度
    parameter TX_FIFO_DEPTH = 4096,
    parameter RX_FIFO_DEPTH = 4096,
    
    // 帧过滤器配置
    parameter ENABLE_MAC_FILTER = 1,
    parameter NUM_MAC_FILTERS = 4
)(
    /*
     * 时钟和复位
     */
    input  wire                         gtx_clk,
    input  wire                         gtx_clk90,
    input  wire                         gtx_rst,
    input  wire                         logic_clk,
    input  wire                         logic_rst,
    
    /*
     * RGMII 接口
     */
    input  wire                         rgmii_rx_clk,
    input  wire [3:0]                   rgmii_rxd,
    input  wire                         rgmii_rx_ctl,
    output wire                         rgmii_tx_clk,
    output wire [3:0]                   rgmii_txd,
    output wire                         rgmii_tx_ctl,
    
    /*
     * AXI Master 接口 (用于 DMA)
     */
    output wire [AXI_ID_WIDTH-1:0]      m_axi_awid,
    output wire [AXI_ADDR_WIDTH-1:0]    m_axi_awaddr,
    output wire [7:0]                   m_axi_awlen,
    output wire [2:0]                   m_axi_awsize,
    output wire [1:0]                   m_axi_awburst,
    output wire                         m_axi_awlock,
    output wire [3:0]                   m_axi_awcache,
    output wire [2:0]                   m_axi_awprot,
    output wire                         m_axi_awvalid,
    input  wire                         m_axi_awready,
    output wire [AXI_DATA_WIDTH-1:0]    m_axi_wdata,
    output wire [AXI_STRB_WIDTH-1:0]    m_axi_wstrb,
    output wire                         m_axi_wlast,
    output wire                         m_axi_wvalid,
    input  wire                         m_axi_wready,
    input  wire [AXI_ID_WIDTH-1:0]      m_axi_bid,
    input  wire [1:0]                   m_axi_bresp,
    input  wire                         m_axi_bvalid,
    output wire                         m_axi_bready,
    output wire [AXI_ID_WIDTH-1:0]      m_axi_arid,
    output wire [AXI_ADDR_WIDTH-1:0]    m_axi_araddr,
    output wire [7:0]                   m_axi_arlen,
    output wire [2:0]                   m_axi_arsize,
    output wire [1:0]                   m_axi_arburst,
    output wire                         m_axi_arlock,
    output wire [3:0]                   m_axi_arcache,
    output wire [2:0]                   m_axi_arprot,
    output wire                         m_axi_arvalid,
    input  wire                         m_axi_arready,
    input  wire [AXI_ID_WIDTH-1:0]      m_axi_rid,
    input  wire [AXI_DATA_WIDTH-1:0]    m_axi_rdata,
    input  wire [1:0]                   m_axi_rresp,
    input  wire                         m_axi_rlast,
    input  wire                         m_axi_rvalid,
    output wire                         m_axi_rready,
    
    /*
     * AXI-Lite Slave 接口 (控制寄存器)
     */
    input  wire [AXIL_ADDR_WIDTH-1:0]   s_axil_awaddr,
    input  wire [2:0]                   s_axil_awprot,
    input  wire                         s_axil_awvalid,
    output wire                         s_axil_awready,
    input  wire [AXIL_DATA_WIDTH-1:0]   s_axil_wdata,
    input  wire [AXIL_STRB_WIDTH-1:0]   s_axil_wstrb,
    input  wire                         s_axil_wvalid,
    output wire                         s_axil_wready,
    output wire [1:0]                   s_axil_bresp,
    output wire                         s_axil_bvalid,
    input  wire                         s_axil_bready,
    input  wire [AXIL_ADDR_WIDTH-1:0]   s_axil_araddr,
    input  wire [2:0]                   s_axil_arprot,
    input  wire                         s_axil_arvalid,
    output wire                         s_axil_arready,
    output wire [AXIL_DATA_WIDTH-1:0]   s_axil_rdata,
    output wire [1:0]                   s_axil_rresp,
    output wire                         s_axil_rvalid,
    input  wire                         s_axil_rready,
    
    /*
     * 中断输出
     */
    output wire                         irq
);

// 内部参数
localparam AXIS_DATA_WIDTH = 8;

// -------------------------------------------------------------------------
// 内部信号
// -------------------------------------------------------------------------

// MAC 接口信号
wire [AXIS_DATA_WIDTH-1:0]  mac_tx_axis_tdata;
wire                        mac_tx_axis_tvalid;
wire                        mac_tx_axis_tready;
wire                        mac_tx_axis_tlast;
wire                        mac_tx_axis_tuser;

wire [AXIS_DATA_WIDTH-1:0]  mac_rx_axis_tdata;
wire                        mac_rx_axis_tvalid;
wire                        mac_rx_axis_tready;
wire                        mac_rx_axis_tlast;
wire                        mac_rx_axis_tuser;

// MAC 状态信号
wire                        mac_tx_error_underflow;
wire                        mac_tx_fifo_overflow;
wire                        mac_tx_fifo_bad_frame;
wire                        mac_tx_fifo_good_frame;
wire                        mac_rx_error_bad_frame;
wire                        mac_rx_error_bad_fcs;
wire                        mac_rx_fifo_overflow;
wire                        mac_rx_fifo_bad_frame;
wire                        mac_rx_fifo_good_frame;
wire [1:0]                  mac_speed;

// 帧过滤器输出
wire [AXIS_DATA_WIDTH-1:0]  filter_rx_axis_tdata;
wire                        filter_rx_axis_tvalid;
wire                        filter_rx_axis_tready;
wire                        filter_rx_axis_tlast;
wire                        filter_rx_axis_tuser;

// DMA 接口信号
wire [AXI_DATA_WIDTH-1:0]   dma_rx_axis_tdata;
wire [AXI_STRB_WIDTH-1:0]   dma_rx_axis_tkeep;
wire                        dma_rx_axis_tvalid;
wire                        dma_rx_axis_tready;
wire                        dma_rx_axis_tlast;
wire                        dma_rx_axis_tuser;

wire [AXI_DATA_WIDTH-1:0]   dma_tx_axis_tdata;
wire [AXI_STRB_WIDTH-1:0]   dma_tx_axis_tkeep;
wire                        dma_tx_axis_tvalid;
wire                        dma_tx_axis_tready;
wire                        dma_tx_axis_tlast;
wire                        dma_tx_axis_tuser;

// DMA 描述符接口
wire [AXI_ADDR_WIDTH-1:0]   dma_rx_desc_addr;
wire [DMA_LEN_WIDTH-1:0]    dma_rx_desc_len;
wire [DMA_TAG_WIDTH-1:0]    dma_rx_desc_tag;
wire                        dma_rx_desc_valid;
wire                        dma_rx_desc_ready;

wire [DMA_LEN_WIDTH-1:0]    dma_rx_desc_status_len;
wire [DMA_TAG_WIDTH-1:0]    dma_rx_desc_status_tag;
wire [3:0]                  dma_rx_desc_status_error;
wire                        dma_rx_desc_status_valid;

wire [AXI_ADDR_WIDTH-1:0]   dma_tx_desc_addr;
wire [DMA_LEN_WIDTH-1:0]    dma_tx_desc_len;
wire [DMA_TAG_WIDTH-1:0]    dma_tx_desc_tag;
wire                        dma_tx_desc_valid;
wire                        dma_tx_desc_ready;

wire [DMA_TAG_WIDTH-1:0]    dma_tx_desc_status_tag;
wire [3:0]                  dma_tx_desc_status_error;
wire                        dma_tx_desc_status_valid;

// 位宽转换信号 (8-bit to 64-bit)
wire [AXI_DATA_WIDTH-1:0]   rx_axis_adapter_tdata;
wire [AXI_STRB_WIDTH-1:0]   rx_axis_adapter_tkeep;
wire                        rx_axis_adapter_tvalid;
wire                        rx_axis_adapter_tready;
wire                        rx_axis_adapter_tlast;
wire                        rx_axis_adapter_tuser;

// 位宽转换信号 (64-bit to 8-bit)
wire [AXIS_DATA_WIDTH-1:0]  tx_axis_adapter_tdata;
wire                        tx_axis_adapter_tvalid;
wire                        tx_axis_adapter_tready;
wire                        tx_axis_adapter_tlast;
wire                        tx_axis_adapter_tuser;

// 控制寄存器
wire [47:0]                  local_mac_reg;
wire [7:0]                   cfg_ifg_reg;
wire                         cfg_tx_enable_reg;
wire                         cfg_rx_enable_reg;
wire                         dma_rx_enable_reg;
wire                         dma_tx_enable_reg;
wire                         filter_enable_reg;
wire                         filter_promiscuous_reg;
wire                         filter_broadcast_reg;
wire                         filter_multicast_reg;

// 中断寄存器
reg                         irq_rx_done = 1'b0;
reg                         irq_tx_done = 1'b0;
reg                         irq_rx_error = 1'b0;
reg                         irq_tx_error = 1'b0;
wire                        irq_enable_reg;

// -------------------------------------------------------------------------
// RGMII MAC 模块实例
// -------------------------------------------------------------------------

eth_mac_1g_rgmii_fifo #(
    .TARGET(TARGET),
    .IODDR_STYLE(IODDR_STYLE),
    .CLOCK_INPUT_STYLE(CLOCK_INPUT_STYLE),
    .USE_CLK90(USE_CLK90),
    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
    .ENABLE_PADDING(1),
    .MIN_FRAME_LENGTH(64),
    .TX_FIFO_DEPTH(TX_FIFO_DEPTH),
    .TX_FRAME_FIFO(1),
    .RX_FIFO_DEPTH(RX_FIFO_DEPTH),
    .RX_FRAME_FIFO(1)
)
eth_mac_inst (
    .gtx_clk(gtx_clk),
    .gtx_clk90(gtx_clk90),
    .gtx_rst(gtx_rst),
    .logic_clk(logic_clk),
    .logic_rst(logic_rst),
    
    .tx_axis_tdata(mac_tx_axis_tdata),
    .tx_axis_tkeep(1'b1),
    .tx_axis_tvalid(mac_tx_axis_tvalid),
    .tx_axis_tready(mac_tx_axis_tready),
    .tx_axis_tlast(mac_tx_axis_tlast),
    .tx_axis_tuser(mac_tx_axis_tuser),
    
    .rx_axis_tdata(mac_rx_axis_tdata),
    .rx_axis_tkeep(),
    .rx_axis_tvalid(mac_rx_axis_tvalid),
    .rx_axis_tready(mac_rx_axis_tready),
    .rx_axis_tlast(mac_rx_axis_tlast),
    .rx_axis_tuser(mac_rx_axis_tuser),
    
    .rgmii_rx_clk(rgmii_rx_clk),
    .rgmii_rxd(rgmii_rxd),
    .rgmii_rx_ctl(rgmii_rx_ctl),
    .rgmii_tx_clk(rgmii_tx_clk),
    .rgmii_txd(rgmii_txd),
    .rgmii_tx_ctl(rgmii_tx_ctl),
    
    .tx_error_underflow(mac_tx_error_underflow),
    .tx_fifo_overflow(mac_tx_fifo_overflow),
    .tx_fifo_bad_frame(mac_tx_fifo_bad_frame),
    .tx_fifo_good_frame(mac_tx_fifo_good_frame),
    .rx_error_bad_frame(mac_rx_error_bad_frame),
    .rx_error_bad_fcs(mac_rx_error_bad_fcs),
    .rx_fifo_overflow(mac_rx_fifo_overflow),
    .rx_fifo_bad_frame(mac_rx_fifo_bad_frame),
    .rx_fifo_good_frame(mac_rx_fifo_good_frame),
    .speed(mac_speed),
    
    .cfg_ifg(cfg_ifg_reg),
    .cfg_tx_enable(cfg_tx_enable_reg),
    .cfg_rx_enable(cfg_rx_enable_reg)
);

// -------------------------------------------------------------------------
// 帧过滤器模块
// -------------------------------------------------------------------------

eth_frame_filter #(
    .DATA_WIDTH(AXIS_DATA_WIDTH),
    .ENABLE_MAC_FILTER(ENABLE_MAC_FILTER),
    .NUM_MAC_FILTERS(NUM_MAC_FILTERS)
)
frame_filter_inst (
    .clk(logic_clk),
    .rst(logic_rst),
    
    .s_axis_tdata(mac_rx_axis_tdata),
    .s_axis_tvalid(mac_rx_axis_tvalid),
    .s_axis_tready(mac_rx_axis_tready),
    .s_axis_tlast(mac_rx_axis_tlast),
    .s_axis_tuser(mac_rx_axis_tuser),
    
    .m_axis_tdata(filter_rx_axis_tdata),
    .m_axis_tvalid(filter_rx_axis_tvalid),
    .m_axis_tready(filter_rx_axis_tready),
    .m_axis_tlast(filter_rx_axis_tlast),
    .m_axis_tuser(filter_rx_axis_tuser),
    
    .filter_enable(filter_enable_reg),
    .promiscuous_mode(filter_promiscuous_reg),
    .broadcast_enable(filter_broadcast_reg),
    .multicast_enable(filter_multicast_reg),
    .local_mac(local_mac_reg)
);

// -------------------------------------------------------------------------
// RX 位宽转换：8-bit → 64-bit
// -------------------------------------------------------------------------

axis_adapter #(
    .S_DATA_WIDTH(AXIS_DATA_WIDTH),
    .S_KEEP_ENABLE(0),
    .M_DATA_WIDTH(AXI_DATA_WIDTH),
    .M_KEEP_ENABLE(1),
    .M_KEEP_WIDTH(AXI_STRB_WIDTH),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(1),
    .USER_WIDTH(1)
)
rx_axis_adapter_inst (
    .clk(logic_clk),
    .rst(logic_rst),
    
    .s_axis_tdata(filter_rx_axis_tdata),
    .s_axis_tkeep(1'b1),
    .s_axis_tvalid(filter_rx_axis_tvalid),
    .s_axis_tready(filter_rx_axis_tready),
    .s_axis_tlast(filter_rx_axis_tlast),
    .s_axis_tid(8'd0),
    .s_axis_tdest(8'd0),
    .s_axis_tuser(filter_rx_axis_tuser),
    
    .m_axis_tdata(rx_axis_adapter_tdata),
    .m_axis_tkeep(rx_axis_adapter_tkeep),
    .m_axis_tvalid(rx_axis_adapter_tvalid),
    .m_axis_tready(rx_axis_adapter_tready),
    .m_axis_tlast(rx_axis_adapter_tlast),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser(rx_axis_adapter_tuser)
);

// RX DMA写入数据连接
assign dma_rx_axis_tdata = rx_axis_adapter_tdata;
assign dma_rx_axis_tkeep = rx_axis_adapter_tkeep;
assign dma_rx_axis_tvalid = rx_axis_adapter_tvalid;
assign rx_axis_adapter_tready = dma_rx_axis_tready;
assign dma_rx_axis_tlast = rx_axis_adapter_tlast;
assign dma_rx_axis_tuser = rx_axis_adapter_tuser;

// -------------------------------------------------------------------------
// TX 位宽转换：64-bit → 8-bit
// -------------------------------------------------------------------------

axis_adapter #(
    .S_DATA_WIDTH(AXI_DATA_WIDTH),
    .S_KEEP_ENABLE(1),
    .S_KEEP_WIDTH(AXI_STRB_WIDTH),
    .M_DATA_WIDTH(AXIS_DATA_WIDTH),
    .M_KEEP_ENABLE(0),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(1),
    .USER_WIDTH(1)
)
tx_axis_adapter_inst (
    .clk(logic_clk),
    .rst(logic_rst),
    
    .s_axis_tdata(dma_tx_axis_tdata),
    .s_axis_tkeep(dma_tx_axis_tkeep),
    .s_axis_tvalid(dma_tx_axis_tvalid),
    .s_axis_tready(dma_tx_axis_tready),
    .s_axis_tlast(dma_tx_axis_tlast),
    .s_axis_tid(8'd0),
    .s_axis_tdest(8'd0),
    .s_axis_tuser(dma_tx_axis_tuser),
    
    .m_axis_tdata(tx_axis_adapter_tdata),
    .m_axis_tkeep(),
    .m_axis_tvalid(tx_axis_adapter_tvalid),
    .m_axis_tready(tx_axis_adapter_tready),
    .m_axis_tlast(tx_axis_adapter_tlast),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser(tx_axis_adapter_tuser)
);

// TX MAC 数据连接
assign mac_tx_axis_tdata = tx_axis_adapter_tdata;
assign mac_tx_axis_tvalid = tx_axis_adapter_tvalid;
assign tx_axis_adapter_tready = mac_tx_axis_tready;
assign mac_tx_axis_tlast = tx_axis_adapter_tlast;
assign mac_tx_axis_tuser = tx_axis_adapter_tuser;

// -------------------------------------------------------------------------
// DMA 引擎
// -------------------------------------------------------------------------

axi_dma #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_MAX_BURST_LEN(AXI_MAX_BURST_LEN),
    .AXIS_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXIS_KEEP_ENABLE(1),
    .AXIS_KEEP_WIDTH(AXI_STRB_WIDTH),
    .AXIS_LAST_ENABLE(1),
    .AXIS_ID_ENABLE(0),
    .AXIS_DEST_ENABLE(0),
    .AXIS_USER_ENABLE(1),
    .AXIS_USER_WIDTH(1),
    .LEN_WIDTH(DMA_LEN_WIDTH),
    .TAG_WIDTH(DMA_TAG_WIDTH),
    .ENABLE_UNALIGNED(1)
)
dma_inst (
    .clk(logic_clk),
    .rst(logic_rst),
    
    // TX: 从内存读取
    .s_axis_read_desc_addr(dma_tx_desc_addr),
    .s_axis_read_desc_len(dma_tx_desc_len),
    .s_axis_read_desc_tag(dma_tx_desc_tag),
    .s_axis_read_desc_id(8'd0),
    .s_axis_read_desc_dest(8'd0),
    .s_axis_read_desc_user(1'b0),
    .s_axis_read_desc_valid(dma_tx_desc_valid),
    .s_axis_read_desc_ready(dma_tx_desc_ready),
    
    .m_axis_read_desc_status_tag(dma_tx_desc_status_tag),
    .m_axis_read_desc_status_error(dma_tx_desc_status_error),
    .m_axis_read_desc_status_valid(dma_tx_desc_status_valid),
    
    .m_axis_read_data_tdata(dma_tx_axis_tdata),
    .m_axis_read_data_tkeep(dma_tx_axis_tkeep),
    .m_axis_read_data_tvalid(dma_tx_axis_tvalid),
    .m_axis_read_data_tready(dma_tx_axis_tready),
    .m_axis_read_data_tlast(dma_tx_axis_tlast),
    .m_axis_read_data_tid(),
    .m_axis_read_data_tdest(),
    .m_axis_read_data_tuser(dma_tx_axis_tuser),
    
    // RX: 写入到内存
    .s_axis_write_desc_addr(dma_rx_desc_addr),
    .s_axis_write_desc_len(dma_rx_desc_len),
    .s_axis_write_desc_tag(dma_rx_desc_tag),
    .s_axis_write_desc_valid(dma_rx_desc_valid),
    .s_axis_write_desc_ready(dma_rx_desc_ready),
    
    .m_axis_write_desc_status_len(dma_rx_desc_status_len),
    .m_axis_write_desc_status_tag(dma_rx_desc_status_tag),
    .m_axis_write_desc_status_id(),
    .m_axis_write_desc_status_dest(),
    .m_axis_write_desc_status_user(),
    .m_axis_write_desc_status_error(dma_rx_desc_status_error),
    .m_axis_write_desc_status_valid(dma_rx_desc_status_valid),
    
    .s_axis_write_data_tdata(dma_rx_axis_tdata),
    .s_axis_write_data_tkeep(dma_rx_axis_tkeep),
    .s_axis_write_data_tvalid(dma_rx_axis_tvalid),
    .s_axis_write_data_tready(dma_rx_axis_tready),
    .s_axis_write_data_tlast(dma_rx_axis_tlast),
    .s_axis_write_data_tid(8'd0),
    .s_axis_write_data_tdest(8'd0),
    .s_axis_write_data_tuser(dma_rx_axis_tuser),
    
    // AXI Master 接口
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
    
    .read_enable(dma_tx_enable_reg),
    .write_enable(dma_rx_enable_reg),
    .write_abort(1'b0)
);

// -------------------------------------------------------------------------
// AXI-Lite 控制寄存器接口（简化版，无IP/ARP相关寄存器）
// -------------------------------------------------------------------------

eth_mac_lite_regs #(
    .DATA_WIDTH(AXIL_DATA_WIDTH),
    .ADDR_WIDTH(AXIL_ADDR_WIDTH)
)
control_regs_inst (
    .clk(logic_clk),
    .rst(logic_rst),
    
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
    
    // 寄存器输出
    .local_mac(local_mac_reg),
    .cfg_ifg(cfg_ifg_reg),
    .cfg_tx_enable(cfg_tx_enable_reg),
    .cfg_rx_enable(cfg_rx_enable_reg),
    .dma_rx_enable(dma_rx_enable_reg),
    .dma_tx_enable(dma_tx_enable_reg),
    .filter_enable(filter_enable_reg),
    .filter_promiscuous(filter_promiscuous_reg),
    .filter_broadcast(filter_broadcast_reg),
    .filter_multicast(filter_multicast_reg),
    .irq_enable(irq_enable_reg),
    
    // DMA 描述符接口
    .dma_rx_desc_addr(dma_rx_desc_addr),
    .dma_rx_desc_len(dma_rx_desc_len),
    .dma_rx_desc_tag(dma_rx_desc_tag),
    .dma_rx_desc_valid(dma_rx_desc_valid),
    .dma_rx_desc_ready(dma_rx_desc_ready),
    .dma_rx_desc_status_len(dma_rx_desc_status_len),
    .dma_rx_desc_status_tag(dma_rx_desc_status_tag),
    .dma_rx_desc_status_error(dma_rx_desc_status_error),
    .dma_rx_desc_status_valid(dma_rx_desc_status_valid),
    
    .dma_tx_desc_addr(dma_tx_desc_addr),
    .dma_tx_desc_len(dma_tx_desc_len),
    .dma_tx_desc_tag(dma_tx_desc_tag),
    .dma_tx_desc_valid(dma_tx_desc_valid),
    .dma_tx_desc_ready(dma_tx_desc_ready),
    .dma_tx_desc_status_tag(dma_tx_desc_status_tag),
    .dma_tx_desc_status_error(dma_tx_desc_status_error),
    .dma_tx_desc_status_valid(dma_tx_desc_status_valid),
    
    // 状态输入
    .mac_speed(mac_speed),
    .mac_tx_error_underflow(mac_tx_error_underflow),
    .mac_rx_error_bad_frame(mac_rx_error_bad_frame),
    .mac_rx_error_bad_fcs(mac_rx_error_bad_fcs),
    
    // 中断
    .irq_rx_done(irq_rx_done),
    .irq_tx_done(irq_tx_done),
    .irq_rx_error(irq_rx_error),
    .irq_tx_error(irq_tx_error)
);

// -------------------------------------------------------------------------
// 中断生成逻辑
// -------------------------------------------------------------------------

always @(posedge logic_clk) begin
    if (logic_rst) begin
        irq_rx_done <= 1'b0;
        irq_tx_done <= 1'b0;
        irq_rx_error <= 1'b0;
        irq_tx_error <= 1'b0;
    end else begin
        if (dma_rx_desc_status_valid && dma_rx_desc_status_error == 4'd0) begin
            irq_rx_done <= 1'b1;
        end
        
        if (dma_tx_desc_status_valid && dma_tx_desc_status_error == 4'd0) begin
            irq_tx_done <= 1'b1;
        end
        
        if (mac_rx_error_bad_frame || mac_rx_error_bad_fcs || 
            (dma_rx_desc_status_valid && dma_rx_desc_status_error != 4'd0)) begin
            irq_rx_error <= 1'b1;
        end
        
        if (mac_tx_error_underflow || 
            (dma_tx_desc_status_valid && dma_tx_desc_status_error != 4'd0)) begin
            irq_tx_error <= 1'b1;
        end
    end
end

assign irq = irq_enable_reg && (irq_rx_done || irq_tx_done || irq_rx_error || irq_tx_error);

endmodule

`resetall

