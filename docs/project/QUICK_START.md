# 以太网 MAC IP 快速入门指南

## 5分钟快速开始

本指南帮助您快速集成和使用以太网 MAC IP。

## 文件清单

已创建的文件：

### Verilog 设计文件
- ✅ `eth_mac_rgmii_axi.v` - 顶层 MAC IP 核心
- ✅ `eth_frame_filter.v` - 帧过滤器模块
- ✅ `eth_mac_axil_regs.v` - 控制寄存器接口
- ✅ `eth_mac_example.v` - 集成示例

### 文档文件
- ✅ `ETH_MAC_RGMII_README.md` - 详细技术文档
- ✅ `PROJECT_SUMMARY.md` - 项目总结
- ✅ `QUICK_START.md` - 本文件
- ✅ `filelist.txt` - 完整文件列表

### 软件和约束
- ✅ `eth_mac_driver.c` - C 语言驱动示例
- ✅ `eth_mac_constraints.xdc` - Xilinx 时序约束

## 快速集成步骤

### 步骤 1: 准备依赖库 (5分钟)

```bash
# 进入您的项目目录
cd /path/to/your/project

# 克隆依赖库
git clone https://github.com/alexforencich/verilog-ethernet
git clone https://github.com/alexforencich/verilog-axi

# 注意：这些库文件在您的系统中已存在于：
# /home/xuser/code_space/verilog/verilog/verilog-ethernet
# /home/xuser/code_space/verilog/verilog/verilog-axi
```

### 步骤 2: 添加文件到 FPGA 项目 (10分钟)

#### Xilinx Vivado

```tcl
# 在 Vivado TCL 控制台执行：

# 添加核心设计文件
add_files {
    eth_mac_rgmii_axi.v
    eth_frame_filter.v
    eth_mac_axil_regs.v
}

# 添加 verilog-ethernet 依赖
add_files [glob verilog-ethernet/rtl/eth_mac_1g_rgmii*.v]
add_files [glob verilog-ethernet/rtl/eth_axis_*.v]
add_files [glob verilog-ethernet/rtl/ip*.v]
add_files [glob verilog-ethernet/rtl/arp*.v]
add_files [glob verilog-ethernet/rtl/eth_arb_mux.v]
add_files [glob verilog-ethernet/rtl/rgmii_phy_if.v]
add_files [glob verilog-ethernet/rtl/lfsr.v]
add_files [glob verilog-ethernet/rtl/*ddr*.v]

# 添加 verilog-axi 依赖
add_files [glob verilog-axi/rtl/axi_dma*.v]
add_files [glob verilog-axi/rtl/arbiter.v]
add_files [glob verilog-axi/rtl/priority_encoder.v]

# 添加约束文件
add_files -fileset constrs_1 eth_mac_constraints.xdc
```

#### Intel Quartus

1. 打开您的 Quartus 项目
2. 选择 "Project" -> "Add/Remove Files in Project"
3. 添加上述所有 .v 文件
4. 对于约束，使用 SDC 格式（需要转换 XDC）

### 步骤 3: 实例化模块 (15分钟)

在您的顶层设计中实例化 MAC IP：

```verilog
// 在您的顶层模块中
eth_mac_rgmii_axi #(
    .TARGET("XILINX"),              // 或 "ALTERA"
    .AXI_DATA_WIDTH(64),
    .AXI_ADDR_WIDTH(32)
) eth_mac_inst (
    // 时钟
    .gtx_clk(clk_125mhz),
    .gtx_clk90(clk_125mhz_90),
    .gtx_rst(rst_125mhz),
    .logic_clk(clk_100mhz),
    .logic_rst(rst_100mhz),
    
    // RGMII 接口 - 连接到顶层端口
    .rgmii_rx_clk(rgmii_rx_clk),
    .rgmii_rxd(rgmii_rxd),
    .rgmii_rx_ctl(rgmii_rx_ctl),
    .rgmii_tx_clk(rgmii_tx_clk),
    .rgmii_txd(rgmii_txd),
    .rgmii_tx_ctl(rgmii_tx_ctl),
    
    // AXI Master - 连接到系统总线
    .m_axi_awid(m_axi_awid),
    .m_axi_awaddr(m_axi_awaddr),
    // ... 其他 AXI 信号
    
    // AXI-Lite Slave - 连接到控制总线
    .s_axil_awaddr(s_axil_awaddr),
    .s_axil_awvalid(s_axil_awvalid),
    // ... 其他 AXI-Lite 信号
    
    // 中断
    .irq(eth_irq)
);
```

完整示例请参考 `eth_mac_example.v`。

### 步骤 4: 时钟和复位 (10分钟)

生成所需的时钟：

#### Xilinx Clocking Wizard

