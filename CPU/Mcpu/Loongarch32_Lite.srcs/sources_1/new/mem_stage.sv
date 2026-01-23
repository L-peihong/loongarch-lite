`include "defines.v"
module mem_stage(
input  wire                  cpu_clk_50M,
input  wire                  cpu_rst_n,
input  wire [`ALUOP_BUS]     mem_aluop_i,
input  wire [`REG_ADDR_BUS]  mem_wa_i,
input  wire                  mem_wreg_i,
input  wire [`REG_BUS]       mem_wd_i,
input  wire [`REG_BUS]       mem_mem_addr_i,
input  wire [`REG_BUS]       mem_mem_wdata_i,
input  wire                  mem_mem_we_i,
input  wire [1:0]            mem_mem_sel_i,
input  wire [`INST_ADDR_BUS] mem_debug_wb_pc_i,
input  wire [`REG_BUS]       dout,
// 输出到外部data_ram的信号
output wire [`INST_ADDR_BUS]  daddr,
output wire [`REG_BUS]       din,
output wire                  we,
output wire [1:0]            mem_sel,
// 输出到写回阶段的信号
output wire [`REG_ADDR_BUS]  mem_wa_o,
output wire                  mem_wreg_o,
output wire [`REG_BUS]       mem_dreg_o,
output wire [`INST_ADDR_BUS] debug_wb_pc
);
// 直接连接外部访存信号（与EXE阶段修正后的字节选择信号联动）
assign daddr  = mem_mem_addr_i;    // 传递EXE阶段计算的访存地址（含地址低位，用于字节选择）
assign din    = mem_mem_wdata_i;   // 传递store指令的写数据（经前推，来自rd寄存器）
assign we     = mem_mem_we_i;      // 传递store指令写使能
assign mem_sel = mem_mem_sel_i;    // 传递EXE阶段修正后的字节选择信号（关联地址低位）

// 写回数据选择（严格遵循LoongArch32规范：ld.b符号扩展，ld.w直接加载）
reg [`REG_BUS] load_res;
always @(*) begin
case (mem_aluop_i)
`LoongArch32_LD_B: begin  // ld.b：符号扩展低8位到32位（小端字节序，取dout[7:0]）
    load_res = {{24{dout[7]}}, dout[7:0]};
end
`LoongArch32_LD_W: begin  // ld.w：直接取32位数据（自然对齐，小端拼接后完整32位）
    load_res = dout;
end
default: begin
    load_res = mem_wd_i;  // 非加载指令（算术/逻辑/移动等），使用EXE阶段执行结果
end
endcase
end

// 写回数据输出：加载指令用存储器读数据，其他指令用EXE阶段结果
assign mem_dreg_o = (mem_aluop_i == `LoongArch32_LD_B || mem_aluop_i == `LoongArch32_LD_W) ? load_res : mem_wd_i;

// 传递到WB阶段的信号（保持与流水线同步）
assign mem_wa_o = mem_wa_i;    // 写回地址
assign mem_wreg_o = mem_wreg_i; // 写回使能

// 调试PC值输出（对接顶层调试接口）
assign debug_wb_pc = mem_debug_wb_pc_i;

endmodule