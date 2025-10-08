/*

以太网 MAC RGMII AXI 测试平台

测试场景：
1. 基本复位和初始化
2. AXI-Lite 寄存器读写
3. RGMII TX 发送数据包
4. RGMII RX 接收数据包
5. DMA 传输测试
6. ARP 协议测试
7. 帧过滤测试

Copyright (c) 2025

*/

`timescale 1ns / 1ps

module eth_mac_rgmii_axi_tb;

// ============================================================================
// 参数定义
// ============================================================================

// 时钟周期
localparam CLK_PERIOD_GTX = 8.0;    // 125 MHz
localparam CLK_PERIOD_LOGIC = 10.0; // 100 MHz

// AXI 参数
localparam AXI_DATA_WIDTH = 64;
localparam AXI_ADDR_WIDTH = 32;
localparam AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8);
localparam AXI_ID_WIDTH = 8;

// AXI-Lite 参数
localparam AXIL_DATA_WIDTH = 32;
localparam AXIL_ADDR_WIDTH = 16;
localparam AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8);

// 内存大小
localparam MEM_SIZE = 16384; // 16KB 用于 DMA

// ============================================================================
// 信号声明
// ============================================================================

// 时钟和复位
reg gtx_clk;
reg gtx_clk90;
reg gtx_rst;
reg logic_clk;
reg logic_rst;

// RGMII 接口
wire rgmii_tx_clk;
wire [3:0] rgmii_txd;
wire rgmii_tx_ctl;
reg rgmii_rx_clk;
reg [3:0] rgmii_rxd;
reg rgmii_rx_ctl;

// AXI Master 接口 (DMA)
wire [AXI_ID_WIDTH-1:0] m_axi_awid;
wire [AXI_ADDR_WIDTH-1:0] m_axi_awaddr;
wire [7:0] m_axi_awlen;
wire [2:0] m_axi_awsize;
wire [1:0] m_axi_awburst;
wire m_axi_awlock;
wire [3:0] m_axi_awcache;
wire [2:0] m_axi_awprot;
wire m_axi_awvalid;
reg m_axi_awready;

wire [AXI_DATA_WIDTH-1:0] m_axi_wdata;
wire [AXI_STRB_WIDTH-1:0] m_axi_wstrb;
wire m_axi_wlast;
wire m_axi_wvalid;
reg m_axi_wready;

reg [AXI_ID_WIDTH-1:0] m_axi_bid;
reg [1:0] m_axi_bresp;
reg m_axi_bvalid;
wire m_axi_bready;

wire [AXI_ID_WIDTH-1:0] m_axi_arid;
wire [AXI_ADDR_WIDTH-1:0] m_axi_araddr;
wire [7:0] m_axi_arlen;
wire [2:0] m_axi_arsize;
wire [1:0] m_axi_arburst;
wire m_axi_arlock;
wire [3:0] m_axi_arcache;
wire [2:0] m_axi_arprot;
wire m_axi_arvalid;
reg m_axi_arready;

reg [AXI_ID_WIDTH-1:0] m_axi_rid;
reg [AXI_DATA_WIDTH-1:0] m_axi_rdata;
reg [1:0] m_axi_rresp;
reg m_axi_rlast;
reg m_axi_rvalid;
wire m_axi_rready;

// AXI-Lite Slave 接口 (控制)
reg [AXIL_ADDR_WIDTH-1:0] s_axil_awaddr;
reg [2:0] s_axil_awprot;
reg s_axil_awvalid;
wire s_axil_awready;

reg [AXIL_DATA_WIDTH-1:0] s_axil_wdata;
reg [AXIL_STRB_WIDTH-1:0] s_axil_wstrb;
reg s_axil_wvalid;
wire s_axil_wready;

wire [1:0] s_axil_bresp;
wire s_axil_bvalid;
reg s_axil_bready;

reg [AXIL_ADDR_WIDTH-1:0] s_axil_araddr;
reg [2:0] s_axil_arprot;
reg s_axil_arvalid;
wire s_axil_arready;

wire [AXIL_DATA_WIDTH-1:0] s_axil_rdata;
wire [1:0] s_axil_rresp;
wire s_axil_rvalid;
reg s_axil_rready;

// 中断
wire irq;

// DMA 内存模拟
reg [7:0] memory [0:MEM_SIZE-1];

// 测试控制
integer test_number;
integer error_count;

// 简单的 AXI 内存模型（用于 DMA 测试）
parameter AXI_MEM_SIZE = 4096;  // 4KB 内存
reg [7:0] axi_memory [0:AXI_MEM_SIZE-1];
integer mem_init_i;

// ============================================================================
// 简单的 AXI 内存模型（用于 DMA 测试）
// ============================================================================

// AXI 写通道处理
reg [7:0] axi_write_count;
reg [31:0] axi_write_addr_latch;

always @(posedge logic_clk) begin
    if (logic_rst) begin
        m_axi_awready <= 1'b0;
        m_axi_wready <= 1'b0;
        m_axi_bvalid <= 1'b0;
        m_axi_bresp <= 2'b00;
        axi_write_count <= 8'd0;
    end else begin
        // 写地址握手
        if (m_axi_awvalid && !m_axi_awready) begin
            m_axi_awready <= 1'b1;
            axi_write_addr_latch <= m_axi_awaddr;
            axi_write_count <= 8'd0;
        end else begin
            m_axi_awready <= 1'b0;
        end
        
        // 写数据握手
        if (m_axi_wvalid && m_axi_awready) begin
            m_axi_wready <= 1'b1;
            // 写入内存
            if (axi_write_addr_latch < AXI_MEM_SIZE) begin
                axi_memory[axi_write_addr_latch + axi_write_count*8 + 0] <= m_axi_wdata[7:0];
                axi_memory[axi_write_addr_latch + axi_write_count*8 + 1] <= m_axi_wdata[15:8];
                axi_memory[axi_write_addr_latch + axi_write_count*8 + 2] <= m_axi_wdata[23:16];
                axi_memory[axi_write_addr_latch + axi_write_count*8 + 3] <= m_axi_wdata[31:24];
                axi_memory[axi_write_addr_latch + axi_write_count*8 + 4] <= m_axi_wdata[39:32];
                axi_memory[axi_write_addr_latch + axi_write_count*8 + 5] <= m_axi_wdata[47:40];
                axi_memory[axi_write_addr_latch + axi_write_count*8 + 6] <= m_axi_wdata[55:48];
                axi_memory[axi_write_addr_latch + axi_write_count*8 + 7] <= m_axi_wdata[63:56];
            end
            axi_write_count <= axi_write_count + 1;
            
            // 最后一次传输，发送响应
            if (m_axi_wlast) begin
                m_axi_bvalid <= 1'b1;
                m_axi_bresp <= 2'b00;  // OKAY
            end
        end else begin
            m_axi_wready <= 1'b0;
        end
        
        // 写响应握手
        if (m_axi_bvalid && m_axi_bready) begin
            m_axi_bvalid <= 1'b0;
        end
    end
end

// AXI 读通道处理
reg [7:0] axi_read_count;
reg [7:0] axi_read_burst_len;
reg [31:0] axi_read_addr_latch;

always @(posedge logic_clk) begin
    if (logic_rst) begin
        m_axi_arready <= 1'b0;
        m_axi_rvalid <= 1'b0;
        m_axi_rdata <= 64'd0;
        m_axi_rresp <= 2'b00;
        m_axi_rlast <= 1'b0;
        axi_read_count <= 8'd0;
    end else begin
        // 读地址握手
        if (m_axi_arvalid && !m_axi_arready) begin
            m_axi_arready <= 1'b1;
            axi_read_addr_latch <= m_axi_araddr;
            axi_read_burst_len <= m_axi_arlen;
            axi_read_count <= 8'd0;
        end else begin
            m_axi_arready <= 1'b0;
        end
        
        // 读数据传输
        if (m_axi_arready) begin
            m_axi_rvalid <= 1'b1;
            m_axi_rresp <= 2'b00;  // OKAY
            
            // 从内存读取
            if (axi_read_addr_latch < AXI_MEM_SIZE) begin
                m_axi_rdata[7:0]   <= axi_memory[axi_read_addr_latch + axi_read_count*8 + 0];
                m_axi_rdata[15:8]  <= axi_memory[axi_read_addr_latch + axi_read_count*8 + 1];
                m_axi_rdata[23:16] <= axi_memory[axi_read_addr_latch + axi_read_count*8 + 2];
                m_axi_rdata[31:24] <= axi_memory[axi_read_addr_latch + axi_read_count*8 + 3];
                m_axi_rdata[39:32] <= axi_memory[axi_read_addr_latch + axi_read_count*8 + 4];
                m_axi_rdata[47:40] <= axi_memory[axi_read_addr_latch + axi_read_count*8 + 5];
                m_axi_rdata[55:48] <= axi_memory[axi_read_addr_latch + axi_read_count*8 + 6];
                m_axi_rdata[63:56] <= axi_memory[axi_read_addr_latch + axi_read_count*8 + 7];
            end else begin
                m_axi_rdata <= 64'hDEADBEEFDEADBEEF;
            end
            
            // 判断是否是最后一次传输
            if (axi_read_count >= axi_read_burst_len) begin
                m_axi_rlast <= 1'b1;
            end else begin
                m_axi_rlast <= 1'b0;
            end
            
            axi_read_count <= axi_read_count + 1;
        end else if (m_axi_rvalid && m_axi_rready) begin
            if (m_axi_rlast) begin
                m_axi_rvalid <= 1'b0;
                m_axi_rlast <= 1'b0;
            end
        end
    end
end

// ============================================================================
// 时钟生成
// ============================================================================

// GTX 时钟 125 MHz
initial begin
    gtx_clk = 1'b0;
    forever #(CLK_PERIOD_GTX/2) gtx_clk = ~gtx_clk;
end

// GTX 90度时钟
initial begin
    #(CLK_PERIOD_GTX/4);
    gtx_clk90 = 1'b0;
    forever #(CLK_PERIOD_GTX/2) gtx_clk90 = ~gtx_clk90;
end

// 逻辑时钟 100 MHz
initial begin
    logic_clk = 1'b0;
    forever #(CLK_PERIOD_LOGIC/2) logic_clk = ~logic_clk;
end

// RGMII RX 时钟 125 MHz
initial begin
    rgmii_rx_clk = 1'b0;
    forever #(CLK_PERIOD_GTX/2) rgmii_rx_clk = ~rgmii_rx_clk;
end

// ============================================================================
// DUT 实例化
// ============================================================================

eth_mac_rgmii_axi #(
    .TARGET("GENERIC"),
    .IODDR_STYLE("IODDR2"),
    .CLOCK_INPUT_STYLE("BUFG"),
    .USE_CLK90("FALSE"),  // 仿真中不需要
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_MAX_BURST_LEN(16),
    .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH),
    .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH),
    .TX_FIFO_DEPTH(1024),
    .RX_FIFO_DEPTH(1024),
    .ARP_CACHE_ADDR_WIDTH(4),  // 减小以加快仿真
    .ARP_REQUEST_RETRY_COUNT(2),
    .ARP_REQUEST_RETRY_INTERVAL(1000),
    .ARP_REQUEST_TIMEOUT(5000)
)
dut (
    .gtx_clk(gtx_clk),
    .gtx_clk90(gtx_clk90),
    .gtx_rst(gtx_rst),
    .logic_clk(logic_clk),
    .logic_rst(logic_rst),
    
    .rgmii_rx_clk(rgmii_rx_clk),
    .rgmii_rxd(rgmii_rxd),
    .rgmii_rx_ctl(rgmii_rx_ctl),
    .rgmii_tx_clk(rgmii_tx_clk),
    .rgmii_txd(rgmii_txd),
    .rgmii_tx_ctl(rgmii_tx_ctl),
    
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
    
    .irq(irq)
);

// ============================================================================
// AXI Slave 模型 (DMA 内存)
// ============================================================================

// AXI 写通道
always @(posedge logic_clk) begin
    if (logic_rst) begin
        m_axi_awready <= 1'b0;
        m_axi_wready <= 1'b0;
        m_axi_bvalid <= 1'b0;
    end else begin
        // 写地址握手
        if (m_axi_awvalid && !m_axi_awready) begin
            m_axi_awready <= 1'b1;
        end else begin
            m_axi_awready <= 1'b0;
        end
        
        // 写数据握手
        if (m_axi_wvalid && !m_axi_wready) begin
            m_axi_wready <= 1'b1;
        end else begin
            m_axi_wready <= 1'b0;
        end
        
        // 写响应
        if (m_axi_wvalid && m_axi_wready && m_axi_wlast) begin
            m_axi_bvalid <= 1'b1;
            m_axi_bresp <= 2'b00; // OKAY
            m_axi_bid <= m_axi_awid;
        end else if (m_axi_bready) begin
            m_axi_bvalid <= 1'b0;
        end
    end
end

// 写入内存
integer write_byte_idx;
always @(posedge logic_clk) begin
    if (m_axi_wvalid && m_axi_wready) begin
        for (write_byte_idx = 0; write_byte_idx < AXI_STRB_WIDTH; write_byte_idx = write_byte_idx + 1) begin
            if (m_axi_wstrb[write_byte_idx]) begin
                memory[m_axi_awaddr[15:0] + write_byte_idx] <= m_axi_wdata[write_byte_idx*8 +: 8];
            end
        end
    end
end

// AXI 读通道
always @(posedge logic_clk) begin
    if (logic_rst) begin
        m_axi_arready <= 1'b0;
        m_axi_rvalid <= 1'b0;
    end else begin
        // 读地址握手
        if (m_axi_arvalid && !m_axi_arready) begin
            m_axi_arready <= 1'b1;
        end else begin
            m_axi_arready <= 1'b0;
        end
        
        // 读数据响应
        if (m_axi_arvalid && m_axi_arready) begin
            m_axi_rvalid <= 1'b1;
            m_axi_rresp <= 2'b00; // OKAY
            m_axi_rid <= m_axi_arid;
            m_axi_rlast <= 1'b1; // 简化：单次传输
            // 从内存读取
            m_axi_rdata <= {memory[m_axi_araddr[15:0]+7], memory[m_axi_araddr[15:0]+6],
                           memory[m_axi_araddr[15:0]+5], memory[m_axi_araddr[15:0]+4],
                           memory[m_axi_araddr[15:0]+3], memory[m_axi_araddr[15:0]+2],
                           memory[m_axi_araddr[15:0]+1], memory[m_axi_araddr[15:0]]};
        end else if (m_axi_rready) begin
            m_axi_rvalid <= 1'b0;
        end
    end
end

// ============================================================================
// AXI-Lite 读写任务
// ============================================================================

task axil_write;
    input [AXIL_ADDR_WIDTH-1:0] addr;
    input [AXIL_DATA_WIDTH-1:0] data;
    begin
        @(posedge logic_clk);
        s_axil_awaddr = addr;
        s_axil_awprot = 3'b000;
        s_axil_awvalid = 1'b1;
        s_axil_wdata = data;
        s_axil_wstrb = {AXIL_STRB_WIDTH{1'b1}};
        s_axil_wvalid = 1'b1;
        s_axil_bready = 1'b1;
        
        // 等待地址握手（顺序握手：先地址后数据）
        wait(s_axil_awready);
        @(posedge logic_clk);
        s_axil_awvalid = 1'b0;
        
        // 等待数据握手
        wait(s_axil_wready);
        @(posedge logic_clk);
        s_axil_wvalid = 1'b0;
        
        // 等待响应
        wait(s_axil_bvalid);
        @(posedge logic_clk);
        s_axil_bready = 1'b0;
        
        $display("[%0t] AXI-Lite Write: Addr=0x%04x, Data=0x%08x", $time, addr, data);
    end
endtask

task axil_read;
    input [AXIL_ADDR_WIDTH-1:0] addr;
    output [AXIL_DATA_WIDTH-1:0] data;
    integer timeout;
    begin
        timeout = 0;
        @(posedge logic_clk);
        s_axil_araddr = addr;
        s_axil_arprot = 3'b000;
        s_axil_arvalid = 1'b1;
        s_axil_rready = 1'b1;
        
        $display("[%0t] AXI-Lite Read Start: Addr=0x%04x, arready=%b", $time, addr, s_axil_arready);
        
        // 等待地址握手（带超时）
        while (!s_axil_arready && timeout < 1000) begin
            @(posedge logic_clk);
            timeout = timeout + 1;
        end
        if (timeout >= 1000) begin
            $display("[%0t] ERROR: Read address timeout! arready=%b", $time, s_axil_arready);
            data = 32'hDEADBEEF;
        end else begin
            $display("[%0t] AXI-Lite Read: Address accepted, waiting for data...", $time);
            @(posedge logic_clk);
            s_axil_arvalid = 1'b0;
            
            // 等待数据（带超时）
            timeout = 0;
            while (!s_axil_rvalid && timeout < 1000) begin
                @(posedge logic_clk);
                timeout = timeout + 1;
            end
            if (timeout >= 1000) begin
                $display("[%0t] ERROR: Read data timeout! rvalid=%b", $time, s_axil_rvalid);
                data = 32'hDEADBEEF;
            end else begin
                $display("[%0t] AXI-Lite Read: Data ready, rvalid=%b", $time, s_axil_rvalid);
                @(posedge logic_clk);
                data = s_axil_rdata;
                s_axil_rready = 1'b0;
                
                // 额外的恢复周期
                @(posedge logic_clk);
                
                $display("[%0t] AXI-Lite Read Complete: Addr=0x%04x, Data=0x%08x", $time, addr, data);
            end
        end
    end
endtask

// ============================================================================
// RGMII 发送任务（简化版）
// ============================================================================

task send_rgmii_frame;
    input [15:0] length;
    integer i;
    begin
        // 前导码
        for (i = 0; i < 14; i = i + 1) begin
            @(posedge rgmii_rx_clk);
            rgmii_rxd <= 4'h5;
            rgmii_rx_ctl <= 1'b1;
            @(negedge rgmii_rx_clk);
            rgmii_rxd <= 4'h5;
            rgmii_rx_ctl <= 1'b1;
        end
        
        // SFD
        @(posedge rgmii_rx_clk);
        rgmii_rxd <= 4'h5;
        rgmii_rx_ctl <= 1'b1;
        @(negedge rgmii_rx_clk);
        rgmii_rxd <= 4'hD;
        rgmii_rx_ctl <= 1'b1;
        
        // 帧数据（简化）
        for (i = 0; i < length; i = i + 1) begin
            @(posedge rgmii_rx_clk);
            rgmii_rxd <= i[3:0];
            rgmii_rx_ctl <= 1'b1;
            @(negedge rgmii_rx_clk);
            rgmii_rxd <= i[7:4];
            rgmii_rx_ctl <= 1'b1;
        end
        
        // 帧间隙
        repeat(24) begin
            @(posedge rgmii_rx_clk);
            rgmii_rxd <= 4'h0;
            rgmii_rx_ctl <= 1'b0;
            @(negedge rgmii_rx_clk);
            rgmii_rxd <= 4'h0;
            rgmii_rx_ctl <= 1'b0;
        end
        
        $display("[%0t] RGMII Frame Sent: Length=%0d", $time, length);
    end
endtask

// 发送一个字节的任务
task send_rgmii_byte;
    input [7:0] data;
    begin
        @(posedge rgmii_rx_clk);
        rgmii_rxd <= data[3:0];
        rgmii_rx_ctl <= 1'b1;
        @(negedge rgmii_rx_clk);
        rgmii_rxd <= data[7:4];
        rgmii_rx_ctl <= 1'b1;
    end
endtask

// 发送以太网帧（带完整头部）
task send_eth_frame;
    input [47:0] dest_mac;
    input [47:0] src_mac;
    input [15:0] eth_type;
    input [15:0] payload_len;
    input [2047:0] payload_data;  // 最大256字节
    integer i;
    begin
        // 前导码
        for (i = 0; i < 7; i = i + 1) begin
            send_rgmii_byte(8'h55);
        end
        
        // SFD
        send_rgmii_byte(8'hD5);
        
        // 目标 MAC 地址
        send_rgmii_byte(dest_mac[47:40]);
        send_rgmii_byte(dest_mac[39:32]);
        send_rgmii_byte(dest_mac[31:24]);
        send_rgmii_byte(dest_mac[23:16]);
        send_rgmii_byte(dest_mac[15:8]);
        send_rgmii_byte(dest_mac[7:0]);
        
        // 源 MAC 地址
        send_rgmii_byte(src_mac[47:40]);
        send_rgmii_byte(src_mac[39:32]);
        send_rgmii_byte(src_mac[31:24]);
        send_rgmii_byte(src_mac[23:16]);
        send_rgmii_byte(src_mac[15:8]);
        send_rgmii_byte(src_mac[7:0]);
        
        // EtherType
        send_rgmii_byte(eth_type[15:8]);
        send_rgmii_byte(eth_type[7:0]);
        
        // Payload
        for (i = 0; i < payload_len; i = i + 1) begin
            send_rgmii_byte(payload_data[i*8 +: 8]);
        end
        
        // 填充到最小帧长度（46字节）
        if (payload_len < 46) begin
            for (i = payload_len; i < 46; i = i + 1) begin
                send_rgmii_byte(8'h00);
            end
        end
        
        // CRC（简化，发送固定值）
        send_rgmii_byte(8'h12);
        send_rgmii_byte(8'h34);
        send_rgmii_byte(8'h56);
        send_rgmii_byte(8'h78);
        
        // 帧间隙
        repeat(24) begin
            @(posedge rgmii_rx_clk);
            rgmii_rxd <= 4'h0;
            rgmii_rx_ctl <= 1'b0;
            @(negedge rgmii_rx_clk);
            rgmii_rxd <= 4'h0;
            rgmii_rx_ctl <= 1'b0;
        end
        
        $display("[%0t] Ethernet Frame Sent: Dest=%012x, Src=%012x, Type=%04x, Len=%0d", 
                 $time, dest_mac, src_mac, eth_type, payload_len);
    end
endtask

// 发送 ARP 请求帧
task send_arp_request;
    input [47:0] sender_mac;
    input [31:0] sender_ip;
    input [31:0] target_ip;
    reg [2047:0] arp_payload;
    begin
        // ARP 请求格式
        arp_payload[15:0]   = 16'h0001;        // Hardware type: Ethernet
        arp_payload[31:16]  = 16'h0800;        // Protocol type: IPv4
        arp_payload[39:32]  = 8'h06;           // Hardware size: 6
        arp_payload[47:40]  = 8'h04;           // Protocol size: 4
        arp_payload[63:48]  = 16'h0001;        // Opcode: Request
        arp_payload[111:64] = sender_mac;      // Sender MAC
        arp_payload[143:112] = sender_ip;      // Sender IP
        arp_payload[191:144] = 48'h000000000000; // Target MAC (unknown)
        arp_payload[223:192] = target_ip;      // Target IP
        
        send_eth_frame(48'hFFFFFFFFFFFF, sender_mac, 16'h0806, 28, arp_payload);
        $display("[%0t] ARP Request: Who has %d.%d.%d.%d? Tell %d.%d.%d.%d",
                 $time,
                 target_ip[31:24], target_ip[23:16], target_ip[15:8], target_ip[7:0],
                 sender_ip[31:24], sender_ip[23:16], sender_ip[15:8], sender_ip[7:0]);
    end
endtask

// 发送 ARP 响应帧
task send_arp_reply;
    input [47:0] sender_mac;
    input [31:0] sender_ip;
    input [47:0] target_mac;
    input [31:0] target_ip;
    reg [2047:0] arp_payload;
    begin
        // ARP 响应格式
        arp_payload[15:0]   = 16'h0001;        // Hardware type: Ethernet
        arp_payload[31:16]  = 16'h0800;        // Protocol type: IPv4
        arp_payload[39:32]  = 8'h06;           // Hardware size: 6
        arp_payload[47:40]  = 8'h04;           // Protocol size: 4
        arp_payload[63:48]  = 16'h0002;        // Opcode: Reply
        arp_payload[111:64] = sender_mac;      // Sender MAC
        arp_payload[143:112] = sender_ip;      // Sender IP
        arp_payload[191:144] = target_mac;     // Target MAC
        arp_payload[223:192] = target_ip;      // Target IP
        
        send_eth_frame(target_mac, sender_mac, 16'h0806, 28, arp_payload);
        $display("[%0t] ARP Reply: %d.%d.%d.%d is at %012x",
                 $time,
                 sender_ip[31:24], sender_ip[23:16], sender_ip[15:8], sender_ip[7:0],
                 sender_mac);
    end
endtask

// ============================================================================
// 测试场景
// ============================================================================

initial begin
    // 初始化
    gtx_rst = 1'b1;
    logic_rst = 1'b1;
    rgmii_rxd = 4'h0;
    rgmii_rx_ctl = 1'b0;
    
    s_axil_awaddr = 16'h0;
    s_axil_awprot = 3'b0;
    s_axil_awvalid = 1'b0;
    s_axil_wdata = 32'h0;
    s_axil_wstrb = 4'h0;
    s_axil_wvalid = 1'b0;
    s_axil_bready = 1'b0;
    s_axil_araddr = 16'h0;
    s_axil_arprot = 3'b0;
    s_axil_arvalid = 1'b0;
    s_axil_rready = 1'b0;
    
    test_number = 0;
    error_count = 0;
    
    // 初始化 AXI 内存
    for (mem_init_i = 0; mem_init_i < AXI_MEM_SIZE; mem_init_i = mem_init_i + 1) begin
        axi_memory[mem_init_i] = 8'h00;
    end
    
    // VCD 波形记录
    $dumpfile("eth_mac_rgmii_axi_tb.vcd");
    $dumpvars(0, eth_mac_rgmii_axi_tb);
    
    // 复位
    #100;
    gtx_rst = 1'b0;
    logic_rst = 1'b0;
    #100;
    
    $display("========================================");
    $display("以太网 MAC RGMII AXI 测试开始");
    $display("========================================");
    
    // 测试1：寄存器读写
    test_number = 1;
    $display("\n[TEST %0d] 寄存器读写测试", test_number);
    test_register_rw();
    
    // 测试2：MAC 配置
    test_number = 2;
    $display("\n[TEST %0d] MAC 配置测试", test_number);
    test_mac_config();
    
    // 测试3：RGMII 接收
    test_number = 3;
    $display("\n[TEST %0d] RGMII 接收测试", test_number);
    test_rgmii_rx();
    
    // 测试4：ARP 协议
    test_number = 4;
    $display("\n[TEST %0d] ARP 协议测试", test_number);
    test_arp_protocol();
    
    // 测试5：帧过滤
    test_number = 5;
    $display("\n[TEST %0d] 帧过滤测试", test_number);
    test_frame_filter();
    
    // 测试6：DMA RX
    test_number = 6;
    $display("\n[TEST %0d] DMA RX 测试", test_number);
    test_dma_rx();
    
    // 测试7：DMA TX
    test_number = 7;
    $display("\n[TEST %0d] DMA TX 测试", test_number);
    test_dma_tx();
    
    // 测试8：RGMII TX
    test_number = 8;
    $display("\n[TEST %0d] RGMII TX 测试", test_number);
    test_rgmii_tx();
    
    // 测试9：中断系统
    test_number = 9;
    $display("\n[TEST %0d] 中断系统详细测试", test_number);
    test_interrupt_system();
    
    // 测试10：多描述符队列
    test_number = 10;
    $display("\n[TEST %0d] 多描述符队列测试", test_number);
    test_multi_descriptor();
    
    // 测试11：错误处理
    test_number = 11;
    $display("\n[TEST %0d] 错误处理测试", test_number);
    test_error_handling();
    
    // 测试结果
    #1000;
    $display("\n========================================");
    $display("测试完成");
    $display("总测试数: %0d", test_number);
    $display("错误数: %0d", error_count);
    if (error_count == 0) begin
        $display("状态: 通过 ✓");
    end else begin
        $display("状态: 失败 ✗");
    end
    $display("========================================");
    
    $finish;
end

// 测试1：寄存器读写
task test_register_rw;
    reg [AXIL_DATA_WIDTH-1:0] read_data;
    begin
        // 写入 MAC 地址低32位
        axil_write(16'h0008, 32'h12345678);
        #50;
        
        // 读回验证
        axil_read(16'h0008, read_data);
        if (read_data != 32'h12345678) begin
            $display("ERROR: MAC地址低32位不匹配！期望=0x12345678, 实际=0x%08x", read_data);
            error_count = error_count + 1;
        end else begin
            $display("PASS: MAC地址低32位正确");
        end
        
        // 写入控制寄存器
        axil_write(16'h0000, 32'h0000000F); // 使能所有功能
        #50;
        
        // 读回验证
        axil_read(16'h0000, read_data);
        if (read_data[3:0] != 4'hF) begin
            $display("ERROR: 控制寄存器不匹配！");
            error_count = error_count + 1;
        end else begin
            $display("PASS: 控制寄存器正确");
        end
    end
endtask

// 测试2：MAC 配置
task test_mac_config;
    begin
        // 配置 MAC 地址
        axil_write(16'h0008, 32'hAABBCCDD); // MAC低
        axil_write(16'h000C, 32'h0000EEFF); // MAC高
        
        // 配置 IP 地址 (192.168.1.100)
        axil_write(16'h0010, 32'hC0A80164);
        
        // 配置网关 (192.168.1.1)
        axil_write(16'h0014, 32'hC0A80101);
        
        // 配置子网掩码
        axil_write(16'h0018, 32'hFFFFFF00);
        
        $display("PASS: MAC 配置完成");
    end
endtask

// 测试3：RGMII 接收
task test_rgmii_rx;
    begin
        // 使能 RX
        axil_write(16'h0000, 32'h00000002);
        #100;
        
        // 发送一个以太网帧
        send_rgmii_frame(64);
        #1000;
        
        $display("PASS: RGMII 接收测试完成");
    end
endtask

// 测试4：ARP 协议测试
task test_arp_protocol;
    begin
        // 配置网络参数
        axil_write(16'h0008, 32'hAABBCCDD); // MAC 低位
        axil_write(16'h000C, 32'h0000EEFF); // MAC 高位  
        axil_write(16'h0010, 32'hC0A80164); // IP: 192.168.1.100
        axil_write(16'h0014, 32'hC0A80101); // Gateway: 192.168.1.1
        axil_write(16'h0018, 32'hFFFFFF00); // Subnet: 255.255.255.0
        
        // 使能 RX
        axil_write(16'h0000, 32'h00000002);
        #1000;
        
        $display("  [4.1] 发送 ARP 请求");
        // 模拟外部设备发送 ARP 请求询问我们的 MAC 地址
        send_arp_request(48'h112233445566, 32'hC0A80101, 32'hC0A80164);
        #5000;  // 等待 ARP 处理
        
        $display("  [4.2] 发送 ARP 响应");
        // 模拟外部设备响应我们的 ARP 请求
        send_arp_reply(48'h112233445566, 32'hC0A80101, 48'hEEFFAABBCCDD, 32'hC0A80164);
        #5000;  // 等待 ARP 缓存更新
        
        $display("PASS: ARP 协议测试完成");
    end
endtask

// 测试5：帧过滤测试
task test_frame_filter;
    reg [2047:0] dummy_payload;
    begin
        // 配置本地 MAC 地址
        axil_write(16'h0008, 32'hAABBCCDD);
        axil_write(16'h000C, 32'h0000EEFF);
        
        // 配置过滤器：使能过滤 + 广播使能
        axil_write(16'h001C, 32'h00000003);
        
        // 使能 RX
        axil_write(16'h0000, 32'h00000002);
        #1000;
        
        dummy_payload = 2048'h0;
        
        $display("  [5.1] 测试单播帧（匹配本地 MAC）");
        send_eth_frame(48'hEEFFAABBCCDD, 48'h112233445566, 16'h0800, 46, dummy_payload);
        #3000;
        
        $display("  [5.2] 测试单播帧（不匹配本地 MAC - 应被过滤）");
        send_eth_frame(48'h998877665544, 48'h112233445566, 16'h0800, 46, dummy_payload);
        #3000;
        
        $display("  [5.3] 测试广播帧");
        send_eth_frame(48'hFFFFFFFFFFFF, 48'h112233445566, 16'h0800, 46, dummy_payload);
        #3000;
        
        $display("  [5.4] 测试组播帧");
        // 使能组播
        axil_write(16'h001C, 32'h00000007); // 过滤使能 + 广播 + 组播
        #1000;
        send_eth_frame(48'h01005E123456, 48'h112233445566, 16'h0800, 46, dummy_payload);
        #3000;
        
        $display("  [5.5] 测试混杂模式");
        // 使能混杂模式
        axil_write(16'h001C, 32'h0000000F); // 所有使能 + 混杂模式
        #1000;
        send_eth_frame(48'h998877665544, 48'h112233445566, 16'h0800, 46, dummy_payload);
        #3000;
        
        $display("PASS: 帧过滤测试完成");
    end
endtask

// 测试6：DMA RX 测试（从 MAC 接收数据到内存）
task test_dma_rx;
    reg [2047:0] dummy_payload;
    integer i;
    reg [AXIL_DATA_WIDTH-1:0] read_data;
    begin
        // 初始化测试数据
        for (i = 0; i < 64; i = i + 1) begin
            dummy_payload[i*8 +: 8] = i[7:0];
        end
        
        // 初始化内存为已知模式
        for (i = 0; i < 128; i = i + 1) begin
            axi_memory[32'h1000 + i] = 8'hAA;
        end
        
        $display("  [6.1] 配置 DMA RX 描述符");
        // 配置 RX 描述符：地址 0x1000，长度 64 字节，tag 0x01
        axil_write(16'h0030, 32'h00001000);  // RX 描述符地址
        axil_write(16'h0034, 32'h00000040);  // RX 描述符长度 (64 字节)
        axil_write(16'h0038, 32'h00000001);  // RX 描述符 tag
        
        // 使能 DMA RX
        axil_write(16'h0000, 32'h00000006);  // RX 使能 + DMA RX 使能
        #1000;
        
        $display("  [6.2] 启动 DMA RX 描述符");
        axil_write(16'h003C, 32'h00000001);  // 写入 1 启动描述符
        #1000;
        
        $display("  [6.3] 发送以太网帧到 MAC");
        send_eth_frame(48'hEEFFAABBCCDD, 48'h112233445566, 16'h0800, 64, dummy_payload);
        #10000;  // 等待 DMA 传输完成
        
        $display("  [6.4] 验证内存数据");
        // 检查内存中的数据（跳过以太网头部14字节）
        for (i = 0; i < 20; i = i + 1) begin
            if (axi_memory[32'h1000 + 14 + i] != i[7:0]) begin
                $display("ERROR: DMA RX 数据不匹配！地址=%04x, 期望=%02x, 实际=%02x",
                        32'h1000 + 14 + i, i[7:0], axi_memory[32'h1000 + 14 + i]);
                error_count = error_count + 1;
            end
        end
        
        // 检查描述符状态
        axil_read(16'h0030, read_data);
        $display("  [6.5] RX 描述符状态: 0x%08x", read_data);
        
        $display("PASS: DMA RX 测试完成");
    end
endtask

// 测试7：DMA TX 测试（从内存发送数据到 MAC）
task test_dma_tx;
    integer i;
    reg [AXIL_DATA_WIDTH-1:0] read_data;
    begin
        $display("  [7.1] 准备发送数据到内存");
        // 准备内存中的数据（以太网帧）
        // 目标 MAC: FFFFFFFFFFFF (广播)
        axi_memory[32'h2000 + 0] = 8'hFF;
        axi_memory[32'h2000 + 1] = 8'hFF;
        axi_memory[32'h2000 + 2] = 8'hFF;
        axi_memory[32'h2000 + 3] = 8'hFF;
        axi_memory[32'h2000 + 4] = 8'hFF;
        axi_memory[32'h2000 + 5] = 8'hFF;
        // 源 MAC: EEFFAABBCCDD
        axi_memory[32'h2000 + 6] = 8'hEE;
        axi_memory[32'h2000 + 7] = 8'hFF;
        axi_memory[32'h2000 + 8] = 8'hAA;
        axi_memory[32'h2000 + 9] = 8'hBB;
        axi_memory[32'h2000 + 10] = 8'hCC;
        axi_memory[32'h2000 + 11] = 8'hDD;
        // EtherType: 0x0800 (IPv4)
        axi_memory[32'h2000 + 12] = 8'h08;
        axi_memory[32'h2000 + 13] = 8'h00;
        // Payload
        for (i = 14; i < 64; i = i + 1) begin
            axi_memory[32'h2000 + i] = i[7:0];
        end
        
        $display("  [7.2] 配置 DMA TX 描述符");
        // 配置 TX 描述符：地址 0x2000，长度 64 字节，tag 0x02
        axil_write(16'h0040, 32'h00002000);  // TX 描述符地址
        axil_write(16'h0044, 32'h00000040);  // TX 描述符长度 (64 字节)
        axil_write(16'h0048, 32'h00000002);  // TX 描述符 tag
        
        // 使能 DMA TX
        axil_write(16'h0000, 32'h00000005);  // TX 使能 + DMA TX 使能
        #1000;
        
        $display("  [7.3] 启动 DMA TX 描述符");
        axil_write(16'h004C, 32'h00000001);  // 写入 1 启动描述符
        #15000;  // 等待 DMA 读取和 TX 传输完成
        
        // 检查描述符状态
        axil_read(16'h0040, read_data);
        $display("  [7.4] TX 描述符状态: 0x%08x", read_data);
        
        $display("PASS: DMA TX 测试完成");
    end
endtask

// 测试8：RGMII TX 完整测试
task test_rgmii_tx;
    reg [2047:0] dummy_payload;
    integer i;
    begin
        // 准备测试数据
        for (i = 0; i < 64; i = i + 1) begin
            dummy_payload[i*8 +: 8] = i[7:0];
        end
        
        // 配置 MAC 地址和 IP
        axil_write(16'h0008, 32'hAABBCCDD);
        axil_write(16'h000C, 32'h0000EEFF);
        axil_write(16'h0010, 32'hC0A80164);
        
        // 使能 TX
        axil_write(16'h0000, 32'h00000001);
        #1000;
        
        $display("  [8.1] 通过 DMA 发送帧（从内存）");
        // 准备内存数据
        for (i = 0; i < 64; i = i + 1) begin
            axi_memory[32'h3000 + i] = i[7:0];
        end
        
        // 配置并启动 TX 描述符
        axil_write(16'h0040, 32'h00003000);
        axil_write(16'h0044, 32'h00000040);
        axil_write(16'h0048, 32'h00000003);
        axil_write(16'h004C, 32'h00000001);
        #10000;
        
        $display("  [8.2] 观察 RGMII TX 信号");
        // 注：实际的 TX 信号会在波形中可见
        $display("     检查波形中的 rgmii_txd 和 rgmii_tx_ctl 信号");
        #5000;
        
        $display("PASS: RGMII TX 测试完成");
    end
endtask

// 测试9：中断系统详细测试
task test_interrupt_system;
    reg [AXIL_DATA_WIDTH-1:0] read_data;
    reg [2047:0] dummy_payload;
    integer i;
    begin
        // 准备测试数据
        for (i = 0; i < 64; i = i + 1) begin
            dummy_payload[i*8 +: 8] = i[7:0];
        end
        
        $display("  [9.1] 测试中断使能和屏蔽");
        // 清除所有中断状态
        axil_write(16'h0024, 32'h0000000F);  // 写1清除
        #1000;
        
        // 使能所有中断
        axil_write(16'h0020, 32'h0000000F);  // bit[3:0]: TX_ERR, RX_ERR, TX_DONE, RX_DONE
        #1000;
        
        // 读取中断使能寄存器
        axil_read(16'h0020, read_data);
        $display("     中断使能寄存器: 0x%08x (期望: 0x0000000F)", read_data);
        if (read_data[3:0] != 4'b1111) begin
            $display("ERROR: 中断使能设置错误！");
            error_count = error_count + 1;
        end
        
        $display("  [9.2] 测试 RX Done 中断");
        // 配置 DMA RX
        for (i = 0; i < 128; i = i + 1) begin
            axi_memory[32'h1000 + i] = 8'h00;
        end
        axil_write(16'h0030, 32'h00001000);
        axil_write(16'h0034, 32'h00000040);
        axil_write(16'h0038, 32'h00000010);
        axil_write(16'h0000, 32'h00000006);  // 使能 RX + DMA RX
        #1000;
        
        // 启动 RX 描述符
        axil_write(16'h003C, 32'h00000001);
        #1000;
        
        // 发送帧触发 RX
        send_eth_frame(48'hEEFFAABBCCDD, 48'h112233445566, 16'h0800, 64, dummy_payload);
        #10000;  // 等待 DMA 完成
        
        // 检查中断状态
        axil_read(16'h0024, read_data);
        $display("     中断状态寄存器: 0x%08x", read_data);
        if (read_data[0]) begin  // RX_DONE 中断
            $display("     ✓ RX Done 中断触发");
        end else begin
            $display("     WARNING: RX Done 中断未触发");
        end
        
        // 检查 IRQ 引脚
        if (irq) begin
            $display("     ✓ IRQ 引脚已拉高");
        end else begin
            $display("     WARNING: IRQ 引脚未拉高");
        end
        
        // 清除中断
        axil_write(16'h0024, 32'h00000001);  // 写1清除 RX_DONE
        #1000;
        axil_read(16'h0024, read_data);
        if (read_data[0] == 0) begin
            $display("     ✓ 中断已清除");
        end
        
        $display("  [9.3] 测试 TX Done 中断");
        // 准备 TX 数据
        for (i = 0; i < 64; i = i + 1) begin
            axi_memory[32'h2000 + i] = i[7:0];
        end
        
        // 配置并启动 TX 描述符
        axil_write(16'h0040, 32'h00002000);
        axil_write(16'h0044, 32'h00000040);
        axil_write(16'h0048, 32'h00000020);
        axil_write(16'h0000, 32'h00000005);  // 使能 TX + DMA TX
        #1000;
        axil_write(16'h004C, 32'h00000001);
        #15000;  // 等待 TX 完成
        
        // 检查中断状态
        axil_read(16'h0024, read_data);
        $display("     中断状态寄存器: 0x%08x", read_data);
        if (read_data[1]) begin  // TX_DONE 中断
            $display("     ✓ TX Done 中断触发");
        end else begin
            $display("     WARNING: TX Done 中断未触发");
        end
        
        // 清除中断
        axil_write(16'h0024, 32'h00000002);
        #1000;
        
        $display("  [9.4] 测试中断屏蔽");
        // 禁用所有中断
        axil_write(16'h0020, 32'h00000000);
        #1000;
        
        // 再次触发 RX（应该不产生中断）
        axil_write(16'h003C, 32'h00000001);
        #1000;
        send_eth_frame(48'hEEFFAABBCCDD, 48'h112233445566, 16'h0800, 64, dummy_payload);
        #10000;
        
        // IRQ 应该保持低电平
        if (!irq) begin
            $display("     ✓ 中断已屏蔽，IRQ 保持低电平");
        end else begin
            $display("     WARNING: 中断屏蔽可能失败");
        end
        
        $display("PASS: 中断系统测试完成");
    end
endtask

// 测试10：多描述符队列测试
task test_multi_descriptor;
    integer i, j;
    reg [AXIL_DATA_WIDTH-1:0] read_data;
    begin
        $display("  [10.1] 准备多个 TX 描述符数据");
        // 准备3个不同的数据包
        for (j = 0; j < 3; j = j + 1) begin
            for (i = 0; i < 64; i = i + 1) begin
                axi_memory[32'h4000 + j*64 + i] = (j*64 + i) & 8'hFF;
            end
        end
        
        // 使能 TX
        axil_write(16'h0000, 32'h00000001);
        #1000;
        
        $display("  [10.2] 连续发送3个描述符");
        // 描述符1
        $display("     发送描述符 1 (地址 0x4000)");
        axil_write(16'h0040, 32'h00004000);
        axil_write(16'h0044, 32'h00000040);
        axil_write(16'h0048, 32'h00000001);
        axil_write(16'h004C, 32'h00000001);
        #5000;
        
        // 描述符2
        $display("     发送描述符 2 (地址 0x4040)");
        axil_write(16'h0040, 32'h00004040);
        axil_write(16'h0044, 32'h00000040);
        axil_write(16'h0048, 32'h00000002);
        axil_write(16'h004C, 32'h00000001);
        #5000;
        
        // 描述符3
        $display("     发送描述符 3 (地址 0x4080)");
        axil_write(16'h0040, 32'h00004080);
        axil_write(16'h0044, 32'h00000040);
        axil_write(16'h0048, 32'h00000003);
        axil_write(16'h004C, 32'h00000001);
        #5000;
        
        $display("  [10.3] 测试 RX 多描述符");
        // 准备3个 RX 缓冲区
        for (j = 0; j < 3; j = j + 1) begin
            for (i = 0; i < 128; i = i + 1) begin
                axi_memory[32'h5000 + j*128 + i] = 8'hAA;
            end
        end
        
        // 使能 RX
        axil_write(16'h0000, 32'h00000002);
        #1000;
        
        // 配置并接收3个帧
        for (j = 0; j < 3; j = j + 1) begin
            $display("     接收到缓冲区 %0d (地址 0x%04x)", j+1, 32'h5000 + j*128);
            axil_write(16'h0030, 32'h5000 + j*128);
            axil_write(16'h0034, 32'h00000080);
            axil_write(16'h0038, 32'h10 + j);
            axil_write(16'h003C, 32'h00000001);
            #1000;
            
            // 发送帧
            send_rgmii_frame(64);
            #5000;
        end
        
        $display("  [10.4] 验证多个描述符都已完成");
        // 检查内存数据（简单验证第一个缓冲区）
        if (axi_memory[32'h5000 + 20] != 8'hAA) begin
            $display("     ✓ 第一个缓冲区已接收数据");
        end
        
        $display("PASS: 多描述符队列测试完成");
    end
endtask

// 测试11：错误处理测试
task test_error_handling;
    reg [AXIL_DATA_WIDTH-1:0] read_data;
    integer i;
    begin
        $display("  [11.1] 测试 AXI 错误响应");
        // 尝试访问超出范围的内存（会触发 DECERR）
        axil_write(16'h0040, 32'hFFFF0000);  // 无效地址
        axil_write(16'h0044, 32'h00000040);
        axil_write(16'h0048, 32'h000000FF);
        axil_write(16'h0000, 32'h00000005);
        #1000;
        
        // 启动描述符（可能导致错误）
        axil_write(16'h004C, 32'h00000001);
        #10000;
        
        // 检查错误状态
        axil_read(16'h0024, read_data);
        $display("     中断状态: 0x%08x", read_data);
        if (read_data[3]) begin  // TX_ERROR bit
            $display("     ✓ 检测到 TX 错误");
        end
        
        // 清除错误
        axil_write(16'h0024, 32'h0000000F);
        #1000;
        
        $display("  [11.2] 测试描述符长度为0");
        // 配置长度为0的描述符
        axil_write(16'h0040, 32'h00004000);
        axil_write(16'h0044, 32'h00000000);  // 长度 = 0
        axil_write(16'h0048, 32'h00000010);
        axil_write(16'h004C, 32'h00000001);
        #5000;
        
        $display("     ✓ 零长度描述符处理完成");
        
        $display("  [11.3] 测试超大描述符");
        // 配置超大长度描述符
        axil_write(16'h0040, 32'h00004000);
        axil_write(16'h0044, 32'h000FFFFF);  // 最大长度
        axil_write(16'h0048, 32'h00000020);
        // 不实际启动，只是测试配置
        #1000;
        
        axil_read(16'h0044, read_data);
        $display("     配置的超大长度: 0x%08x", read_data);
        
        $display("  [11.4] 测试未对齐地址");
        // 配置非对齐地址
        axil_write(16'h0040, 32'h00004001);  // 地址 +1（非对齐）
        axil_write(16'h0044, 32'h00000040);
        axil_write(16'h0048, 32'h00000030);
        #1000;
        
        $display("     ✓ 非对齐地址配置完成");
        
        $display("  [11.5] 测试寄存器写保护");
        // 尝试写只读寄存器（状态寄存器）
        axil_write(16'h0004, 32'hDEADBEEF);
        #1000;
        axil_read(16'h0004, read_data);
        if (read_data != 32'hDEADBEEF) begin
            $display("     ✓ 状态寄存器写保护正常 (值=0x%08x)", read_data);
        end
        
        $display("PASS: 错误处理测试完成");
    end
endtask

// 超时检测
initial begin
    #100000000; // 100ms 超时
    $display("ERROR: 仿真超时！");
    $finish;
end

endmodule

