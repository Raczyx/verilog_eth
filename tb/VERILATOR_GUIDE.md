# Verilator 仿真指南

## 概述

Verilator 是一个高性能的 Verilog/SystemVerilog 仿真器，比 Icarus Verilog 快 10-100 倍。

## 新增文件

为 Verilator 仿真添加了以下文件：

1. **`eth_mac_rgmii_axi_tb.cpp`** - C++ testbench 封装
2. **`Makefile.verilator`** - Verilator 专用 Makefile
3. **`run_verilator.sh`** - 一键运行脚本

## 快速开始

### 方法1：使用快速脚本（最简单）

```bash
cd tb
./run_verilator.sh
```

### 方法2：使用 Makefile

```bash
cd tb

# 构建并运行
make -f Makefile.verilator

# 只构建
make -f Makefile.verilator build

# 只运行
make -f Makefile.verilator run

# 查看波形
make -f Makefile.verilator waves

# 清理
make -f Makefile.verilator clean
```

### 方法3：通用 Makefile

原有的 Makefile 也支持 Verilator：

```bash
cd tb
make SIM=verilator
```

## 安装 Verilator

### Ubuntu/Debian

```bash
sudo apt-get install verilator
```

### Fedora/CentOS

```bash
sudo dnf install verilator
```

### 从源码编译（最新版本）

```bash
git clone https://github.com/verilator/verilator
cd verilator
autoconf
./configure
make
sudo make install
```

## Verilator vs Icarus Verilog

| 特性 | Verilator | Icarus Verilog |
|------|-----------|----------------|
| **速度** | ⭐⭐⭐⭐⭐ 非常快 | ⭐⭐ 较慢 |
| **编译时间** | 较长 | 较短 |
| **内存使用** | 较多 | 较少 |
| **易用性** | ⭐⭐⭐ 中等 | ⭐⭐⭐⭐⭐ 简单 |
| **SystemVerilog** | ✓ 完整支持 | ✓ 部分支持 |
| **调试** | C++ 调试器 | VCD 波形 |
| **适用场景** | 大规模仿真 | 快速测试 |

## 输出示例

```bash
$ ./run_verilator.sh

╔═══════════════════════════════════════════════════╗
║   Verilator 仿真 - 以太网 MAC RGMII AXI         ║
╚═══════════════════════════════════════════════════╝

[INFO] 检查依赖...
[INFO] 检测到 Verilator: Verilator 4.228 2023-01-16 rev v4.228

[INFO] 使用 Verilator 构建...

=== 使用 Verilator 构建 ===
Verilator 版本:
Verilator 4.228 2023-01-16 rev v4.228

编译文件列表:
  设计文件: 3 个
  以太网库: 16 个
  AXI 库: 5 个
  测试文件: 1 个

%Info: eth_mac_rgmii_axi_tb.v:1: $readmemh file not found: ...
...（编译输出）...

=== 构建完成 ===
可执行文件: obj_dir/Veth_mac_rgmii_axi_tb
[SUCCESS] 构建完成

[INFO] 运行仿真...

========================================
Verilator 仿真开始
========================================
[INFO] 应用复位...
[INFO] 复位释放
[INFO] 运行仿真...
[10000 ns] 仿真进度: 10000 周期
[20000 ns] 仿真进度: 20000 周期
...

========================================
仿真完成
总周期数: 50000
仿真时间: 400000 ns
========================================

波形文件已保存: eth_mac_rgmii_axi_tb.vcd
使用以下命令查看波形:
  gtkwave eth_mac_rgmii_axi_tb.vcd

[SUCCESS] 仿真完成

是否打开波形查看器？(y/n) y
[INFO] 打开 GTKWave...

[SUCCESS] 完成！
```

## C++ Testbench 说明

`eth_mac_rgmii_axi_tb.cpp` 是 Verilator 的 C++ 封装：

- 生成时钟信号
- 控制复位序列
- 记录 VCD 波形
- 显示仿真进度

### 修改 C++ Testbench

如需定制，编辑 `eth_mac_rgmii_axi_tb.cpp`：

