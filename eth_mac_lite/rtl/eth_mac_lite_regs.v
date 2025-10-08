/*

以太网 MAC Lite AXI-Lite 控制寄存器接口
简化版本：无 IP/ARP 相关寄存器

寄存器地址映射：
0x0000: 控制寄存器
0x0004: 状态寄存器
0x0008-0x000C: 本地 MAC 地址
0x0010: 过滤器配置
0x0014: 中断使能
0x0018: 中断状态
0x001C: IFG 配置
0x0020-0x002C: RX DMA 描述符
0x0030-0x003C: TX DMA 描述符

Copyright (c) 2025

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

module eth_mac_lite_regs #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 16,
    parameter STRB_WIDTH = (DATA_WIDTH/8)
)(
    input  wire                         clk,
    input  wire                         rst,
    
    /*
     * AXI-Lite Slave 接口
     */
    input  wire [ADDR_WIDTH-1:0]        s_axil_awaddr,
    input  wire [2:0]                   s_axil_awprot,
    input  wire                         s_axil_awvalid,
    output wire                         s_axil_awready,
    input  wire [DATA_WIDTH-1:0]        s_axil_wdata,
    input  wire [STRB_WIDTH-1:0]        s_axil_wstrb,
    input  wire                         s_axil_wvalid,
    output wire                         s_axil_wready,
    output wire [1:0]                   s_axil_bresp,
    output wire                         s_axil_bvalid,
    input  wire                         s_axil_bready,
    input  wire [ADDR_WIDTH-1:0]        s_axil_araddr,
    input  wire [2:0]                   s_axil_arprot,
    input  wire                         s_axil_arvalid,
    output wire                         s_axil_arready,
    output wire [DATA_WIDTH-1:0]        s_axil_rdata,
    output wire [1:0]                   s_axil_rresp,
    output wire                         s_axil_rvalid,
    input  wire                         s_axil_rready,
    
    /*
     * 寄存器输出
     */
    output wire [47:0]                  local_mac,
    output wire [7:0]                   cfg_ifg,
    output wire                         cfg_tx_enable,
    output wire                         cfg_rx_enable,
    output wire                         dma_rx_enable,
    output wire                         dma_tx_enable,
    output wire                         filter_enable,
    output wire                         filter_promiscuous,
    output wire                         filter_broadcast,
    output wire                         filter_multicast,
    output wire                         irq_enable,
    
    /*
     * DMA 描述符接口
     */
    output wire [31:0]                  dma_rx_desc_addr,
    output wire [19:0]                  dma_rx_desc_len,
    output wire [7:0]                   dma_rx_desc_tag,
    output wire                         dma_rx_desc_valid,
    input  wire                         dma_rx_desc_ready,
    input  wire [19:0]                  dma_rx_desc_status_len,
    input  wire [7:0]                   dma_rx_desc_status_tag,
    input  wire [3:0]                   dma_rx_desc_status_error,
    input  wire                         dma_rx_desc_status_valid,
    
    output wire [31:0]                  dma_tx_desc_addr,
    output wire [19:0]                  dma_tx_desc_len,
    output wire [7:0]                   dma_tx_desc_tag,
    output wire                         dma_tx_desc_valid,
    input  wire                         dma_tx_desc_ready,
    input  wire [7:0]                   dma_tx_desc_status_tag,
    input  wire [3:0]                   dma_tx_desc_status_error,
    input  wire                         dma_tx_desc_status_valid,
    
    /*
     * 状态输入
     */
    input  wire [1:0]                   mac_speed,
    input  wire                         mac_tx_error_underflow,
    input  wire                         mac_rx_error_bad_frame,
    input  wire                         mac_rx_error_bad_fcs,
    
    /*
     * 中断
     */
    input  wire                         irq_rx_done,
    input  wire                         irq_tx_done,
    input  wire                         irq_rx_error,
    input  wire                         irq_tx_error
);

