`include "defines.v"
module if_stage(
    input  wire                  cpu_clk_50M,
    input  wire                  cpu_rst_n,
    input  wire                  stall_i,          // 流水线暂停信号（来自冒险单元）
    input  wire                  flush_i,          // 流水线冲刷信号（来自冒险单元）
    input  wire [`INST_ADDR_BUS] branch_target_i,  // 分支目标地址（来自执行阶段）
    input  wire                  branch_valid_i,   // 分支有效信号（来自执行阶段）
    output logic [`INST_ADDR_BUS] pc,              // 当前PC值
    output wire [`INST_ADDR_BUS]  iaddr,           // 指令存储器地址（当前PC）
    output wire [`INST_ADDR_BUS]  debug_wb_pc      // 调试用PC值
);
    wire [`INST_ADDR_BUS] pc_next;          // 下一个PC值
    wire [`INST_ADDR_BUS] pc_plus4;         // PC+4
    reg [`INST_ADDR_BUS]  delay_pc;         // 延迟转移用PC寄存器
    reg                   delay_branch;      // 延迟转移标记（分支有效延迟1周期）

    // 计算PC+4（指令按4字节对齐）
    assign pc_plus4 = pc + 4;

    // 延迟转移逻辑：分支指令后延迟1周期更新PC（符合PPT延迟转移设计）
    always @(posedge cpu_clk_50M or negedge cpu_rst_n) begin
        if (cpu_rst_n == `RST_ENABLE) begin
            delay_pc    <= `PC_INIT;
            delay_branch <= `FALSE_V;
        end else if (!stall_i) begin  // 无暂停时更新延迟寄存器
            delay_pc    <= branch_target_i;
            delay_branch <= branch_valid_i;
        end
    end

    // 下一个PC选择：延迟转移周期用分支目标地址，否则PC+4
    assign pc_next = delay_branch ? delay_pc : pc_plus4;

    // PC寄存器更新（支持暂停和冲刷）
    always @(posedge cpu_clk_50M or negedge cpu_rst_n) begin
        if (cpu_rst_n == `RST_ENABLE) begin
            pc <= `PC_INIT;
        end else if (flush_i) begin
            pc <= `PC_INIT;  // 冲刷时PC复位
        end else if (!stall_i) begin
            pc <= pc_next;   // 无暂停时更新PC
        end
    end

    // 指令存储器地址：当前PC（修正原代码pc_next错误）
    assign iaddr = (cpu_rst_n == `RST_ENABLE) ? `PC_INIT : pc;
    // 调试用PC值输出
    assign debug_wb_pc = pc;
endmodule