#include "helper.h"
#include "monitor.h"
#include "reg.h"

extern uint32_t instr;
extern char assembly[80];

/* 通用工具函数：地址自然对齐检查（n=数据宽度，返回true表示对齐） */
static bool check_alignment(uint32_t vaddr, size_t n) {
    return (vaddr % n) == 0;
}

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
    op_dest->type = OP_TYPE_REG;
    op_dest->reg  = rd;
    reg_w(rd) = reg_w(rj) + (uint32_t)simm;
    sprintf(assembly, "addi.w	%s,\t%s,\t0x%03x", REG_NAME(rd), REG_NAME(rj), imm12);
}

/* andi rd, rj, ui12 */
make_helper(andi) {
    int rd = instr & 0x1F;
    int rj = (instr >> 5) & 0x1F;
    uint32_t ui12 = (instr >> 10) & 0xFFF;
    op_dest->type = OP_TYPE_REG;
    op_dest->reg  = rd; 
    reg_w(rd) = reg_w(rj) & ui12;
    sprintf(assembly, "andi	%s,\t%s,\t0x%03x", REG_NAME(rd), REG_NAME(rj), ui12);
}

/* xori rd, rj, ui12 */
make_helper(xori) {
    int rd = instr & 0x1F;
    int rj = (instr >> 5) & 0x1F;
    uint32_t ui12 = (instr >> 10) & 0xFFF;
    op_dest->type = OP_TYPE_REG;
    op_dest->reg  = rd;
    reg_w(rd) = reg_w(rj) ^ ui12;
    sprintf(assembly, "xori	%s,\t%s,\t0x%03x", REG_NAME(rd), REG_NAME(rj), ui12);
}

/* sltui rd, rj, si12  -- immediate is sign-extended, compare unsigned */
/* sltui rd, rj, ui12  -- 无符号比较：rj < ui12 → rd=1，否则0 */
make_helper(sltui) {
    // 正确解析字段：rd=bits4-0, rj=bits9-5, ui12=bits21-10（无符号12位）
    int rd = instr & 0x1F;
    int rj = (instr >> 5) & 0x1F;
    uint32_t ui12 = (instr >> 10) & 0xFFF;  // sltui是无符号立即数，无需符号扩展
    
    // 核心：无符号比较（LoongArch sltui 定义为无符号）
    uint32_t rj_val = reg_w(rj);
    uint32_t result = (rj_val < ui12) ? 1 : 0;
    
    // 写回目标寄存器
    op_dest->type = OP_TYPE_REG;
    op_dest->reg  = rd;
    reg_w(rd) = result;
    
    // 打印汇编指令
    sprintf(assembly, "sltui\t%s,\t%s,\t0x%03x", REG_NAME(rd), REG_NAME(rj), ui12);
    
    // 调试日志（可选）
    Log("sltui: rj(%s)=0x%08x < ui12=0x%03x → rd(%s)=0x%08x", 
        REG_NAME(rj), rj_val, ui12, REG_NAME(rd), result);
}

/* ====================== st.w 修复 ====================== */
make_helper(st_w) {
    int rd = instr & 0x1F;    /* 源寄存器：待存储的值 */
    int rj = (instr >> 5) & 0x1F; /* 基址寄存器 */
    uint32_t imm12 = (instr >> 10) & 0xFFF;
    int32_t simm = signext12(imm12);
    uint32_t vaddr = reg_w(rj) + (uint32_t)simm;
    uint32_t paddr = vaddr & 0x7FFFFFFF;

    /* 1. 地址对齐检查（st.w 需 4 字节自然对齐） */
    if (!check_alignment(vaddr, 4)) {
        panic("st.w: unaligned address 0x%08x (not 4-byte aligned)", vaddr);
    }

    /* 2. 核心语义：将 GR[rd] 的 32 位值写入内存（完整实现） */
    mem_write(paddr, 4, reg_w(rd));

    sprintf(assembly, "st.w\t%s,\t%s,\t0x%03x", REG_NAME(rd), REG_NAME(rj), imm12);
}

/* ====================== ld.w 修复 ====================== */
make_helper(ld_w) {
    int rd = instr & 0x1F;    /* 目标寄存器：存储读取的值 */
    int rj = (instr >> 5) & 0x1F; /* 基址寄存器 */
    uint32_t imm12 = (instr >> 10) & 0xFFF;
    int32_t simm = signext12(imm12);
    uint32_t vaddr = reg_w(rj) + (uint32_t)simm;
    uint32_t paddr = vaddr & 0x7FFFFFFF;

    /* 1. 地址对齐检查（ld.w 需 4 字节自然对齐） */
    if (!check_alignment(vaddr, 4)) {
        panic("ld.w: unaligned address 0x%08x (not 4-byte aligned)", vaddr);
    }

    /* 2. 核心语义：从内存读取 32 位值到 GR[rd] */
    reg_w(rd) = mem_read(paddr, 4);

    sprintf(assembly, "ld.w\t%s,\t%s,\t0x%03x", REG_NAME(rd), REG_NAME(rj), imm12);
}

/* ====================== st.b 修复 ====================== */
make_helper(st_b) {
    int rd = instr & 0x1F;    /* 源寄存器：待存储的低8位值 */
    int rj = (instr >> 5) & 0x1F; /* 基址寄存器 */
    uint32_t imm12 = (instr >> 10) & 0xFFF;
    int32_t simm = signext12(imm12);
    uint32_t vaddr = reg_w(rj) + (uint32_t)simm;
    uint32_t paddr = vaddr & 0x7FFFFFFF;

    /* 1. 地址对齐检查（st.b 是字节访问，自然对齐永远成立，无需报错） */
    (void)check_alignment(vaddr, 1); /* 占位，符合架构规范 */

    /* 2. 核心语义：将 GR[rd] 的低 8 位写入内存 */
    mem_write(paddr, 1, reg_w(rd) & 0xFF);

    sprintf(assembly, "st.b\t%s,\t%s,\t0x%03x", REG_NAME(rd), REG_NAME(rj), imm12);
}

/* ====================== ld.b 修复 ====================== */
make_helper(ld_b) {
    int rd = instr & 0x1F;    /* 目标寄存器：存储符号扩展后的值 */
    int rj = (instr >> 5) & 0x1F; /* 基址寄存器 */
    uint32_t imm12 = (instr >> 10) & 0xFFF;
    int32_t simm = signext12(imm12);
    uint32_t vaddr = reg_w(rj) + (uint32_t)simm;
    uint32_t paddr = vaddr & 0x7FFFFFFF;

    /* 1. 地址对齐检查（ld.b 是字节访问，自然对齐永远成立） */
    (void)check_alignment(vaddr, 1); /* 占位，符合架构规范 */

    /* 2. 核心语义：读取 8 位值并符号扩展到 32 位 */
    uint32_t b = mem_read(paddr, 1) & 0xFF; /* 读取原始字节 */
    if (b & 0x80) { /* 符号位为1，扩展为32位负数 */
        reg_w(rd) = (uint32_t)(0xFFFFFF00 | b);
    } else { /* 符号位为0，扩展为32位正数 */
        reg_w(rd) = b;
    }

    sprintf(assembly, "ld.b\t%s,\t%s,\t0x%03x", REG_NAME(rd), REG_NAME(rj), imm12);
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


