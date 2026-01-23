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
    op_src1->reg = (instr >> 5) & 0x1F;
    op_src1->val = reg_w(op_src1->reg);

    op_src2->type = OP_TYPE_IMM;
    op_src2->imm = (instr >> 10) & 0xFFF;
    op_src2->val = op_src2->imm;

    op_dest->type = OP_TYPE_REG;
    op_dest->reg = instr & 0x1F;
}

static inline int32_t signext12(uint32_t imm12) {
    if (imm12 & 0x800) return (int32_t)(imm12 | 0xFFFFF000);
    return (int32_t)imm12;
}

static inline int32_t signext16(uint32_t imm16) {
    if (imm16 & 0x8000) return (int32_t)(imm16 | 0xFFFF0000);
    return (int32_t)imm16;
}

/* ====================== 关键修复：14-bit 分支立即数 ====================== */
static inline int32_t signext14(uint32_t imm14) {
    if (imm14 & 0x2000)   // bit13 是符号位
        return (int32_t)(imm14 | 0xFFFFC000);
    return (int32_t)imm14;
}

/* ====================== 算术 / 逻辑指令 ====================== */

make_helper(ori) {
    decode_ui12_type(instr);
    reg_w(op_dest->reg) = op_src1->val | op_src2->val;
    sprintf(assembly, "ori\t%s,\t%s,\t0x%03x",
            REG_NAME(op_dest->reg),
            REG_NAME(op_src1->reg),
            op_src2->imm);
}

make_helper(addi_w) {
    int rd = instr & 0x1F;
    int rj = (instr >> 5) & 0x1F;
    uint32_t imm12 = (instr >> 10) & 0xFFF;
    int32_t simm = signext12(imm12);

    op_dest->type = OP_TYPE_REG;
    op_dest->reg  = rd;

    reg_w(rd) = reg_w(rj) + (uint32_t)simm;
    sprintf(assembly, "addi.w	%s,\t%s,\t0x%03x",
            REG_NAME(rd), REG_NAME(rj), imm12);
}

make_helper(andi) {
    int rd = instr & 0x1F;
    int rj = (instr >> 5) & 0x1F;
    uint32_t ui12 = (instr >> 10) & 0xFFF;

    op_dest->type = OP_TYPE_REG;
    op_dest->reg  = rd;

    reg_w(rd) = reg_w(rj) & ui12;
    sprintf(assembly, "andi	%s,\t%s,\t0x%03x",
            REG_NAME(rd), REG_NAME(rj), ui12);
}

make_helper(xori) {
    int rd = instr & 0x1F;
    int rj = (instr >> 5) & 0x1F;
    uint32_t ui12 = (instr >> 10) & 0xFFF;
    reg_w(rd) = reg_w(rj) ^ ui12;
    sprintf(assembly, "xori\t%s,\t%s,\t0x%03x",
            REG_NAME(rd), REG_NAME(rj), ui12);
}

/* ====================== sltui ====================== */

make_helper(sltui) {
    int rd = instr & 0x1F;
    int rj = (instr >> 5) & 0x1F;
    uint32_t imm12 = (instr >> 10) & 0xFFF;

    /* Golden Trace：这是一次寄存器写回 */
    op_dest->type = OP_TYPE_REG;
    op_dest->reg  = rd;

    reg_w(rd) = (reg_w(rj) < imm12);

    sprintf(assembly, "sltui	%s,\t%s,\t0x%03x",
            REG_NAME(rd), REG_NAME(rj), imm12);
}


