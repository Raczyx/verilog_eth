# 以太网 MAC IP - RGMII 接口 (带 ARP 和 DMA)

## 概述

这是一个完整的千兆以太网 MAC IP 核，基于 RGMII 物理接口，整合了以下功能：

- **RGMII 物理接口**：支持 10/100/1000 Mbps 自适应
- **ARP 协议支持**：自动处理 ARP 请求和响应，维护 ARP 缓存
- **帧过滤器**：可配置的 MAC 地址过滤、广播/组播过滤、混杂模式
- **双通道 DMA**：独立的 RX 和 TX DMA 引擎，通过 AXI 总线访问系统内存
- **AXI-Lite 控制接口**：完整的寄存器配置接口
- **中断支持**：RX/TX 完成和错误中断

## 模块列表

### 1. eth_mac_rgmii_axi.v (顶层模块)
主要的以太网 MAC IP 核，整合所有功能模块。

### 2. eth_frame_filter.v
以太网帧过滤器模块，支持：
- 基于目标 MAC 地址的过滤
- 广播帧过滤
- 组播帧过滤
- 混杂模式（接收所有帧）

### 3. eth_mac_axil_regs.v
AXI-Lite 控制寄存器接口，提供软件配置和状态读取。

## 系统架构

```
                          +------------------------------------------+
                          |      eth_mac_rgmii_axi (顶层)            |
                          |                                          |
   RGMII Interface        |  +----------------------------------+    |    AXI Master (DMA)
   ----------------       |  |  eth_mac_1g_rgmii_fifo         |    |    ----------------
   rgmii_rx_clk    -----> |  |  (RGMII MAC + FIFO)            |    |    m_axi_*
   rgmii_rxd[3:0]  -----> |  +----------------------------------+    |    
   rgmii_rx_ctl    -----> |            |                             |    
   rgmii_tx_clk    <----- |            v                             |    
   rgmii_txd[3:0]  <----- |  +----------------------------------+    |    
   rgmii_tx_ctl    <----- |  |  eth_frame_filter              |    |    
                          |  |  (帧过滤器)                     |    |    
                          |  +----------------------------------+    |    
                          |            |                             |    
   AXI-Lite Slave         |            v                             |    
   (控制寄存器)           |  +----------------------------------+    |    
   ----------------       |  |  eth_axis_rx                   |    |    
   s_axil_*        -----> |  |  (以太网帧接收器)               |    |    
                          |  +----------------------------------+    |    
                          |            |                             |    
                          |            v                             |    
                          |  +----------------------------------+    |    
                          |  |  ip_complete                   |    |    
                          |  |  (IP + ARP 协议栈)             |    |    
                          |  +----------------------------------+    |    
                          |            |                             |    
                          |            v                             |    
                          |  +----------------------------------+    |    
                          |  |  axi_dma                       |    |    
                          |  |  (双通道 DMA 引擎)             | ---|--> AXI Master
                          |  +----------------------------------+    |    
                          |                                          |    
                          |  +----------------------------------+    |    
                          |  |  eth_mac_axil_regs             |    |    
                          |  |  (控制寄存器接口)               | <--|--- AXI-Lite Slave
                          |  +----------------------------------+    |    
                          |                                          |    
                          +------------------------------------------+
                                         |
                                         v
                                      irq (中断输出)
```

## 接口说明

### 时钟和复位

| 信号 | 方向 | 宽度 | 说明 |
|------|------|------|------|
| gtx_clk | 输入 | 1 | GTX 时钟 (125 MHz)，用于千兆以太网 |
| gtx_clk90 | 输入 | 1 | GTX 90度相移时钟，用于 RGMII TX |
| gtx_rst | 输入 | 1 | GTX 时钟域复位 |
| logic_clk | 输入 | 1 | 逻辑时钟，用于 AXI 接口 |
| logic_rst | 输入 | 1 | 逻辑时钟域复位 |

### RGMII 接口

| 信号 | 方向 | 宽度 | 说明 |
|------|------|------|------|
| rgmii_rx_clk | 输入 | 1 | RGMII 接收时钟 |
| rgmii_rxd | 输入 | 4 | RGMII 接收数据 |
| rgmii_rx_ctl | 输入 | 1 | RGMII 接收控制 |
| rgmii_tx_clk | 输出 | 1 | RGMII 发送时钟 |
| rgmii_txd | 输出 | 4 | RGMII 发送数据 |
| rgmii_tx_ctl | 输出 | 1 | RGMII 发送控制 |

