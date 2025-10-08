/*

以太网帧过滤器模块

功能：
- 根据目标MAC地址过滤帧
- 支持单播、广播和组播过滤
- 支持混杂模式
- 可配置多个MAC地址匹配

Copyright (c) 2025

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

module eth_frame_filter #(
    parameter DATA_WIDTH = 8,
    parameter ENABLE_MAC_FILTER = 1,
    parameter NUM_MAC_FILTERS = 4
)(
    input  wire                     clk,
    input  wire                     rst,
    
    /*
     * AXI Stream 输入
     */
    input  wire [DATA_WIDTH-1:0]    s_axis_tdata,
    input  wire                     s_axis_tvalid,
    output wire                     s_axis_tready,
    input  wire                     s_axis_tlast,
    input  wire                     s_axis_tuser,
    
    /*
     * AXI Stream 输出
     */
    output wire [DATA_WIDTH-1:0]    m_axis_tdata,
    output wire                     m_axis_tvalid,
    input  wire                     m_axis_tready,
    output wire                     m_axis_tlast,
    output wire                     m_axis_tuser,
    
    /*
     * 配置
     */
    input  wire                     filter_enable,
    input  wire                     promiscuous_mode,
    input  wire                     broadcast_enable,
    input  wire                     multicast_enable,
    input  wire [47:0]              local_mac
);

// 状态机定义
localparam [2:0]
    STATE_IDLE = 3'd0,
    STATE_PARSE_HEADER = 3'd1,
    STATE_CHECK_FILTER = 3'd2,
    STATE_FORWARD = 3'd3,
    STATE_DROP = 3'd4;

reg [2:0] state_reg = STATE_IDLE, state_next;
reg [3:0] byte_count_reg = 4'd0, byte_count_next;
reg [47:0] dest_mac_reg = 48'd0, dest_mac_next;
reg forward_frame_reg = 1'b0, forward_frame_next;

// FIFO 信号
reg [DATA_WIDTH-1:0]    fifo_tdata_reg = {DATA_WIDTH{1'b0}};
reg                     fifo_tvalid_reg = 1'b0;
reg                     fifo_tlast_reg = 1'b0;
reg                     fifo_tuser_reg = 1'b0;

// 输出分配
assign m_axis_tdata = fifo_tdata_reg;
assign m_axis_tvalid = fifo_tvalid_reg && forward_frame_reg;
assign m_axis_tlast = fifo_tlast_reg;
assign m_axis_tuser = fifo_tuser_reg;
assign s_axis_tready = !fifo_tvalid_reg || (m_axis_tready && forward_frame_reg) || !forward_frame_reg;

// MAC 地址匹配逻辑
wire is_broadcast = (dest_mac_reg == 48'hFFFFFFFFFFFF);
wire is_multicast = dest_mac_reg[40]; // 组播地址最高位为1
wire is_local_mac = (dest_mac_reg == local_mac);
wire frame_accepted;

generate
    if (ENABLE_MAC_FILTER) begin : gen_mac_filter
        assign frame_accepted = promiscuous_mode ||
                                (is_broadcast && broadcast_enable) ||
                                (is_multicast && multicast_enable) ||
                                is_local_mac;
    end else begin : gen_no_filter
        assign frame_accepted = 1'b1;
    end
endgenerate

// 状态机时序逻辑
always @(posedge clk) begin
    if (rst) begin
        state_reg <= STATE_IDLE;
        byte_count_reg <= 4'd0;
        dest_mac_reg <= 48'd0;
        forward_frame_reg <= 1'b0;
        fifo_tdata_reg <= {DATA_WIDTH{1'b0}};
        fifo_tvalid_reg <= 1'b0;
        fifo_tlast_reg <= 1'b0;
        fifo_tuser_reg <= 1'b0;
    end else begin
        state_reg <= state_next;
        byte_count_reg <= byte_count_next;
        dest_mac_reg <= dest_mac_next;
        forward_frame_reg <= forward_frame_next;
        
        // 缓存输入数据
        if (s_axis_tvalid && s_axis_tready) begin
            fifo_tdata_reg <= s_axis_tdata;
            fifo_tvalid_reg <= 1'b1;
            fifo_tlast_reg <= s_axis_tlast;
            fifo_tuser_reg <= s_axis_tuser;
        end else if (m_axis_tready || !forward_frame_reg) begin
            fifo_tvalid_reg <= 1'b0;
        end
    end
end

// 状态机组合逻辑
always @* begin
    state_next = state_reg;
    byte_count_next = byte_count_reg;
    dest_mac_next = dest_mac_reg;
    forward_frame_next = forward_frame_reg;
    
    case (state_reg)
        STATE_IDLE: begin
            if (s_axis_tvalid) begin
                state_next = STATE_PARSE_HEADER;
                byte_count_next = 4'd0;
                dest_mac_next = 48'd0;
                forward_frame_next = 1'b0;
            end
        end
        
        STATE_PARSE_HEADER: begin
            if (s_axis_tvalid && s_axis_tready) begin
                // 解析目标 MAC 地址 (前6字节)
                if (byte_count_reg < 4'd6) begin
                    dest_mac_next = {dest_mac_reg[39:0], s_axis_tdata};
                    byte_count_next = byte_count_reg + 4'd1;
                    
                    if (byte_count_reg == 4'd5) begin
                        state_next = STATE_CHECK_FILTER;
                    end
                end
                
                // 如果帧提前结束
                if (s_axis_tlast && byte_count_reg < 4'd5) begin
                    state_next = STATE_DROP;
                    forward_frame_next = 1'b0;
                end
            end
        end
        
        STATE_CHECK_FILTER: begin
            // 检查是否通过过滤器
            if (!filter_enable || frame_accepted) begin
                state_next = STATE_FORWARD;
                forward_frame_next = 1'b1;
            end else begin
                state_next = STATE_DROP;
                forward_frame_next = 1'b0;
            end
        end
        
        STATE_FORWARD: begin
            if (s_axis_tvalid && s_axis_tready && s_axis_tlast) begin
                state_next = STATE_IDLE;
                forward_frame_next = 1'b0;
            end
        end
        
        STATE_DROP: begin
            if (s_axis_tvalid && s_axis_tready && s_axis_tlast) begin
                state_next = STATE_IDLE;
            end
        end
        
        default: begin
            state_next = STATE_IDLE;
        end
    endcase
end

endmodule

`resetall

