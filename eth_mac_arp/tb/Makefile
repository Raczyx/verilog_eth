# Makefile for eth_mac_arp testbench

# 编译器
IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave

# 目录设置
RTL_DIR = ../rtl
PARENT_RTL_DIR = ../..
AXI_RTL_DIR = ../../verilog-axi/rtl
ETH_RTL_DIR = ../../verilog-ethernet/rtl
AXIS_RTL_DIR = ../../verilog-ethernet/lib/axis/rtl

# 顶层模块
TOP_MODULE = eth_mac_arp_tb

# 输出文件
VVP_FILE = $(TOP_MODULE).vvp
VCD_FILE = $(TOP_MODULE).vcd

# RTL 文件列表
RTL_FILES = \
	$(RTL_DIR)/eth_mac_arp.v \
	$(RTL_DIR)/eth_mac_arp_regs.v \
	$(PARENT_RTL_DIR)/eth_frame_filter.v

# MAC 层文件
MAC_FILES = \
	$(ETH_RTL_DIR)/eth_mac_1g_rgmii_fifo.v \
	$(ETH_RTL_DIR)/eth_mac_1g_rgmii.v \
	$(ETH_RTL_DIR)/eth_mac_1g.v \
	$(ETH_RTL_DIR)/axis_gmii_rx.v \
	$(ETH_RTL_DIR)/axis_gmii_tx.v \
	$(ETH_RTL_DIR)/lfsr.v \
	$(ETH_RTL_DIR)/rgmii_phy_if.v \
	$(ETH_RTL_DIR)/ssio_ddr_in.v \
	$(ETH_RTL_DIR)/ssio_ddr_out.v \
	$(ETH_RTL_DIR)/mii_phy_if.v \
	$(ETH_RTL_DIR)/iddr.v \
	$(ETH_RTL_DIR)/oddr.v \
	$(ETH_RTL_DIR)/ssio_sdr_in.v

# 以太网帧处理
ETH_FILES = \
	$(ETH_RTL_DIR)/eth_axis_rx.v \
	$(ETH_RTL_DIR)/eth_axis_tx.v

# ARP 模块
ARP_FILES = \
	$(ETH_RTL_DIR)/arp_eth_rx.v \
	$(ETH_RTL_DIR)/arp_eth_tx.v \
	$(ETH_RTL_DIR)/arp.v \
	$(ETH_RTL_DIR)/arp_cache.v

# AXI 文件
AXI_FILES = \
	$(AXI_RTL_DIR)/axi_dma.v \
	$(AXI_RTL_DIR)/axi_dma_rd.v \
	$(AXI_RTL_DIR)/axi_dma_wr.v \
	$(AXI_RTL_DIR)/arbiter.v \
	$(AXI_RTL_DIR)/priority_encoder.v

# AXIS 文件
AXIS_FILES = \
	$(AXIS_RTL_DIR)/axis_adapter.v \
	$(AXIS_RTL_DIR)/axis_fifo.v \
	$(AXIS_RTL_DIR)/axis_async_fifo.v \
	$(AXIS_RTL_DIR)/axis_async_fifo_adapter.v

# 测试文件
TB_FILES = eth_mac_arp_tb.v

# 所有文件
ALL_FILES = $(RTL_FILES) $(MAC_FILES) $(ETH_FILES) $(ARP_FILES) $(AXI_FILES) $(AXIS_FILES) $(TB_FILES)

# 编译选项
IVERILOG_FLAGS = -g2012 -Wall -Wno-timescale

# 默认目标
all: compile run

# 编译
compile: $(VVP_FILE)

$(VVP_FILE): $(ALL_FILES)
	@echo "========================================"
	@echo "编译 eth_mac_arp 测试平台..."
	@echo "========================================"
	$(IVERILOG) $(IVERILOG_FLAGS) -o $(VVP_FILE) $(ALL_FILES)
	@echo "编译完成!"

# 运行仿真
run: $(VVP_FILE)
	@echo "========================================"
	@echo "运行仿真..."
	@echo "========================================"
	$(VVP) $(VVP_FILE)

# 查看波形
waves: $(VCD_FILE)
	$(GTKWAVE) $(VCD_FILE) &

# 清理
clean:
	rm -f $(VVP_FILE) $(VCD_FILE)
	@echo "清理完成!"

# 完整测试 (编译 + 运行)
test: clean all
	@echo "========================================"
	@echo "测试完成!"
	@echo "========================================"

# 显示帮助
help:
	@echo "可用目标:"
	@echo "  all     - 编译并运行仿真 (默认)"
	@echo "  compile - 仅编译"
	@echo "  run     - 仅运行仿真"
	@echo "  waves   - 使用 GTKWave 查看波形"
	@echo "  clean   - 清理生成的文件"
	@echo "  test    - 完整测试 (清理+编译+运行)"
	@echo "  help    - 显示此帮助信息"

# 检查文件
check:
	@echo "检查所有文件是否存在..."
	@for file in $(ALL_FILES); do \
		if [ ! -f $$file ]; then \
			echo "[错误] 文件不存在: $$file"; \
			exit 1; \
		fi \
	done
	@echo "所有文件检查通过!"

.PHONY: all compile run waves clean test help check

