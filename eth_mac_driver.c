/**
 * 以太网 MAC IP 软件驱动示例
 * 
 * 此文件展示如何从处理器（如 ARM、RISC-V、MicroBlaze）端
 * 通过 AXI-Lite 接口控制以太网 MAC IP
 * 
 * Copyright (c) 2025
 */

#include <stdint.h>
#include <stdbool.h>
#include <string.h>

// ============================================================================
// 寄存器地址定义
// ============================================================================

// 假设 MAC IP 的基地址为 0x43C00000（根据实际系统修改）
#define ETH_MAC_BASE_ADDR       0x43C00000UL

// 寄存器偏移量
#define ETH_REG_CTRL            0x0000  // 控制寄存器
#define ETH_REG_STATUS          0x0004  // 状态寄存器
#define ETH_REG_MAC_ADDR_LOW    0x0008  // MAC 地址低32位
#define ETH_REG_MAC_ADDR_HIGH   0x000C  // MAC 地址高16位
#define ETH_REG_LOCAL_IP        0x0010  // 本地 IP 地址
#define ETH_REG_GATEWAY_IP      0x0014  // 网关 IP 地址
#define ETH_REG_SUBNET_MASK     0x0018  // 子网掩码
#define ETH_REG_FILTER_CONFIG   0x001C  // 过滤器配置
#define ETH_REG_IRQ_ENABLE      0x0020  // 中断使能
#define ETH_REG_IRQ_STATUS      0x0024  // 中断状态
#define ETH_REG_IFG_CONFIG      0x0028  // 帧间隙配置

#define ETH_REG_RX_DESC_ADDR    0x0030  // RX DMA 描述符地址
#define ETH_REG_RX_DESC_LEN     0x0034  // RX DMA 描述符长度
#define ETH_REG_RX_DESC_TAG     0x0038  // RX DMA 描述符标签
#define ETH_REG_RX_DESC_VALID   0x003C  // RX DMA 描述符有效

#define ETH_REG_TX_DESC_ADDR    0x0040  // TX DMA 描述符地址
#define ETH_REG_TX_DESC_LEN     0x0044  // TX DMA 描述符长度
#define ETH_REG_TX_DESC_TAG     0x0048  // TX DMA 描述符标签
#define ETH_REG_TX_DESC_VALID   0x004C  // TX DMA 描述符有效

// 控制寄存器位定义
#define ETH_CTRL_TX_EN          (1 << 0)
#define ETH_CTRL_RX_EN          (1 << 1)
#define ETH_CTRL_DMA_RX_EN      (1 << 2)
#define ETH_CTRL_DMA_TX_EN      (1 << 3)
#define ETH_CTRL_CLEAR_ARP      (1 << 4)

// 过滤器配置位定义
#define ETH_FILTER_ENABLE       (1 << 0)
#define ETH_FILTER_PROMISCUOUS  (1 << 1)
#define ETH_FILTER_BROADCAST    (1 << 2)
#define ETH_FILTER_MULTICAST    (1 << 3)

// 中断状态位定义
#define ETH_IRQ_RX_DONE         (1 << 0)
#define ETH_IRQ_TX_DONE         (1 << 1)
#define ETH_IRQ_RX_ERROR        (1 << 2)
#define ETH_IRQ_TX_ERROR        (1 << 3)

// 链路速度定义
#define ETH_SPEED_10M           0
#define ETH_SPEED_100M          1
#define ETH_SPEED_1000M         2

// ============================================================================
// 寄存器访问宏
// ============================================================================

#define ETH_WRITE_REG(offset, value) \
    (*((volatile uint32_t *)(ETH_MAC_BASE_ADDR + (offset))) = (value))

#define ETH_READ_REG(offset) \
    (*((volatile uint32_t *)(ETH_MAC_BASE_ADDR + (offset))))

// ============================================================================
// 数据结构定义
// ============================================================================

typedef struct {
    uint8_t mac[6];         // MAC 地址
    uint32_t ip;            // IP 地址
    uint32_t gateway;       // 网关地址
    uint32_t netmask;       // 子网掩码
    bool promiscuous;       // 混杂模式
    bool broadcast;         // 广播使能
    bool multicast;         // 组播使能
} eth_mac_config_t;

typedef struct {
    uint32_t addr;          // DMA 缓冲区地址
    uint32_t len;           // 数据长度
    uint8_t tag;            // 描述符标签
    bool valid;             // 有效标志
} eth_dma_desc_t;

