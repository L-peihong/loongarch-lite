#include "helper.h"
#include "monitor.h"
#include "reg.h"

extern uint32_t instr;
extern char assembly[80];

/* decode I12-type instrucion with unsigned immediate */
static void decode_ui12_type(uint32_t instr) {

	op_src1->type = OP_TYPE_REG;
	op_src1->reg = (instr >> 5) & 0x0000001F;
	op_src1->val = reg_w(op_src1->reg);

	op_src2->type = OP_TYPE_IMM;
	op_src2->imm = (instr >> 10) & 0x00000FFF;
	op_src2->val = op_src2->imm;

	op_dest->type = OP_TYPE_REG;
	op_dest->reg = instr & 0x0000001F;
}

static inline int32_t signext12(uint32_t imm12) {
    if (imm12 & 0x800) return (int32_t)(imm12 | 0xFFFFF000);
    return (int32_t)imm12;
}
static inline int32_t signext16(uint32_t imm16) {
    if (imm16 & 0x8000) return (int32_t)(imm16 | 0xFFFF0000);
    return (int32_t)imm16;
}

make_helper(ori) {

	decode_ui12_type(instr);
	reg_w(op_dest->reg) = op_src1->val | op_src2->val;
	sprintf(assembly, "ori	%s,\t%s,\t0x%03x", REG_NAME(op_dest->reg), REG_NAME(op_src1->reg), op_src2->imm);
}

/* addi.w rd, rj, si12 */
make_helper(addi_w) {
    int rd = instr & 0x1F;
    int rj = (instr >> 5) & 0x1F;
    uint32_t imm12 = (instr >> 10) & 0xFFF;
    int32_t simm = signext12(imm12);
    reg_w(rd) = reg_w(rj) + (uint32_t)simm;
    sprintf(assembly, "addi.w	%s,\t%s,\t0x%03x", REG_NAME(rd), REG_NAME(rj), imm12);
}

/* andi rd, rj, ui12 */
make_helper(andi) {
    int rd = instr & 0x1F;
    int rj = (instr >> 5) & 0x1F;
    uint32_t ui12 = (instr >> 10) & 0xFFF;
    reg_w(rd) = reg_w(rj) & ui12;
    sprintf(assembly, "andi	%s,\t%s,\t0x%03x", REG_NAME(rd), REG_NAME(rj), ui12);
}

/* xori rd, rj, ui12 */
make_helper(xori) {
    int rd = instr & 0x1F;
    int rj = (instr >> 5) & 0x1F;
    uint32_t ui12 = (instr >> 10) & 0xFFF;
    reg_w(rd) = reg_w(rj) ^ ui12;
    sprintf(assembly, "xori	%s,\t%s,\t0x%03x", REG_NAME(rd), REG_NAME(rj), ui12);
}

/* sltui rd, rj, si12  -- immediate is sign-extended, compare unsigned */
make_helper(sltui) {
    int rd = instr & 0x1F;
    int rj = (instr >> 5) & 0x1F;
    uint32_t imm12 = (instr >> 10) & 0xFFF;
    int32_t simm = signext12(imm12);
    uint32_t lhs = reg_w(rj);
    uint32_t rhs = (uint32_t)simm;
    reg_w(rd) = (lhs < rhs) ? 1 : 0;
    sprintf(assembly, "sltui	%s,\t%s,\t0x%03x", REG_NAME(rd), REG_NAME(rj), imm12);
}

/* ld.w rd, rj, si12 */
make_helper(ld_w) {
    int rd = instr & 0x1F;
    int rj = (instr >> 5) & 0x1F;
    uint32_t imm12 = (instr >> 10) & 0xFFF;
    int32_t simm = signext12(imm12);
    uint32_t vaddr = reg_w(rj) + (uint32_t)simm;
    uint32_t paddr = vaddr & 0x7FFFFFFF;
    reg_w(rd) = mem_read(paddr, 4);
    sprintf(assembly, "ld.w	%s,\t%s,\t0x%03x", REG_NAME(rd), REG_NAME(rj), imm12);
}