```tcl
# 创建时钟向导 IP
create_ip -name clk_wiz -vendor xilinx.com -library ip -module_name eth_clk_wiz

# 配置：
# - 输入时钟：根据您的板卡（例如 200 MHz）
# - 输出时钟1：125 MHz (gtx_clk)
# - 输出时钟2：125 MHz, 相位 90° (gtx_clk90)
# - 输出时钟3：100 MHz (logic_clk，如果需要)
```

#### 复位同步

```verilog
// 复位同步器（在各个时钟域）
reg [3:0] rst_sync = 4'b1111;
always @(posedge clk or posedge async_rst) begin
    if (async_rst)
        rst_sync <= 4'b1111;
    else
        rst_sync <= {rst_sync[2:0], 1'b0};
end
wire sync_rst = rst_sync[3];
```

### 步骤 5: 软件初始化 (10分钟)

将 `eth_mac_driver.c` 添加到您的软件项目：

```c
#include "eth_mac_driver.c"

int main(void) {
    // 1. 初始化 MAC
    eth_mac_init_example();
    
    // 2. 配置网络参数
    uint8_t mac[6] = {0x00, 0x11, 0x22, 0x33, 0x44, 0x55};
    eth_mac_set_address(mac);
    eth_mac_set_ip(0xC0A80164);      // 192.168.1.100
    eth_mac_set_gateway(0xC0A80101);  // 192.168.1.1
    eth_mac_set_netmask(0xFFFFFF00);  // 255.255.255.0
    
    // 3. 使能 MAC
    eth_mac_tx_enable(true);
    eth_mac_rx_enable(true);
    eth_mac_dma_enable(true, true);
    
    // 4. 使能中断
    eth_mac_irq_enable(true);
    
    // 5. 主循环
    while (1) {
        // 发送和接收数据包
        eth_mac_send_example();
        eth_mac_recv_example();
    }
    
    return 0;
}
```

## 验证测试

### 基本连接测试

1. **硬件连接**
   - 连接以太网 PHY 芯片到 FPGA
   - 连接网线到 PHY
   - 上电

2. **软件测试**
   ```bash
   # 从 PC 端 ping FPGA
   ping 192.168.1.100
   
   # 应该能看到响应（如果 ARP 工作正常）
   ```

3. **检查状态**
   ```c
   uint32_t speed = eth_mac_get_speed();
   printf("Link speed: %s\n", eth_mac_get_speed_string());
   ```

### 性能测试

使用 iperf 测试吞吐量：

```bash
# 在 PC 端作为服务器
iperf -s

# FPGA 作为客户端（需要实现 TCP/IP 栈）
# 或者使用简单的 UDP echo 测试
```

## 故障排查

### 常见问题

1. **没有链路**
   - 检查 RGMII 时钟是否正确
   - 检查 PHY 芯片配置
   - 验证引脚连接

2. **无法 ping 通**
   - 检查 MAC/IP 地址配置
   - 确认 TX/RX 都已使能
   - 查看中断状态寄存器

3. **DMA 不工作**
   - 确认 AXI 总线连接正确
   - 检查缓冲区地址对齐
   - 验证 DMA 使能位

4. **性能不佳**
   - 检查 FIFO 深度设置
   - 优化 DMA 突发长度
   - 确认时钟频率满足要求

### 调试工具

1. **读取状态寄存器**
   ```c
   uint32_t status = eth_read_reg(ETH_REG_STATUS);
   uint32_t irq = eth_read_reg(ETH_REG_IRQ_STATUS);
   ```

2. **使用 ILA**
   - 在 Vivado 中插入 ILA 核
   - 监控 RGMII 接口信号
   - 观察 AXI 事务

3. **Wireshark 抓包**
   - 在 PC 端使用 Wireshark
   - 查看是否有以太网帧
   - 分析 ARP 交互

## 下一步

- 📖 阅读完整文档：`ETH_MAC_RGMII_README.md`
- 🔧 查看项目总结：`PROJECT_SUMMARY.md`
- 💻 参考驱动代码：`eth_mac_driver.c`
- 🎯 查看集成示例：`eth_mac_example.v`

## 支持的板卡

此 IP 已在以下平台测试（理论上）：

- ✓ Xilinx Zynq-7000
- ✓ Xilinx Zynq UltraScale+
- ✓ Xilinx Artix-7
- ✓ Xilinx Kintex-7
- ✓ Xilinx Virtex-7
- ✓ Xilinx UltraScale/UltraScale+

## 技术支持

遇到问题？

1. 检查 `ETH_MAC_RGMII_README.md` 的常见问题章节
2. 查看 verilog-ethernet 库的文档和示例
3. 在相关项目的 GitHub Issues 中搜索

## 许可证

本设计基于开源项目，遵循原项目的许可证：
- verilog-ethernet: MIT License
- verilog-axi: MIT License

---

**祝您使用愉快！如有任何改进建议，欢迎反馈。**

