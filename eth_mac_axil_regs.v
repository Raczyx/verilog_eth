/*

以太网 MAC AXI-Lite 控制寄存器接口

寄存器地址映射：
0x0000: 控制寄存器
0x0004: 状态寄存器
0x0008-0x000C: 本地 MAC 地址
0x0010: 本地 IP 地址
0x0014: 网关 IP 地址
0x0018: 子网掩码
0x001C: 过滤器配置
0x0020: 中断使能
0x0024: 中断状态
0x0028: IFG 配置
0x0030-0x003C: RX DMA 描述符
0x0040-0x004C: TX DMA 描述符

Copyright (c) 2025

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

module eth_mac_axil_regs #(
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
    output wire [31:0]                  local_ip,
    output wire [31:0]                  gateway_ip,
    output wire [31:0]                  subnet_mask,
    output wire                         clear_arp_cache,
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
reg [ADDR_WIDTH-1:0]    read_addr_reg = {ADDR_WIDTH{1'b0}};
reg                     read_addr_valid_reg = 1'b0;
reg [DATA_WIDTH-1:0]    read_data_reg = {DATA_WIDTH{1'b0}};
reg                     read_data_valid_reg = 1'b0;
reg [1:0]               write_resp_reg = 2'b00;
reg                     write_resp_valid_reg = 1'b0;

// 配置寄存器
reg [31:0]              ctrl_reg = 32'h00000003;  // TX/RX 默认使能
reg [31:0]              local_mac_low_reg = 32'h00000000;
reg [15:0]              local_mac_high_reg = 16'h0000;
reg [31:0]              local_ip_reg = 32'h00000000;
reg [31:0]              gateway_ip_reg = 32'h00000000;
reg [31:0]              subnet_mask_reg = 32'hFFFFFF00;
reg [31:0]              filter_config_reg = 32'h00000003;  // 默认使能 + 广播
reg [31:0]              irq_enable_reg = 32'h00000000;
reg [31:0]              irq_status_reg = 32'h00000000;
reg [7:0]               ifg_config_reg = 8'd12;

// DMA 描述符寄存器
reg [31:0]              rx_desc_addr_reg = 32'h00000000;
reg [19:0]              rx_desc_len_reg = 20'h00000;
reg [7:0]               rx_desc_tag_reg = 8'h00;
reg                     rx_desc_valid_reg = 1'b0;

reg [31:0]              tx_desc_addr_reg = 32'h00000000;
reg [19:0]              tx_desc_len_reg = 20'h00000;
reg [7:0]               tx_desc_tag_reg = 8'h00;
reg                     tx_desc_valid_reg = 1'b0;

// 写地址通道
assign s_axil_awready = !write_addr_valid_reg;
assign s_axil_wready = write_addr_valid_reg && s_axil_wvalid;

always @(posedge clk) begin
    if (rst) begin
        write_addr_valid_reg <= 1'b0;
    end else begin
        if (s_axil_awvalid && s_axil_awready) begin
            write_addr_reg <= s_axil_awaddr;
            write_addr_valid_reg <= 1'b1;
        end else if (s_axil_wvalid && s_axil_wready) begin
            write_addr_valid_reg <= 1'b0;
        end
    end
end

// 写数据和响应
assign s_axil_bresp = write_resp_reg;
assign s_axil_bvalid = write_resp_valid_reg;

always @(posedge clk) begin
    if (rst) begin
        ctrl_reg <= 32'h00000003;
        local_mac_low_reg <= 32'h00000000;
        local_mac_high_reg <= 16'h0000;
        local_ip_reg <= 32'h00000000;
        gateway_ip_reg <= 32'h00000000;
        subnet_mask_reg <= 32'hFFFFFF00;
        filter_config_reg <= 32'h00000003;
        irq_enable_reg <= 32'h00000000;
        ifg_config_reg <= 8'd12;
        rx_desc_addr_reg <= 32'h00000000;
        rx_desc_len_reg <= 20'h00000;
        rx_desc_tag_reg <= 8'h00;
        rx_desc_valid_reg <= 1'b0;
        tx_desc_addr_reg <= 32'h00000000;
        tx_desc_len_reg <= 20'h00000;
        tx_desc_tag_reg <= 8'h00;
        tx_desc_valid_reg <= 1'b0;
        write_resp_valid_reg <= 1'b0;
        write_resp_reg <= 2'b00;
    end else begin
        // 清除单次脉冲信号
        if (dma_rx_desc_ready) begin
            rx_desc_valid_reg <= 1'b0;
        end
        if (dma_tx_desc_ready) begin
            tx_desc_valid_reg <= 1'b0;
        end
        
        // 写操作
        if (s_axil_wvalid && s_axil_wready) begin
            write_resp_valid_reg <= 1'b1;
            write_resp_reg <= 2'b00;  // OKAY
            
            case (write_addr_reg[7:0])
                8'h00: ctrl_reg <= s_axil_wdata;
                8'h08: local_mac_low_reg <= s_axil_wdata;
                8'h0C: local_mac_high_reg <= s_axil_wdata[15:0];
                8'h10: local_ip_reg <= s_axil_wdata;
                8'h14: gateway_ip_reg <= s_axil_wdata;
                8'h18: subnet_mask_reg <= s_axil_wdata;
                8'h1C: filter_config_reg <= s_axil_wdata;
                8'h20: irq_enable_reg <= s_axil_wdata;
                8'h24: irq_status_reg <= irq_status_reg & ~s_axil_wdata;  // 写1清除
                8'h28: ifg_config_reg <= s_axil_wdata[7:0];
                8'h30: rx_desc_addr_reg <= s_axil_wdata;
                8'h34: rx_desc_len_reg <= s_axil_wdata[19:0];
                8'h38: rx_desc_tag_reg <= s_axil_wdata[7:0];
                8'h3C: rx_desc_valid_reg <= s_axil_wdata[0];
                8'h40: tx_desc_addr_reg <= s_axil_wdata;
                8'h44: tx_desc_len_reg <= s_axil_wdata[19:0];
                8'h48: tx_desc_tag_reg <= s_axil_wdata[7:0];
                8'h4C: tx_desc_valid_reg <= s_axil_wdata[0];
                default: write_resp_reg <= 2'b11;  // DECERR
            endcase
        end else if (s_axil_bready) begin
            write_resp_valid_reg <= 1'b0;
        end
        
        // 更新中断状态
        if (irq_rx_done) irq_status_reg[0] <= 1'b1;
        if (irq_tx_done) irq_status_reg[1] <= 1'b1;
        if (irq_rx_error) irq_status_reg[2] <= 1'b1;
        if (irq_tx_error) irq_status_reg[3] <= 1'b1;
    end
end

// 读地址通道
assign s_axil_arready = !read_addr_valid_reg;

always @(posedge clk) begin
    if (rst) begin
        read_addr_valid_reg <= 1'b0;
    end else begin
        if (s_axil_arvalid && s_axil_arready) begin
            read_addr_reg <= s_axil_araddr;
            read_addr_valid_reg <= 1'b1;
        end else if (read_data_valid_reg && s_axil_rready) begin
            read_addr_valid_reg <= 1'b0;
        end
    end
end

// 读数据通道
assign s_axil_rdata = read_data_reg;
assign s_axil_rresp = 2'b00;  // OKAY
assign s_axil_rvalid = read_data_valid_reg;

always @(posedge clk) begin
    if (rst) begin
        read_data_valid_reg <= 1'b0;
        read_data_reg <= {DATA_WIDTH{1'b0}};
    end else begin
        if (read_addr_valid_reg && !read_data_valid_reg) begin
            read_data_valid_reg <= 1'b1;
            
            case (read_addr_reg[7:0])
                8'h00: read_data_reg <= ctrl_reg;
                8'h04: read_data_reg <= {30'd0, mac_speed};
                8'h08: read_data_reg <= local_mac_low_reg;
                8'h0C: read_data_reg <= {16'd0, local_mac_high_reg};
                8'h10: read_data_reg <= local_ip_reg;
                8'h14: read_data_reg <= gateway_ip_reg;
                8'h18: read_data_reg <= subnet_mask_reg;
                8'h1C: read_data_reg <= filter_config_reg;
                8'h20: read_data_reg <= irq_enable_reg;
                8'h24: read_data_reg <= irq_status_reg;
                8'h28: read_data_reg <= {24'd0, ifg_config_reg};
                8'h30: read_data_reg <= rx_desc_addr_reg;
                8'h34: read_data_reg <= {12'd0, rx_desc_len_reg};
                8'h38: read_data_reg <= {24'd0, rx_desc_tag_reg};
                8'h3C: read_data_reg <= {31'd0, rx_desc_valid_reg};
                8'h40: read_data_reg <= tx_desc_addr_reg;
                8'h44: read_data_reg <= {12'd0, tx_desc_len_reg};
                8'h48: read_data_reg <= {24'd0, tx_desc_tag_reg};
                8'h4C: read_data_reg <= {31'd0, tx_desc_valid_reg};
                default: read_data_reg <= 32'hDEADBEEF;
            endcase
        end else if (s_axil_rready) begin
            read_data_valid_reg <= 1'b0;
        end
    end
end

// 输出分配
assign local_mac = {local_mac_high_reg, local_mac_low_reg};
assign local_ip = local_ip_reg;
assign gateway_ip = gateway_ip_reg;
assign subnet_mask = subnet_mask_reg;
assign clear_arp_cache = ctrl_reg[4];
assign cfg_ifg = ifg_config_reg;
assign cfg_tx_enable = ctrl_reg[0];
assign cfg_rx_enable = ctrl_reg[1];
assign dma_rx_enable = ctrl_reg[2];
assign dma_tx_enable = ctrl_reg[3];
assign filter_enable = filter_config_reg[0];
assign filter_promiscuous = filter_config_reg[1];
assign filter_broadcast = filter_config_reg[2];
assign filter_multicast = filter_config_reg[3];
assign irq_enable = irq_enable_reg[0];

// DMA 描述符输出
assign dma_rx_desc_addr = rx_desc_addr_reg;
assign dma_rx_desc_len = rx_desc_len_reg;
assign dma_rx_desc_tag = rx_desc_tag_reg;
assign dma_rx_desc_valid = rx_desc_valid_reg;

assign dma_tx_desc_addr = tx_desc_addr_reg;
assign dma_tx_desc_len = tx_desc_len_reg;
assign dma_tx_desc_tag = tx_desc_tag_reg;
assign dma_tx_desc_valid = tx_desc_valid_reg;

endmodule

`resetall

