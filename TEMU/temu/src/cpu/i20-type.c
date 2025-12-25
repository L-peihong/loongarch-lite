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

make_helper(lu12i_w) {

	decode_i20_type(instr);
    op_dest->type = OP_TYPE_REG;
	reg_w(op_dest->reg) = (op_src2->val << 12);
	sprintf(assembly, "lu12i.w\t%s,\t0x%04x", REG_NAME(op_dest->reg), op_src2->imm);
}

make_helper(pcaddu12i) {
    /* reuse decode_i20_type logic: op_dest = instr & 0x1F ; imm20 = (instr >> 5) & 0xFFFFF */
    uint32_t imm20 = (instr >> 5) & 0x000FFFFF;
    int32_t simm20 = (imm20 & 0x80000) ? (int32_t)(imm20 | 0xFFF00000) : (int32_t)imm20;
    int32_t simm = simm20 << 12; /* {si20,12'b0} then sign extend took place before shift */
    int rd = instr & 0x1F;
    /* 注：helper 以 make_helper(name) => void name(uint32_t pc) 的形式调用，因此 cpu.pc 当前等于执行前递增的 pc。
     * 我们应将CPU的程序计数器（cpu.pc）作为程序计数器基址。使用cpu.pc（其当前值等于当前程序计数器）.
     */
    op_dest->type = OP_TYPE_REG;
    op_dest->reg  = rd;
    reg_w(rd) = cpu.pc + (uint32_t)simm;
    sprintf(assembly, "pcaddu12i\t%s,\t0x%05x", REG_NAME(rd), imm20);
}

