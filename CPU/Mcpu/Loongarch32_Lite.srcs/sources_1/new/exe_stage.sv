`include "defines.v"
module exe_stage(
    input  wire [`ALUTYPE_BUS]   exe_alutype_i,    // 指令类型
    input  wire [`ALUOP_BUS]     exe_aluop_i,      // 操作码
    input  wire [`REG_BUS]       exe_src1_i,       // 操作数1（rs1/PC）
    input  wire [`REG_BUS]       exe_src2_i,       // 操作数2（rs2/立即数/rd）
    input  wire [`REG_ADDR_BUS]  exe_wa_i,         // 写回地址
    input  wire                  exe_wreg_i,       // 写回使能
    input  wire [`INST_ADDR_BUS] exe_debug_wb_pc,  // 调试PC值
    input  wire [`INST_ADDR_BUS] exe_branch_target_i, // 分支目标地址
    // 输出信号
    output wire [`ALUOP_BUS]     exe_aluop_o,      // 操作码（传递到MEM）
    output wire [`REG_ADDR_BUS]  exe_wa_o,         // 写回地址
    output wire                  exe_wreg_o,       // 写回使能
    output wire [`REG_BUS]       exe_wd_o,         // 执行结果（写回数据）
    output wire [`REG_BUS]       exe_mem_addr_o,   // 访存地址（基址+偏移）
    output wire [`REG_BUS]       exe_mem_wdata_o,  // 访存写数据（store：rd的值）
    output wire                  exe_mem_we_o,     // 访存写使能（store）
    output wire [1:0]            exe_mem_sel_o,    // 访存字节选择（b/w）
    output wire                  exe_branch_valid_o,// 分支有效信号（延迟转移用）
    output wire [`INST_ADDR_BUS] debug_wb_pc       // 调试PC值输出
);
    // 内部信号定义
    reg [`REG_BUS]  arith_res;    // 算术运算结果
    reg [`REG_BUS]  logic_res;    // 逻辑运算结果
    reg [`REG_BUS]  shift_res;    // 移位运算结果
    reg [`REG_BUS]  move_res;     // 移动指令结果
    reg             branch_flag;  // 分支条件满足标记

    // 算术运算逻辑（add.w/addi.w/sltui）
    always @(*) begin
        case (exe_aluop_i)
            `LoongArch32_ADD_W:  arith_res = exe_src1_i + exe_src2_i;
            `LoongArch32_ADDI_W: arith_res = exe_src1_i + exe_src2_i;
            `LoongArch32_SLTU:   arith_res = (exe_src1_i < exe_src2_i) ? 32'h00000001 : 32'h00000000;
            default:             arith_res = `ZERO_WORD;
        endcase
    end

    // 逻辑运算逻辑（and/or/xor/andi/ori）
    always @(*) begin
        case (exe_aluop_i)
            `LoongArch32_ANDI:   logic_res = exe_src1_i & exe_src2_i;
            `LoongArch32_OR:     logic_res = exe_src1_i | exe_src2_i;
            `LoongArch32_ORI:    logic_res = exe_src1_i | exe_src2_i;
            `LoongArch32_XOR:    logic_res = exe_src1_i ^ exe_src2_i;
            default:             logic_res = `ZERO_WORD;
        endcase
    end

    // 移位运算逻辑（sll.w：移位量取低5位）
    always @(*) begin
        if (exe_aluop_i == `LoongArch32_SLL) begin
            shift_res = exe_src1_i << (exe_src2_i & 32'h0000001F);
        end else begin
            shift_res = `ZERO_WORD;
        end
    end

    // 移动指令逻辑（lu12i.w/pcaddu12i）
    always @(*) begin
        case (exe_aluop_i)
            `LoongArch32_LU12I_W:    move_res = exe_src2_i;  // 已在ID阶段完成左移12位
            `LoongArch32_PCADDU12I:  move_res = exe_src1_i + exe_src2_i;  // PC + 符号扩展移位后立即数
            default:                 move_res = `ZERO_WORD;
        endcase
    end

    // 分支条件判断逻辑（beq/bne/bgeu，符合LoongArch规范）
    always @(*) begin
        branch_flag = `FALSE_V;
        case (exe_aluop_i)
            `LoongArch32_BEQ:  branch_flag = (exe_src1_i == exe_src2_i);
            `LoongArch32_BNE:  branch_flag = (exe_src1_i != exe_src2_i);
            `LoongArch32_BGEU: branch_flag = (exe_src1_i >= exe_src2_i);
            default: ;
        endcase
    end

    // 执行结果选择（按指令类型）
    assign exe_wd_o = (exe_alutype_i == `ARITH) ? arith_res :
                      (exe_alutype_i == `LOGIC)  ? logic_res :
                      (exe_alutype_i == `SHIFT)  ? shift_res :
                      (exe_alutype_i == `MOVE)   ? move_res : `ZERO_WORD;

    // 访存相关信号生成
    assign exe_mem_addr_o = exe_src1_i + exe_src2_i;  // 基址（rs1）+偏移（立即数）
    assign exe_mem_wdata_o = exe_src2_i;              // store：写数据=rd的值（经前推）
    assign exe_mem_we_o = (exe_alutype_i == `STORE) ? `WRITE_ENABLE : `WRITE_DISABLE;
    assign exe_mem_sel_o = (exe_aluop_i == `LoongArch32_LD_B || exe_aluop_i == `LoongArch32_ST_B) ? 2'b01 : 2'b10;

    // 分支有效信号（传递到IF阶段，用于延迟转移）
    assign exe_branch_valid_o = (exe_alutype_i == `BRANCH) && branch_flag;

    // 传递到MEM阶段的信号
    assign exe_aluop_o = exe_aluop_i;
    assign exe_wa_o = exe_wa_i;
    assign exe_wreg_o = exe_wreg_i;

    // 调试PC值输出
    assign debug_wb_pc = exe_debug_wb_pc;
endmodule