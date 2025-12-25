#include "monitor.h"
#include "helper.h"
#include "watchpoint.h"
#include "reg.h"

#include <limits.h>
#include <stdio.h>

#define MAX_INSTR_TO_PRINT 10
#define RUN_FOREVER ((uint32_t)~0u)

extern uint32_t instr;  // 声明instr是外部全局变量（定义在exec.c中）

int temu_state = STOP;
void exec(uint32_t);
char assembly[80];
char asm_buf[128];

/* ================= Golden Trace ================= */

static FILE *golden_fp = NULL;

/* 打开 Golden Trace 文件（首次使用） */
static inline void init_golden_trace() {
    if (golden_fp == NULL) {
        golden_fp = fopen("golden_trace.txt", "w");
        Assert(golden_fp, "Cannot open golden_trace.txt");
    }
}

/* 判断是否是分支或 store 指令（不需要 trace） */
static inline int skip_golden_trace(uint32_t opcode1) {
    /* 分支指令 */
    if (opcode1 == 0x10 || opcode1 == 0x11 || opcode1 == 0x13)
        return 1;
    /* store 指令 */
    if (opcode1 == 0x0D || opcode1 == 0x0F)
        return 1;
    return 0;
}

/* 输出 Golden Trace */
static inline void dump_golden_trace(uint32_t arch_pc) {
    init_golden_trace();

    /* 只关心写寄存器的指令 */
    if (ops_decoded.dest.type != OP_TYPE_REG)
        return;

    uint32_t opcode1 = instr >> 26;
    if (skip_golden_trace(opcode1))
        return;

    int reg = ops_decoded.dest.reg;
    uint32_t val = reg_w(reg);

    fprintf(golden_fp,
            "pc=0x%08x reg=%d value=0x%08x\n",
            arch_pc, reg, val);
    fflush(golden_fp);
}

/* ================================================= */

void print_bin_instr(uint32_t pc) {
    int i;
    int l = sprintf(asm_buf, "%8x:   ", pc);
    for (i = 3; i >= 0; i--) {
        l += sprintf(asm_buf + l, "%02x ", instr_fetch(pc + i, 1));
    }
    sprintf(asm_buf + l, "%*.s", 8, "");
}

/* cpu_exec: n 表示执行条数；RUN_FOREVER 表示一直运行 */
void cpu_exec(volatile uint32_t n) {
    if (temu_state == END) {
        printf("Program execution has ended. To restart, exit TEMU and run again.\n");
        return;
    }
    temu_state = RUNNING;

#ifdef DEBUG
    volatile uint32_t n_temp = n;
#endif

    if (n == RUN_FOREVER) {
        while (temu_state == RUNNING) {
            uint32_t arch_pc = cpu.pc;
            uint32_t pc = arch_pc & 0x7FFFFFFF;

#ifdef DEBUG
            if ((n_temp & 0xffff) == 0) fputc('.', stderr);
#endif
            exec(pc);

            /* ===== Golden Trace：记录本条指令的架构 PC ===== */
            dump_golden_trace(arch_pc);
            /* =========================================== */

            cpu.pc += 4;

#ifdef DEBUG
            print_bin_instr(pc);
            strcat(asm_buf, assembly);
            Log_write("%s", asm_buf);
            if (n_temp < MAX_INSTR_TO_PRINT) {
                printf("%s", asm_buf);
            }
#endif
            if (!check_wp()) {
                temu_state = STOP;
                break;
            }
            if (temu_state != RUNNING) break;
        }
    } else {
        for (; n > 0; n--) {
            uint32_t arch_pc = cpu.pc;
            uint32_t pc = arch_pc & 0x7FFFFFFF;

#ifdef DEBUG
            if ((n & 0xffff) == 0) fputc('.', stderr);
#endif
            exec(pc);

            /* ===== Golden Trace：记录本条指令的架构 PC ===== */
            dump_golden_trace(arch_pc);
            /* =========================================== */

            cpu.pc += 4;

#ifdef DEBUG
            print_bin_instr(pc);
            strcat(asm_buf, assembly);
            Log_write("%s", asm_buf);
            if (n_temp < MAX_INSTR_TO_PRINT) {
                printf("%s", asm_buf);
            }
#endif
            if (!check_wp()) {
                temu_state = STOP;
                break;
            }
            if (temu_state != RUNNING) break;
        }
    }

    if (temu_state == RUNNING) temu_state = STOP;
}
