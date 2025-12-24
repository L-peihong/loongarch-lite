#include "monitor.h"
#include "helper.h"
#include "watchpoint.h"
#include "reg.h"

#include <limits.h>

#define MAX_INSTR_TO_PRINT 10
#define RUN_FOREVER ((uint32_t)~0u) /* UINT32_MAX */

int temu_state = STOP;
void exec(uint32_t);
char assembly[80];
char asm_buf[128];

void print_bin_instr(uint32_t pc) {
    int i;
    int l = sprintf(asm_buf, "%8x:   ", pc);
    for (i = 3; i >= 0; i--) {
        l += sprintf(asm_buf + l, "%02x ", instr_fetch(pc + i, 1));
    }
    sprintf(asm_buf + l, "%*.s", 8, "");
}

/* cpu_exec: n 表示执行条数；若传入 RUN_FOREVER (UINT32_MAX) 则无限执行直到被暂停 */
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
        /* 无限循环直到监视点或终止 */
        while (temu_state == RUNNING) {
            uint32_t pc = cpu.pc & 0x7FFFFFFF;
#ifdef DEBUG
            if ((n_temp & 0xffff) == 0) fputc('.', stderr);
#endif
            exec(pc);
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
            if (temu_state != RUNNING) break;
        }
    } else {
        for (; n > 0; n--) {
            uint32_t pc = cpu.pc & 0x7FFFFFFF;
#ifdef DEBUG
            uint32_t pc_temp = pc;
            if ((n & 0xffff) == 0) fputc('.', stderr);
#endif
            exec(pc);
            cpu.pc += 4;

#ifdef DEBUG
            print_bin_instr(pc_temp);
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
            if (temu_state != RUNNING) break;
        }
    }

    if (temu_state == RUNNING) temu_state = STOP;
}

