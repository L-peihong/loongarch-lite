`include "defines.v"
module memwb_reg(
    input  wire                  cpu_clk_50M,
    input  wire                  cpu_rst_n,
    input  wire                  stall_i,          // 流水线暂停信号
    // 来自访存阶段的信号
    input  wire [`REG_ADDR_BUS]  mem_wa,           // 写回地址
    input  wire                  mem_wreg,         // 写回使能
    input  wire [`REG_BUS]       mem_dreg,         // 写回数据
    input  wire [`INST_ADDR_BUS] mem_debug_wb_pc,  // 调试PC值
    // 输出到写回阶段的信号
    output reg [`REG_ADDR_BUS]   wb_wa,            // 写回地址
    output reg                   wb_wreg,          // 写回使能
    output reg [`REG_BUS]        wb_dreg,          // 写回数据
    output reg [`INST_ADDR_BUS]  wb_debug_wb_pc    // 调试PC值
);
    always @(posedge cpu_clk_50M or negedge cpu_rst_n) begin
        if (cpu_rst_n == `RST_ENABLE) begin
            wb_wa             <= `REG_NOP;
            wb_wreg           <= `WRITE_DISABLE;
            wb_dreg           <= `ZERO_WORD;
            wb_debug_wb_pc    <= `PC_INIT;
        end else if (!stall_i) begin
            // 无暂停时传递访存阶段信号
            wb_wa             <= mem_wa;
            wb_wreg           <= mem_wreg;
            wb_dreg           <= mem_dreg;
            wb_debug_wb_pc    <= mem_debug_wb_pc;
        end
    end
endmodule