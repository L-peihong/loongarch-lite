#include "helper.h"
#include "monitor.h"
#include "reg.h"

extern uint32_t instr;
extern char assembly[80];

/* decode 3R-type instrucion */
static void decode_3r_type(uint32_t instr) {

	op_src1->type = OP_TYPE_REG;
	op_src1->reg = (instr >> 5) & 0x0000001F;
	op_src1->val = reg_w(op_src1->reg);
	
	op_src2->type = OP_TYPE_REG;
	op_src2->imm = (instr >> 10) & 0x0000001F;
	op_src2->val = reg_w(op_src2->reg);

	op_dest->type = OP_TYPE_REG;
	op_dest->reg = instr & 0x0000001F;
}

/* Helper: extract regs for 3R-type (rd: bits[4:0], rj: bits[9:5], rk: bits[14:10]) */
/* 注意：这里直接从 instr 取字段（与 decode_3r_type 类似），避免依赖有问题的 decode_3r_type */
static inline void decode_3r_regs(uint32_t instr, int *rd, int *rj, int *rk) {
    *rj = (instr >> 5) & 0x1F;
    *rk = (instr >> 10) & 0x1F;
    *rd = instr & 0x1F;
}

make_helper(or) {

	decode_3r_type(instr);
	reg_w(op_dest->reg) = (op_src1->val | op_src2->val);
	sprintf(assembly, "or\t%s,\t%s,\t%s", REG_NAME(op_dest->reg), REG_NAME(op_src1->reg), REG_NAME(op_src2->reg));
}

/* add.w rd, rj, rk */
make_helper(add_w) {
    int rd, rj, rk;
    decode_3r_regs(instr, &rd, &rj, &rk);
    uint32_t v1 = reg_w(rj);
    uint32_t v2 = reg_w(rk);
    uint32_t res = v1 + v2;
    reg_w(rd) = res;
    sprintf(assembly, "add.w\t%s,\t%s,\t%s", REG_NAME(rd), REG_NAME(rj), REG_NAME(rk));
}

/* and rd, rj, rk  (and.w semantics) */
make_helper(and_w) {
    int rd, rj, rk;
    decode_3r_regs(instr, &rd, &rj, &rk);
    reg_w(rd) = reg_w(rj) & reg_w(rk);
    sprintf(assembly, "and\t%s,\t%s,\t%s", REG_NAME(rd), REG_NAME(rj), REG_NAME(rk));
}

/* xor rd, rj, rk */
make_helper(xor) {
    int rd, rj, rk;
    decode_3r_regs(instr, &rd, &rj, &rk);
    reg_w(rd) = reg_w(rj) ^ reg_w(rk);
    sprintf(assembly, "xor\t%s,\t%s,\t%s", REG_NAME(rd), REG_NAME(rj), REG_NAME(rk));
}

/* sll.w rd, rj, rk  (logical left, shift amount = rk[4:0]) */
make_helper(sll_w) {
    int rd, rj, rk;
    decode_3r_regs(instr, &rd, &rj, &rk);
    uint32_t sh = reg_w(rk) & 0x1F;
    uint32_t res = reg_w(rj) << sh;
    reg_w(rd) = res;
    sprintf(assembly, "sll.w\t%s,\t%s,\t%s", REG_NAME(rd), REG_NAME(rj), REG_NAME(rk));
}


