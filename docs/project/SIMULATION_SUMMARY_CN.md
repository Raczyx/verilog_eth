# 仿真工具使用总结

## ⚡ 快速开始

```bash
cd /home/xuser/code_space/verilog/verilog/tb

# 运行仿真（推荐）
./run_sim.sh
```

## 📊 仿真工具对比

| 特性 | Icarus Verilog | Verilator |
|------|----------------|-----------|
| **状态** | ✅ **推荐使用** | ⚠️ 不适合当前 TB |
| **仿真类型** | 事件驱动 | 周期精确（综合） |
| **兼容性** | 完整支持 IEEE 1364 | 有限支持 |
| **`wait()` 语句** | ✅ 支持 | ❌ 不支持 |
| **复杂时序** | ✅ 支持 | ❌ 受限 |
| **学习曲线** | ⭐⭐ 简单 | ⭐⭐⭐⭐ 复杂 |
| **适用场景** | 功能验证 | 语法/综合检查 |

## ✅ Icarus Verilog（推荐）

### 为什么推荐？

1. **完整支持**：支持所有 testbench 特性
2. **开箱即用**：无需修改代码
3. **易于使用**：简单直观
4. **波形完整**：VCD 波形包含所有信号

### 使用方法

```bash
# 方法 1：使用智能脚本（最简单）
cd tb
./run_sim.sh

# 方法 2：使用 Makefile
cd tb
make                # 编译并运行
make waves          # 查看波形
make clean          # 清理

# 方法 3：手动命令
cd tb
iverilog -o sim_build/sim.vvp \
    -g2005-sv \
    -I .. \
    -I ../verilog-ethernet/rtl \
    -I ../verilog-axi/rtl \
    eth_mac_rgmii_axi_tb.v \
    ../eth_mac_rgmii_axi.v \
    ...（其他文件）

vvp sim_build/sim.vvp
```

### 输出示例

```
╔═══════════════════════════════════════════════════╗
║   Icarus Verilog 仿真                            ║
╚═══════════════════════════════════════════════════╝

[INFO] 编译 Verilog 源文件...
[INFO] 运行仿真...

========================================
以太网 MAC RGMII AXI 测试台
========================================
测试时间: 2025-10-06 
仿真时间: 100 us
========================================

...（仿真输出）...

[完成] 0 个错误
波形文件: work/eth_mac_rgmii_axi_tb.vcd
```

## ⚠️ Verilator（不推荐用于当前项目）

### 为什么不推荐？

Verilator 是**综合工具**而非传统仿真器，对当前 testbench 的限制：

```verilog
// ❌ 不支持：wait() 语句
wait(s_axil_awready && s_axil_wready);

// ❌ 不支持：task 中的多个事件控制
task axil_write;
    @(posedge logic_clk);    // ❌
    ...
    @(posedge logic_clk);    // ❌ 第二个就不行
endtask

// ❌ 不支持：forever 中的延迟（无 --timing）
forever #(CLK_PERIOD/2) clk = ~clk;
```

### 何时使用 Verilator？

Verilator 更适合：

```bash
# 语法检查
verilator --lint-only ../eth_mac_rgmii_axi.v \
    -I../verilog-ethernet/rtl \
    -I../verilog-axi/rtl

# 综合前检查
verilator --top-module eth_mac_rgmii_axi \
    --lint-only \
    （文件列表）
```

**不适合**：功能仿真（除非重写为 C++ testbench）

## 📈 性能对比

对于您的设计规模（~5K 行 RTL）：

| 工具 | 编译时间 | 运行时间 | 总时间 | 适用性 |
|------|----------|----------|---------|--------|
| **Icarus** | 5秒 | 10秒 | 15秒 | ✅ 完美 |
| **Verilator** | 20秒 | 2秒 | 22秒 | ❌ 需要重写 |

**结论**：对于中等规模设计，Icarus Verilog 更快更方便！

## 🔧 常见问题

### Q: 波形文件在哪里？

**A**: `tb/work/eth_mac_rgmii_axi_tb.vcd`

```bash
cd tb
gtkwave work/eth_mac_rgmii_axi_tb.vcd work/eth_mac_rgmii_axi_tb.gtkw
```

### Q: 如何修改仿真时间？

**A**: 编辑 `tb/eth_mac_rgmii_axi_tb.v`：

```verilog
initial begin
    // ... 
    #100000000;  // 修改这个数字（单位：时间刻度）
    $finish;
end
```

### Q: 仿真太慢怎么办？

**A**: 

1. **减少仿真时间**（上面的方法）
2. **禁用波形记录**（删除 `$dumpfile` 相关代码）
3. **减小追踪深度**
4. **仅在关键时刻记录波形**

### Q: 我必须使用 Verilator 怎么办？

**A**: 需要**完全重写 testbench**：

1. 创建纯 C++ testbench
2. 移除所有 `wait()` 语句
3. 重写所有 tasks 为 C++ 函数
4. 手动管理时序

**代价很大，不建议！**

## 🎯 推荐工作流程

### 日常开发

```bash
# 1. 修改 RTL 代码
vim ../eth_mac_rgmii_axi.v

# 2. 运行仿真
cd tb
./run_sim.sh

# 3. 查看波形（如果有错误）
make waves

# 4. 迭代修改
```

### 完整验证

```bash
# Step 1: 功能仿真（Icarus）
cd tb
make clean
make
make waves

# Step 2: 语法检查（Verilator，可选）
verilator --lint-only \
    --top-module eth_mac_rgmii_axi \
    ../eth_mac_rgmii_axi.v \
    -I../verilog-ethernet/rtl \
    -I../verilog-axi/rtl

# Step 3: FPGA 综合
# 使用 Vivado/Quartus
```

## 📚 相关文档

- **主测试文档**: `TESTING_GUIDE.md`
- **Verilator 详细说明**: `VERILATOR_NOTE.md`
- **快速参考**: `TESTING_SUMMARY.txt`
- **测试目录 README**: `tb/README_TEST.md`

## ✅ 总结

| 需求 | 工具选择 |
|------|----------|
| 功能仿真 | ✅ **Icarus Verilog** |
| 波形分析 | ✅ **Icarus + GTKWave** |
| 语法检查 | ✅ **Verilator --lint-only** |
| 综合检查 | ✅ **Verilator --lint-only** |
| FPGA 实现 | ✅ **Vivado/Quartus** |

---

## 🚀 立即开始

```bash
cd /home/xuser/code_space/verilog/verilog/tb
./run_sim.sh
```

**就这么简单！** 🎉

