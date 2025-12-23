#include "helper.h"
#include "monitor.h"
#include "reg.h"

extern uint32_t instr;
extern char assembly[80];

/* decode I20-type instrucion with signed immediate */
static void decode_i20_type(uint32_t instr) {

	
	op_src2->type = OP_TYPE_IMM;
	op_src2->imm = (instr >> 5) & 0x000FFFFF;
	op_src2->val = op_src2->imm;

	op_dest->type = OP_TYPE_REG;
	op_dest->reg = instr & 0x0000001F;
}

// temu/src/cpu/i20-type.c
make_helper(lu12i_w) {
    decode_i20_type(instr);  // 框架已提供
    // 将20位立即数左移12位
    reg_w(op_dest->reg) = (op_src2->val << 12);
    sprintf(assembly, "lu12i.w\t%s,\t0x%04x", 
            REG_NAME(op_dest->reg), op_src2->imm);
}

// temu/src/cpu/i20-type.c
make_helper(pcaddu12i) {
    decode_i20_type(instr);
    // 将20位立即数左移12位并符号扩展
    int32_t imm = ((int32_t)op_src2->imm << 12) >> 12; // 符号扩展
    imm <<= 12; // 左移12位
    
    // 当前PC (注意pc已映射为物理地址)
    uint32_t current_pc = cpu.pc & 0x7FFFFFFF;
    
    // 计算结果 (保持32位结果)
    reg_w(op_dest->reg) = (current_pc + imm) & 0xFFFFFFFF;
    
    sprintf(assembly, "pcaddu12i\t%s,\t0x%05x", 
            REG_NAME(op_dest->reg), op_src2->imm);
}

