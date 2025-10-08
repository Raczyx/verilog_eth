# Makefile for Ethernet MAC RGMII AXI Testbench
# 支持 Icarus Verilog 和 Verilator 仿真器

# ============================================================================
# 配置
# ============================================================================

# 仿真器选择: iverilog, verilator
SIM ?= iverilog

# 顶层模块
TOP_MODULE = eth_mac_rgmii_axi_tb

# 工作目录
WORK_DIR = work
SIM_DIR = sim_build

# RTL 源文件目录
RTL_DIR = ..
ETH_RTL_DIR = ../verilog-ethernet/rtl
AXI_RTL_DIR = ../verilog-axi/rtl

# Testbench 文件
TB_FILES = eth_mac_rgmii_axi_tb.v

# 核心设计文件
DESIGN_FILES = \
	$(RTL_DIR)/eth_mac_rgmii_axi.v \
	$(RTL_DIR)/eth_frame_filter.v \
	$(RTL_DIR)/eth_mac_axil_regs.v

# verilog-ethernet 依赖文件
ETH_FILES = \
	$(ETH_RTL_DIR)/eth_mac_1g_rgmii.v \
	$(ETH_RTL_DIR)/eth_mac_1g_rgmii_fifo.v \
	$(ETH_RTL_DIR)/eth_mac_1g.v \
	$(ETH_RTL_DIR)/eth_axis_rx.v \
	$(ETH_RTL_DIR)/eth_axis_tx.v \
	$(ETH_RTL_DIR)/ip_complete.v \
	$(ETH_RTL_DIR)/ip.v \
	$(ETH_RTL_DIR)/ip_eth_rx.v \
	$(ETH_RTL_DIR)/ip_eth_tx.v \
	$(ETH_RTL_DIR)/arp.v \
	$(ETH_RTL_DIR)/arp_eth_rx.v \
	$(ETH_RTL_DIR)/arp_eth_tx.v \
	$(ETH_RTL_DIR)/arp_cache.v \
	$(ETH_RTL_DIR)/eth_arb_mux.v \
	$(ETH_RTL_DIR)/axis_gmii_rx.v \
	$(ETH_RTL_DIR)/axis_gmii_tx.v \
	$(ETH_RTL_DIR)/rgmii_phy_if.v \
	$(ETH_RTL_DIR)/ssio_ddr_in.v \
	$(ETH_RTL_DIR)/ssio_ddr_out.v \
	$(ETH_RTL_DIR)/iddr.v \
	$(ETH_RTL_DIR)/oddr.v \
	$(ETH_RTL_DIR)/lfsr.v \
	$(ETH_RTL_DIR)/../lib/axis/rtl/axis_async_fifo_adapter.v \
	$(ETH_RTL_DIR)/../lib/axis/rtl/axis_async_fifo.v

# verilog-axi 依赖文件
AXI_FILES = \
	$(AXI_RTL_DIR)/axi_dma.v \
	$(AXI_RTL_DIR)/axi_dma_rd.v \
	$(AXI_RTL_DIR)/axi_dma_wr.v \
	$(AXI_RTL_DIR)/arbiter.v \
	$(AXI_RTL_DIR)/priority_encoder.v

# verilog-axis 依赖文件（如果需要）
# AXIS_FILES = 

# 所有源文件
ALL_FILES = $(DESIGN_FILES) $(ETH_FILES) $(AXI_FILES) $(TB_FILES)

# 编译选项
IVERILOG_FLAGS = -g2012 -Wall -Wno-timescale
VERILATOR_FLAGS = --binary --trace --trace-structs -Wall -Wno-fatal

# 波形文件
WAVEFORM = $(WORK_DIR)/eth_mac_rgmii_axi_tb.vcd
WAVEFORM_GTK = $(WORK_DIR)/eth_mac_rgmii_axi_tb.gtkw

# ============================================================================
# 目标
# ============================================================================

.PHONY: all sim clean waves help

# 默认目标
all: sim

# 创建工作目录
$(WORK_DIR):
	@mkdir -p $(WORK_DIR)

$(SIM_DIR):
	@mkdir -p $(SIM_DIR)