/* st.w rd, rj, si12  (store low 32 bits of GR[rd]) */
make_helper(st_w) {
    int rd = instr & 0x1F;   /* source register index */
    int rj = (instr >> 5) & 0x1F; /* base */
    uint32_t imm12 = (instr >> 10) & 0xFFF;
    int32_t simm = signext12(imm12);
    uint32_t vaddr = reg_w(rj) + (uint32_t)simm;
    uint32_t paddr = vaddr & 0x7FFFFFFF;
    mem_write(paddr, 4, reg_w(rd));
    sprintf(assembly, "st.w	%s,\t%s,\t0x%03x", REG_NAME(rd), REG_NAME(rj), imm12);
}

/* ld.b rd, rj, si12  (sign-extended byte) */
make_helper(ld_b) {
    int rd = instr & 0x1F;
    int rj = (instr >> 5) & 0x1F;
    uint32_t imm12 = (instr >> 10) & 0xFFF;
    int32_t simm = signext12(imm12);
    uint32_t vaddr = reg_w(rj) + (uint32_t)simm;
    uint32_t paddr = vaddr & 0x7FFFFFFF;
    uint32_t b = mem_read(paddr, 1) & 0xFF;
    if (b & 0x80) reg_w(rd) = (uint32_t)(0xFFFFFF00 | b);
    else reg_w(rd) = b;
    sprintf(assembly, "ld.b	%s,\t%s,\t0x%03x", REG_NAME(rd), REG_NAME(rj), imm12);
}

/* st.b rd, rj, si12  (store low 8 bits of GR[rd]) */
make_helper(st_b) {
    int rd = instr & 0x1F;
    int rj = (instr >> 5) & 0x1F;
    uint32_t imm12 = (instr >> 10) & 0xFFF;
    int32_t simm = signext12(imm12);
    uint32_t vaddr = reg_w(rj) + (uint32_t)simm;
    uint32_t paddr = vaddr & 0x7FFFFFFF;
    mem_write(paddr, 1, reg_w(rd) & 0xFF);
    sprintf(assembly, "st.b	%s,\t%s,\t0x%03x", REG_NAME(rd), REG_NAME(rj), imm12);
}

/*
 * Branch format used in this lab:
 * - rj: bits[9:5]
 * - rd: bits[4:0]
 * - offs16: bits[25:10]
 *
 * LoongArch branch target:
 *   target = pc + 4 + (signext(offs16) << 2)
 *
 * Note: cpu-exec.c will do cpu.pc += 4 after exec(pc).
 * To keep that structure unchanged, we set cpu.pc to (target - 4) here.
 */

make_helper(beq) {
    int rj = (instr >> 5) & 0x1F;
    int rd = instr & 0x1F;
    uint32_t offs16 = (instr >> 10) & 0xFFFF;
    int32_t simm = signext16(offs16);
    int32_t branch_off = simm << 2;
    uint32_t target = pc + 4 + (uint32_t)branch_off;

    if (reg_w(rj) == reg_w(rd)) {
        cpu.pc = target - 4;
    }
    sprintf(assembly, "beq	%s,\t%s,\t0x%04x", REG_NAME(rj), REG_NAME(rd), offs16);
}

make_helper(bne) {
    int rj = (instr >> 5) & 0x1F;
    int rd = instr & 0x1F;
    uint32_t offs16 = (instr >> 10) & 0xFFFF;
    int32_t simm = signext16(offs16);
    int32_t branch_off = simm << 2;
    uint32_t target = pc + 4 + (uint32_t)branch_off;

    if (reg_w(rj) != reg_w(rd)) {
        cpu.pc = target - 4;
    }
    sprintf(assembly, "bne	%s,\t%s,\t0x%04x", REG_NAME(rj), REG_NAME(rd), offs16);
}

make_helper(bgeu) {
    int rj = (instr >> 5) & 0x1F;
    int rd = instr & 0x1F;
    uint32_t offs16 = (instr >> 10) & 0xFFFF;
    int32_t simm = signext16(offs16);
    int32_t branch_off = simm << 2;
    uint32_t target = pc + 4 + (uint32_t)branch_off;

    if ((uint32_t)reg_w(rj) >= (uint32_t)reg_w(rd)) {
        cpu.pc = target - 4;
    }
    sprintf(assembly, "bgeu	%s,\t%s,\t0x%04x", REG_NAME(rj), REG_NAME(rd), offs16);
}