/* ====================== st.w 修复（含调试） ====================== */
make_helper(st_w) {
    int rd = instr & 0x1F;    /* 源寄存器：待存储的值 */
    int rj = (instr >> 5) & 0x1F; /* 基址寄存器 */
    uint32_t imm12 = (instr >> 10) & 0xFFF;
    int32_t simm = signext12(imm12);
    uint32_t vaddr = reg_w(rj) + (uint32_t)simm;
    uint32_t paddr = vaddr & 0x7FFFFFFF;

    /* 对齐检查（st.w 需 4 字节对齐） */
    if (!check_alignment(vaddr, 4)) {
        panic("st.w: unaligned address 0x%08x (not 4-byte aligned)", vaddr);
    }

    /* 调试日志：写前信息 */
    Log("ST.W: rd=%s(%d)=0x%08x  rj=%s(%d)=0x%08x imm12=0x%03x simm=%d vaddr=0x%08x paddr=0x%08x",
        REG_NAME(rd), rd, reg_w(rd), REG_NAME(rj), rj, reg_w(rj), imm12, simm, vaddr, paddr);

    /* 核心写操作（使用现有接口） */
    mem_write(paddr, 4, reg_w(rd));

    /* 立刻读回以验证（使用 mem_read） */
    {
        uint32_t back = mem_read(paddr, 4);
        Log("ST.W: after mem_write mem_read(0x%08x,4) = 0x%08x", paddr, back);
    }

    /* 诊断性：直接访问底层 hw_mem（仅用于定位问题，非长期代码） */
#ifdef DEBUG
    {
        extern uint8_t *hw_mem; /* memory.h -> extern */
        /* 仅当 paddr 在物理内存范围内时才直接访问 */
        if (paddr < HW_MEM_SIZE) {
            uint32_t direct = *(uint32_t *)(hw_mem + paddr);
            Log("ST.W: direct hw_mem read at paddr=0x%08x -> 0x%08x", paddr, direct);
        } else {
            Log("ST.W: paddr 0x%08x out of HW_MEM_SIZE (%u)", paddr, HW_MEM_SIZE);
        }
    }
#endif

    sprintf(assembly, "st.w\t%s,\t%s,\t0x%03x", REG_NAME(rd), REG_NAME(rj), imm12);
}

/* ====================== ld.w 修复（含调试） ====================== */
make_helper(ld_w) {
    int rd = instr & 0x1F;    /* 目标寄存器：存储读取的值 */
    int rj = (instr >> 5) & 0x1F; /* 基址寄存器 */
    uint32_t imm12 = (instr >> 10) & 0xFFF;
    int32_t simm = signext12(imm12);
    uint32_t vaddr = reg_w(rj) + (uint32_t)simm;
    uint32_t paddr = vaddr & 0x7FFFFFFF;

    // ========== 新增：设置op_dest，让Golden Trace捕捉Load指令的寄存器写回 ==========
    op_dest->type = OP_TYPE_REG;
    op_dest->reg  = rd;

    if (!check_alignment(vaddr, 4)) {
        panic("ld.w: unaligned address 0x%08x (not 4-byte aligned)", vaddr);
    }

    Log("LD.W: rd=%s(%d) rj=%s(%d)=0x%08x imm12=0x%03x simm=%d vaddr=0x%08x paddr=0x%08x",
        REG_NAME(rd), rd, REG_NAME(rj), rj, reg_w(rj), imm12, simm, vaddr, paddr);

    reg_w(rd) = mem_read(paddr, 4);

    Log("LD.W: result reg %s(%d) = 0x%08x", REG_NAME(rd), rd, reg_w(rd));

    sprintf(assembly, "ld.w\t%s,\t%s,\t0x%03x", REG_NAME(rd), REG_NAME(rj), imm12);
}

/* ====================== st.b 修复（含调试） ====================== */
make_helper(st_b) {
    int rd = instr & 0x1F;    /* 源寄存器：低8位待存储 */
    int rj = (instr >> 5) & 0x1F; /* 基址寄存器 */
    uint32_t imm12 = (instr >> 10) & 0xFFF;
    int32_t simm = signext12(imm12);
    uint32_t vaddr = reg_w(rj) + (uint32_t)simm;
    uint32_t paddr = vaddr & 0x7FFFFFFF;

    /* 字节访问天然对齐；记录日志 */
    Log("ST.B: rd=%s(%d)=0x%08x rj=%s(%d)=0x%08x imm12=0x%03x vaddr=0x%08x paddr=0x%08x",
        REG_NAME(rd), rd, reg_w(rd), REG_NAME(rj), rj, reg_w(rj), imm12, vaddr, paddr);

    mem_write(paddr, 1, reg_w(rd) & 0xFF);

    {
        uint32_t back = mem_read(paddr, 1) & 0xFF;
        Log("ST.B: after mem_write mem_read(0x%08x,1) = 0x%02x", paddr, back);
    }

    sprintf(assembly, "st.b\t%s,\t%s,\t0x%03x", REG_NAME(rd), REG_NAME(rj), imm12);
}

