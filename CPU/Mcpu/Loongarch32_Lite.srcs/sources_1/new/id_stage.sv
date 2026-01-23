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
    output wire [`INST_ADDR_BUS] id_branch_target_o,// 分支目标地址
    
    // 输出到寄存器堆/冒险单元的信号
    output wire [`REG_ADDR_BUS]  ra1,               // 寄存器读地址1（rs1）
    output wire [`REG_ADDR_BUS]  ra2,               // 寄存器读地址2（rs2）
    output wire [`INST_ADDR_BUS] debug_wb_pc        // 调试PC值输出
);

    // 1. 指令字节序转换（假设 inst_rom 按照小端序输出，此处需调整为符合阅读习惯的大端序）
    // 如果你的 inst_rom IP 核已经配置为 Word 访问且不需要交换，请注释掉此行直接用 id_inst_i
    wire [`INST_BUS] inst = {id_inst_i[7:0], id_inst_i[15:8], id_inst_i[23:16], id_inst_i[31:24]};

    // 2. 提取指令字段（严格遵循 LoongArch32 规范）
    wire [5:0]  opcode1 = inst[31:26];  // 一级 opcode
    wire [3:0]  opcode2 = inst[25:22];  // 二级 opcode
    wire [6:0]  opcode3 = inst[21:15];  // 三级 opcode
    wire [4:0]  rj      = inst[9:5];    // 源寄存器1 (Base)
    wire [4:0]  rk      = inst[14:10];  // 源寄存器2 (3R型)
    wire [4:0]  rd      = inst[4:0];    // 目标寄存器 / Store源数据
    wire [11:0] imm12   = inst[21:10];  // 12位立即数
    wire [15:0] imm16   = inst[21:6];   // 16位立即数 (Branch)
    wire [19:0] imm20   = inst[24:5];   // 20位立即数 (Lu12i)

    // 3. 指令识别信号
    // 算术运算
    wire inst_addw     = (opcode1 == 6'h00) && (opcode2 == 4'h00) && (opcode3 == 7'h20);
    // [FIX] 关键修复：addi.w 的 opcode2 是 0x0A，不是 0x08
    wire inst_addiw    = (opcode1 == 6'h00) && (opcode2 == 4'h0A); 
    wire inst_sltui    = (opcode1 == 6'h00) && (opcode2 == 4'h09);
    
    // 逻辑运算
    wire inst_or       = (opcode1 == 6'h00) && (opcode2 == 4'h00) && (opcode3 == 7'h2A);
    wire inst_xor      = (opcode1 == 6'h00) && (opcode2 == 4'h00) && (opcode3 == 7'h2B);
    wire inst_andi     = (opcode1 == 6'h00) && (opcode2 == 4'h0D);
    wire inst_ori      = (opcode1 == 6'h00) && (opcode2 == 4'h0E);
    
    // 移位运算
    wire inst_sllw     = (opcode1 == 6'h00) && (opcode2 == 4'h00) && (opcode3 == 7'h2E);
    
    // 访存指令
    wire inst_load     = (opcode1 == 6'h0A);
    wire inst_store    = (opcode1 == 6'h0B);
    wire inst_ldb      = inst_load && (opcode2 == 4'h00);
    wire inst_ldw      = inst_load && (opcode2 == 4'h02);
    wire inst_stb      = inst_store && (opcode2 == 4'h04);
    wire inst_stw      = inst_store && (opcode2 == 4'h06);
    
    // 分支跳转
    wire inst_beq      = (opcode1 == 6'h16);
    wire inst_bne      = (opcode1 == 6'h17);
    wire inst_bgeu     = (opcode1 == 6'h1B);
    
    // 立即数加载
    wire inst_lu12iw   = (opcode1 == 6'h05);
    wire inst_pcaddu12i= (opcode1 == 6'h07);

    // 4. 生成 ALU 控制信号
    assign id_alutype_o = inst_addw || inst_addiw || inst_sltui ? `ARITH :
                          inst_or || inst_ori || inst_andi || inst_xor ? `LOGIC :
                          inst_sllw ? `SHIFT :
                          inst_lu12iw || inst_pcaddu12i ? `MOVE :
                          inst_beq || inst_bne || inst_bgeu ? `BRANCH :
                          inst_load ? `LOAD :
                          inst_store ? `STORE : `NOP;

    assign id_aluop_o = inst_addw  ? `LoongArch32_ADD_W :
                        inst_addiw ? `LoongArch32_ADDI_W :
                        inst_or    ? `LoongArch32_OR :
                        inst_ori   ? `LoongArch32_ORI :
                        inst_andi  ? `LoongArch32_ANDI :
                        inst_xor   ? `LoongArch32_XOR :
                        inst_sltui ? `LoongArch32_SLTU :
                        inst_sllw  ? `LoongArch32_SLL :
                        inst_lu12iw? `LoongArch32_LU12I_W :
                        inst_pcaddu12i ? `LoongArch32_PCADDU12I :
                        inst_beq   ? `LoongArch32_BEQ :
                        inst_bne   ? `LoongArch32_BNE :
                        inst_bgeu  ? `LoongArch32_BGEU :
                        inst_ldb   ? `LoongArch32_LD_B :
                        inst_ldw   ? `LoongArch32_LD_W :
                        inst_stb   ? `LoongArch32_ST_B :
                        inst_stw   ? `LoongArch32_ST_W : `LoongArch32_SLL;

    // 5. 寄存器控制
    // Store 和 Branch 指令不写回通用寄存器
    assign id_wreg_o = !(inst_store || inst_beq || inst_bne || inst_bgeu);
    assign id_wa_o   = rd;

    // 6. 寄存器读地址控制 (Forwarding 依赖此信号)
    assign ra1 = rj; // 所有指令 rs1 都是 rj
    // Store 指令的数据源是 rd; Branch 比较用 rd; 3R 运算用 rk
    assign ra2 = (inst_store || inst_beq || inst_bne || inst_bgeu) ? rd : 
                 (inst_addw || inst_or || inst_xor || inst_sllw) ? rk : `REG_NOP;

    // 7. 立即数扩展逻辑
    wire [`REG_BUS] imm12_sext = {{20{imm12[11]}}, imm12}; // 符号扩展
    wire [`REG_BUS] imm12_zext = {20'h00000, imm12};       // 零扩展
    wire [`REG_BUS] imm16_sext = {{16{imm16[15]}}, imm16}; // 分支偏移符号扩展
    // [FIX] pcaddu12i/lu12i.w 使用无符号拼接
    wire [`REG_BUS] imm20_sh12 = {imm20, 12'h000}; 

    // 8. 操作数前推选择 (Forwarding Logic)
    // 优先级: EXE > MEM > WB > RegFile
    wire [`REG_BUS] op1_reg = (forward_sel1_i == 2'b01) ? forward_data_exe :
                              (forward_sel1_i == 2'b10) ? forward_data_mem :
                              (forward_sel1_i == 2'b11) ? forward_data_wb  : rd1;
                              
    wire [`REG_BUS] op2_reg = (forward_sel2_i == 2'b01) ? forward_data_exe :
                              (forward_sel2_i == 2'b10) ? forward_data_mem :
                              (forward_sel2_i == 2'b11) ? forward_data_wb  : rd2;

    // 9. 最终操作数选择 (ALU Inputs)
    // src1: pcaddu12i 用 PC，其他用 rs1
    assign id_src1_o = inst_pcaddu12i ? id_pc_i : op1_reg;

    // src2: 根据指令类型选择立即数或 rs2
    assign id_src2_o = inst_addiw  ? imm12_sext :
                       inst_ori    ? imm12_zext :
                       inst_andi   ? imm12_zext :
                       inst_sltui  ? imm12_zext :
                       inst_lu12iw ? imm20_sh12 :
                       inst_pcaddu12i ? imm20_sh12 :
                       inst_load   ? imm12_sext : // Load: Base+Offset
                       inst_store  ? imm12_sext : // Store: Base+Offset (计算地址用)
                       op2_reg;                   // 3R型、Branch等使用寄存器值

    // 10. 分支目标地址计算 (PC + imm16 << 2)
    assign id_branch_target_o = id_pc_i + (imm16_sext << 2);

    // 11. 调试信号透传
    assign debug_wb_pc = id_debug_wb_pc_i;

endmodule