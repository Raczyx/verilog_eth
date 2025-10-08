# 以太网 MAC RGMII AXI 测试指南

## 📋 测试文件概览

已为以太网 MAC IP 创建完整的测试环境：

### 核心测试文件

| 文件 | 说明 | 行数 |
|------|------|------|
| `tb/eth_mac_rgmii_axi_tb.v` | 主测试平台（Verilog） | ~700 |
| `tb/Makefile` | 仿真构建脚本 | ~200 |
| `tb/run_sim.sh` | 智能运行脚本 | ~300 |
| `tb/README_TEST.md` | 详细测试文档 | - |
| `tb/work/eth_mac_rgmii_axi_tb.gtkw` | GTKWave 配置文件 | - |

## 🚀 快速开始

### 方法1：使用自动化脚本（推荐）

```bash
# 进入项目目录
cd /home/xuser/code_space/verilog/verilog

# 运行仿真（最简单）
./tb/run_sim.sh

# 运行并查看波形
./tb/run_sim.sh -w

# 使用 Verilator（更快）
./tb/run_sim.sh -s verilator -w

# 清理后运行
./tb/run_sim.sh -c -w
```

### 方法2：使用 Makefile

```bash
cd tb

# 运行仿真
make

# 查看波形
make waves

# 清理
make clean

# 使用 Verilator
make SIM=verilator
```

## 📊 测试场景

当前实现的测试：

### ✅ 测试1：寄存器读写
- **目的**：验证 AXI-Lite 接口
- **覆盖**：MAC地址寄存器、控制寄存器、状态寄存器
- **状态**：✓ 已实现

### ✅ 测试2：MAC 配置
- **目的**：验证网络参数配置
- **覆盖**：MAC地址、IP地址、网关、子网掩码
- **状态**：✓ 已实现

### ✅ 测试3：RGMII 接收
- **目的**：验证 RGMII 物理接口
- **覆盖**：帧接收、前导码、SFD、FCS
- **状态**：✓ 已实现

## 🎯 测试输出示例

### 成功运行输出

```
╔═══════════════════════════════════════════════════╗
║   以太网 MAC RGMII AXI 仿真                      ║
╚═══════════════════════════════════════════════════╝

[INFO] 检查依赖...
[SUCCESS] 依赖检查通过
[INFO] 开始仿真（使用 iverilog）...

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

[SUCCESS] 仿真完成
[SUCCESS] ✓ 所有测试通过！

[INFO] === 仿真统计 ===
  波形文件大小: 2.5M
  测试数量: 3
  错误数量: 0
  警告数量: 0

[SUCCESS] 完成！
```

## 📈 波形查看

### 自动打开波形

```bash
./tb/run_sim.sh -w
```

### 手动打开波形

```bash
gtkwave tb/work/eth_mac_rgmii_axi_tb.vcd tb/work/eth_mac_rgmii_axi_tb.gtkw
```

### 关键信号组

波形文件已配置以下信号组：

1. **时钟和复位**
   - `gtx_clk`, `gtx_clk90`, `logic_clk`
   - `gtx_rst`, `logic_rst`

2. **测试控制**
   - `test_number` - 当前测试编号
   - `error_count` - 错误计数

3. **RGMII 接口**
   - TX: `rgmii_tx_clk`, `rgmii_txd`, `rgmii_tx_ctl`
   - RX: `rgmii_rx_clk`, `rgmii_rxd`, `rgmii_rx_ctl`

4. **AXI-Lite 控制**
   - 写通道：`awaddr`, `wdata`, `wvalid`, `wready`
   - 读通道：`araddr`, `rdata`, `rvalid`, `rready`

5. **AXI Master (DMA)**
   - 写通道：`awaddr`, `wdata`, `wvalid`, `wready`
   - 读通道：`araddr`, `rdata`, `rvalid`, `rready`

6. **中断**
   - `irq` - 中断信号

## 🔧 添加新测试

### 步骤1：在 testbench 中添加测试任务

编辑 `tb/eth_mac_rgmii_axi_tb.v`：

```verilog
// 在文件末尾添加新测试任务
task test_dma_transfer;
    reg [AXIL_DATA_WIDTH-1:0] read_data;
    integer i;
    begin
        $display("开始 DMA 传输测试...");
        
        // 1. 配置 TX DMA 描述符
        axil_write(16'h0040, 32'h00001000);  // 源地址
        axil_write(16'h0044, 32'h00000040);  // 长度 64 字节
        axil_write(16'h0048, 32'h00000001);  // 标签
        axil_write(16'h004C, 32'h00000001);  // 启动传输
        
        // 2. 等待传输完成
        for (i = 0; i < 1000; i = i + 1) begin
            axil_read(16'h004C, read_data);
            if (read_data[0] == 0) break;
            #100;
        end
        
        if (i >= 1000) begin
            $display("ERROR: DMA 传输超时");
            error_count = error_count + 1;
        end else begin
            $display("PASS: DMA 传输成功");
        end
    end
endtask
```

### 步骤2：在主测试序列中调用

```verilog
// 在 initial begin 块中添加
test_number = 4;
$display("\n[TEST %0d] DMA 传输测试", test_number);
test_dma_transfer();
```

## 🐛 调试技巧

### 1. 增加详细日志