// ============================================================================
// 底层寄存器访问函数
// ============================================================================

/**
 * 写入32位寄存器
 */
static inline void eth_write_reg(uint32_t offset, uint32_t value)
{
    ETH_WRITE_REG(offset, value);
}

/**
 * 读取32位寄存器
 */
static inline uint32_t eth_read_reg(uint32_t offset)
{
    return ETH_READ_REG(offset);
}

// ============================================================================
// MAC 配置函数
// ============================================================================

/**
 * 设置 MAC 地址
 * @param mac: MAC 地址数组 (6字节)
 */
void eth_mac_set_address(const uint8_t mac[6])
{
    uint32_t mac_low = (mac[3] << 24) | (mac[2] << 16) | (mac[1] << 8) | mac[0];
    uint32_t mac_high = (mac[5] << 8) | mac[4];
    
    eth_write_reg(ETH_REG_MAC_ADDR_LOW, mac_low);
    eth_write_reg(ETH_REG_MAC_ADDR_HIGH, mac_high);
}

/**
 * 设置 IP 地址
 * @param ip: IP 地址 (网络字节序)
 */
void eth_mac_set_ip(uint32_t ip)
{
    eth_write_reg(ETH_REG_LOCAL_IP, ip);
}

/**
 * 设置网关地址
 * @param gateway: 网关地址 (网络字节序)
 */
void eth_mac_set_gateway(uint32_t gateway)
{
    eth_write_reg(ETH_REG_GATEWAY_IP, gateway);
}

/**
 * 设置子网掩码
 * @param netmask: 子网掩码 (网络字节序)
 */
void eth_mac_set_netmask(uint32_t netmask)
{
    eth_write_reg(ETH_REG_SUBNET_MASK, netmask);
}

/**
 * 配置过滤器
 * @param enable: 使能过滤器
 * @param promiscuous: 混杂模式
 * @param broadcast: 允许广播
 * @param multicast: 允许组播
 */
void eth_mac_config_filter(bool enable, bool promiscuous, 
                           bool broadcast, bool multicast)
{
    uint32_t config = 0;
    
    if (enable) config |= ETH_FILTER_ENABLE;
    if (promiscuous) config |= ETH_FILTER_PROMISCUOUS;
    if (broadcast) config |= ETH_FILTER_BROADCAST;
    if (multicast) config |= ETH_FILTER_MULTICAST;
    
    eth_write_reg(ETH_REG_FILTER_CONFIG, config);
}

/**
 * 设置帧间隙
 * @param ifg: 帧间隙值 (字节数，通常为12)
 */
void eth_mac_set_ifg(uint8_t ifg)
{
    eth_write_reg(ETH_REG_IFG_CONFIG, ifg);
}

/**
 * 清除 ARP 缓存
 */
void eth_mac_clear_arp_cache(void)
{
    uint32_t ctrl = eth_read_reg(ETH_REG_CTRL);
    eth_write_reg(ETH_REG_CTRL, ctrl | ETH_CTRL_CLEAR_ARP);
    // 等待一段时间后清除该位
    for (volatile int i = 0; i < 1000; i++);
    eth_write_reg(ETH_REG_CTRL, ctrl & ~ETH_CTRL_CLEAR_ARP);
}

// ============================================================================
// MAC 控制函数
// ============================================================================

/**
 * 使能/禁用 MAC TX
 * @param enable: true=使能, false=禁用
 */
void eth_mac_tx_enable(bool enable)
{
    uint32_t ctrl = eth_read_reg(ETH_REG_CTRL);
    if (enable) {
        ctrl |= ETH_CTRL_TX_EN;
    } else {
        ctrl &= ~ETH_CTRL_TX_EN;
    }
    eth_write_reg(ETH_REG_CTRL, ctrl);
}

/**
 * 使能/禁用 MAC RX
 * @param enable: true=使能, false=禁用
 */
void eth_mac_rx_enable(bool enable)
{
    uint32_t ctrl = eth_read_reg(ETH_REG_CTRL);
    if (enable) {
        ctrl |= ETH_CTRL_RX_EN;
    } else {
        ctrl &= ~ETH_CTRL_RX_EN;
    }
    eth_write_reg(ETH_REG_CTRL, ctrl);
}

/**
 * 使能/禁用 DMA
 * @param tx_enable: TX DMA 使能
 * @param rx_enable: RX DMA 使能
 */
