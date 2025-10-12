/*

以太网MAC、DMA和MDIO的APB从设备接口
提供寄存器映射用于配置和控制

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
 * APB从设备接口 - 以太网MAC、DMA和MDIO控制
 */
module eth_mac_dma_mdio_apb #
(
    // APB参数
    parameter APB_ADDR_WIDTH = 16,
    parameter APB_DATA_WIDTH = 32,
    
    // MAC参数
    parameter TARGET = "XILINX",
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
     * 时钟和复位
     */
    input  wire                       clk,
    input  wire                       rst,
    input  wire                       gtx_clk,
    input  wire                       gtx_clk90,
    input  wire                       gtx_rst,
    
    /*
     * APB从设备接口
     */
    input  wire [APB_ADDR_WIDTH-1:0]  apb_paddr,
    input  wire                       apb_psel,
    input  wire                       apb_penable,
    input  wire                       apb_pwrite,
    input  wire [APB_DATA_WIDTH-1:0]  apb_pwdata,
    output wire [APB_DATA_WIDTH-1:0]  apb_prdata,
    output wire                       apb_pready,
    output wire                       apb_pslverr,
    
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
     * 中断输出
     */
    output wire                       irq_tx_done,
    output wire                       irq_rx_done,
    output wire                       irq_tx_error,
    output wire                       irq_rx_error,
    output wire                       irq_link_change
);

//-----------------------------------------------------------------------------
// 寄存器地址定义
//-----------------------------------------------------------------------------
localparam ADDR_CONTROL        = 16'h0000;  // 控制寄存器
localparam ADDR_STATUS         = 16'h0004;  // 状态寄存器
localparam ADDR_INT_ENABLE     = 16'h0008;  // 中断使能
localparam ADDR_INT_STATUS     = 16'h000C;  // 中断状态
localparam ADDR_MAC_CONFIG     = 16'h0010;  // MAC配置
localparam ADDR_PHY_ADDR       = 16'h0014;  // PHY地址配置

// MDIO寄存器
localparam ADDR_MDIO_CONTROL   = 16'h0020;  // MDIO控制
localparam ADDR_MDIO_STATUS    = 16'h0024;  // MDIO状态
localparam ADDR_MDIO_DATA      = 16'h0028;  // MDIO数据
localparam ADDR_MDIO_ADDR      = 16'h002C;  // MDIO地址

// DMA TX描述符寄存器
localparam ADDR_TX_DESC_ADDR_L = 16'h0040;  // TX描述符地址低32位
localparam ADDR_TX_DESC_ADDR_H = 16'h0044;  // TX描述符地址高32位
localparam ADDR_TX_DESC_LEN    = 16'h0048;  // TX描述符长度
localparam ADDR_TX_DESC_TAG    = 16'h004C;  // TX描述符标签
localparam ADDR_TX_DESC_CTRL   = 16'h0050;  // TX描述符控制

// DMA RX描述符寄存器
localparam ADDR_RX_DESC_ADDR_L = 16'h0060;  // RX描述符地址低32位
localparam ADDR_RX_DESC_ADDR_H = 16'h0064;  // RX描述符地址高32位
localparam ADDR_RX_DESC_LEN    = 16'h0068;  // RX描述符长度
localparam ADDR_RX_DESC_TAG    = 16'h006C;  // RX描述符标签
localparam ADDR_RX_DESC_CTRL   = 16'h0070;  // RX描述符控制

// 状态寄存器
localparam ADDR_TX_STATUS      = 16'h0080;  // TX状态
localparam ADDR_RX_STATUS      = 16'h0084;  // RX状态
localparam ADDR_LINK_STATUS    = 16'h0088;  // 链路状态

// 统计计数器
localparam ADDR_TX_FRAME_CNT   = 16'h00A0;  // TX帧计数
localparam ADDR_RX_FRAME_CNT   = 16'h00A4;  // RX帧计数
localparam ADDR_TX_ERROR_CNT   = 16'h00A8;  // TX错误计数
localparam ADDR_RX_ERROR_CNT   = 16'h00AC;  // RX错误计数

