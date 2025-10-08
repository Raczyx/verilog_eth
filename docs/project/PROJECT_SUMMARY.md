# 以太网 MAC IP 项目总结

## 项目概述

本项目实现了一个完整的千兆以太网 MAC IP 核，基于开源的 verilog-ethernet 和 verilog-axi 库，提供了标准的 RGMII 物理接口、ARP 协议支持、帧过滤功能和 DMA 传输能力。

## 设计特性

### 核心功能
1. **RGMII 物理接口**
   - 支持 10/100/1000 Mbps 自适应
   - 自动速率检测
   - 符合 IEEE 802.3 标准
   - DDR 数据传输

2. **ARP 协议栈**
   - 自动 ARP 请求和响应
   - 可配置的 ARP 缓存（默认512项）
   - 超时和重试机制
   - 支持网关和子网配置

3. **帧过滤器**
   - 基于 MAC 地址的过滤
   - 广播帧控制
   - 组播帧控制
   - 混杂模式支持
   - 可配置多个 MAC 地址

4. **DMA 引擎**
   - 双通道独立 DMA（RX/TX）
   - AXI4 Master 接口
   - 支持突发传输（最大256）
   - 64位数据宽度
   - 描述符驱动

5. **控制接口**
   - AXI4-Lite Slave 接口
   - 完整的寄存器映射
   - 状态监控
   - 中断支持

## 文件结构

```
verilog/
├── eth_mac_rgmii_axi.v          # 顶层模块（主要 IP 核）
├── eth_frame_filter.v           # 帧过滤器模块
├── eth_mac_axil_regs.v          # AXI-Lite 控制寄存器
├── eth_mac_example.v            # 使用示例（Verilog）
├── eth_mac_driver.c             # 软件驱动示例（C）
├── ETH_MAC_RGMII_README.md      # 详细文档
├── PROJECT_SUMMARY.md           # 本文件
├── filelist.txt                 # 文件列表
│
├── verilog-ethernet/            # 以太网库（依赖）
│   └── rtl/
│       ├── eth_mac_1g_rgmii_fifo.v
│       ├── ip_complete.v
│       ├── arp.v
│       └── ... (其他库文件)
│
└── verilog-axi/                 # AXI 库（依赖）
    └── rtl/
        ├── axi_dma.v
        ├── axi_dma_rd.v
        ├── axi_dma_wr.v
        └── ... (其他库文件)
```

## 主要模块说明

### 1. eth_mac_rgmii_axi (顶层模块)

**功能**：整合所有功能模块的顶层设计

**关键特性**：
- 多时钟域设计（GTX 时钟、逻辑时钟）
- 异步 FIFO 用于时钟域跨越
- 完整的控制和数据路径
- 中断生成逻辑

**接口**：
- RGMII 物理接口（输入/输出）
- AXI Master（DMA 数据传输）
- AXI-Lite Slave（控制寄存器）
- 中断输出

### 2. eth_frame_filter

**功能**：对接收的以太网帧进行过滤

**特性**：
- 硬件实现的 MAC 地址匹配
- 状态机解析以太网头
- 低延迟（几个时钟周期）
- 可旁路（禁用过滤）

### 3. eth_mac_axil_regs

**功能**：提供软件可访问的控制寄存器

**特性**：
- 完整的 AXI-Lite Slave 接口实现
- 26 个可访问寄存器
- 中断状态管理
- DMA 描述符管理

## 资源占用估算

### FPGA 资源（Xilinx 7 Series）
- **逻辑单元（LUTs）**: ~8,000 - 12,000
- **触发器（FFs）**: ~10,000 - 15,000
- **BRAM**: ~10 - 20 块（36Kb）
- **DSP**: 0
- **IOB**: 10（RGMII 接口）
- **时钟资源**: 2 BUFG, 1 BUFR/BUFIO

### 性能
- **最大频率**：
  - GTX 时钟：125 MHz
  - 逻辑时钟：100+ MHz
- **吞吐量**：1 Gbps（全双工）
- **延迟**：< 1 μs（MAC + DMA）

## 使用流程

### 硬件集成步骤

1. **准备依赖库**
   ```bash
   # 克隆依赖库
   git clone https://github.com/alexforencich/verilog-ethernet
   git clone https://github.com/alexforencich/verilog-axi
   ```

2. **添加文件到项目**
   - 将所有必需的 .v 文件添加到 FPGA 项目
   - 使用 filelist.txt 作为参考

3. **实例化模块**
   - 参考 eth_mac_example.v
   - 根据实际系统调整参数

4. **时钟配置**
   - 生成 125 MHz 和 125 MHz 90度相移时钟（用于RGMII TX）
   - 配置系统时钟（逻辑时钟）

5. **添加约束**
   - RGMII 接口时序约束
   - 时钟域跨越约束
   - 引脚分配

### 软件开发步骤

1. **包含驱动文件**
   ```c
   #include "eth_mac_driver.c"
   ```

2. **初始化 MAC**
   ```c
   eth_mac_init_example();
   ```

3. **发送数据**
   ```c
   eth_mac_send_example();
   ```

4. **接收数据**
   ```c
   eth_mac_recv_example();
   ```

5. **中断处理**
   ```c
   // 注册中断处理函数
   register_irq_handler(ETH_IRQ_NUM, eth_mac_isr);
   ```

## 测试和验证

### 推荐的测试步骤

1. **环回测试**
   - 配置 PHY 为环回模式
   - 发送数据并验证接收

2. **ARP 测试**
   - 配置 IP 地址
   - 使用 ping 测试 ARP 功能

3. **性能测试**
   - 使用 iperf 进行吞吐量测试
   - 验证 1 Gbps 性能

4. **稳定性测试**
   - 长时间运行测试
   - 错误计数器监控

### 调试工具

- **Xilinx ILA**：监控内部信号
- **ChipScope**：实时波形查看
- **Wireshark**：网络数据包分析
- **寄存器读写**：通过 AXI-Lite 接口

## 已知限制

1. **平台支持**
   - 主要针对 Xilinx FPGA 优化
   - Intel/Altera 平台需要修改 DDR IO 模块

2. **协议支持**
   - 当前仅支持 IPv4
   - 不支持 IPv6
   - 不支持 VLAN 标签（可扩展）

3. **DMA 限制**
   - 单个描述符模式（非链式）
   - 需要软件轮询或中断驱动

## 扩展建议

### 可能的改进方向

1. **功能扩展**
   - 添加 VLAN 支持
   - 实现 IEEE 1588 PTP 时间戳
   - 添加流量统计计数器
   - 实现多队列 DMA

2. **性能优化**
   - 增加描述符队列深度
   - 实现链式 DMA 描述符
   - 添加数据缓存

3. **协议支持**
   - 添加 UDP/TCP 校验和卸载
   - 实现 IPv6 支持
   - 添加 IGMP 组播支持

## 许可和致谢

本设计基于以下优秀的开源项目：

- **verilog-ethernet** by Alex Forencich
  - https://github.com/alexforencich/verilog-ethernet
  
- **verilog-axi** by Alex Forencich
  - https://github.com/alexforencich/verilog-axi

感谢开源社区的贡献！

## 联系和支持

如有问题或建议，请参考：
- verilog-ethernet 文档
- verilog-axi 文档
- ETH_MAC_RGMII_README.md（详细使用说明）

## 版本信息

- **版本**: 1.0
- **日期**: 2025-10
- **状态**: 初始发布

---

**注意**：本设计仅供学习和参考使用。在生产环境使用前，请进行充分的测试和验证。

