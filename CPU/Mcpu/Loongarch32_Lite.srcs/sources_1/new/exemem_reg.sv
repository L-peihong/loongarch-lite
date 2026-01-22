`include "defines.v"
module exemem_reg(
    input  wire                  cpu_clk_50M,
    input  wire                  cpu_rst_n,
    input  wire                  stall_i,          // 流水线暂停信号
    // 来自执行阶段的信号
    input  wire [`ALUOP_BUS]     exe_aluop,        // 操作码
    input  wire [`REG_ADDR_BUS]  exe_wa,           // 写回地址
    input  wire                  exe_wreg,         // 写回使能
    input  wire [`REG_BUS]       exe_wd,           // 执行结果
    input  wire [`REG_BUS]       exe_mem_addr,     // 访存地址
    input  wire [`REG_BUS]       exe_mem_wdata,    // 访存写数据
    input  wire                  exe_mem_we,       // 访存写使能
    input  wire [1:0]            exe_mem_sel,      // 访存字节选择
    input  wire [`INST_ADDR_BUS] exe_debug_wb_pc,  // 调试PC值
    // 输出到访存阶段的信号
    output reg [`ALUOP_BUS]      mem_aluop,        // 操作码
    output reg [`REG_ADDR_BUS]   mem_wa,           // 写回地址
    output reg                   mem_wreg,         // 写回使能
    output reg [`REG_BUS]        mem_wd,           // 执行结果
    output reg [`REG_BUS]        mem_mem_addr,     // 访存地址
    output reg [`REG_BUS]        mem_mem_wdata,    // 访存写数据
    output reg                   mem_mem_we,       // 访存写使能
    output reg [1:0]             mem_mem_sel,      // 访存字节选择
    output reg [`INST_ADDR_BUS]  mem_debug_wb_pc   // 调试PC值
);
    always @(posedge cpu_clk_50M or negedge cpu_rst_n) begin
        if (cpu_rst_n == `RST_ENABLE) begin
            mem_aluop         <= `LoongArch32_SLL;
            mem_wa            <= `REG_NOP;
            mem_wreg          <= `WRITE_DISABLE;
            mem_wd            <= `ZERO_WORD;
            mem_mem_addr      <= `ZERO_WORD;
            mem_mem_wdata     <= `ZERO_WORD;
            mem_mem_we        <= `WRITE_DISABLE;
            mem_mem_sel       <= 2'b00;
            mem_debug_wb_pc   <= `PC_INIT;
        end else if (!stall_i) begin
            // 无暂停时传递执行阶段信号
            mem_aluop         <= exe_aluop;
            mem_wa            <= exe_wa;
            mem_wreg          <= exe_wreg;
            mem_wd            <= exe_wd;
            mem_mem_addr      <= exe_mem_addr;
            mem_mem_wdata     <= exe_mem_wdata;
            mem_mem_we        <= exe_mem_we;
            mem_mem_sel       <= exe_mem_sel;
            mem_debug_wb_pc   <= exe_debug_wb_pc;
        end
    end
endmodule