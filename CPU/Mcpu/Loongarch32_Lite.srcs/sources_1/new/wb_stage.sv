`include "defines.v"
module wb_stage(
    input  wire [`REG_ADDR_BUS]  wb_wa_i,          // 写回地址（来自MEM/WB寄存器）
    input  wire                  wb_wreg_i,        // 写回使能（来自MEM/WB寄存器）
    input  wire [`REG_BUS]       wb_dreg_i,        // 写回数据（来自MEM/WB寄存器）
    input  wire [`INST_ADDR_BUS] wb_debug_wb_pc_i, // 调试PC值（来自MEM/WB寄存器）
    // 输出到寄存器堆的信号
    output wire [`REG_ADDR_BUS]  wb_wa_o,          // 写回地址（对接寄存器堆wa）
    output wire                  wb_wreg_o,        // 写回使能（对接寄存器堆we）
    output wire [`WORD_BUS]      wb_wd_o,          // 写回数据（对接寄存器堆wd）
    // 调试信号输出（对接顶层模块）
    output wire [`INST_ADDR_BUS] debug_wb_pc,      // 调试用PC值
    output wire                  debug_wb_rf_wen,  // 寄存器写使能（调试）
    output wire [`REG_ADDR_BUS]  debug_wb_rf_wnum, // 写回寄存器编号（调试）
    output wire [`WORD_BUS]      debug_wb_rf_wdata // 写回寄存器数据（调试）
);
    // 直接传递写回信号到寄存器堆（保持原有直通逻辑）
    assign wb_wa_o = wb_wa_i;
    assign wb_wreg_o = wb_wreg_i;
    assign wb_wd_o = wb_dreg_i;

    // 调试信号直接映射（保持原有调试逻辑）
    assign debug_wb_pc = wb_debug_wb_pc_i;
    assign debug_wb_rf_wen = wb_wreg_i;
    assign debug_wb_rf_wnum = wb_wa_i;
    assign debug_wb_rf_wdata = wb_dreg_i;
endmodule