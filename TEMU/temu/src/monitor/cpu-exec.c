#include "monitor.h"
#include "helper.h"
#include "watchpoint.h"
#include "reg.h"

#include <limits.h>
#include <stdio.h>
#include <string.h>

#define MAX_INSTR_TO_PRINT 10
#define RUN_FOREVER ((uint32_t)~0u)

extern uint32_t instr;

int temu_state = STOP;
void exec(uint32_t);
char assembly[80];
char asm_buf[128];

/* ================= Golden Trace ================= */

static FILE *golden_fp = NULL;

static inline void init_golden_trace() {
    if (golden_fp == NULL) {
        golden_fp = fopen("golden_trace.txt", "w");
        Assert(golden_fp, "Cannot open golden_trace.txt");
    }
}

static inline void dump_golden_trace(uint32_t arch_pc) {
    init_golden_trace();

    /* 只有本条指令真实写寄存器时才记录 */
    if (ops_decoded.dest.type != OP_TYPE_REG)
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

void cpu_exec(volatile uint32_t n) {
    if (temu_state == END) {
        printf("Program execution has ended. To restart, exit TEMU and run again.\n");
        return;
    }
    temu_state = RUNNING;

#ifdef DEBUG
    volatile uint32_t n_temp = n;
#endif

    while (temu_state == RUNNING && (n == RUN_FOREVER || n-- > 0)) {

        uint32_t arch_pc = cpu.pc;
        uint32_t pc = arch_pc & 0x7FFFFFFF;

        /* 关键修复：清空译码状态，避免残留 dest */
        memset(&ops_decoded, 0, sizeof(ops_decoded));

#ifdef DEBUG
        if ((n & 0xffff) == 0) fputc('.', stderr);
#endif

        exec(pc);

        /* Golden Trace：使用本条指令真实写回结果 */
        dump_golden_trace(arch_pc);

        cpu.pc += 4;

#ifdef DEBUG
        print_bin_instr(pc);
        strcat(asm_buf, assembly);
        Log_write("%s\n", asm_buf);
        if (n_temp < MAX_INSTR_TO_PRINT) {
            printf("%s\n", asm_buf);
        }
#endif

        if (!check_wp()) {
            temu_state = STOP;
            break;
        }
    }

    if (temu_state == RUNNING)
        temu_state = STOP;
}