### AXI Master 接口 (DMA)

标准的 AXI4 Master 接口，用于 DMA 传输：
- 支持全速率读写操作
- 可配置的突发长度（默认最大 256）
- 数据宽度可配置（默认 64 位）

### AXI-Lite Slave 接口 (控制寄存器)

标准的 AXI4-Lite Slave 接口，用于配置和状态读取：
- 数据宽度：32 位
- 地址宽度：16 位
- 支持所有标准的 AXI-Lite 信号

## 寄存器地址映射

### 控制和状态寄存器

| 地址 | 名称 | 访问 | 说明 |
|------|------|------|------|
| 0x0000 | CTRL | RW | 控制寄存器<br>[0]: TX 使能<br>[1]: RX 使能<br>[2]: DMA RX 使能<br>[3]: DMA TX 使能<br>[4]: 清除 ARP 缓存 |
| 0x0004 | STATUS | RO | 状态寄存器<br>[1:0]: 链路速度 (0=10M, 1=100M, 2=1000M) |
| 0x0008 | MAC_ADDR_LOW | RW | 本地 MAC 地址低 32 位 |
| 0x000C | MAC_ADDR_HIGH | RW | 本地 MAC 地址高 16 位 |
| 0x0010 | LOCAL_IP | RW | 本地 IP 地址 |
| 0x0014 | GATEWAY_IP | RW | 网关 IP 地址 |
| 0x0018 | SUBNET_MASK | RW | 子网掩码 |
| 0x001C | FILTER_CONFIG | RW | 过滤器配置<br>[0]: 过滤使能<br>[1]: 混杂模式<br>[2]: 广播使能<br>[3]: 组播使能 |
| 0x0020 | IRQ_ENABLE | RW | 中断使能<br>[0]: 全局中断使能 |
| 0x0024 | IRQ_STATUS | RW1C | 中断状态 (写1清除)<br>[0]: RX 完成<br>[1]: TX 完成<br>[2]: RX 错误<br>[3]: TX 错误 |
| 0x0028 | IFG_CONFIG | RW | 帧间隙配置 (默认12) |

### RX DMA 描述符寄存器

| 地址 | 名称 | 访问 | 说明 |
|------|------|------|------|
| 0x0030 | RX_DESC_ADDR | RW | RX DMA 目标地址 |
| 0x0034 | RX_DESC_LEN | RW | RX DMA 传输长度 |
| 0x0038 | RX_DESC_TAG | RW | RX DMA 标签 |
| 0x003C | RX_DESC_VALID | RW | RX DMA 描述符有效 (写1启动) |

### TX DMA 描述符寄存器

| 地址 | 名称 | 访问 | 说明 |
|------|------|------|------|
| 0x0040 | TX_DESC_ADDR | RW | TX DMA 源地址 |
| 0x0044 | TX_DESC_LEN | RW | TX DMA 传输长度 |
| 0x0048 | TX_DESC_TAG | RW | TX DMA 标签 |
| 0x004C | TX_DESC_VALID | RW | TX DMA 描述符有效 (写1启动) |

## 使用示例

### 1. 初始化配置

```c
// 配置本地 MAC 地址
write_reg(0x0008, 0x12345678);  // MAC 低32位
write_reg(0x000C, 0x0000AABB);  // MAC 高16位: AA:BB:12:34:56:78

// 配置本地 IP 地址 (192.168.1.100)
write_reg(0x0010, 0xC0A80164);

// 配置网关 IP (192.168.1.1)
write_reg(0x0014, 0xC0A80101);

// 配置子网掩码 (255.255.255.0)
write_reg(0x0018, 0xFFFFFF00);

// 配置过滤器 (使能 + 广播)
write_reg(0x001C, 0x00000005);

// 使能 TX/RX 和 DMA
write_reg(0x0000, 0x0000000F);

// 使能中断
write_reg(0x0020, 0x00000001);
```

### 2. 发送数据包 (TX)

