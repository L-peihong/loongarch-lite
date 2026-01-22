`include "defines.v"
module hazard_unit(
input  wire                  cpu_rst_n,
// 来自解码阶段的信号
input  wire [`REG_ADDR_BUS]  id_ra1_i,          // 解码阶段rs1地址（rj）
input  wire [`REG_ADDR_BUS]  id_ra2_i,          // 解码阶段rs2地址（rk/rd）
input  wire [`ALUTYPE_BUS]   id_alutype_i,      // 解码阶段指令类型
// 来自执行阶段的信号
input  wire [`REG_ADDR_BUS]  exe_wa_i,          // 执行阶段写回地址
input  wire                  exe_wreg_i,        // 执行阶段写回使能
input  wire [`ALUTYPE_BUS]   exe_alutype_i,     // 执行阶段指令类型
// 来自访存阶段的信号
input  wire [`REG_ADDR_BUS]  mem_wa_i,          // 访存阶段写回地址
input  wire                  mem_wreg_i,        // 访存阶段写回使能
// 来自写回阶段的信号
input  wire [`REG_ADDR_BUS]  wb_wa_i,           // 写回阶段写回地址
input  wire                  wb_wreg_i,         // 写回阶段写回使能
// 输出控制信号
output reg [1:0]             forward_sel1_o,    // rs1前推选择（00:无 01:EXE 10:MEM 11:WB）
output reg [1:0]             forward_sel2_o,    // rs2/rd前推选择
output reg                   stall_o,           // 流水线暂停信号（IF/ID保持）
output reg                   flush_o            // 流水线冲刷信号（复位时）
);
// 数据冒险检测：rs1冲突（EXE/MEM/WB阶段写回地址与rs1相同）
wire rs1_exe_hazard = (id_ra1_i == exe_wa_i) && exe_wreg_i && (id_ra1_i != `REG_NOP);
wire rs1_mem_hazard = (id_ra1_i == mem_wa_i) && mem_wreg_i && (id_ra1_i != `REG_NOP) && !rs1_exe_hazard;
wire rs1_wb_hazard  = (id_ra1_i == wb_wa_i)  && wb_wreg_i  && (id_ra1_i != `REG_NOP) && !rs1_exe_hazard && !rs1_mem_hazard;

// 数据冒险检测：rs2/rd冲突（含3R型的rk和store的rd）
wire rs2_exe_hazard = (id_ra2_i == exe_wa_i) && exe_wreg_i && (id_ra2_i != `REG_NOP);
wire rs2_mem_hazard = (id_ra2_i == mem_wa_i) && mem_wreg_i && (id_ra2_i != `REG_NOP) && !rs2_exe_hazard;
wire rs2_wb_hazard  = (id_ra2_i == wb_wa_i)  && wb_wreg_i  && (id_ra2_i != `REG_NOP) && !rs2_exe_hazard && !rs2_mem_hazard;

// load-use冒险检测（EXE是LOAD，且ID阶段使用其结果）
wire load_use_hazard = (exe_alutype_i == `LOAD) && (rs1_exe_hazard || rs2_exe_hazard);

// 分支冒险检测（ID阶段是分支指令）
wire branch_hazard = (id_alutype_i == `BRANCH);

// 数据前推选择逻辑（优先级：EXE > MEM > WB，确保3R型指令rs2前推）
always @(*) begin
// rs1前推选择
if (rs1_exe_hazard) begin
    forward_sel1_o = 2'b01;  // 前推EXE阶段结果
end else if (rs1_mem_hazard) begin
    forward_sel1_o = 2'b10;  // 前推MEM阶段结果
end else if (rs1_wb_hazard) begin
    forward_sel1_o = 2'b11;  // 前推WB阶段结果
end else begin
    forward_sel1_o = 2'b00;  // 不前推（使用寄存器堆数据）
end

// rs2/rd前推选择（核心：3R型的rk也走此逻辑，确保前推生效）
if (rs2_exe_hazard) begin
    forward_sel2_o = 2'b01;
end else if (rs2_mem_hazard) begin
    forward_sel2_o = 2'b10;
end else if (rs2_wb_hazard) begin
    forward_sel2_o = 2'b11;
end else begin
    forward_sel2_o = 2'b00;
end
end

// 流水线暂停逻辑：load-use冒险或分支冒险时暂停（IF/ID保持，EXE清零）
always @(*) begin
if (cpu_rst_n == `RST_ENABLE) begin
    stall_o = `FALSE_V;
end else begin
    stall_o = load_use_hazard || branch_hazard;
end
end

// 流水线冲刷逻辑：仅复位时冲刷
always @(*) begin
if (cpu_rst_n == `RST_ENABLE) begin
    flush_o = `TRUE_V;
end else begin
    flush_o = `FALSE_V;
end
end
endmodule