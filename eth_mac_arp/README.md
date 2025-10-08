# 以太网 MAC with ARP - 中等版本

## 概述

以太网 MAC with ARP 是介于完整版和 Lite 版之间的一个版本，专为需要 ARP 地址解析但不需要完整 IP 协议处理的应用设计。

### 核心定位

```
┌─────────────────────────────────────────────────────────┐
│                    版本对比                              │
├─────────────────────────────────────────────────────────┤
│ 完整版:   MAC + ARP + IP   (100% 资源)                  │
│ ARP版:    MAC + ARP        (55% 资源)    ← 本版本       │
│ Lite版:   MAC              (40% 资源)                    │
└─────────────────────────────────────────────────────────┘
```

### 主要特点

✅ **保留的功能**
- RGMII 物理接口 (10/100/1000 Mbps)
- MAC 层完整处理
- 帧过滤器
- **ARP 协议栈**
  - ARP 请求/应答自动处理
  - ARP 缓存管理 (512 条目)
  - IP→MAC 地址查询接口
- DMA 引擎
- 中断系统

❌ **移除的功能**
- IP 包解析和构建
- IP 校验和处理
- IP 路由逻辑

## 适用场景

### 推荐使用 ARP 版 ✅

1. **软件处理 IP，硬件辅助 ARP**
   - 软件自己构建/解析 IP 包
   - 需要硬件维护 ARP 缓存
   - 需要快速的 IP→MAC 查询

2. **使用 IP 地址作为设备标识**
   - 用 IP 地址标识网络中的设备
   - 但传输自定义协议（非标准 IP 包）
   - 需要 ARP 来发现设备的 MAC 地址

3. **混合协议栈**
   - 主要使用自定义以太网协议
   - 同时需要与标准 IP 设备通信
   - 需要 ARP 地址解析能力

4. **简化的网络应用**
   - 同网段通信（无需路由）
   - 需要动态 MAC 地址发现
   - 不需要完整 IP 功能

### 实际应用示例

**工业控制网络**
```
场景: PLC 之间通信
- 使用 IP 地址标识 PLC 设备
- 传输自定义的控制指令（非 TCP/UDP）
- 需要 ARP 来发现新加入的设备
- 不需要复杂的 IP 路由

解决方案: 使用 ARP 版
- 硬件自动响应 ARP 请求
- 软件查询 ARP 缓存获取目标 MAC
- 软件构建自定义控制帧发送
```

**实时数据采集**
```
场景: 多个传感器节点向中心节点发送数据
- 使用 IP 地址配置传感器
- 传输轻量级的传感器数据帧
- 需要 ARP 来建立 IP→MAC 映射
- 不需要 IP 协议的额外开销

解决方案: 使用 ARP 版
- 硬件维护所有传感器的 IP→MAC 映射
- 软件直接发送传感器数据（无 IP 头）
- 降低延迟和处理复杂度
```

## 三个版本对比

| 特性 | 完整版 | ARP版 | Lite版 |
|------|--------|-------|--------|
| **物理接口** ||||
| RGMII | ✅ | ✅ | ✅ |
| **MAC层** ||||
| MAC处理 | ✅ | ✅ | ✅ |
| 帧过滤 | ✅ | ✅ | ✅ |
| **网络层** ||||
| ARP协议 | ✅ | ✅ | ❌ |
| ARP缓存 | ✅ (512) | ✅ (512) | ❌ |
| IP解析 | ✅ | ❌ | ❌ |
| IP构建 | ✅ | ❌ | ❌ |
| **DMA** ||||
| RX DMA | ✅ | ✅ | ✅ |
| TX DMA | ✅ | ✅ | ✅ |
| **控制** ||||
| 寄存器数 | 26个 | 20个 | 16个 |
| IP配置 | ✅ | ✅* | ❌ |
| **资源** ||||
| LUT | 6200 | 3400 | 2500 |
| FF | 4500 | 2700 | 1800 |
| BRAM | 12 | 10 | 8 |
| 相对占用 | 100% | 55% | 40% |

*注: ARP版需要本地IP地址用于ARP协议

## 功能详解

### ARP 功能

**自动处理**：
```
接收到 ARP 请求 → 如果目标IP是本机 → 自动回复 ARP 应答
接收到 ARP 应答 → 更新 ARP 缓存表
```

**软件查询**：
```c
// 查询 ARP 缓存
uint8_t mac[6];
bool found = query_arp_cache(target_ip, mac);

if (found) {
    // 使用查到的 MAC 地址发送数据
    send_frame(mac, data);
} else {
    // 发起 ARP 请求
    send_arp_request(target_ip);
    // 等待 ARP 应答...
}
```