# ============================================================================
# Icarus Verilog 仿真
# ============================================================================

ifeq ($(SIM),iverilog)

# 编译
$(WORK_DIR)/$(TOP_MODULE).vvp: $(ALL_FILES) | $(WORK_DIR)
	@echo "=== 使用 Icarus Verilog 编译 ==="
	iverilog $(IVERILOG_FLAGS) -o $@ $(ALL_FILES)
	@echo "编译完成: $@"

# 运行仿真
sim: $(WORK_DIR)/$(TOP_MODULE).vvp
	@echo "=== 运行仿真 ==="
	cd $(WORK_DIR) && vvp $(TOP_MODULE).vvp
	@echo ""
	@echo "=== 仿真完成 ==="
	@if [ -f $(WAVEFORM) ]; then \
		echo "波形文件: $(WAVEFORM)"; \
		echo "使用 'make waves' 查看波形"; \
	fi

# 查看波形
waves:
	@if [ -f $(WAVEFORM) ]; then \
		echo "使用 GTKWave 打开波形..."; \
		gtkwave $(WAVEFORM) $(WAVEFORM_GTK) & \
	else \
		echo "错误: 波形文件不存在。请先运行 'make sim'"; \
	fi

endif

# ============================================================================
# Verilator 仿真
# ============================================================================

ifeq ($(SIM),verilator)

# 编译和运行
sim: $(ALL_FILES) | $(SIM_DIR)
	@echo "=== 使用 Verilator 编译和运行 ==="
	verilator $(VERILATOR_FLAGS) --top $(TOP_MODULE) $(ALL_FILES) \
		--Mdir $(SIM_DIR) -o $(TOP_MODULE)
	$(SIM_DIR)/$(TOP_MODULE)
	@echo "=== 仿真完成 ==="

# 查看波形
waves:
	@if [ -f $(SIM_DIR)/$(TOP_MODULE).vcd ]; then \
		echo "使用 GTKWave 打开波形..."; \
		gtkwave $(SIM_DIR)/$(TOP_MODULE).vcd & \
	else \
		echo "错误: 波形文件不存在。请先运行 'make sim'"; \
	fi

endif

# ============================================================================
# 清理
# ============================================================================

clean:
	@echo "清理生成的文件..."
	rm -rf $(WORK_DIR) $(SIM_DIR)
	rm -f *.vcd *.vvp *.lxt *.fst
	@echo "清理完成"

# ============================================================================
# 帮助信息
# ============================================================================

help:
	@echo "Ethernet MAC RGMII AXI 仿真 Makefile"
	@echo ""
	@echo "目标:"
	@echo "  all (默认)  - 编译并运行仿真"
	@echo "  sim         - 运行仿真"
	@echo "  waves       - 使用 GTKWave 查看波形"
	@echo "  clean       - 清理生成的文件"
	@echo "  help        - 显示此帮助信息"
	@echo ""
	@echo "选项:"
	@echo "  SIM=iverilog  - 使用 Icarus Verilog (默认)"
	@echo "  SIM=verilator - 使用 Verilator"
	@echo ""
	@echo "示例:"
	@echo "  make                    # 使用 Icarus Verilog 运行仿真"
	@echo "  make SIM=verilator      # 使用 Verilator 运行仿真"
	@echo "  make waves              # 查看波形"
	@echo "  make clean              # 清理"
	@echo ""
	@echo "要求:"
	@echo "  - Icarus Verilog: iverilog, vvp"
	@echo "  - Verilator: verilator"
	@echo "  - GTKWave: gtkwave (查看波形)"

# ============================================================================
# 调试信息
# ============================================================================

info:
	@echo "配置信息:"
	@echo "  仿真器: $(SIM)"
	@echo "  顶层模块: $(TOP_MODULE)"
	@echo "  工作目录: $(WORK_DIR)"
	@echo "  设计文件数: $(words $(DESIGN_FILES))"
	@echo "  Ethernet 文件数: $(words $(ETH_FILES))"
	@echo "  AXI 文件数: $(words $(AXI_FILES))"
	@echo "  总文件数: $(words $(ALL_FILES))"

