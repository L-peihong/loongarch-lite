`include "defines.v"
module idexe_reg(
    input  wire                  cpu_clk_50M,
    input  wire                  cpu_rst_n,
    input  wire                  stall_i,          // 流水线暂停信号
    input  wire                  flush_i,          // 流水线冲刷信号（EXE阶段清零）
    // 来自解码阶段的信号
    input  wire [`ALUTYPE_BUS]   id_alutype,       // 指令类型
    input  wire [`ALUOP_BUS]     id_aluop,         // 操作码
    input  wire [`REG_BUS]       id_src1,          // 操作数1
    input  wire [`REG_BUS]       id_src2,          // 操作数2
    input  wire [`REG_ADDR_BUS]  id_wa,            // 写回地址
    input  wire                  id_wreg,          // 写回使能
    input  wire [`INST_ADDR_BUS] id_debug_wb_pc,   // 调试PC值
    input  wire [`INST_ADDR_BUS] id_branch_target, // 分支目标地址
    // 输出到执行阶段的信号
    output reg [`ALUTYPE_BUS]    exe_alutype,      // 指令类型
    output reg [`ALUOP_BUS]      exe_aluop,        // 操作码
    output reg [`REG_BUS]        exe_src1,         // 操作数1
    output reg [`REG_BUS]        exe_src2,         // 操作数2
    output reg [`REG_ADDR_BUS]   exe_wa,           // 写回地址
    output reg                   exe_wreg,         // 写回使能
    output reg [`INST_ADDR_BUS]  exe_debug_wb_pc,  // 调试PC值
    output reg [`INST_ADDR_BUS]  exe_branch_target // 分支目标地址
);
    always @(posedge cpu_clk_50M or negedge cpu_rst_n) begin
        if (cpu_rst_n == `RST_ENABLE) begin
            exe_alutype        <= `NOP;
            exe_aluop          <= `LoongArch32_SLL;
            exe_src1           <= `ZERO_WORD;
            exe_src2           <= `ZERO_WORD;
            exe_wa             <= `REG_NOP;
            exe_wreg           <= `WRITE_DISABLE;
            exe_debug_wb_pc    <= `PC_INIT;
            exe_branch_target  <= `PC_INIT;
        end else if (flush_i || stall_i) begin
            // 冲刷或暂停时，EXE阶段清零（避免错误执行）
            exe_alutype        <= `NOP;
            exe_aluop          <= `LoongArch32_SLL;
            exe_src1           <= `ZERO_WORD;
            exe_src2           <= `ZERO_WORD;
            exe_wa             <= `REG_NOP;
            exe_wreg           <= `WRITE_DISABLE;
            exe_debug_wb_pc    <= `PC_INIT;
            exe_branch_target  <= `PC_INIT;
        end else begin
            // 无暂停时传递解码阶段信号
            exe_alutype        <= id_alutype;
            exe_aluop          <= id_aluop;
            exe_src1           <= id_src1;
            exe_src2           <= id_src2;
            exe_wa             <= id_wa;
            exe_wreg           <= id_wreg;
            exe_debug_wb_pc    <= id_debug_wb_pc;
            exe_branch_target  <= id_branch_target;
        end
    end
endmodule