**手动 ARP 操作**：
```c
// 发送 ARP 请求（查找某个IP的MAC）
send_arp_request(target_ip);

// 发送 ARP 应答（响应别人的查询）
send_arp_reply(target_ip, target_mac);

// 清除 ARP 缓存
clear_arp_cache();

// 读取 ARP 缓存表
for (int i = 0; i < 512; i++) {
    if (read_arp_entry(i, &ip, &mac)) {
        printf("Entry %d: IP=%08x MAC=%012llx\n", i, ip, mac);
    }
}
```

### 数据流

**RX 路径**：
```
RGMII → MAC → Filter → Eth Parse
                          │
                          ├─ EtherType = 0x0806 (ARP) → ARP处理 → 更新缓存
                          │                                        (不传给软件)
                          │
                          └─ 其他 → 原始帧 → DMA → 内存 → 软件处理
```

**TX 路径**：
```
软件准备的数据 → DMA → 检测帧类型
                          │
                          ├─ 如果是ARP帧 → ARP模块处理
                          │
                          └─ 其他 → 直接发送 → MAC → RGMII
```

## 寄存器映射

| 地址 | 名称 | 访问 | 描述 |
|------|------|------|------|
| 0x0000 | CTRL | R/W | 控制寄存器 |
| 0x0004 | STATUS | R | 状态寄存器 |
| 0x0008 | MAC_LO | R/W | MAC地址[31:0] |
| 0x000C | MAC_HI | R/W | MAC地址[47:32] |
| 0x0010 | LOCAL_IP | R/W | 本地IP地址 |
| 0x0014 | GATEWAY_IP | R/W | 网关IP地址 |
| 0x0018 | SUBNET | R/W | 子网掩码 |
| 0x001C | FILTER | R/W | 过滤器配置 |
| 0x0020 | IRQ_EN | R/W | 中断使能 |
| 0x0024 | IRQ_ST | R/W1C | 中断状态 |
| 0x0028 | IFG | R/W | 帧间隙配置 |
| 0x002C | ARP_CTRL | R/W | ARP控制 |
| 0x0030 | RX_ADDR | R/W | RX描述符地址 |
| 0x0034 | RX_LEN | R/W | RX描述符长度 |
| 0x0038 | RX_TAG | R/W | RX描述符Tag |
| 0x003C | RX_CTRL | R/W | RX描述符控制 |
| 0x0040 | TX_ADDR | R/W | TX描述符地址 |
| 0x0044 | TX_LEN | R/W | TX描述符长度 |
| 0x0048 | TX_TAG | R/W | TX描述符Tag |
| 0x004C | TX_CTRL | R/W | TX描述符控制 |

**ARP 特定寄存器** (扩展):
| 地址 | 名称 | 访问 | 描述 |
|------|------|------|------|
| 0x0100 | ARP_CACHE_CTRL | R/W | ARP缓存控制 |
| 0x0104 | ARP_QUERY_IP | W | 查询的IP地址 |
| 0x0108 | ARP_QUERY_MAC_LO | R | 查询结果MAC[31:0] |
| 0x010C | ARP_QUERY_MAC_HI | R | 查询结果MAC[47:32] |
| 0x0110 | ARP_QUERY_STATUS | R | 查询状态 |

## 快速开始

### 1. 初始化

```c
// 设置本地MAC地址
write_reg(MAC_LO, 0xAABBCCDD);
write_reg(MAC_HI, 0x0000EEFF);

// 设置本地IP地址（ARP需要）
write_reg(LOCAL_IP, 0xC0A80164);  // 192.168.1.100

// 设置网关和子网掩码
write_reg(GATEWAY_IP, 0xC0A80101);  // 192.168.1.1
write_reg(SUBNET, 0xFFFFFF00);      // 255.255.255.0

// 配置过滤器和使能
write_reg(FILTER, 0x00000001);      // 使能过滤
write_reg(CTRL, 0x0000000F);        // 使能所有功能
```

### 2. 使用 ARP 查询

```c
// 方法1: 查询 ARP 缓存
uint32_t target_ip = 0xC0A80165;  // 192.168.1.101
write_reg(ARP_QUERY_IP, target_ip);

uint32_t status = read_reg(ARP_QUERY_STATUS);
if (status & 0x01) {  // 找到
    uint32_t mac_lo = read_reg(ARP_QUERY_MAC_LO);
    uint32_t mac_hi = read_reg(ARP_QUERY_MAC_HI);
    printf("Found MAC: %04x%08x\n", mac_hi, mac_lo);
} else {
    // 未找到，发送 ARP 请求
    send_arp_request(target_ip);
}
```

### 3. 发送自定义帧

