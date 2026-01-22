`include "defines.v"
module ifid_reg(
    input  wire                  cpu_clk_50M,
    input  wire                  cpu_rst_n,
    input  wire                  stall_i,          // 流水线暂停信号（保持）
    input  wire                  flush_i,          // 流水线冲刷信号（清零）
    // 来自取指阶段的信号
    input  wire [`INST_ADDR_BUS] if_pc,            // 取指阶段PC值
    input  wire [`INST_ADDR_BUS] if_debug_wb_pc,    // 取指阶段调试PC
    input  wire [`INST_BUS]      inst,              // 读取的指令
    // 输出到解码阶段的信号
    output reg [`INST_ADDR_BUS]  id_pc,             // 解码阶段PC值
    output reg [`INST_BUS]       id_inst,           // 解码阶段指令
    output reg [`INST_ADDR_BUS]  id_debug_wb_pc     // 解码阶段调试PC
);
    always @(posedge cpu_clk_50M or negedge cpu_rst_n) begin
        if (cpu_rst_n == `RST_ENABLE) begin
            id_pc           <= `PC_INIT;
            id_debug_wb_pc  <= `PC_INIT;
            id_inst         <= `ZERO_WORD;
        end else if (flush_i) begin
            // 冲刷时清零指令和PC
            id_pc           <= `PC_INIT;
            id_debug_wb_pc  <= `PC_INIT;
            id_inst         <= `ZERO_WORD;
        end else if (!stall_i) begin
            // 无暂停时传递取指阶段信号
            id_pc           <= if_pc;
            id_debug_wb_pc  <= if_debug_wb_pc;
            id_inst         <= inst;
        end
        // 暂停时保持原有值
    end
endmodule