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
// 直接连接外部访存信号
assign daddr  = mem_mem_addr_i;    // 访存地址传递到外部data_ram
assign din    = mem_mem_wdata_i;   // 写数据传递到外部data_ram
assign we     = mem_mem_we_i;      // 写使能传递到外部data_ram
assign mem_sel = mem_mem_sel_i;    // 保持字节选择信号赋值
// 写回数据选择（修正ld.b符号扩展，保持原有逻辑）
reg [`REG_BUS] load_res;
always @(*) begin
case (mem_aluop_i)
`LoongArch32_LD_B: begin  // 符号扩展低8位（符合LoongArch规范）
    load_res = {{24{dout[7]}}, dout[7:0]};
end
`LoongArch32_LD_W: begin  // 直接取32位数据
    load_res = dout;
end
default: begin
    load_res = mem_wd_i;  // 非加载指令，使用执行阶段结果
end
endcase
end
// 写回数据输出：加载指令用存储器读数据，其他用执行结果
assign mem_dreg_o = (mem_aluop_i == `LoongArch32_LD_B || mem_aluop_i == `LoongArch32_LD_W) ? load_res : mem_wd_i;
// 传递到WB阶段的信号
assign mem_wa_o = mem_wa_i;
assign mem_wreg_o = mem_wreg_i;
// 调试PC值输出
assign debug_wb_pc = mem_debug_wb_pc_i;
endmodule