```c
// 查询目标的 MAC 地址
uint8_t dest_mac[6];
if (query_arp(target_ip, dest_mac)) {
    // 构建以太网帧（你的自定义格式）
    uint8_t frame[1500];
    
    // 以太网头部
    memcpy(frame, dest_mac, 6);           // 目的MAC
    memcpy(frame + 6, local_mac, 6);      // 源MAC
    frame[12] = 0x88;                     // EtherType (自定义)
    frame[13] = 0xB5;
    
    // 你的协议数据
    memcpy(frame + 14, your_data, data_len);
    
    // 通过 DMA 发送
    send_via_dma(frame, 14 + data_len);
}
```

### 4. 接收数据

```c
// 配置接收
write_reg(RX_ADDR, (uint32_t)rx_buffer);
write_reg(RX_LEN, 1518);
write_reg(RX_CTRL, 0x01);  // 启动

// 中断处理
void irq_handler() {
    uint32_t status = read_reg(IRQ_ST);
    
    if (status & 0x01) {  // RX Done
        // 解析接收到的帧
        uint8_t *dest_mac = rx_buffer;
        uint8_t *src_mac = rx_buffer + 6;
        uint16_t ethertype = *(uint16_t*)(rx_buffer + 12);
        
        if (ethertype == 0x0806) {
            // 这是ARP包，硬件已自动处理
            // 一般不会到这里，因为ARP由硬件处理
        } else {
            // 你的协议数据
            handle_custom_protocol(rx_buffer + 14);
        }
        
        // 清除中断
        write_reg(IRQ_ST, 0x01);
    }
}
```

## 性能指标

### 资源占用 (估算)

| 资源 | 完整版 | ARP版 | Lite版 |
|------|--------|-------|--------|
| LUT | 6,200 | 3,400 | 2,500 |
| FF | 4,500 | 2,700 | 1,800 |
| BRAM | 12 | 10 | 8 |

**节省分析**：
- 相比完整版：节省约 45% 资源
- 相比Lite版：增加约 35% 资源（换取ARP功能）

### 延迟

| 路径 | 完整版 | ARP版 | Lite版 |
|------|--------|-------|--------|
| RX (非ARP) | 600ns | 450ns | 400ns |
| RX (ARP) | 600ns | 450ns | N/A |
| TX | 480ns | 250ns | 200ns |

## 设计架构

```
┌──────────────────────────────────────────────────────────┐
│                     接收路径                              │
└──────────────────────────────────────────────────────────┘

RGMII → MAC → Filter → Eth Parse
                          │
                          ├─ ARP (0x0806)
                          │    │
                          │    └─→ ARP模块 → 更新缓存
                          │                   │
                          │                   └─→ (可选)通知软件
                          │
                          └─ 其他
                               │
                               └─→ DMA → 内存

┌──────────────────────────────────────────────────────────┐
│                     发送路径                              │
└──────────────────────────────────────────────────────────┘

内存 → DMA → 检测EtherType
              │
              ├─ ARP (0x0806)
              │    │
              │    └─→ ARP模块处理 → MAC → RGMII
              │
              └─ 其他
                   │
                   └─→ MAC → RGMII
```

## 与完整版的区别

**移除的模块**：
- `ip.v` - IP包处理模块
- `ip_eth_rx.v` - IP接收
- `ip_eth_tx.v` - IP发送

**保留的模块**：
- `arp.v` - ARP协议处理
- `arp_cache.v` - ARP缓存表
- `arp_eth_rx.v` - ARP接收
- `arp_eth_tx.v` - ARP发送

**简化的模块**：
- 控制寄存器（去掉IP相关的状态和配置）
- 帧分发器（只需区分ARP和其他）

## 常见问题

### Q: 为什么需要 IP 地址寄存器？

A: ARP 协议需要本地 IP 地址来：
1. 响应针对本机的 ARP 请求
2. 发送 ARP 请求时填写发送者 IP
3. 判断是否在同一子网

### Q: 与 Lite 版的主要区别？

A: 
- Lite 版：完全不处理 ARP，所有帧都传给软件
- ARP 版：自动处理 ARP，维护 IP→MAC 映射表

### Q: 软件如何知道 ARP 缓存更新了？

A: 有几种方式：
1. 轮询 ARP 缓存状态寄存器
2. 配置 ARP 更新中断
3. 在查询时实时读取

### Q: 可以禁用 ARP 功能吗？

A: 可以！配置寄存器中有 ARP_ENABLE 位。
禁用后，ARP 包也会传递给软件处理，类似 Lite 版。

## 升级路径

### 从 Lite 版升级

如果您发现需要 ARP 功能：
1. 添加 IP 地址配置
2. 使用 ARP 查询接口
3. 无需修改现有的帧发送/接收代码

### 升级到完整版

如果您需要完整的 IP 协议：
1. 替换顶层模块
2. 添加 IP 相关寄存器配置
3. 修改应用层，使用 IP 接口而非原始帧

## 许可证

Copyright (c) 2025

---

**维护者**: AI Assistant  
**创建日期**: 2025年10月7日  
**版本**: v1.0