void eth_mac_dma_enable(bool tx_enable, bool rx_enable)
{
    uint32_t ctrl = eth_read_reg(ETH_REG_CTRL);
    
    if (tx_enable) {
        ctrl |= ETH_CTRL_DMA_TX_EN;
    } else {
        ctrl &= ~ETH_CTRL_DMA_TX_EN;
    }
    
    if (rx_enable) {
        ctrl |= ETH_CTRL_DMA_RX_EN;
    } else {
        ctrl &= ~ETH_CTRL_DMA_RX_EN;
    }
    
    eth_write_reg(ETH_REG_CTRL, ctrl);
}

// ============================================================================
// 状态查询函数
// ============================================================================

/**
 * 获取链路速度
 * @return: 0=10M, 1=100M, 2=1000M
 */
uint32_t eth_mac_get_speed(void)
{
    uint32_t status = eth_read_reg(ETH_REG_STATUS);
    return status & 0x3;
}

/**
 * 获取链路速度字符串
 */
const char* eth_mac_get_speed_string(void)
{
    switch (eth_mac_get_speed()) {
        case ETH_SPEED_10M:   return "10 Mbps";
        case ETH_SPEED_100M:  return "100 Mbps";
        case ETH_SPEED_1000M: return "1000 Mbps";
        default:              return "Unknown";
    }
}

// ============================================================================
// DMA 传输函数
// ============================================================================

/**
 * 发送数据包 (TX)
 * @param buffer: 数据缓冲区地址 (必须是物理地址)
 * @param len: 数据长度 (字节)
 * @param tag: 描述符标签 (用于跟踪)
 * @return: 0=成功, -1=失败
 */
int eth_mac_send_packet(uint32_t buffer, uint32_t len, uint8_t tag)
{
    // 检查上一个传输是否完成
    if (eth_read_reg(ETH_REG_TX_DESC_VALID) & 0x1) {
        return -1;  // 忙
    }
    
    // 配置 TX 描述符
    eth_write_reg(ETH_REG_TX_DESC_ADDR, buffer);
    eth_write_reg(ETH_REG_TX_DESC_LEN, len);
    eth_write_reg(ETH_REG_TX_DESC_TAG, tag);
    
    // 启动传输
    eth_write_reg(ETH_REG_TX_DESC_VALID, 1);
    
    return 0;
}

/**
 * 配置接收缓冲区 (RX)
 * @param buffer: 接收缓冲区地址 (必须是物理地址)
 * @param max_len: 最大接收长度 (字节)
 * @param tag: 描述符标签
 * @return: 0=成功, -1=失败
 */
int eth_mac_recv_packet(uint32_t buffer, uint32_t max_len, uint8_t tag)
{
    // 检查上一个接收是否完成
    if (eth_read_reg(ETH_REG_RX_DESC_VALID) & 0x1) {
        return -1;  // 忙
    }
    
    // 配置 RX 描述符
    eth_write_reg(ETH_REG_RX_DESC_ADDR, buffer);
    eth_write_reg(ETH_REG_RX_DESC_LEN, max_len);
    eth_write_reg(ETH_REG_RX_DESC_TAG, tag);
    
    // 启动接收
    eth_write_reg(ETH_REG_RX_DESC_VALID, 1);
    
    return 0;
}

/**
 * 获取实际接收的数据长度
 * @return: 接收的字节数
 */
uint32_t eth_mac_get_rx_length(void)
{
    return eth_read_reg(ETH_REG_RX_DESC_LEN) & 0xFFFFF;
}

// ============================================================================
// 中断处理函数
// ============================================================================

/**
 * 使能中断
 * @param enable: true=使能, false=禁用
 */
void eth_mac_irq_enable(bool enable)
{
    eth_write_reg(ETH_REG_IRQ_ENABLE, enable ? 1 : 0);
}

/**
 * 获取中断状态
 * @return: 中断状态位掩码
 */
uint32_t eth_mac_get_irq_status(void)
{
    return eth_read_reg(ETH_REG_IRQ_STATUS);
}

/**
 * 清除中断状态
 * @param mask: 要清除的中断位掩码
 */
void eth_mac_clear_irq(uint32_t mask)
{
    eth_write_reg(ETH_REG_IRQ_STATUS, mask);
}

/**
 * 中断服务例程示例
 */
