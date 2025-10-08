#!/bin/bash

# Verilator 仿真快速运行脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 打印函数
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查 Verilator
check_verilator() {
    if ! command -v verilator &> /dev/null; then
        print_error "Verilator 未安装"
        echo ""
        echo "安装方法："
        echo "  Ubuntu/Debian: sudo apt-get install verilator"
        echo "  Fedora/CentOS: sudo dnf install verilator"
        echo "  从源码编译: https://verilator.org/guide/latest/install.html"
        exit 1
    fi
    
    print_info "检测到 Verilator: $(verilator --version | head -n 1)"
}

# 检查 GTKWave
check_gtkwave() {
    if ! command -v gtkwave &> /dev/null; then
        print_info "GTKWave 未安装（可选，用于查看波形）"
        return 1
    fi
    return 0
}

# 主函数
main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════╗"
    echo "║   Verilator 仿真 - 以太网 MAC RGMII AXI         ║"
    echo "╚═══════════════════════════════════════════════════╝"
    echo ""
    
    # 检查依赖
    print_info "检查依赖..."
    check_verilator
    HAS_GTKWAVE=0
    check_gtkwave && HAS_GTKWAVE=1
    echo ""
    
    # 构建
    print_info "使用 Verilator 构建..."
    echo ""
    if make -f Makefile.verilator build; then
        print_success "构建完成"
    else
        print_error "构建失败"
        exit 1
    fi
    
    echo ""
    
    # 运行
    print_info "运行仿真..."
    echo ""
    if make -f Makefile.verilator run; then
        print_success "仿真完成"
    else
        print_error "仿真失败"
        exit 1
    fi
    
    echo ""
    
    # 询问是否查看波形
    if [ $HAS_GTKWAVE -eq 1 ]; then
        echo ""
        read -p "是否打开波形查看器？(y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "打开 GTKWave..."
            make -f Makefile.verilator waves
        fi
    fi
    
    echo ""
    print_success "完成！"
}

# 运行
main "$@"