/* ====================== ld.b 修复（含调试） ====================== */
make_helper(ld_b) {
    int rd = instr & 0x1F;    /* 目标寄存器：符号扩展后写回 */
    int rj = (instr >> 5) & 0x1F; /* 基址寄存器 */
    uint32_t imm12 = (instr >> 10) & 0xFFF;
    int32_t simm = signext12(imm12);
    uint32_t vaddr = reg_w(rj) + (uint32_t)simm;
    uint32_t paddr = vaddr & 0x7FFFFFFF;

    // ========== 新增：设置op_dest，让Golden Trace捕捉Load指令的寄存器写回 ==========
    op_dest->type = OP_TYPE_REG;
    op_dest->reg  = rd;

    Log("LD.B: rd=%s(%d) rj=%s(%d)=0x%08x imm12=0x%03x vaddr=0x%08x paddr=0x%08x",
        REG_NAME(rd), rd, REG_NAME(rj), rj, reg_w(rj), imm12, vaddr, paddr);

    uint32_t b = mem_read(paddr, 1) & 0xFF;
    if (b & 0x80) reg_w(rd) = (uint32_t)(0xFFFFFF00 | b);
    else reg_w(rd) = b;

    Log("LD.B: result reg %s(%d) = 0x%08x", REG_NAME(rd), rd, reg_w(rd));

    sprintf(assembly, "ld.b\t%s,\t%s,\t0x%03x", REG_NAME(rd), REG_NAME(rj), imm12);
}

make_helper(beq) {
    int rj = (instr >> 5) & 0x1F;
    int rd = instr & 0x1F;

    uint32_t offs14 = (instr >> 10) & 0x3FFF;

    /* offs14 << 2 后再符号扩展 */
    int32_t branch_off = (int32_t)((offs14 << 2) << 16) >> 16;

    uint32_t arch_pc = cpu.pc;
    uint32_t target  = arch_pc + branch_off;   // 没有 +4

    if (reg_w(rj) == reg_w(rd)) {
        /* 抵消外层 cpu.pc += 4 */
        cpu.pc = target - 4;
    }

    sprintf(assembly, "beq	%s,\t%s,\t0x%04x",
            REG_NAME(rj), REG_NAME(rd), offs14);
}



make_helper(bne) {
    int rj = (instr >> 5) & 0x1F;
    int rd = instr & 0x1F;

    uint32_t offs14 = (instr >> 10) & 0x3FFF;
    int32_t branch_off = (int32_t)((offs14 << 2) << 16) >> 16;

    uint32_t arch_pc = cpu.pc;
    uint32_t target  = arch_pc + branch_off;

    if (reg_w(rj) != reg_w(rd)) {
        cpu.pc = target - 4;
    }

    sprintf(assembly, "bne	%s,\t%s,\t0x%04x",
            REG_NAME(rj), REG_NAME(rd), offs14);
}



make_helper(bgeu) {
    int rj = (instr >> 5) & 0x1F;
    int rd = instr & 0x1F;

    uint32_t offs14 = (instr >> 10) & 0x3FFF;
    int32_t branch_off = (int32_t)((offs14 << 2) << 16) >> 16;

    uint32_t arch_pc = cpu.pc;
    uint32_t target  = arch_pc + branch_off;

    if ((uint32_t)reg_w(rj) >= (uint32_t)reg_w(rd)) {
        cpu.pc = target - 4;
    }

    sprintf(assembly, "bgeu	%s,\t%s,\t0x%04x",
            REG_NAME(rj), REG_NAME(rd), offs14);
}




