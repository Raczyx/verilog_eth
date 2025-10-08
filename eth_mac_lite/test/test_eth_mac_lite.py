# test_eth_mac_lite.py (Final Corrected Version using TestFactory)

import logging
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, Timer
from cocotb.regression import TestFactory

from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiBus, AxiRam
from cocotbext.eth import RgmiiPhy

# -----------------------------------------------------------------------------
# Testbench Class
# -----------------------------------------------------------------------------
class TB:
    def __init__(self, dut):
        self.dut = dut
        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        # Clocks
        cocotb.start_soon(Clock(dut.logic_clk, 10, units="ns").start()) # 100 MHz
        cocotb.start_soon(Clock(dut.gtx_clk, 8, units="ns").start())    # 125 MHz

        # AXI-Lite Master for control registers
        self.axil_master = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "s_axil"), dut.logic_clk, dut.logic_rst)

        # AXI RAM model for DMA
        self.axi_ram = AxiRam(AxiBus.from_prefix(dut, "m_axi"), dut.logic_clk, dut.logic_rst, size=2**16)

        # RGMII PHY model with internal loopback
        self.phy = RgmiiPhy(dut.rgmii_rxd, dut.rgmii_rx_ctl, dut.rgmii_txd, dut.rgmii_tx_ctl, dut.gtx_clk)
        self.phy.rx.set_source(self.phy.tx) # Internal loopback

    async def reset(self):
        self.log.info("Starting reset...")
        self.dut.logic_rst.value = 1
        self.dut.gtx_rst.value = 1
        await ClockCycles(self.dut.logic_clk, 5)
        self.dut.logic_rst.value = 0
        self.dut.gtx_rst.value = 0
        await ClockCycles(self.dut.logic_clk, 5)
        self.log.info("Reset complete")

    async def read_reg(self, addr):
        read_result = await self.axil_master.read(addr, 4)
        return read_result.data.integer

    async def write_reg(self, addr, data):
        await self.axil_master.write(addr, data.to_bytes(4, 'little'))

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------
def create_test_frame(dest_mac=0xFFFFFFFFFFFF, src_mac=0x5A5152535455, ethertype=0x88B5, payload=b''):
    """Creates a simple Ethernet frame."""
    if len(payload) < 46:
        payload += b'\x00' * (46 - len(payload))
    
    frame = dest_mac.to_bytes(6, 'big') + \
            src_mac.to_bytes(6, 'big') + \
            ethertype.to_bytes(2, 'big') + \
            payload
    return frame

# -----------------------------------------------------------------------------
# Test Logic Implementations
# -----------------------------------------------------------------------------

async def run_test_reg_access(dut):
    """Test register read/write access."""
    tb = TB(dut)
    await tb.reset()

    tb.log.info("Testing register access...")
    
    mac_lo = 0x11223344
    mac_hi = 0x00005566
    
    tb.log.info(f"Writing MAC address: {mac_hi:04X}{mac_lo:08X}")
    await tb.write_reg(0x0008, mac_lo)
    await tb.write_reg(0x000C, mac_hi)

    read_mac_lo = await tb.read_reg(0x0008)
    read_mac_hi = await tb.read_reg(0x000C)
    tb.log.info(f"Read back MAC address: {read_mac_hi:04X}{read_mac_lo:08X}")
    
    assert read_mac_lo == mac_lo
    assert read_mac_hi == mac_hi
    tb.log.info("MAC Address registers test PASSED")
    await ClockCycles(dut.logic_clk, 10)


