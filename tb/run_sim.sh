#!/bin/bash

# 以太网 MAC RGMII AXI 仿真运行脚本
# 提供更友好的用户接口

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示帮助信息
show_help() {
    cat << EOF
以太网 MAC RGMII AXI 仿真脚本

用法: $0 [选项]

选项:
    -s, --simulator <sim>   选择仿真器 (iverilog, verilator)
    -w, --waves             仿真后自动打开波形查看器
    -c, --clean             运行前清理旧文件
    -v, --verbose           显示详细输出
    -h, --help              显示此帮助信息

示例:
    $0                      # 使用默认设置运行
    $0 -s verilator -w      # 使用 Verilator 并查看波形
    $0 -c -w                # 清理后运行并查看波形

EOF
}

# 检查依赖
check_dependencies() {
    print_info "检查依赖..."
    
    local missing_deps=0
    
    # 检查 Make
    if ! command -v make &> /dev/null; then
        print_error "make 未安装"
        missing_deps=1
    fi
    
    # 检查仿真器
    if [ "$SIMULATOR" == "iverilog" ]; then
        if ! command -v iverilog &> /dev/null; then
            print_error "Icarus Verilog (iverilog) 未安装"
            print_info "安装: sudo apt-get install iverilog"
            missing_deps=1
        fi
        if ! command -v vvp &> /dev/null; then
            print_error "vvp 未安装"
            missing_deps=1
        fi
    elif [ "$SIMULATOR" == "verilator" ]; then
        if ! command -v verilator &> /dev/null; then
            print_error "Verilator 未安装"
            print_info "安装: sudo apt-get install verilator"
            missing_deps=1
        fi
    fi
    
    # 检查波形查看器
    if [ "$OPEN_WAVES" == "yes" ]; then
        if ! command -v gtkwave &> /dev/null; then
            print_warning "GTKWave 未安装，无法查看波形"
            print_info "安装: sudo apt-get install gtkwave"
            OPEN_WAVES="no"
        fi
    fi
    
    if [ $missing_deps -eq 1 ]; then
        print_error "缺少必要的依赖，请先安装"
        exit 1
    fi
    
    print_success "依赖检查通过"
}

# 清理旧文件
clean_old_files() {
    print_info "清理旧文件..."
    make clean > /dev/null 2>&1 || true
    print_success "清理完成"
}

# 运行仿真
run_simulation() {
    print_info "开始仿真（使用 $SIMULATOR）..."
    echo ""
    
    if [ "$VERBOSE" == "yes" ]; then
        make SIM=$SIMULATOR
    else
        make SIM=$SIMULATOR 2>&1 | tee sim.log
    fi
    
    local exit_code=$?
    echo ""
    
    if [ $exit_code -eq 0 ]; then
        print_success "仿真完成"
        
        # 检查测试结果
        if grep -q "状态: 通过" sim.log 2>/dev/null || \
           grep -q "状态: 通过" work/simulation.log 2>/dev/null; then
            print_success "✓ 所有测试通过！"
            return 0
        elif grep -q "状态: 失败" sim.log 2>/dev/null || \
             grep -q "状态: 失败" work/simulation.log 2>/dev/null; then
            print_error "✗ 部分测试失败"
            return 1
        else
            print_warning "无法确定测试结果"
            return 0
        fi
    else
        print_error "仿真失败"
        return $exit_code
    fi
}

# 打开波形查看器
open_waveform() {
    print_info "打开波形查看器..."
    
    local vcd_file=""
    
    if [ "$SIMULATOR" == "iverilog" ]; then
        vcd_file="work/eth_mac_rgmii_axi_tb.vcd"
    elif [ "$SIMULATOR" == "verilator" ]; then
        vcd_file="sim_build/eth_mac_rgmii_axi_tb.vcd"
    fi
    
    if [ -f "$vcd_file" ]; then
        print_info "波形文件: $vcd_file"
        gtkwave "$vcd_file" work/eth_mac_rgmii_axi_tb.gtkw 2>/dev/null &
        print_success "GTKWave 已启动"
    else
        print_error "波形文件不存在: $vcd_file"
    fi
}

# 显示统计信息
show_statistics() {
    echo ""
    print_info "=== 仿真统计 ==="
    
    if [ -f "work/eth_mac_rgmii_axi_tb.vcd" ]; then
        local vcd_size=$(du -h work/eth_mac_rgmii_axi_tb.vcd | cut -f1)
        echo "  波形文件大小: $vcd_size"
    fi
    
    if [ -f "sim.log" ]; then
        local num_tests=$(grep -c "\[TEST" sim.log 2>/dev/null || echo "0")
        local num_errors=$(grep -c "ERROR" sim.log 2>/dev/null || echo "0")
        local num_warnings=$(grep -c "WARNING" sim.log 2>/dev/null || echo "0")
        
        echo "  测试数量: $num_tests"
        echo "  错误数量: $num_errors"
        echo "  警告数量: $num_warnings"
    fi
    
    echo ""
}

# 主程序
main() {
    # 默认设置
    SIMULATOR="iverilog"
    OPEN_WAVES="no"
    DO_CLEAN="no"
    VERBOSE="no"
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--simulator)
                SIMULATOR="$2"
                shift 2
                ;;
            -w|--waves)
                OPEN_WAVES="yes"
                shift
                ;;
            -c|--clean)
                DO_CLEAN="yes"
                shift
                ;;
            -v|--verbose)
                VERBOSE="yes"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 验证仿真器选择
    if [ "$SIMULATOR" != "iverilog" ] && [ "$SIMULATOR" != "verilator" ]; then
        print_error "不支持的仿真器: $SIMULATOR"
        print_info "支持的仿真器: iverilog, verilator"
        exit 1
    fi
    
    echo ""
    echo "╔═══════════════════════════════════════════════════╗"
    echo "║   以太网 MAC RGMII AXI 仿真                      ║"
    echo "╚═══════════════════════════════════════════════════╝"
    echo ""
    
    # 检查依赖
    check_dependencies
    
    # 清理（如果需要）
    if [ "$DO_CLEAN" == "yes" ]; then
        clean_old_files
    fi
    
    # 运行仿真
    if run_simulation; then
        SIM_SUCCESS=true
    else
        SIM_SUCCESS=false
    fi
    
    # 显示统计
    show_statistics
    
    # 打开波形（如果需要且仿真成功）
    if [ "$OPEN_WAVES" == "yes" ] && [ "$SIM_SUCCESS" == "true" ]; then
        open_waveform
    fi
    
    echo ""
    if [ "$SIM_SUCCESS" == "true" ]; then
        print_success "完成！"
        exit 0
    else
        print_error "仿真失败"
        exit 1
    fi
}

# 运行主程序
main "$@"