//-----------------------------------------------------------------------------
// 内部寄存器
//-----------------------------------------------------------------------------

// 控制寄存器 (0x0000)
reg        ctrl_mac_tx_en = 1'b0;
reg        ctrl_mac_rx_en = 1'b0;
reg        ctrl_dma_tx_en = 1'b1;
reg        ctrl_dma_rx_en = 1'b1;
reg        ctrl_reset = 1'b0;

// MAC配置 (0x0010)
reg [7:0]  cfg_ifg = 8'd12;

// PHY地址配置 (0x0014)
reg [4:0]  phy_addr = 5'h01;
reg [7:0]  mdio_divider = 8'd50;

// MDIO控制 (0x0020)
reg        mdio_write_req_reg = 1'b0;
reg        mdio_read_req_reg = 1'b0;
reg        mdio_no_preamble = 1'b0;

// MDIO数据和地址 (0x0028, 0x002C)
reg [15:0] mdio_write_data_reg = 16'h0;
reg [4:0]  mdio_reg_addr_reg = 5'h0;

// DMA TX描述符
reg [AXI_ADDR_WIDTH-1:0] tx_desc_addr_reg = {AXI_ADDR_WIDTH{1'b0}};
reg [LEN_WIDTH-1:0]      tx_desc_len_reg = {LEN_WIDTH{1'b0}};
reg [TAG_WIDTH-1:0]      tx_desc_tag_reg = {TAG_WIDTH{1'b0}};
reg                      tx_desc_valid_reg = 1'b0;

// DMA RX描述符
reg [AXI_ADDR_WIDTH-1:0] rx_desc_addr_reg = {AXI_ADDR_WIDTH{1'b0}};
reg [LEN_WIDTH-1:0]      rx_desc_len_reg = {LEN_WIDTH{1'b0}};
reg [TAG_WIDTH-1:0]      rx_desc_tag_reg = {TAG_WIDTH{1'b0}};
reg                      rx_desc_valid_reg = 1'b0;

// 中断使能和状态
reg        int_en_tx_done = 1'b0;
reg        int_en_rx_done = 1'b0;
reg        int_en_tx_error = 1'b0;
reg        int_en_rx_error = 1'b0;
reg        int_en_link_change = 1'b0;

reg        int_status_tx_done = 1'b0;
reg        int_status_rx_done = 1'b0;
reg        int_status_tx_error = 1'b0;
reg        int_status_rx_error = 1'b0;
reg        int_status_link_change = 1'b0;

// 统计计数器
reg [31:0] tx_frame_counter = 32'h0;
reg [31:0] rx_frame_counter = 32'h0;
reg [31:0] tx_error_counter = 32'h0;
reg [31:0] rx_error_counter = 32'h0;

// 链路状态跟踪
reg        link_up_prev = 1'b0;

//-----------------------------------------------------------------------------
// APB接口信号
//-----------------------------------------------------------------------------
reg [APB_DATA_WIDTH-1:0] apb_prdata_reg = {APB_DATA_WIDTH{1'b0}};
reg                      apb_pready_reg = 1'b1;
reg                      apb_pslverr_reg = 1'b0;

assign apb_prdata = apb_prdata_reg;
assign apb_pready = apb_pready_reg;
assign apb_pslverr = apb_pslverr_reg;

//-----------------------------------------------------------------------------
// 以太网模块信号
//-----------------------------------------------------------------------------
wire        tx_desc_ready;
wire [TAG_WIDTH-1:0] tx_desc_status_tag;
wire [3:0]  tx_desc_status_error;
wire        tx_desc_status_valid;

wire        rx_desc_ready;
wire [LEN_WIDTH-1:0] rx_desc_status_len;
wire [TAG_WIDTH-1:0] rx_desc_status_tag;
wire [3:0]  rx_desc_status_error;
wire        rx_desc_status_valid;

wire        tx_error_underflow;
wire        tx_fifo_overflow;
wire        tx_fifo_bad_frame;
wire        tx_fifo_good_frame;
wire        rx_error_bad_frame;
wire        rx_error_bad_fcs;
wire        rx_fifo_overflow;
wire        rx_fifo_bad_frame;
wire        rx_fifo_good_frame;
wire [1:0]  speed;

wire        mdio_busy;
wire [15:0] mdio_read_data;
wire        mdio_link_fail;
wire        mdio_data_valid;

//-----------------------------------------------------------------------------
// APB寄存器读写逻辑
//-----------------------------------------------------------------------------

// APB写操作
always @(posedge clk) begin
    if (rst) begin
        ctrl_mac_tx_en <= 1'b0;
        ctrl_mac_rx_en <= 1'b0;
        ctrl_dma_tx_en <= 1'b1;
        ctrl_dma_rx_en <= 1'b1;
        ctrl_reset <= 1'b0;
        cfg_ifg <= 8'd12;
        phy_addr <= 5'h01;
        mdio_divider <= 8'd50;
        mdio_write_req_reg <= 1'b0;
        mdio_read_req_reg <= 1'b0;
        mdio_no_preamble <= 1'b0;
        mdio_write_data_reg <= 16'h0;
        mdio_reg_addr_reg <= 5'h0;
        tx_desc_addr_reg <= {AXI_ADDR_WIDTH{1'b0}};
        tx_desc_len_reg <= {LEN_WIDTH{1'b0}};
        tx_desc_tag_reg <= {TAG_WIDTH{1'b0}};
        tx_desc_valid_reg <= 1'b0;
        rx_desc_addr_reg <= {AXI_ADDR_WIDTH{1'b0}};
        rx_desc_len_reg <= {LEN_WIDTH{1'b0}};
        rx_desc_tag_reg <= {TAG_WIDTH{1'b0}};
        rx_desc_valid_reg <= 1'b0;
        int_en_tx_done <= 1'b0;
        int_en_rx_done <= 1'b0;
        int_en_tx_error <= 1'b0;
        int_en_rx_error <= 1'b0;
        int_en_link_change <= 1'b0;
    end else begin
        // 自动清除单次脉冲信号
        mdio_write_req_reg <= 1'b0;
        mdio_read_req_reg <= 1'b0;
        tx_desc_valid_reg <= 1'b0;
        rx_desc_valid_reg <= 1'b0;
        ctrl_reset <= 1'b0;
        
        if (apb_psel && apb_pwrite && apb_penable) begin
            case (apb_paddr)
                ADDR_CONTROL: begin
                    ctrl_mac_tx_en <= apb_pwdata[0];
                    ctrl_mac_rx_en <= apb_pwdata[1];
                    ctrl_dma_tx_en <= apb_pwdata[2];
                    ctrl_dma_rx_en <= apb_pwdata[3];
                    ctrl_reset <= apb_pwdata[31];
                end
                
                ADDR_INT_ENABLE: begin
                    int_en_tx_done <= apb_pwdata[0];
                    int_en_rx_done <= apb_pwdata[1];
                    int_en_tx_error <= apb_pwdata[2];
                    int_en_rx_error <= apb_pwdata[3];
                    int_en_link_change <= apb_pwdata[4];
                end
                
                ADDR_INT_STATUS: begin
                    // 写1清除
                    if (apb_pwdata[0]) int_status_tx_done <= 1'b0;
                    if (apb_pwdata[1]) int_status_rx_done <= 1'b0;
                    if (apb_pwdata[2]) int_status_tx_error <= 1'b0;
                    if (apb_pwdata[3]) int_status_rx_error <= 1'b0;
                    if (apb_pwdata[4]) int_status_link_change <= 1'b0;
                end
                
                ADDR_MAC_CONFIG: begin
                    cfg_ifg <= apb_pwdata[7:0];
                end
                
                ADDR_PHY_ADDR: begin
                    phy_addr <= apb_pwdata[4:0];
                    mdio_divider <= apb_pwdata[15:8];
                end
                
                ADDR_MDIO_CONTROL: begin
                    mdio_write_req_reg <= apb_pwdata[0];
                    mdio_read_req_reg <= apb_pwdata[1];
                    mdio_no_preamble <= apb_pwdata[2];
                end
                
                ADDR_MDIO_DATA: begin
                    mdio_write_data_reg <= apb_pwdata[15:0];
                end
                
                ADDR_MDIO_ADDR: begin
                    mdio_reg_addr_reg <= apb_pwdata[4:0];
                end
                
                ADDR_TX_DESC_ADDR_L: begin
                    tx_desc_addr_reg[31:0] <= apb_pwdata;
                end
                
                ADDR_TX_DESC_ADDR_H: begin
                    if (AXI_ADDR_WIDTH > 32)
                        tx_desc_addr_reg[AXI_ADDR_WIDTH-1:32] <= apb_pwdata[AXI_ADDR_WIDTH-33:0];
                end
                
                ADDR_TX_DESC_LEN: begin
                    tx_desc_len_reg <= apb_pwdata[LEN_WIDTH-1:0];
                end
                
                ADDR_TX_DESC_TAG: begin
                    tx_desc_tag_reg <= apb_pwdata[TAG_WIDTH-1:0];
                end
                
                ADDR_TX_DESC_CTRL: begin
                    tx_desc_valid_reg <= apb_pwdata[0];
                end
                
                ADDR_RX_DESC_ADDR_L: begin
                    rx_desc_addr_reg[31:0] <= apb_pwdata;
                end
                
                ADDR_RX_DESC_ADDR_H: begin
                    if (AXI_ADDR_WIDTH > 32)
                        rx_desc_addr_reg[AXI_ADDR_WIDTH-1:32] <= apb_pwdata[AXI_ADDR_WIDTH-33:0];
                end
                
                ADDR_RX_DESC_LEN: begin
                    rx_desc_len_reg <= apb_pwdata[LEN_WIDTH-1:0];
                end
                
                ADDR_RX_DESC_TAG: begin
                    rx_desc_tag_reg <= apb_pwdata[TAG_WIDTH-1:0];
                end
                
                ADDR_RX_DESC_CTRL: begin
                    rx_desc_valid_reg <= apb_pwdata[0];
                end
            endcase
        end
    end
end

// APB读操作
always @(posedge clk) begin
    if (rst) begin
        apb_prdata_reg <= {APB_DATA_WIDTH{1'b0}};
    end else begin
        if (apb_psel && !apb_pwrite) begin
            case (apb_paddr)
                ADDR_CONTROL: begin
                    apb_prdata_reg <= {ctrl_reset, 27'h0, ctrl_dma_rx_en, ctrl_dma_tx_en, 
                                      ctrl_mac_rx_en, ctrl_mac_tx_en};
                end
                
                ADDR_STATUS: begin
                    apb_prdata_reg <= {28'h0, speed, mdio_link_fail, !mdio_link_fail};
                end
                
                ADDR_INT_ENABLE: begin
                    apb_prdata_reg <= {27'h0, int_en_link_change, int_en_rx_error, 
                                      int_en_tx_error, int_en_rx_done, int_en_tx_done};
                end
                
                ADDR_INT_STATUS: begin
                    apb_prdata_reg <= {27'h0, int_status_link_change, int_status_rx_error, 
                                      int_status_tx_error, int_status_rx_done, int_status_tx_done};
                end
                
                ADDR_MAC_CONFIG: begin
                    apb_prdata_reg <= {24'h0, cfg_ifg};
                end
                
                ADDR_PHY_ADDR: begin
                    apb_prdata_reg <= {16'h0, mdio_divider, 3'h0, phy_addr};
                end
                
                ADDR_MDIO_CONTROL: begin
                    apb_prdata_reg <= {29'h0, mdio_no_preamble, mdio_read_req_reg, mdio_write_req_reg};
                end
                
                ADDR_MDIO_STATUS: begin
                    apb_prdata_reg <= {30'h0, mdio_data_valid, mdio_busy};
                end
                
                ADDR_MDIO_DATA: begin
                    apb_prdata_reg <= {16'h0, mdio_read_data};
                end
                
                ADDR_MDIO_ADDR: begin
                    apb_prdata_reg <= {27'h0, mdio_reg_addr_reg};
                end
                
                ADDR_TX_DESC_ADDR_L: begin
                    apb_prdata_reg <= tx_desc_addr_reg[31:0];
                end
                
                ADDR_TX_DESC_ADDR_H: begin
                    if (AXI_ADDR_WIDTH > 32)
                        apb_prdata_reg <= {{(32-(AXI_ADDR_WIDTH-32)){1'b0}}, tx_desc_addr_reg[AXI_ADDR_WIDTH-1:32]};
                    else
                        apb_prdata_reg <= 32'h0;
                end
                
                ADDR_TX_DESC_LEN: begin
                    apb_prdata_reg <= {{(32-LEN_WIDTH){1'b0}}, tx_desc_len_reg};
                end
                
                ADDR_TX_DESC_TAG: begin
                    apb_prdata_reg <= {{(32-TAG_WIDTH){1'b0}}, tx_desc_tag_reg};
                end
                
                ADDR_TX_DESC_CTRL: begin
                    apb_prdata_reg <= {30'h0, tx_desc_ready, tx_desc_valid_reg};
                end
                
                ADDR_RX_DESC_ADDR_L: begin
                    apb_prdata_reg <= rx_desc_addr_reg[31:0];
                end
                
                ADDR_RX_DESC_ADDR_H: begin
                    if (AXI_ADDR_WIDTH > 32)
                        apb_prdata_reg <= {{(32-(AXI_ADDR_WIDTH-32)){1'b0}}, rx_desc_addr_reg[AXI_ADDR_WIDTH-1:32]};
                    else
                        apb_prdata_reg <= 32'h0;
                end
                
                ADDR_RX_DESC_LEN: begin
                    apb_prdata_reg <= {{(32-LEN_WIDTH){1'b0}}, rx_desc_len_reg};
                end
                
                ADDR_RX_DESC_TAG: begin
                    apb_prdata_reg <= {{(32-TAG_WIDTH){1'b0}}, rx_desc_tag_reg};
                end
                
                ADDR_RX_DESC_CTRL: begin
                    apb_prdata_reg <= {30'h0, rx_desc_ready, rx_desc_valid_reg};
                end
                
                ADDR_TX_STATUS: begin
                    apb_prdata_reg <= {24'h0, tx_desc_status_error, tx_desc_status_tag};
                end
                
                ADDR_RX_STATUS: begin
                    apb_prdata_reg <= {8'h0, rx_desc_status_error, rx_desc_status_len};
                end
                
                ADDR_LINK_STATUS: begin
                    apb_prdata_reg <= {24'h0, rx_fifo_overflow, tx_fifo_overflow, 
                                      rx_error_bad_fcs, rx_error_bad_frame, 
                                      tx_error_underflow, speed, !mdio_link_fail};
                end
                
                ADDR_TX_FRAME_CNT: begin
                    apb_prdata_reg <= tx_frame_counter;
                end
                
                ADDR_RX_FRAME_CNT: begin
                    apb_prdata_reg <= rx_frame_counter;
                end
                
                ADDR_TX_ERROR_CNT: begin
                    apb_prdata_reg <= tx_error_counter;
                end
                
                ADDR_RX_ERROR_CNT: begin
                    apb_prdata_reg <= rx_error_counter;
                end
                
                default: begin
                    apb_prdata_reg <= 32'h0;
                end
            endcase
        end
    end
end

//-----------------------------------------------------------------------------
// 中断生成逻辑
//-----------------------------------------------------------------------------

// TX完成中断
always @(posedge clk) begin
    if (rst) begin
        int_status_tx_done <= 1'b0;
    end else begin
        if (tx_desc_status_valid && (tx_desc_status_error == 4'h0))
            int_status_tx_done <= 1'b1;
        else if (apb_psel && apb_pwrite && apb_penable && 
                 (apb_paddr == ADDR_INT_STATUS) && apb_pwdata[0])
            int_status_tx_done <= 1'b0;
    end
end

// RX完成中断
always @(posedge clk) begin
    if (rst) begin
        int_status_rx_done <= 1'b0;
    end else begin
        if (rx_desc_status_valid && (rx_desc_status_error == 4'h0))
            int_status_rx_done <= 1'b1;
        else if (apb_psel && apb_pwrite && apb_penable && 
                 (apb_paddr == ADDR_INT_STATUS) && apb_pwdata[1])
            int_status_rx_done <= 1'b0;
    end
end

// TX错误中断
always @(posedge clk) begin
    if (rst) begin
        int_status_tx_error <= 1'b0;
    end else begin
        if (tx_desc_status_valid && (tx_desc_status_error != 4'h0))
            int_status_tx_error <= 1'b1;
        else if (apb_psel && apb_pwrite && apb_penable && 
                 (apb_paddr == ADDR_INT_STATUS) && apb_pwdata[2])
            int_status_tx_error <= 1'b0;
    end
end

// RX错误中断
always @(posedge clk) begin
    if (rst) begin
        int_status_rx_error <= 1'b0;
    end else begin
        if (rx_desc_status_valid && (rx_desc_status_error != 4'h0))
            int_status_rx_error <= 1'b1;
        else if (apb_psel && apb_pwrite && apb_penable && 
                 (apb_paddr == ADDR_INT_STATUS) && apb_pwdata[3])
            int_status_rx_error <= 1'b0;
    end
end

// 链路状态变化中断
always @(posedge clk) begin
    if (rst) begin
        link_up_prev <= 1'b0;
        int_status_link_change <= 1'b0;
    end else begin
        link_up_prev <= !mdio_link_fail;
        
        if (link_up_prev != !mdio_link_fail)
            int_status_link_change <= 1'b1;
        else if (apb_psel && apb_pwrite && apb_penable && 
                 (apb_paddr == ADDR_INT_STATUS) && apb_pwdata[4])
            int_status_link_change <= 1'b0;
    end
end

// 中断输出
assign irq_tx_done = int_en_tx_done && int_status_tx_done;
assign irq_rx_done = int_en_rx_done && int_status_rx_done;
assign irq_tx_error = int_en_tx_error && int_status_tx_error;
assign irq_rx_error = int_en_rx_error && int_status_rx_error;
assign irq_link_change = int_en_link_change && int_status_link_change;

//-----------------------------------------------------------------------------
// 统计计数器
//-----------------------------------------------------------------------------

// TX帧计数
always @(posedge clk) begin
    if (rst || ctrl_reset)
        tx_frame_counter <= 32'h0;
    else if (tx_fifo_good_frame)
        tx_frame_counter <= tx_frame_counter + 1;
end

// RX帧计数
always @(posedge clk) begin
    if (rst || ctrl_reset)
        rx_frame_counter <= 32'h0;
    else if (rx_fifo_good_frame)
        rx_frame_counter <= rx_frame_counter + 1;
end

// TX错误计数
always @(posedge clk) begin
    if (rst || ctrl_reset)
        tx_error_counter <= 32'h0;
    else if (tx_fifo_bad_frame || tx_error_underflow)
        tx_error_counter <= tx_error_counter + 1;
end

// RX错误计数
always @(posedge clk) begin
    if (rst || ctrl_reset)
        rx_error_counter <= 32'h0;
    else if (rx_fifo_bad_frame || rx_error_bad_fcs)
        rx_error_counter <= rx_error_counter + 1;
end

//-----------------------------------------------------------------------------
// 以太网MAC、DMA和MDIO集成模块实例
//-----------------------------------------------------------------------------

eth_mac_dma_mdio_integration #(
    .TARGET(TARGET),
    .IODDR_STYLE(IODDR_STYLE),
    .CLOCK_INPUT_STYLE(CLOCK_INPUT_STYLE),
    .USE_CLK90(USE_CLK90),
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
    .RX_DROP_WHEN_FULL(RX_DROP_WHEN_FULL),
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
eth_inst (
    .clk(clk),
    .rst(rst || ctrl_reset),
    .gtx_clk(gtx_clk),
    .gtx_clk90(gtx_clk90),
    .gtx_rst(gtx_rst),
    
    // DMA TX描述符
    .s_axis_read_desc_addr(tx_desc_addr_reg),
    .s_axis_read_desc_len(tx_desc_len_reg),
    .s_axis_read_desc_tag(tx_desc_tag_reg),
    .s_axis_read_desc_id({AXIS_ID_WIDTH{1'b0}}),
    .s_axis_read_desc_dest({AXIS_DEST_WIDTH{1'b0}}),
    .s_axis_read_desc_user({AXIS_USER_WIDTH{1'b0}}),
    .s_axis_read_desc_valid(tx_desc_valid_reg),
    .s_axis_read_desc_ready(tx_desc_ready),
    
    // DMA TX状态
    .m_axis_read_desc_status_tag(tx_desc_status_tag),
    .m_axis_read_desc_status_error(tx_desc_status_error),
    .m_axis_read_desc_status_valid(tx_desc_status_valid),
    
    // DMA RX描述符
    .s_axis_write_desc_addr(rx_desc_addr_reg),
    .s_axis_write_desc_len(rx_desc_len_reg),
    .s_axis_write_desc_tag(rx_desc_tag_reg),
    .s_axis_write_desc_valid(rx_desc_valid_reg),
    .s_axis_write_desc_ready(rx_desc_ready),
    
    // DMA RX状态
    .m_axis_write_desc_status_len(rx_desc_status_len),
    .m_axis_write_desc_status_tag(rx_desc_status_tag),
    .m_axis_write_desc_status_id(),
    .m_axis_write_desc_status_dest(),
    .m_axis_write_desc_status_user(),
    .m_axis_write_desc_status_error(rx_desc_status_error),
    .m_axis_write_desc_status_valid(rx_desc_status_valid),
    
    // RGMII接口
    .rgmii_rx_clk(rgmii_rx_clk),
    .rgmii_rxd(rgmii_rxd),
    .rgmii_rx_ctl(rgmii_rx_ctl),
    .rgmii_tx_clk(rgmii_tx_clk),
    .rgmii_txd(rgmii_txd),
    .rgmii_tx_ctl(rgmii_tx_ctl),
    
    // MDIO接口
    .mdc(mdc),
    .mdio_o(mdio_o),
    .mdio_oe(mdio_oe),
    .mdio_i(mdio_i),
    
    // MDIO控制
    .mdio_divider(mdio_divider),
    .mdio_no_preamble(mdio_no_preamble),
    .mdio_ctrl_data(mdio_write_data_reg),
    .mdio_reg_addr(mdio_reg_addr_reg),
    .mdio_phy_addr(phy_addr),
    .mdio_write_req(mdio_write_req_reg),
    .mdio_read_req(mdio_read_req_reg),
    .mdio_scan_req(1'b0),
    .mdio_busy(mdio_busy),
    .mdio_read_data(mdio_read_data),
    .mdio_link_fail(mdio_link_fail),
    .mdio_data_valid(mdio_data_valid),
    
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
    
    // 状态
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
    .cfg_tx_enable(ctrl_mac_tx_en),
    .cfg_rx_enable(ctrl_mac_rx_en),
    .dma_read_enable(ctrl_dma_tx_en),
    .dma_write_enable(ctrl_dma_rx_en),
    .dma_write_abort(1'b0)
);

endmodule

`resetall