在 testbench 中添加：

```verilog
initial begin
    $monitor("[%0t] state=%d awvalid=%b awready=%b", 
             $time, current_state, m_axi_awvalid, m_axi_awready);
end
```

### 2. 使用断点

```verilog
if (critical_condition) begin
    $display("DEBUG: 到达关键点");
    $stop;  // 暂停仿真
end
```

### 3. 保存数据到文件

```verilog
integer debug_file;
initial begin
    debug_file = $fopen("debug_output.txt", "w");
end

always @(posedge clk) begin
    if (interesting_event)
        $fwrite(debug_file, "[%0t] data=%h\n", $time, signal);
end
```

### 4. 使用 `$display` vs `$monitor`

- `$display`: 执行时打印一次
- `$monitor`: 信号变化时自动打印

```verilog
// 一次性打印
$display("当前值: %h", value);

// 自动监控
$monitor("值改变: %h", value);
```

## ⚙️ 仿真器对比

| 特性 | Icarus Verilog | Verilator | ModelSim |
|------|----------------|-----------|----------|
| **速度** | 中 | 快 | 快 |
| **易用性** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **免费** | ✓ | ✓ | ✗ |
| **波形** | VCD | VCD/FST | WLF |
| **SystemVerilog** | 部分 | 完整 | 完整 |
| **推荐场景** | 快速测试 | 大规模仿真 | 专业开发 |

### 选择建议

- **初学者**：使用 Icarus Verilog（简单、开源）
- **追求速度**：使用 Verilator
- **专业开发**：使用 ModelSim/Questa

## 📝 测试检查清单

在提交代码前，确保通过以下测试：

- [ ] 所有寄存器读写正常
- [ ] MAC/IP 配置正确
- [ ] RGMII 接口工作
- [ ] DMA 传输功能正常
- [ ] ARP 请求/响应正常
- [ ] 帧过滤功能正常
- [ ] 中断产生和清除正常
- [ ] 无时序违规
- [ ] 无 linter 警告

## 🔄 持续集成

### 集成到 CI/CD

#### GitHub Actions 示例

```yaml
name: FPGA Simulation Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Install Icarus Verilog
        run: sudo apt-get install -y iverilog
      
      - name: Run Tests
        run: |
          cd tb
          make SIM=iverilog
      
      - name: Check Results
        run: |
          if grep -q "状态: 通过" tb/sim.log; then
            echo "Tests PASSED"
          else
            echo "Tests FAILED"
            exit 1
          fi
      
      - name: Upload Waveforms
        if: always()
        uses: actions/upload-artifact@v2
        with:
          name: waveforms
          path: tb/work/*.vcd
```

#### GitLab CI 示例

```yaml
test:
  image: ubuntu:latest
  before_script:
    - apt-get update && apt-get install -y iverilog make
  script:
    - cd tb
    - make SIM=iverilog
    - grep "状态: 通过" sim.log
  artifacts:
    paths:
      - tb/work/*.vcd
    when: always
```

## 📚 参考资料

### 官方文档
- [Icarus Verilog 文档](http://iverilog.icarus.com/documentation.html)
- [Verilator 手册](https://verilator.org/guide/latest/)
- [GTKWave 文档](http://gtkwave.sourceforge.net/)

### 项目文档
- [主 README](./ETH_MAC_RGMII_README.md) - 完整 IP 文档
- [项目总结](./PROJECT_SUMMARY.md) - 架构和设计
- [快速开始](./QUICK_START.md) - 快速集成指南

### 测试相关
- [测试平台 README](./tb/README_TEST.md) - 详细测试文档
- [驱动示例](./eth_mac_driver.c) - 软件驱动

## 🆘 常见问题

### Q: 编译错误 "Cannot find module"

**A**: 检查路径设置，确保依赖库存在：
```bash
ls -la verilog-ethernet/rtl/
ls -la verilog-axi/rtl/
```

### Q: 仿真运行很慢

**A**: 
1. 使用 Verilator：`make SIM=verilator`
2. 减小 FIFO 深度（在 testbench 参数中）
3. 缩短 ARP 超时时间

### Q: 波形文件太大

**A**: 
1. 减少仿真时间
2. 使用 FST 格式（Verilator）：更小的文件
3. 只记录关键信号

### Q: 测试失败但找不到原因

**A**: 
1. 查看 `sim.log` 详细日志
2. 打开波形文件分析时序
3. 增加 `$display` 输出
4. 使用 `$stop` 断点调试

## 🎯 未来计划

计划添加的测试和功能：

### 短期（1-2周）
- [ ] 完整 DMA 传输测试
- [ ] ARP 请求/响应测试
- [ ] 帧过滤全面测试
- [ ] 错误注入测试

### 中期（1-2月）
- [ ] 性能压力测试
- [ ] 随机化测试
- [ ] Coverage 覆盖率报告
- [ ] Python cocotb 测试

### 长期（3-6月）
- [ ] UVM 验证环境
- [ ] 形式化验证
- [ ] 自动回归测试
- [ ] FPGA 硬件测试

## 📞 支持

如遇到问题：

1. 查阅本文档和相关文档
2. 检查 GitHub Issues
3. 查看示例代码
4. 联系项目维护者

---

**祝测试顺利！** 🎉

最后更新：2025-10-06

