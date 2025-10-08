/*

以太网 MAC ARP 版本 - AXI-Lite 控制寄存器接口

寄存器地址映射：
0x0000: 控制寄存器 (TX/RX enable, DMA enable, Filter enable, ARP enable)
0x0004: 状态寄存器 (Speed, Errors)
0x0008: 本地 MAC 地址 [31:0]
0x000C: 本地 MAC 地址 [47:32]
0x0010: 本地 IP 地址
0x0014: 网关 IP 地址
0x0018: 子网掩码
0x001C: 过滤器配置
0x0020: 中断使能
0x0024: 中断状态
0x0028: IFG 配置
0x002C: ARP 控制
0x0030: RX DMA 描述符地址
0x0034: RX DMA 描述符长度
0x0038: RX DMA 描述符 Tag
0x003C: RX DMA 描述符控制/状态
0x0040: TX DMA 描述符地址
0x0044: TX DMA 描述符长度
0x0048: TX DMA 描述符 Tag
0x004C: TX DMA 描述符控制/状态

Copyright (c) 2025

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

module eth_mac_arp_regs #(
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
    output wire                         arp_enable,
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
     * 中断输入
     */
    input  wire                         irq_rx_done,
    input  wire                         irq_tx_done,
    input  wire                         irq_rx_error,
    input  wire                         irq_tx_error
);

// AXI-Lite 状态机
localparam STATE_IDLE = 2'd0;
localparam STATE_WRITE = 2'd1;
localparam STATE_WRITE_RESP = 2'd2;
localparam STATE_READ = 2'd3;