// AXI-Lite 接口逻辑
reg [ADDR_WIDTH-1:0]    write_addr_reg = {ADDR_WIDTH{1'b0}};
reg                     write_addr_valid_reg = 1'b0;
reg [DATA_WIDTH-1:0]    write_data_reg = {DATA_WIDTH{1'b0}};
reg [STRB_WIDTH-1:0]    write_strb_reg = {STRB_WIDTH{1'b0}};
reg                     write_data_valid_reg = 1'b0;

assign s_axil_awready = !write_addr_valid_reg;
assign s_axil_wready = !write_data_valid_reg;
assign s_axil_bresp = 2'b00;  // OKAY
assign s_axil_bvalid = write_addr_valid_reg && write_data_valid_reg;

always @(posedge clk) begin
    if (rst) begin
        write_addr_valid_reg <= 1'b0;
        write_data_valid_reg <= 1'b0;
    end else begin
        if (s_axil_awvalid && s_axil_awready) begin
            write_addr_reg <= s_axil_awaddr;
            write_addr_valid_reg <= 1'b1;
        end else if (s_axil_bvalid && s_axil_bready) begin
            write_addr_valid_reg <= 1'b0;
        end
        
        if (s_axil_wvalid && s_axil_wready) begin
            write_data_reg <= s_axil_wdata;
            write_strb_reg <= s_axil_wstrb;
            write_data_valid_reg <= 1'b1;
        end else if (s_axil_bvalid && s_axil_bready) begin
            write_data_valid_reg <= 1'b0;
        end
    end
end

reg [ADDR_WIDTH-1:0]    read_addr_reg = {ADDR_WIDTH{1'b0}};
reg                     read_addr_valid_reg = 1'b0;
reg [DATA_WIDTH-1:0]    read_data_reg = {DATA_WIDTH{1'b0}};
reg                     read_data_valid_reg = 1'b0;

assign s_axil_arready = !read_addr_valid_reg;
assign s_axil_rdata = read_data_reg;
assign s_axil_rresp = 2'b00;  // OKAY
assign s_axil_rvalid = read_data_valid_reg;

always @(posedge clk) begin
    if (rst) begin
        read_addr_valid_reg <= 1'b0;
        read_data_valid_reg <= 1'b0;
    end else begin
        if (s_axil_arvalid && s_axil_arready) begin
            read_addr_reg <= s_axil_araddr;
            read_addr_valid_reg <= 1'b1;
        end else if (read_addr_valid_reg && !read_data_valid_reg) begin
            read_addr_valid_reg <= 1'b0;
        end
        
        if (read_addr_valid_reg && !read_data_valid_reg) begin
            read_data_valid_reg <= 1'b1;
        end else if (s_axil_rvalid && s_axil_rready) begin
            read_data_valid_reg <= 1'b0;
        end
    end
end

// 寄存器定义
reg [31:0]  ctrl_reg = 32'h00000000;
reg [47:0]  mac_addr_reg = 48'h000000000000;
reg [31:0]  filter_cfg_reg = 32'h00000000;
reg [31:0]  irq_enable_reg = 32'h00000000;
reg [31:0]  irq_status_reg = 32'h00000000;
reg [31:0]  ifg_cfg_reg = 32'h0000000C;  // 默认 12

// DMA RX 描述符寄存器
reg [31:0]  dma_rx_desc_addr_reg = 32'h00000000;
reg [31:0]  dma_rx_desc_len_reg = 32'h00000000;
reg [31:0]  dma_rx_desc_tag_reg = 32'h00000000;
reg [31:0]  dma_rx_desc_ctrl_reg = 32'h00000000;

// DMA TX 描述符寄存器
reg [31:0]  dma_tx_desc_addr_reg = 32'h00000000;
reg [31:0]  dma_tx_desc_len_reg = 32'h00000000;
reg [31:0]  dma_tx_desc_tag_reg = 32'h00000000;
reg [31:0]  dma_tx_desc_ctrl_reg = 32'h00000000;

// 状态寄存器 (只读)
wire [31:0] status_reg = {
    30'd0,
    mac_speed
};

// 写操作
always @(posedge clk) begin
    if (rst) begin
        ctrl_reg <= 32'h00000000;
        mac_addr_reg <= 48'h000000000000;
        filter_cfg_reg <= 32'h00000000;
        irq_enable_reg <= 32'h00000000;
        irq_status_reg <= 32'h00000000;
        ifg_cfg_reg <= 32'h0000000C;
        dma_rx_desc_addr_reg <= 32'h00000000;
        dma_rx_desc_len_reg <= 32'h00000000;
        dma_rx_desc_tag_reg <= 32'h00000000;
        dma_rx_desc_ctrl_reg <= 32'h00000000;
        dma_tx_desc_addr_reg <= 32'h00000000;
        dma_tx_desc_len_reg <= 32'h00000000;
        dma_tx_desc_tag_reg <= 32'h00000000;
        dma_tx_desc_ctrl_reg <= 32'h00000000;
    end else begin
        // 自动清除描述符 valid 位
        if (dma_rx_desc_valid && dma_rx_desc_ready) begin
            dma_rx_desc_ctrl_reg[0] <= 1'b0;
        end
        if (dma_tx_desc_valid && dma_tx_desc_ready) begin
            dma_tx_desc_ctrl_reg[0] <= 1'b0;
        end
        
        // 中断状态自动置位
        if (irq_rx_done) irq_status_reg[0] <= 1'b1;
        if (irq_tx_done) irq_status_reg[1] <= 1'b1;
        if (irq_rx_error) irq_status_reg[2] <= 1'b1;
        if (irq_tx_error) irq_status_reg[3] <= 1'b1;
        
        // 寄存器写入
        if (write_addr_valid_reg && write_data_valid_reg) begin
            case (write_addr_reg[7:0])
                8'h00: ctrl_reg <= write_data_reg;
                8'h08: mac_addr_reg[31:0] <= write_data_reg;
                8'h0C: mac_addr_reg[47:32] <= write_data_reg[15:0];
                8'h10: filter_cfg_reg <= write_data_reg;
                8'h14: irq_enable_reg <= write_data_reg;
                8'h18: irq_status_reg <= irq_status_reg & ~write_data_reg;  // W1C
                8'h1C: ifg_cfg_reg <= write_data_reg;
                8'h20: dma_rx_desc_addr_reg <= write_data_reg;
                8'h24: dma_rx_desc_len_reg <= write_data_reg;
                8'h28: dma_rx_desc_tag_reg <= write_data_reg;
                8'h2C: dma_rx_desc_ctrl_reg <= write_data_reg;
                8'h30: dma_tx_desc_addr_reg <= write_data_reg;
                8'h34: dma_tx_desc_len_reg <= write_data_reg;
                8'h38: dma_tx_desc_tag_reg <= write_data_reg;
                8'h3C: dma_tx_desc_ctrl_reg <= write_data_reg;
            endcase
        end
    end
end

// 读操作
always @(posedge clk) begin
    if (read_addr_valid_reg && !read_data_valid_reg) begin
        case (read_addr_reg[7:0])
            8'h00: read_data_reg <= ctrl_reg;
            8'h04: read_data_reg <= status_reg;
            8'h08: read_data_reg <= mac_addr_reg[31:0];
            8'h0C: read_data_reg <= {16'd0, mac_addr_reg[47:32]};
            8'h10: read_data_reg <= filter_cfg_reg;
            8'h14: read_data_reg <= irq_enable_reg;
            8'h18: read_data_reg <= irq_status_reg;
            8'h1C: read_data_reg <= ifg_cfg_reg;
            8'h20: read_data_reg <= dma_rx_desc_addr_reg;
            8'h24: read_data_reg <= dma_rx_desc_len_reg;
            8'h28: read_data_reg <= dma_rx_desc_tag_reg;
            8'h2C: read_data_reg <= dma_rx_desc_ctrl_reg;
            8'h30: read_data_reg <= dma_tx_desc_addr_reg;
            8'h34: read_data_reg <= dma_tx_desc_len_reg;
            8'h38: read_data_reg <= dma_tx_desc_tag_reg;
            8'h3C: read_data_reg <= dma_tx_desc_ctrl_reg;
            default: read_data_reg <= 32'h00000000;
        endcase
    end
end

// 输出连接
assign local_mac = mac_addr_reg;
assign cfg_ifg = ifg_cfg_reg[7:0];
assign cfg_tx_enable = ctrl_reg[0];
assign cfg_rx_enable = ctrl_reg[1];
assign dma_tx_enable = ctrl_reg[2];
assign dma_rx_enable = ctrl_reg[3];
assign filter_enable = filter_cfg_reg[0];
assign filter_promiscuous = filter_cfg_reg[1];
assign filter_broadcast = filter_cfg_reg[2];
assign filter_multicast = filter_cfg_reg[3];
assign irq_enable = irq_enable_reg[0];

// DMA 描述符输出
assign dma_rx_desc_addr = dma_rx_desc_addr_reg;
assign dma_rx_desc_len = dma_rx_desc_len_reg[19:0];
assign dma_rx_desc_tag = dma_rx_desc_tag_reg[7:0];
assign dma_rx_desc_valid = dma_rx_desc_ctrl_reg[0];

assign dma_tx_desc_addr = dma_tx_desc_addr_reg;
assign dma_tx_desc_len = dma_tx_desc_len_reg[19:0];
assign dma_tx_desc_tag = dma_tx_desc_tag_reg[7:0];
assign dma_tx_desc_valid = dma_tx_desc_ctrl_reg[0];

endmodule

`resetall
