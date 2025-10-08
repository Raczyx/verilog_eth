# ==============================================================================
# 以太网 MAC IP 时序和引脚约束文件 (Xilinx XDC)
# 适用于 Xilinx 7 Series, UltraScale, UltraScale+ FPGA
# ==============================================================================

# ==============================================================================
# 时钟约束
# ==============================================================================

# GTX 时钟 - 125 MHz (用于千兆以太网)
create_clock -period 8.000 -name gtx_clk [get_ports gtx_clk]
create_clock -period 8.000 -name gtx_clk90 [get_ports gtx_clk90]

# 逻辑时钟 - 假设 100 MHz (根据实际系统调整)
create_clock -period 10.000 -name logic_clk [get_ports logic_clk]

# RGMII 接收时钟 (由 PHY 提供)
create_clock -period 8.000 -name rgmii_rx_clk [get_ports rgmii_rx_clk]

# ==============================================================================
# 时钟域跨越约束
# ==============================================================================

# GTX 时钟域和逻辑时钟域之间的异步路径
set_clock_groups -asynchronous \
    -group [get_clocks gtx_clk] \
    -group [get_clocks logic_clk]

# RGMII RX 时钟域和其他时钟域之间的异步路径
set_clock_groups -asynchronous \
    -group [get_clocks rgmii_rx_clk] \
    -group [get_clocks gtx_clk] \
    -group [get_clocks logic_clk]

# GTX 时钟和 GTX 90度时钟之间的同步（相同频率，相位差90度）
set_clock_groups -physically_exclusive \
    -group [get_clocks gtx_clk] \
    -group [get_clocks gtx_clk90]

# ==============================================================================
# RGMII 接口约束
# ==============================================================================

# RGMII 输入延迟约束 (典型值，根据实际 PHY 调整)
# 假设建立时间 1.2ns，保持时间 1.2ns
set_input_delay -clock [get_clocks rgmii_rx_clk] -max 1.2 [get_ports {rgmii_rxd[*] rgmii_rx_ctl}]
set_input_delay -clock [get_clocks rgmii_rx_clk] -min -1.2 [get_ports {rgmii_rxd[*] rgmii_rx_ctl}]
set_input_delay -clock [get_clocks rgmii_rx_clk] -max 1.2 [get_ports {rgmii_rxd[*] rgmii_rx_ctl}] -clock_fall -add_delay
set_input_delay -clock [get_clocks rgmii_rx_clk] -min -1.2 [get_ports {rgmii_rxd[*] rgmii_rx_ctl}] -clock_fall -add_delay

# RGMII 输出延迟约束 (典型值)
set_output_delay -clock [get_clocks gtx_clk] -max 1.0 [get_ports {rgmii_txd[*] rgmii_tx_ctl}]
set_output_delay -clock [get_clocks gtx_clk] -min -0.5 [get_ports {rgmii_txd[*] rgmii_tx_ctl}]
set_output_delay -clock [get_clocks gtx_clk] -max 1.0 [get_ports {rgmii_txd[*] rgmii_tx_ctl}] -clock_fall -add_delay
set_output_delay -clock [get_clocks gtx_clk] -min -0.5 [get_ports {rgmii_txd[*] rgmii_tx_ctl}] -clock_fall -add_delay

# ==============================================================================
# RGMII 引脚位置约束 (示例 - 根据实际板卡修改)
# ==============================================================================

# 注意：以下引脚位置仅为示例，必须根据实际硬件板卡修改

# RGMII TX 接口
# set_property PACKAGE_PIN Y18 [get_ports rgmii_tx_clk]
# set_property PACKAGE_PIN Y19 [get_ports {rgmii_txd[0]}]
# set_property PACKAGE_PIN V18 [get_ports {rgmii_txd[1]}]
# set_property PACKAGE_PIN W19 [get_ports {rgmii_txd[2]}]
# set_property PACKAGE_PIN W18 [get_ports {rgmii_txd[3]}]
# set_property PACKAGE_PIN V17 [get_ports rgmii_tx_ctl]

# RGMII RX 接口
# set_property PACKAGE_PIN U19 [get_ports rgmii_rx_clk]
# set_property PACKAGE_PIN T19 [get_ports {rgmii_rxd[0]}]
# set_property PACKAGE_PIN T17 [get_ports {rgmii_rxd[1]}]
# set_property PACKAGE_PIN U17 [get_ports {rgmii_rxd[2]}]
# set_property PACKAGE_PIN U16 [get_ports {rgmii_rxd[3]}]
# set_property PACKAGE_PIN V16 [get_ports rgmii_rx_ctl]

# ==============================================================================
# RGMII IO 标准约束
# ==============================================================================

# RGMII 通常使用 HSTL 或 LVCMOS 标准 (根据 PHY 要求选择)
# set_property IOSTANDARD LVCMOS18 [get_ports rgmii_tx_clk]
# set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_txd[*]}]
# set_property IOSTANDARD LVCMOS18 [get_ports rgmii_tx_ctl]
# set_property IOSTANDARD LVCMOS18 [get_ports rgmii_rx_clk]
# set_property IOSTANDARD LVCMOS18 [get_ports {rgmii_rxd[*]}]
# set_property IOSTANDARD LVCMOS18 [get_ports rgmii_rx_ctl]

# 输出驱动强度
# set_property DRIVE 12 [get_ports rgmii_tx_clk]
# set_property DRIVE 12 [get_ports {rgmii_txd[*]}]
# set_property DRIVE 12 [get_ports rgmii_tx_ctl]

# 输入端接
# set_property SLEW FAST [get_ports rgmii_tx_clk]
# set_property SLEW FAST [get_ports {rgmii_txd[*]}]
# set_property SLEW FAST [get_ports rgmii_tx_ctl]

# ==============================================================================
# 时序例外 - 虚假路径
# ==============================================================================

# 复位信号异步路径
set_false_path -from [get_ports sys_rst]
set_false_path -from [get_ports gtx_rst]
set_false_path -from [get_ports logic_rst]

# ==============================================================================
# 多周期路径约束 (如果需要)
# ==============================================================================

# 某些寄存器配置路径可以是多周期
# set_multicycle_path -setup 2 -from [get_pins -hier -filter {NAME =~ *config_reg*/C}]
# set_multicycle_path -hold 1 -from [get_pins -hier -filter {NAME =~ *config_reg*/C}]

# ==============================================================================
# 位置约束 (可选)
# ==============================================================================

# 将关键逻辑放置在靠近 IO 的区域以提高性能
# create_pblock pblock_eth_mac
# add_cells_to_pblock [get_pblocks pblock_eth_mac] [get_cells -hier -filter {NAME =~ *eth_mac_inst*}]
# resize_pblock [get_pblocks pblock_eth_mac] -add {SLICE_X0Y0:SLICE_X50Y50}

# ==============================================================================
# 注意事项
# ==============================================================================

# 1. 必须根据实际硬件板卡修改引脚位置
# 2. 时序参数应根据 PHY 芯片数据手册调整
# 3. IO 标准必须匹配 PHY 芯片要求
# 4. 对于不同的 FPGA 系列，某些约束可能需要调整
# 5. 建议运行时序分析确保满足要求

# ==============================================================================
# 调试约束 (可选)
# ==============================================================================

# 如果使用 Xilinx ILA 进行调试
# set_property C_CLK_INPUT_FREQ_HZ 100000000 [get_debug_cores dbg_hub]
# set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
# set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
# connect_debug_port dbg_hub/clk [get_nets logic_clk]