reg [1:0] state_reg = STATE_IDLE, state_next;
reg [ADDR_WIDTH-1:0] addr_reg = {ADDR_WIDTH{1'b0}}, addr_next;
reg [DATA_WIDTH-1:0] write_data_reg = {DATA_WIDTH{1'b0}}, write_data_next;
reg [STRB_WIDTH-1:0] write_strb_reg = {STRB_WIDTH{1'b0}}, write_strb_next;

reg s_axil_awready_reg = 1'b0, s_axil_awready_next;
reg s_axil_wready_reg = 1'b0, s_axil_wready_next;
reg s_axil_bvalid_reg = 1'b0, s_axil_bvalid_next;
reg s_axil_arready_reg = 1'b0, s_axil_arready_next;
reg [DATA_WIDTH-1:0] s_axil_rdata_reg = {DATA_WIDTH{1'b0}}, s_axil_rdata_next;
reg s_axil_rvalid_reg = 1'b0, s_axil_rvalid_next;

assign s_axil_awready = s_axil_awready_reg;
assign s_axil_wready = s_axil_wready_reg;
assign s_axil_bresp = 2'b00;
assign s_axil_bvalid = s_axil_bvalid_reg;
assign s_axil_arready = s_axil_arready_reg;
assign s_axil_rdata = s_axil_rdata_reg;
assign s_axil_rresp = 2'b00;
assign s_axil_rvalid = s_axil_rvalid_reg;

// 寄存器
reg [31:0] ctrl_reg = 32'h00000000;
reg [31:0] mac_lo_reg = 32'h00000000;
reg [31:0] mac_hi_reg = 32'h00000000;
reg [31:0] local_ip_reg = 32'h00000000;
reg [31:0] gateway_ip_reg = 32'h00000000;
reg [31:0] subnet_mask_reg = 32'hFFFFFF00;
reg [31:0] filter_reg = 32'h00000000;
reg [31:0] irq_enable_reg = 32'h00000000;
reg [31:0] ifg_reg = 32'h0000000C;
reg [31:0] arp_ctrl_reg = 32'h00000001; // ARP enable by default

// DMA 描述符寄存器
reg [31:0] dma_rx_addr_reg = 32'h00000000;
reg [19:0] dma_rx_len_reg = 20'd0;
reg [7:0] dma_rx_tag_reg = 8'd0;
reg dma_rx_start_reg = 1'b0;

reg [31:0] dma_tx_addr_reg = 32'h00000000;
reg [19:0] dma_tx_len_reg = 20'd0;
reg [7:0] dma_tx_tag_reg = 8'd0;
reg dma_tx_start_reg = 1'b0;

// 寄存器输出
assign local_mac = {mac_hi_reg[15:0], mac_lo_reg};
assign local_ip = local_ip_reg;
assign gateway_ip = gateway_ip_reg;
assign subnet_mask = subnet_mask_reg;
assign clear_arp_cache = arp_ctrl_reg[1];
assign cfg_ifg = ifg_reg[7:0];
assign cfg_tx_enable = ctrl_reg[0];
assign cfg_rx_enable = ctrl_reg[1];
assign dma_tx_enable = ctrl_reg[2];
assign dma_rx_enable = ctrl_reg[3];
assign filter_enable = filter_reg[0];
assign filter_promiscuous = filter_reg[1];
assign filter_broadcast = filter_reg[2];
assign filter_multicast = filter_reg[3];
assign arp_enable = arp_ctrl_reg[0];
assign irq_enable = irq_enable_reg[0];

// DMA 接口
assign dma_rx_desc_addr = dma_rx_addr_reg;
assign dma_rx_desc_len = dma_rx_len_reg;
assign dma_rx_desc_tag = dma_rx_tag_reg;
assign dma_rx_desc_valid = dma_rx_start_reg;

assign dma_tx_desc_addr = dma_tx_addr_reg;
assign dma_tx_desc_len = dma_tx_len_reg;
assign dma_tx_desc_tag = dma_tx_tag_reg;
assign dma_tx_desc_valid = dma_tx_start_reg;

// 状态寄存器
wire [31:0] status_reg = {
    29'd0,
    mac_speed
};

// 中断状态寄存器
wire [31:0] irq_status_reg = {
    28'd0,
    irq_tx_error,
    irq_rx_error,
    irq_tx_done,
    irq_rx_done
};

// AXI-Lite 状态机
always @* begin
    state_next = state_reg;
    addr_next = addr_reg;
    write_data_next = write_data_reg;
    write_strb_next = write_strb_reg;
    
    s_axil_awready_next = 1'b0;
    s_axil_wready_next = 1'b0;
    s_axil_bvalid_next = s_axil_bvalid_reg && !s_axil_bready;
    s_axil_arready_next = 1'b0;
    s_axil_rdata_next = s_axil_rdata_reg;
    s_axil_rvalid_next = s_axil_rvalid_reg && !s_axil_rready;
    
    case (state_reg)
        STATE_IDLE: begin
            if (s_axil_awvalid) begin
                addr_next = s_axil_awaddr;
                s_axil_awready_next = 1'b1;
                state_next = STATE_WRITE;
            end else if (s_axil_arvalid) begin
                addr_next = s_axil_araddr;
                s_axil_arready_next = 1'b1;
                state_next = STATE_READ;
            end
        end
        
        STATE_WRITE: begin
            if (s_axil_wvalid) begin
                write_data_next = s_axil_wdata;
                write_strb_next = s_axil_wstrb;
                s_axil_wready_next = 1'b1;
                s_axil_bvalid_next = 1'b1;
                state_next = STATE_WRITE_RESP;
            end
        end
        
        STATE_WRITE_RESP: begin
            if (s_axil_bready || !s_axil_bvalid_reg) begin
                state_next = STATE_IDLE;
            end
        end
        
        STATE_READ: begin
            s_axil_rvalid_next = 1'b1;
            if (s_axil_rready || !s_axil_rvalid_reg) begin
                state_next = STATE_IDLE;
            end
        end
    endcase
end

always @(posedge clk) begin
    if (rst) begin
        state_reg <= STATE_IDLE;
        addr_reg <= {ADDR_WIDTH{1'b0}};
        write_data_reg <= {DATA_WIDTH{1'b0}};
        write_strb_reg <= {STRB_WIDTH{1'b0}};
        
        s_axil_awready_reg <= 1'b0;
        s_axil_wready_reg <= 1'b0;
        s_axil_bvalid_reg <= 1'b0;
        s_axil_arready_reg <= 1'b0;
        s_axil_rdata_reg <= {DATA_WIDTH{1'b0}};
        s_axil_rvalid_reg <= 1'b0;
    end else begin
        state_reg <= state_next;
        addr_reg <= addr_next;
        write_data_reg <= write_data_next;
        write_strb_reg <= write_strb_next;
        
        s_axil_awready_reg <= s_axil_awready_next;
        s_axil_wready_reg <= s_axil_wready_next;
        s_axil_bvalid_reg <= s_axil_bvalid_next;
        s_axil_arready_reg <= s_axil_arready_next;
        s_axil_rdata_reg <= s_axil_rdata_next;
        s_axil_rvalid_reg <= s_axil_rvalid_next;
    end
end

// 写寄存器逻辑
always @(posedge clk) begin
    if (rst) begin
        ctrl_reg <= 32'h00000000;
        mac_lo_reg <= 32'h00000000;
        mac_hi_reg <= 32'h00000000;
        local_ip_reg <= 32'h00000000;
        gateway_ip_reg <= 32'h00000000;
        subnet_mask_reg <= 32'hFFFFFF00;
        filter_reg <= 32'h00000000;
        irq_enable_reg <= 32'h00000000;
        ifg_reg <= 32'h0000000C;
        arp_ctrl_reg <= 32'h00000001;
        
        dma_rx_addr_reg <= 32'h00000000;
        dma_rx_len_reg <= 20'd0;
        dma_rx_tag_reg <= 8'd0;
        dma_rx_start_reg <= 1'b0;
        
        dma_tx_addr_reg <= 32'h00000000;
        dma_tx_len_reg <= 20'd0;
        dma_tx_tag_reg <= 8'd0;
        dma_tx_start_reg <= 1'b0;
    end else begin
        // 自动清除的单脉冲信号
        dma_rx_start_reg <= 1'b0;
        dma_tx_start_reg <= 1'b0;
        
        // DMA 握手
        if (dma_rx_desc_valid && dma_rx_desc_ready) begin
            dma_rx_start_reg <= 1'b0;
        end
        
        if (dma_tx_desc_valid && dma_tx_desc_ready) begin
            dma_tx_start_reg <= 1'b0;
        end
        
        // 写操作
        if (state_reg == STATE_WRITE && s_axil_wvalid) begin
            case (addr_reg[15:0])
                16'h0000: ctrl_reg <= apply_write_strobe(ctrl_reg, s_axil_wdata, s_axil_wstrb);
                16'h0008: mac_lo_reg <= apply_write_strobe(mac_lo_reg, s_axil_wdata, s_axil_wstrb);
                16'h000C: mac_hi_reg <= apply_write_strobe(mac_hi_reg, s_axil_wdata, s_axil_wstrb);
                16'h0010: local_ip_reg <= apply_write_strobe(local_ip_reg, s_axil_wdata, s_axil_wstrb);
                16'h0014: gateway_ip_reg <= apply_write_strobe(gateway_ip_reg, s_axil_wdata, s_axil_wstrb);
                16'h0018: subnet_mask_reg <= apply_write_strobe(subnet_mask_reg, s_axil_wdata, s_axil_wstrb);
                16'h001C: filter_reg <= apply_write_strobe(filter_reg, s_axil_wdata, s_axil_wstrb);
                16'h0020: irq_enable_reg <= apply_write_strobe(irq_enable_reg, s_axil_wdata, s_axil_wstrb);
                16'h0028: ifg_reg <= apply_write_strobe(ifg_reg, s_axil_wdata, s_axil_wstrb);
                16'h002C: arp_ctrl_reg <= apply_write_strobe(arp_ctrl_reg, s_axil_wdata, s_axil_wstrb);
                
                // RX DMA
                16'h0030: dma_rx_addr_reg <= apply_write_strobe(dma_rx_addr_reg, s_axil_wdata, s_axil_wstrb);
                16'h0034: begin
                    dma_rx_len_reg <= s_axil_wdata[19:0];
                end
                16'h0038: begin
                    dma_rx_tag_reg <= s_axil_wdata[7:0];
                end
                16'h003C: dma_rx_start_reg <= s_axil_wdata[0]; // Start
                
                // TX DMA
                16'h0040: dma_tx_addr_reg <= apply_write_strobe(dma_tx_addr_reg, s_axil_wdata, s_axil_wstrb);
                16'h0044: begin
                    dma_tx_len_reg <= s_axil_wdata[19:0];
                end
                16'h0048: begin
                    dma_tx_tag_reg <= s_axil_wdata[7:0];
                end
                16'h004C: dma_tx_start_reg <= s_axil_wdata[0]; // Start
            endcase
        end
    end
end

// 读寄存器逻辑
always @* begin
    s_axil_rdata_next = s_axil_rdata_reg;
    
    if (state_reg == STATE_READ) begin
        case (addr_reg[15:0])
            16'h0000: s_axil_rdata_next = ctrl_reg;
            16'h0004: s_axil_rdata_next = status_reg;
            16'h0008: s_axil_rdata_next = mac_lo_reg;
            16'h000C: s_axil_rdata_next = mac_hi_reg;
            16'h0010: s_axil_rdata_next = local_ip_reg;
            16'h0014: s_axil_rdata_next = gateway_ip_reg;
            16'h0018: s_axil_rdata_next = subnet_mask_reg;
            16'h001C: s_axil_rdata_next = filter_reg;
            16'h0020: s_axil_rdata_next = irq_enable_reg;
            16'h0024: s_axil_rdata_next = irq_status_reg;
            16'h0028: s_axil_rdata_next = ifg_reg;
            16'h002C: s_axil_rdata_next = arp_ctrl_reg;
            
            // RX DMA status
            16'h0030: s_axil_rdata_next = dma_rx_addr_reg;
            16'h0034: s_axil_rdata_next = {12'd0, dma_rx_len_reg};
            16'h0038: s_axil_rdata_next = {24'd0, dma_rx_tag_reg};
            16'h003C: s_axil_rdata_next = {
                27'd0,
                dma_rx_desc_status_error,
                dma_rx_desc_ready
            };
            
            // TX DMA status
            16'h0040: s_axil_rdata_next = dma_tx_addr_reg;
            16'h0044: s_axil_rdata_next = {12'd0, dma_tx_len_reg};
            16'h0048: s_axil_rdata_next = {24'd0, dma_tx_tag_reg};
            16'h004C: s_axil_rdata_next = {
                27'd0,
                dma_tx_desc_status_error,
                dma_tx_desc_ready
            };
            
            default: s_axil_rdata_next = 32'h00000000;
        endcase
    end
end

// 辅助函数：应用写字节使能
function [31:0] apply_write_strobe;
    input [31:0] old_value;
    input [31:0] new_value;
    input [3:0] strobe;
    integer i;
    begin
        apply_write_strobe = old_value;
        for (i = 0; i < 4; i = i + 1) begin
            if (strobe[i]) begin
                apply_write_strobe[i*8 +: 8] = new_value[i*8 +: 8];
            end
        end
    end
endfunction

endmodule

`resetall