async def run_test_tx_rx(dut, filter_mode=None):
    """Main logic for all TX/RX tests."""
    tb = TB(dut)
    await tb.reset()

    local_mac = 0x1A2B3C4D5E6F
    
    await tb.write_reg(0x0008, local_mac & 0xFFFFFFFF)
    await tb.write_reg(0x000C, local_mac >> 32)
    
    filter_cfg = 0
    if filter_mode == 'promiscuous':
        filter_cfg = 0b0011
    elif filter_mode == 'unicast':
        filter_cfg = 0b0001
    elif filter_mode == 'broadcast':
        filter_cfg = 0b0101

    await tb.write_reg(0x0010, filter_cfg)
    await tb.write_reg(0x0014, 0b1111) # Enable all interrupts
    await tb.write_reg(0x0000, 0b1111) # Enable TX/RX and DMA

    rx_buf_addr = 0x1000
    await tb.write_reg(0x0020, rx_buf_addr)
    await tb.write_reg(0x0024, 2048)
    await tb.write_reg(0x002C, 1) # Start RX DMA

    tx_buf_addr = 0x2000
    payload = f"Test frame for {filter_mode} mode!".encode()
    
    dest_mac = local_mac
    if filter_mode == 'broadcast':
      dest_mac = 0xFFFFFFFFFFFF
    
    tx_frame = create_test_frame(dest_mac=dest_mac, payload=payload)
    tb.axi_ram.write(tx_buf_addr, tx_frame)
    await tb.write_reg(0x0030, tx_buf_addr)
    await tb.write_reg(0x0034, len(tx_frame))
    await tb.write_reg(0x003C, 1) # Start TX DMA

    tb.log.info(f"[{filter_mode}] Configuration complete, starting transfer...")
    
    # Wait for both TX and RX interrupts
    for _ in range(20): # Timeout loop
        await ClockCycles(dut.logic_clk, 50)
        irq_status = await tb.read_reg(0x0018)
        if (irq_status & 0b0011) == 0b0011:
            tb.log.info(f"[{filter_mode}] Both TX and RX Done interrupts received!")
            break
    else:
        irq_status = await tb.read_reg(0x0018)
        assert False, f"Timeout waiting for TX/RX interrupts. Final IRQ status: {irq_status:04b}"

    rx_data = tb.axi_ram.read(rx_buf_addr, len(tx_frame))
    assert rx_data == tx_frame, "Received data does not match transmitted data"
    tb.log.info(f"[{filter_mode}] Frame content verification PASSED")

    await tb.write_reg(0x0018, 0b1111) # Clear all interrupts
    await ClockCycles(dut.logic_clk, 2)
    irq_status_after_clear = await tb.read_reg(0x0018)
    assert irq_status_after_clear == 0, "Interrupts did not clear correctly"
    tb.log.info(f"[{filter_mode}] Interrupt clear verification PASSED")


async def run_test_filter_drop(dut):
    """Test that the frame filter correctly drops frames."""
    tb = TB(dut)
    await tb.reset()

    local_mac = 0x1A2B3C4D5E6F
    other_mac = 0xAAABACADAEAF
    
    await tb.write_reg(0x0008, local_mac & 0xFFFFFFFF)
    await tb.write_reg(0x000C, local_mac >> 32)
    
    await tb.write_reg(0x0010, 0b0001) # filter enable ONLY, no broadcast/promiscuous
    await tb.write_reg(0x0014, 0x1)   # Enable RX_DONE IRQ
    await tb.write_reg(0x0000, 0b1011) # Enable RX, DMA_RX

    await tb.write_reg(0x0020, 0x1000)
    await tb.write_reg(0x0024, 2048)
    await tb.write_reg(0x002C, 1)

    tb.log.info("Injecting frame that should be dropped...")
    frame_to_drop = create_test_frame(dest_mac=other_mac)
    await tb.phy.rx.send(frame_to_drop)

    await ClockCycles(dut.logic_clk, 500)
    irq_status = await tb.read_reg(0x0018)
    assert not (irq_status & 0x1), "Interrupt was generated for a dropped frame"
    tb.log.info("Frame was correctly dropped. Test PASSED.")

# -----------------------------------------------------------------------------
# Test Factory to generate the tests
# -----------------------------------------------------------------------------

# A factory for the single register access test
tf_reg = TestFactory(run_test_reg_access)
tf_reg.generate_tests()

# A factory for the TX/RX tests, parameterized by filter_mode
tf_tx_rx = TestFactory(run_test_tx_rx)
tf_tx_rx.add_option("filter_mode", ["promiscuous", "unicast", "broadcast"])
tf_tx_rx.generate_tests()

# A factory for the filter drop test
tf_drop = TestFactory(run_test_filter_drop)
tf_drop.generate_tests()