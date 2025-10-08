# 以太网 MAC RGMII AXI 测试文档

## 概述

本目录包含以太网 MAC IP 核的完整测试环境，支持多种仿真器和测试方法。

## 目录结构

```
tb/
├── eth_mac_rgmii_axi_tb.v    # 主测试平台
├── Makefile                   # 仿真脚本
├── README_TEST.md             # 本文件
└── work/                      # 仿真输出目录（自动生成）
```

## 快速开始

### 方法1：使用 Icarus Verilog（推荐）

```bash
# 进入测试目录
cd tb

# 运行仿真
make

# 查看波形
make waves

# 清理
make clean
```

### 方法2：使用 Verilator

```bash
# 进入测试目录
cd tb

# 运行仿真
make SIM=verilator

# 查看波形
make waves

# 清理
make clean
```

## 测试场景

当前测试平台包含以下测试场景：

### 测试1：寄存器读写测试
- **目的**：验证 AXI-Lite 控制接口
- **内容**：
  - MAC 地址寄存器读写
  - 控制寄存器读写
  - 状态寄存器读取

### 测试2：MAC 配置测试
- **目的**：验证 MAC/IP 配置
- **内容**：
  - 配置本地 MAC 地址
  - 配置本地 IP 地址
  - 配置网关和子网掩码

### 测试3：RGMII 接收测试
- **目的**：验证 RGMII 接口数据接收
- **内容**：
  - 发送标准以太网帧
  - 验证帧接收
  - 检查 FIFO 状态

## 测试输出

### 控制台输出

仿真运行时会在控制台显示详细的测试进度和结果：

```
========================================
以太网 MAC RGMII AXI 测试开始
========================================

[TEST 1] 寄存器读写测试
[   100] AXI-Lite Write: Addr=0x0008, Data=0x12345678
[   150] AXI-Lite Read: Addr=0x0008, Data=0x12345678
PASS: MAC地址低32位正确
PASS: 控制寄存器正确

[TEST 2] MAC 配置测试
PASS: MAC 配置完成

[TEST 3] RGMII 接收测试
[  1000] RGMII Frame Sent: Length=64
PASS: RGMII 接收测试完成

========================================
测试完成
总测试数: 3
错误数: 0
状态: 通过 ✓
========================================
```

### 波形文件

仿真会生成 VCD 波形文件：
- **位置**: `work/eth_mac_rgmii_axi_tb.vcd`
- **查看**: `make waves` 或手动运行 `gtkwave work/eth_mac_rgmii_axi_tb.vcd`

## 关键信号说明

### 时钟和复位
- `gtx_clk`: GTX 时钟 (125 MHz)
- `gtx_clk90`: GTX 90度相移时钟
- `logic_clk`: 逻辑时钟 (100 MHz)
- `gtx_rst`, `logic_rst`: 复位信号

### RGMII 接口
- `rgmii_tx_clk/rxd/tx_ctl`: RGMII TX 接口
- `rgmii_rx_clk/rxd/rx_ctl`: RGMII RX 接口

### AXI Master (DMA)
- `m_axi_aw*`: 写地址通道
- `m_axi_w*`: 写数据通道
- `m_axi_b*`: 写响应通道
- `m_axi_ar*`: 读地址通道
- `m_axi_r*`: 读数据通道

### AXI-Lite Slave (控制)
- `s_axil_aw*`: 写地址通道
- `s_axil_w*`: 写数据通道
- `s_axil_b*`: 写响应通道
- `s_axil_ar*`: 读地址通道
- `s_axil_r*`: 读数据通道

## 添加新测试

要添加新的测试场景，在 `eth_mac_rgmii_axi_tb.v` 中：

1. 增加测试任务：
```verilog
task test_new_feature;
    begin
        // 测试代码
        $display("PASS: 新功能测试完成");
    end
endtask
```

2. 在主测试序列中调用：
```verilog
// 测试4：新功能
test_number = 4;
$display("\n[TEST %0d] 新功能测试", test_number);
test_new_feature();
```

## 常见问题

### Q1: 仿真编译失败

**A**: 检查以下事项：
1. 确认所有依赖库文件存在（verilog-ethernet, verilog-axi）
2. 检查文件路径是否正确
3. 查看 Makefile 中的路径设置

### Q2: 波形文件无法打开

**A**: 
```bash
# 确认 VCD 文件存在
ls -l work/*.vcd

# 手动打开
gtkwave work/eth_mac_rgmii_axi_tb.vcd
```

### Q3: 仿真运行很慢

**A**: 
- 减小 FIFO 深度（在 testbench 实例化参数中）
- 减小 ARP 缓存大小
- 缩短超时时间
- 使用 Verilator（比 Icarus Verilog 快）

### Q4: DMA 测试失败

**A**: 
- 检查内存模型初始化
- 确认 AXI 接口握手正确
- 查看 DMA 描述符配置

## 仿真性能

### Icarus Verilog
- **编译时间**: ~5-10秒
- **运行时间**: ~10-30秒（取决于测试数量）
- **优点**: 易于安装和使用
- **缺点**: 仿真速度较慢

### Verilator
- **编译时间**: ~10-20秒
- **运行时间**: ~2-5秒
- **优点**: 仿真速度快
- **缺点**: 设置稍复杂

## 高级仿真选项

### 使用 Questa Sim / ModelSim

```bash
# 编译
vlog -sv +define+SIMULATION eth_mac_rgmii_axi_tb.v ../eth_mac_rgmii_axi.v ...

# 仿真
vsim -c work.eth_mac_rgmii_axi_tb -do "run -all; quit"
```

### 使用 VCS

```bash
# 编译
vcs -sverilog +v2k -debug_all eth_mac_rgmii_axi_tb.v ../eth_mac_rgmii_axi.v ...

# 仿真
./simv
```

## 持续集成 (CI)

可以将测试集成到 CI/CD 流程：

```yaml
# .gitlab-ci.yml 或 .github/workflows/test.yml
test:
  script:
    - cd tb
    - make SIM=iverilog
    - grep "状态: 通过" work/simulation.log
```

## 调试技巧

### 1. 增加详细输出

在 testbench 中添加：
```verilog
initial begin
    $monitor("[%0t] awvalid=%b awready=%b", $time, m_axi_awvalid, m_axi_awready);
end
```

### 2. 断点调试

使用 `$stop` 暂停仿真：
```verilog
if (error_detected) begin
    $display("ERROR detected!");
    $stop;
end
```

### 3. 保存关键数据

```verilog
integer dump_file;
initial begin
    dump_file = $fopen("debug_data.txt", "w");
end

always @(posedge clk) begin
    if (interesting_condition)
        $fwrite(dump_file, "[%0t] data=%h\n", $time, important_signal);
end
```

## 未来改进

计划添加的测试：

- [ ] DMA 完整传输测试
- [ ] ARP 请求/响应测试
- [ ] 帧过滤功能测试
- [ ] 中断功能测试
- [ ] 错误注入测试
- [ ] 性能压力测试
- [ ] 多帧连续传输测试
- [ ] 随机化测试（使用 UVM）

## 参考资料

- [Icarus Verilog 文档](http://iverilog.icarus.com/)
- [Verilator 文档](https://verilator.org/guide/latest/)
- [GTKWave 用户手册](http://gtkwave.sourceforge.net/)
- [verilog-ethernet README](../verilog-ethernet/README.md)
- [verilog-axi README](../verilog-axi/README.md)

## 联系方式

如有问题或建议，请查阅主项目文档或提交 Issue。

