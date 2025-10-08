/*
 * Verilator C++ Testbench for Ethernet MAC RGMII AXI
 * 
 * 这是 Verilator 的 C++ 测试封装
 */

#include <stdlib.h>
#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Veth_mac_rgmii_axi_tb.h"

// 时钟周期（纳秒）
#define CLK_PERIOD_GTX    8    // 125 MHz
#define CLK_PERIOD_LOGIC  10   // 100 MHz

// 仿真时间（纳秒）
vluint64_t main_time = 0;

// 用于 Verilator 的时间函数
double sc_time_stamp() {
    return main_time;
}

int main(int argc, char** argv) {
    // 初始化 Verilator
    Verilated::commandArgs(argc, argv);
    
    // 创建 DUT 实例
    Veth_mac_rgmii_axi_tb* tb = new Veth_mac_rgmii_axi_tb;
    
    // 启用波形追踪
    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    tb->trace(tfp, 99);  // 追踪深度
    tfp->open("eth_mac_rgmii_axi_tb.vcd");
    
    std::cout << "========================================" << std::endl;
    std::cout << "Verilator 仿真开始" << std::endl;
    std::cout << "========================================" << std::endl;
    
    // 初始化信号
    tb->gtx_clk = 0;
    tb->gtx_clk90 = 0;
    tb->logic_clk = 0;
    tb->gtx_rst = 1;
    tb->logic_rst = 1;
    
    // 复位周期
    std::cout << "[INFO] 应用复位..." << std::endl;
    for (int i = 0; i < 20; i++) {
        tb->gtx_clk = 0;
        tb->logic_clk = 0;
        tb->eval();
        tfp->dump(main_time);
        main_time += CLK_PERIOD_GTX / 2;
        
        tb->gtx_clk = 1;
        tb->logic_clk = (i % 2) ? 1 : 0;
        tb->eval();
        tfp->dump(main_time);
        main_time += CLK_PERIOD_GTX / 2;
    }
    
    // 释放复位
    tb->gtx_rst = 0;
    tb->logic_rst = 0;
    std::cout << "[INFO] 复位释放" << std::endl;
    
    // 主仿真循环
    int cycle_count = 0;
    int max_cycles = 100000;  // 最大仿真周期
    
    std::cout << "[INFO] 运行仿真..." << std::endl;
    
    while (!Verilated::gotFinish() && cycle_count < max_cycles) {
        // GTX 时钟切换 (125 MHz)
        tb->gtx_clk = 0;
        tb->eval();
        tfp->dump(main_time);
        main_time += CLK_PERIOD_GTX / 2;
        
        tb->gtx_clk = 1;
        tb->eval();
        tfp->dump(main_time);
        main_time += CLK_PERIOD_GTX / 2;
        
        // Logic 时钟切换 (100 MHz) - 每 5 个 GTX 周期切换 4 次
        if (cycle_count % 5 == 0) {
            tb->logic_clk = !tb->logic_clk;
        }
        
        // GTX 90 度时钟（相位偏移）
        if (cycle_count % 4 == 1) {
            tb->gtx_clk90 = !tb->gtx_clk90;
        }
        
        cycle_count++;
        
        // 定期显示进度
        if (cycle_count % 10000 == 0) {
            std::cout << "[" << main_time << " ns] 仿真进度: " 
                     << cycle_count << " 周期" << std::endl;
        }
    }
    
    std::cout << "\n========================================" << std::endl;
    std::cout << "仿真完成" << std::endl;
    std::cout << "总周期数: " << cycle_count << std::endl;
    std::cout << "仿真时间: " << main_time << " ns" << std::endl;
    std::cout << "========================================" << std::endl;
    
    // 清理
    tfp->close();
    delete tfp;
    delete tb;
    
    std::cout << "\n波形文件已保存: eth_mac_rgmii_axi_tb.vcd" << std::endl;
    std::cout << "使用以下命令查看波形:" << std::endl;
    std::cout << "  gtkwave eth_mac_rgmii_axi_tb.vcd" << std::endl;
    
    return 0;
}