```c
// 准备发送缓冲区
uint8_t *tx_buffer = allocate_dma_buffer(1500);
// ... 填充数据到 tx_buffer ...

// 配置 TX DMA 描述符
write_reg(0x0040, (uint32_t)tx_buffer);  // 源地址
write_reg(0x0044, 1500);                  // 长度
write_reg(0x0048, 0x01);                  // 标签
write_reg(0x004C, 0x01);                  // 启动传输

// 等待中断或轮询状态
while ((read_reg(0x0024) & 0x02) == 0);  // 等待 TX 完成
write_reg(0x0024, 0x02);                 // 清除中断标志
```

### 3. 接收数据包 (RX)

```c
// 准备接收缓冲区
uint8_t *rx_buffer = allocate_dma_buffer(2048);

// 配置 RX DMA 描述符
write_reg(0x0030, (uint32_t)rx_buffer);  // 目标地址
write_reg(0x0034, 2048);                  // 最大长度
write_reg(0x0038, 0x01);                  // 标签
write_reg(0x003C, 0x01);                  // 启动接收

// 等待中断或轮询状态
while ((read_reg(0x0024) & 0x01) == 0);  // 等待 RX 完成
write_reg(0x0024, 0x01);                 // 清除中断标志

// 读取实际接收的长度
uint32_t rx_len = read_reg(0x0034) & 0xFFFFF;
// 处理接收到的数据
process_packet(rx_buffer, rx_len);
```

## 参数配置

主要参数可以在实例化时配置：

```verilog
eth_mac_rgmii_axi #(
    .TARGET("XILINX"),              // 目标平台
    .IODDR_STYLE("IODDR"),          // DDR 样式
    .CLOCK_INPUT_STYLE("BUFR"),     // 时钟输入样式
    .AXI_DATA_WIDTH(64),            // AXI 数据宽度
    .AXI_ADDR_WIDTH(32),            // AXI 地址宽度
    .TX_FIFO_DEPTH(4096),           // TX FIFO 深度
    .RX_FIFO_DEPTH(4096),           // RX FIFO 深度
    .ENABLE_MAC_FILTER(1),          // 使能 MAC 过滤
    .NUM_MAC_FILTERS(4),            // MAC 过滤器数量
    .ARP_CACHE_ADDR_WIDTH(9)        // ARP 缓存深度 (512项)
) eth_mac_inst (
    // ... 端口连接 ...
);
```

## 依赖的库模块

此设计依赖以下开源库：

### verilog-ethernet 库
- `eth_mac_1g_rgmii_fifo`: RGMII MAC 核心
- `eth_axis_rx`: 以太网帧接收器
- `eth_axis_tx`: 以太网帧发送器
- `ip_complete`: IP/ARP 协议栈
- `eth_arb_mux`: 以太网仲裁复用器

### verilog-axi 库
- `axi_dma`: AXI DMA 引擎
- `axi_dma_rd`: DMA 读通道
- `axi_dma_wr`: DMA 写通道

## 性能特性

- **最大吞吐量**: 1 Gbps (千兆以太网)
- **最小帧间隙**: 12 字节 (可配置)
- **DMA 突发长度**: 最大 256 传输
- **RX/TX FIFO**: 各 4KB (可配置)
- **ARP 缓存**: 512 项 (可配置)
- **延迟**: 典型 < 1 μs (MAC + DMA)

## 时序要求

1. **GTX 时钟**: 125 MHz (千兆模式)
2. **逻辑时钟**: ≥ 100 MHz (推荐)
3. **时钟域跨越**: 自动处理 (内部 CDC 逻辑)

## 注意事项

1. **时钟关系**: gtx_clk 和 logic_clk 必须是独立的时钟源
2. **复位**: 上电后需要对两个时钟域分别复位
3. **DMA 缓冲区对齐**: 推荐使用 AXI_DATA_WIDTH 对齐的地址
4. **帧长度**: 支持 64-1518 字节 (标准以太网帧)
5. **中断处理**: 中断状态位需要软件清除 (写1清除)

## 许可证

本设计基于以下开源项目：
- verilog-ethernet (Copyright Alex Forencich)
- verilog-axi (Copyright Alex Forencich)

请参考各库的许可证文件。

## 版本历史

- **v1.0** (2025-10): 初始版本
  - RGMII 物理接口
  - ARP 协议支持
  - 帧过滤功能
  - DMA 传输支持
  - AXI-Lite 控制接口