```cpp
// 修改仿真时间
int max_cycles = 100000;  // 增加到更多周期

// 添加自定义激励
tb->s_axil_awaddr = 0x0008;
tb->s_axil_wdata = 0x12345678;
tb->eval();

// 添加更多调试输出
if (tb->irq) {
    std::cout << "中断触发！" << std::endl;
}
```

## 性能优化

### 编译优化

在 `Makefile.verilator` 中修改：

```makefile
VERILATOR_FLAGS = \
    --cc \
    --exe \
    --build \
    -O3 \              # 添加优化级别
    --x-assign fast \  # 快速 X 赋值
    --x-initial fast \ # 快速 X 初始化
    --noassert \       # 禁用断言（仅发布版）
    ...
```

### 减少波形大小

```makefile
VERILATOR_FLAGS = \
    --trace-depth 2 \  # 减小追踪深度（默认 99）
    ...
```

或在运行时选择性记录：

```cpp
// 只在关键时刻记录波形
if (main_time > 1000 && main_time < 2000) {
    tfp->dump(main_time);
}
```

## 调试技巧

### 1. 使用 GDB 调试

```bash
cd tb
make -f Makefile.verilator build
gdb ./obj_dir/Veth_mac_rgmii_axi_tb

# 在 GDB 中：
(gdb) break main
(gdb) run
(gdb) step
```

### 2. 添加打印语句

在 C++ testbench 中：

```cpp
if (tb->m_axi_awvalid && tb->m_axi_awready) {
    std::cout << "[" << main_time << "] AXI Write: addr=0x" 
              << std::hex << tb->m_axi_awaddr << std::endl;
}
```

### 3. 使用 Verilator 的内置调试

```bash
# 生成更详细的调试信息
verilator --debug --debug-check ...
```

## 常见问题

### Q: 编译时间很长

**A**: Verilator 首次编译会很慢（可能几分钟），但后续只重新编译修改的部分。

### Q: 内存不足

**A**: 
1. 减小 `--trace-depth`
2. 减少仿真周期
3. 增加系统内存或使用 swap

### Q: 找不到头文件

**A**: 确保 Verilator 正确安装：
```bash
verilator --version
which verilator
```

### Q: 波形文件太大

**A**: 
1. 减小 `--trace-depth`
2. 使用 FST 格式（更小）：
```cpp
#include <verilated_fst_c.h>
VerilatedFstC* tfp = new VerilatedFstC;
tfp->open("eth_mac_rgmii_axi_tb.fst");
```

## 高级功能

### 多线程仿真

在 `Makefile.verilator` 中添加：

```makefile
VERILATOR_FLAGS = \
    --threads 4 \  # 使用 4 个线程
    ...
```

### Coverage 覆盖率

```makefile
VERILATOR_FLAGS = \
    --coverage \   # 启用覆盖率
    ...
```

运行后生成报告：
```bash
verilator_coverage --annotate logs logs/coverage.dat
```

### DPI-C 接口

可以在 C++ 中调用自定义函数：

```cpp
// 在 Verilog 中：
import "DPI-C" function void my_cpp_function();

// 在 C++ 中：
extern "C" void my_cpp_function() {
    std::cout << "Called from Verilog!" << std::endl;
}
```

## 与原有仿真的对比

### Icarus Verilog 方式

```bash
# 编译：5秒
# 运行：30秒
# 总计：35秒
make SIM=iverilog
```

### Verilator 方式

```bash
# 编译：20秒（首次）
# 运行：5秒
# 总计：25秒（首次），5秒（后续）
make -f Makefile.verilator
```

**结论**：Verilator 首次较慢，但重复仿真快得多！

## 资源链接

- [Verilator 官方文档](https://verilator.org/guide/latest/)
- [Verilator GitHub](https://github.com/verilator/verilator)
- [Verilator 示例](https://github.com/verilator/verilator/tree/master/examples)

## 总结

Verilator 优势：
- ✅ 仿真速度快 10-100 倍
- ✅ 支持大规模设计
- ✅ 可使用 C++ 调试工具
- ✅ 完整 SystemVerilog 支持

适用场景：
- 大规模仿真
- 需要快速迭代
- 性能关键的验证
- 需要 C++ 集成

---

开始使用 Verilator：
```bash
cd tb
./run_verilator.sh
```

