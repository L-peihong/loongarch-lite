#include "temu.h"
#include <stdlib.h>
#include <stdio.h>

CPU_state cpu;

/* regfile: names WITHOUT leading '$' — 便于表达式解析中用无'$'形式匹配寄存器名
 * display_reg() 打印时会统一加上 '$' 前缀以贴合汇编风格输出。
 */
const char *regfile[] = {
    "zero", "ra", "tp", "sp",
    "a0", "a1", "a2", "a3",
    "a4", "a5", "a6", "a7",
    "t0", "t1", "t2", "t3",
    "t4", "t5", "t6", "t7",
    "t8", "x",  "fp", "s0",
    "s1", "s2", "s3", "s4",
    "s5", "s6", "s7", "s8"
};

void display_reg() {
    int i;
    printf("===== Register Status =====\n");
    for (i = 0; i < 32; i++) {
        char name[16];
        snprintf(name, sizeof(name), "$%s", regfile[i]); /* regfile contains names without '$' */
        printf("%-6s 0x%08x (%d)\n", name, cpu.gpr[i]._32, cpu.gpr[i]._32);
    }
    printf("PC    0x%08x (%d)\n", cpu.pc, cpu.pc);
    printf("===========================\n");
}