void eth_mac_isr(void)
{
    uint32_t irq_status = eth_mac_get_irq_status();
    
    if (irq_status & ETH_IRQ_RX_DONE) {
        // 接收完成
        uint32_t rx_len = eth_mac_get_rx_length();
        // 处理接收到的数据...
        
        // 清除中断标志
        eth_mac_clear_irq(ETH_IRQ_RX_DONE);
    }
    
    if (irq_status & ETH_IRQ_TX_DONE) {
        // 发送完成
        
        // 清除中断标志
        eth_mac_clear_irq(ETH_IRQ_TX_DONE);
    }
    
    if (irq_status & ETH_IRQ_RX_ERROR) {
        // 接收错误
        
        // 清除中断标志
        eth_mac_clear_irq(ETH_IRQ_RX_ERROR);
    }
    
    if (irq_status & ETH_IRQ_TX_ERROR) {
        // 发送错误
        
        // 清除中断标志
        eth_mac_clear_irq(ETH_IRQ_TX_ERROR);
    }
}

// ============================================================================
// 初始化和使用示例
// ============================================================================

/**
 * 初始化以太网 MAC
 */
void eth_mac_init_example(void)
{
    // 1. 配置 MAC 地址
    uint8_t mac_addr[6] = {0x00, 0x11, 0x22, 0x33, 0x44, 0x55};
    eth_mac_set_address(mac_addr);
    
    // 2. 配置 IP 地址 (192.168.1.100)
    eth_mac_set_ip(0xC0A80164);
    
    // 3. 配置网关 (192.168.1.1)
    eth_mac_set_gateway(0xC0A80101);
    
    // 4. 配置子网掩码 (255.255.255.0)
    eth_mac_set_netmask(0xFFFFFF00);
    
    // 5. 配置过滤器 (使能 + 广播)
    eth_mac_config_filter(true, false, true, false);
    
    // 6. 设置帧间隙
    eth_mac_set_ifg(12);
    
    // 7. 使能中断
    eth_mac_irq_enable(true);
    
    // 8. 使能 MAC TX/RX 和 DMA
    eth_mac_tx_enable(true);
    eth_mac_rx_enable(true);
    eth_mac_dma_enable(true, true);
    
    // 9. 打印状态
    // printf("Ethernet MAC initialized\n");
    // printf("Link speed: %s\n", eth_mac_get_speed_string());
}

/**
 * 发送数据包示例
 */
void eth_mac_send_example(void)
{
    // 分配发送缓冲区 (必须是 DMA 可访问的物理地址)
    static uint8_t tx_buffer[1518] __attribute__((aligned(64)));
    
    // 填充以太网帧
    // 目标 MAC (6 bytes)
    tx_buffer[0] = 0xFF; tx_buffer[1] = 0xFF;
    tx_buffer[2] = 0xFF; tx_buffer[3] = 0xFF;
    tx_buffer[4] = 0xFF; tx_buffer[5] = 0xFF;
    
    // 源 MAC (6 bytes)
    tx_buffer[6] = 0x00; tx_buffer[7] = 0x11;
    tx_buffer[8] = 0x22; tx_buffer[9] = 0x33;
    tx_buffer[10] = 0x44; tx_buffer[11] = 0x55;
    
    // EtherType (2 bytes) - 0x0800 for IPv4
    tx_buffer[12] = 0x08; tx_buffer[13] = 0x00;
    
    // 填充数据...
    for (int i = 14; i < 64; i++) {
        tx_buffer[i] = i;
    }
    
    // 发送数据包 (最小64字节)
    uint32_t buffer_addr = (uint32_t)tx_buffer;
    if (eth_mac_send_packet(buffer_addr, 64, 0x01) == 0) {
        // printf("Packet sent\n");
    }
}

/**
 * 接收数据包示例
 */
void eth_mac_recv_example(void)
{
    // 分配接收缓冲区
    static uint8_t rx_buffer[2048] __attribute__((aligned(64)));
    
    // 配置接收
    uint32_t buffer_addr = (uint32_t)rx_buffer;
    if (eth_mac_recv_packet(buffer_addr, sizeof(rx_buffer), 0x01) == 0) {
        // 等待接收完成 (通过中断或轮询)
        while (eth_read_reg(ETH_REG_RX_DESC_VALID) & 0x1);
        
        // 检查中断状态
        uint32_t irq = eth_mac_get_irq_status();
        if (irq & ETH_IRQ_RX_DONE) {
            uint32_t rx_len = eth_mac_get_rx_length();
            // printf("Received packet: %d bytes\n", rx_len);
            
            // 处理接收到的数据
            // process_packet(rx_buffer, rx_len);
            
            // 清除中断
            eth_mac_clear_irq(ETH_IRQ_RX_DONE);
        }
    }
}

