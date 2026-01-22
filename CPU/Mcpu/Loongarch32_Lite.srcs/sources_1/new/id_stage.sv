`include "defines.v"
module id_stage(
    input  wire                  cpu_clk_50M,
    input  wire                  cpu_rst_n,
    // 来自IF/ID寄存器的信号
    input  wire [`INST_ADDR_BUS] id_pc_i,           // 解码阶段PC值
    input  wire [`INST_ADDR_BUS] id_debug_wb_pc_i,  // 调试PC值
    input  wire [`INST_BUS]      id_inst_i,         // 待解码指令
    // 来自寄存器堆的信号
    input  wire [`REG_BUS]       rd1,               // 读端口1数据（rs1）
    input  wire [`REG_BUS]       rd2,               // 读端口2数据（rs2）
    // 来自前推单元的信号（数据前推：EXE/MEM/WB阶段结果）
    input  wire [`REG_BUS]       forward_data_exe,  // EXE阶段前推数据（最高优先级）
    input  wire [`REG_BUS]       forward_data_mem,  // MEM阶段前推数据
    input  wire [`REG_BUS]       forward_data_wb,   // WB阶段前推数据
    input  wire [1:0]            forward_sel1_i,    // rs1前推选择信号
    input  wire [1:0]            forward_sel2_i,    // rs2/rd前推选择信号
    // 输出到ID/EXE寄存器的信号
    output wire [`ALUTYPE_BUS]   id_alutype_o,      // 指令类型
    output wire [`ALUOP_BUS]     id_aluop_o,        // 指令操作码
    output wire [`REG_ADDR_BUS]  id_wa_o,           // 写回寄存器地址
    output wire                  id_wreg_o,         // 写寄存器使能
    output wire [`REG_BUS]       id_src1_o,         // 操作数1（rs1/PC）
    output wire [`REG_BUS]       id_src2_o,         // 操作数2（rs2/立即数/rd）
    output wire [`INST_ADDR_BUS] id_branch_target_o,// 分支目标地址（修正左移2位）
    output wire [`REG_ADDR_BUS]  ra1,               // 寄存器读地址1（rs1）
    output wire [`REG_ADDR_BUS]  ra2,               // 寄存器读地址2（rs2/rd）
    output wire [`INST_ADDR_BUS] debug_wb_pc        // 调试PC值输出
);
    // 指令字节序转换（小端→大端）
    wire [`INST_BUS] inst = {id_inst_i[7:0], id_inst_i[15:8], id_inst_i[23:16], id_inst_i[31:24]};

    // 提取指令字段（严格遵循LoongArch32规范）
    wire [5:0]  opcode1 = inst[31:26];  // 一级 opcode（31:26）
    wire [3:0]  opcode2 = inst[25:22];  // 二级 opcode（25:22）
    wire [6:0]  opcode3 = inst[21:15];  // 三级 opcode（3R型指令）
    wire [4:0]  rj      = inst[9:5];    // 源寄存器1（rs1：9:5）
    wire [4:0]  rk      = inst[14:10];  // 源寄存器2（rs2：14:10，3R型）
    wire [4:0]  rd      = inst[4:0];    // 目标寄存器（rd：4:0）/store源数据寄存器
    wire [11:0] imm12   = inst[21:10];  // 12位立即数（I型：21:10）
    wire [15:0] imm16   = inst[21:6];   // 16位立即数（分支：21:6）
    wire [19:0] imm20   = inst[24:5];   // 20位立即数（U型：24:5）

    // 指令识别信号
    wire inst_addw     = (opcode1 == 6'h00) && (opcode2 == 4'h00) && (opcode3 == 7'h20);
    wire inst_or       = (opcode1 == 6'h00) && (opcode2 == 4'h00) && (opcode3 == 7'h28);
    wire inst_xor      = (opcode1 == 6'h00) && (opcode2 == 4'h00) && (opcode3 == 7'h29);
    wire inst_sllw     = (opcode1 == 6'h00) && (opcode2 == 4'h00) && (opcode3 == 7'h2E);
    wire inst_addiw    = (opcode1 == 6'h00) && (opcode2 == 4'h08);
    wire inst_sltui    = (opcode1 == 6'h00) && (opcode2 == 4'h09);
    wire inst_andi     = (opcode1 == 6'h00) && (opcode2 == 4'h0D);
    wire inst_ori      = (opcode1 == 6'h00) && (opcode2 == 4'h0E);
    wire inst_lu12iw   = (opcode1 == 6'h05);  // LoongArch规范opcode1=0x05
    wire inst_pcaddu12i= (opcode1 == 6'h07);
    wire inst_load     = (opcode1 == 6'h0A);  // load opcode1=0x0A（规范附录B）
    wire inst_store    = (opcode1 == 6'h0B);  // store opcode1=0x0B（规范附录B）
    wire inst_beq      = (opcode1 == 6'h16);
    wire inst_bne      = (opcode1 == 6'h17);
    wire inst_bgeu     = (opcode1 == 6'h1B);
    wire inst_ldb      = inst_load && (opcode2 == 4'h00);
    wire inst_ldw      = inst_load && (opcode2 == 4'h02);
    wire inst_stb      = inst_store && (opcode2 == 4'h04);
    wire inst_stw      = inst_store && (opcode2 == 4'h06);

    // 生成alutype（指令类型）
    assign id_alutype_o = inst_addw  ? `ARITH   :
                          inst_addiw ? `ARITH   :
                          inst_or    ? `LOGIC   :
                          inst_ori   ? `LOGIC   :
                          inst_andi  ? `LOGIC   :
                          inst_xor   ? `LOGIC   :
                          inst_sltui ? `ARITH   :
                          inst_sllw  ? `SHIFT   :
                          inst_lu12iw? `MOVE    :
                          inst_pcaddu12i ? `MOVE :
                          inst_beq   ? `BRANCH  :
                          inst_bne   ? `BRANCH  :
                          inst_bgeu  ? `BRANCH  :
                          inst_ldb   ? `LOAD    :
                          inst_ldw   ? `LOAD    :
                          inst_stb   ? `STORE   :
                          inst_stw   ? `STORE   : `NOP;

    // 生成aluop（指令操作码）
    assign id_aluop_o = inst_addw  ? `LoongArch32_ADD_W    :
                        inst_addiw ? `LoongArch32_ADDI_W   :
                        inst_or    ? `LoongArch32_OR       :
                        inst_ori   ? `LoongArch32_ORI      :
                        inst_andi  ? `LoongArch32_ANDI     :
                        inst_xor   ? `LoongArch32_XOR      :
                        inst_sltui ? `LoongArch32_SLTU     :
                        inst_sllw  ? `LoongArch32_SLL      :
                        inst_lu12iw? `LoongArch32_LU12I_W  :
                        inst_pcaddu12i ? `LoongArch32_PCADDU12I :
                        inst_beq   ? `LoongArch32_BEQ      :
                        inst_bne   ? `LoongArch32_BNE      :
                        inst_bgeu  ? `LoongArch32_BGEU     :
                        inst_ldb   ? `LoongArch32_LD_B     :
                        inst_ldw   ? `LoongArch32_LD_W     :
                        inst_stb   ? `LoongArch32_ST_B     :
                        inst_stw   ? `LoongArch32_ST_W     : `LoongArch32_SLL;

    // 生成写寄存器使能（store/branch不写寄存器）
    assign id_wreg_o = !(inst_store || inst_beq || inst_bne || inst_bgeu);
    // 生成写回寄存器地址（rd）
    assign id_wa_o = rd;

    // 生成寄存器读地址（store的ra2=rd，3R型ra2=rk）
    assign ra1 = rj;  // 所有指令rs1=rj
    assign ra2 = inst_store ? rd :
                 (inst_addw || inst_or || inst_xor || inst_sllw) ? rk : 5'h0;

    // 立即数扩展逻辑（严格遵循LoongArch规范）
    wire [`REG_BUS] imm12_sext = {{20{imm12[11]}}, imm12};  // 12位符号扩展
    wire [`REG_BUS] imm12_zext = {20'h00000, imm12};        // 12位零扩展
    wire [`REG_BUS] imm16_sext = {{16{imm16[15]}}, imm16};  // 16位符号扩展（分支）
    wire [`REG_BUS] imm20_sh12 = {imm20, 12'h000};          // lu12i.w：20位左移12位
    wire [`REG_BUS] imm20_sext_sh12 = {{12{imm20[19]}}, imm20, 12'h000};  // pcaddu12i符号扩展

    // 操作数1前推选择（EXE > MEM > WB > 寄存器堆）
    wire [`REG_BUS] op1_reg = (forward_sel1_i == 2'b01) ? forward_data_exe :
                              (forward_sel1_i == 2'b10) ? forward_data_mem :
                              (forward_sel1_i == 2'b11) ? forward_data_wb  : rd1;
    wire [`REG_BUS] op1 = inst_pcaddu12i ? id_pc_i : op1_reg;  // pcaddu12i：op1=PC

    // 操作数2前推选择（覆盖store的rd前推）
    wire [`REG_BUS] op2_reg = (forward_sel2_i == 2'b01) ? forward_data_exe :
                              (forward_sel2_i == 2'b10) ? forward_data_mem :
                              (forward_sel2_i == 2'b11) ? forward_data_wb  : rd2;
    wire [`REG_BUS] op2 = inst_addiw  ? imm12_sext :
                          inst_ori    ? imm12_zext :
                          inst_andi   ? imm12_zext :
                          inst_sltui  ? imm12_zext :
                          inst_lu12iw ? imm20_sh12 :
                          inst_pcaddu12i ? imm20_sext_sh12 :
                          inst_load   ? imm12_sext :
                          inst_store  ? op2_reg :  // store：op2=rd的值（经前推）
                          op2_reg;

    // 输出最终操作数
    assign id_src1_o = op1;
    assign id_src2_o = op2;

    // 分支目标地址计算（修正：imm16左移2位，符合LoongArch规范）
    assign id_branch_target_o = id_pc_i + 4 + (imm16_sext << 2);

    // 调试PC值输出
    assign debug_wb_pc = id_debug_wb_pc_i;
endmodule