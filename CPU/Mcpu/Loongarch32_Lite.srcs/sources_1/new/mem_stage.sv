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
assign daddr  = mem_mem_addr_i;
assign din    = mem_mem_wdata_i;
assign we     = mem_mem_we_i;
assign mem_sel = mem_mem_sel_i;

// 修复：ld.b 字节选择+符号扩展，ld.w 直接加载
reg [`REG_BUS] load_res;
always @(*) begin
case (mem_aluop_i)
`LoongArch32_LD_B: begin  
    case (mem_mem_sel_i)
        2'b01: load_res = {{24{dout[7]}},  dout[7:0]};   // 地址0x0 → 第0字节
        2'b10: load_res = {{24{dout[15]}}, dout[15:8]};  // 地址0x1 → 第1字节
        2'b11: load_res = {{24{dout[23]}}, dout[23:16]}; // 地址0x2 → 第2字节
        2'b00: load_res = {{24{dout[31]}}, dout[31:24]}; // 地址0x3 → 第3字节
        default: load_res = {{24{dout[7]}}, dout[7:0]};
    endcase
end
`LoongArch32_LD_W: begin  
    load_res = dout;
end
default: begin
    load_res = mem_wd_i;
end
endcase
end

// 写回数据输出
assign mem_dreg_o = (mem_aluop_i == `LoongArch32_LD_B || mem_aluop_i == `LoongArch32_LD_W) ? load_res : mem_wd_i;
// 传递到WB阶段的信号
assign mem_wa_o = mem_wa_i;
assign mem_wreg_o = mem_wreg_i;
// 调试PC值输出
assign debug_wb_pc = mem_debug_wb_pc_i;
endmodule