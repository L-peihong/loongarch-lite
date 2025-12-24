#include "monitor.h"
#include "expr.h"
#include "watchpoint.h"
#include "reg.h"
#include "memory.h"
#include <stdlib.h>
#include <readline/readline.h>
#include <readline/history.h>
#include <string.h>
#include <limits.h>
#include <ctype.h>
#include <stdio.h>

void cpu_exec(uint32_t);
#define RUN_FOREVER ((uint32_t)~0u)

/* helper: trim in-place */
static void trim(char *s) {
    if (!s) return;
    char *p = s;
    while (isspace((unsigned char)*p)) p++;
    if (p != s) memmove(s, p, strlen(p) + 1);
    int len = strlen(s);
    while (len > 0 && isspace((unsigned char)s[len - 1])) s[--len] = '\0';
}

/* rl_gets */
char* rl_gets() {
    static char *line_read = NULL;
    if (line_read) {
        free(line_read);
        line_read = NULL;
    }
    line_read = readline("(temu) ");
    if (line_read && *line_read) add_history(line_read);
    return line_read;
}

/* continue */
static int cmd_c(char *args) {
    cpu_exec(RUN_FOREVER);
    return 0;
}

/* quit */
static int cmd_q(char *args) { return -1; }

/* single-step si [N] */
static int cmd_si(char *args) {
    uint32_t n = 1;
    if (args != NULL) {
        char buf[64];
        strncpy(buf, args, sizeof(buf)-1);
        buf[sizeof(buf)-1] = '\0';
        trim(buf);
        if (strlen(buf) > 0) {
            n = (uint32_t)atoi(buf);
            if (n == 0) {
                puts("Invalid number of instructions (must be positive).");
                return 1;
            }
        }
    }
    cpu_exec(n);
    return 0;
}

/* x N EXPR - dump memory N words from EXPR */
static int cmd_x(char *args) {
    if (!args) {
        puts("Usage: x N EXPR");
        return 1;
    }
    char buf[256];
    strncpy(buf, args, sizeof(buf)-1);
    buf[sizeof(buf)-1] = '\0';
    trim(buf);
    char *p = buf;
    char *n_str = strtok(p, " ");
    char *expr_str = strtok(NULL, "");
    if (!n_str || !expr_str) {
        puts("Usage: x N EXPR");
        return 1;
    }
    trim(n_str);
    trim(expr_str);
    int n = atoi(n_str);
    if (n <= 0) {
        puts("N must be positive");
        return 1;
    }
    bool success;
    uint32_t start = expr(expr_str, &success);
    if (!success) {
        puts("Invalid expression for address");
        return 1;
    }
    start &= 0x7FFFFFFF;
    printf("Memory from 0x%08x (%d words):\n", start, n);
    for (int i = 0; i < n; i++) {
        uint32_t addr = start + i * 4;
        uint32_t val = mem_read(addr, 4);
        if (i % 4 == 0) printf("0x%08x: ", addr);
        printf("0x%08x ", val);
        if (i % 4 == 3) putchar('\n');
    }
    if (n % 4 != 0) putchar('\n');
    return 0;
}

/* info r / info w */
static int cmd_info(char *args) {
    if (!args) {
        puts("Usage: info r | info w");
        return 1;
    }
    char buf[32];
    strncpy(buf, args, sizeof(buf)-1);
    buf[sizeof(buf)-1] = '\0';
    trim(buf);
    if (strcmp(buf, "r") == 0) {
        display_reg();
    } else if (strcmp(buf, "w") == 0) {
        info_wp();
    } else {
        puts("Invalid subcommand for info");
        return 1;
    }
    return 0;
}

/* w EXPR  (or w EXPR == VAL) */
static int cmd_w(char *args) {
    if (!args) {
        puts("Usage: w EXPR (e.g., w $a0 or w $a0 == 0x100)");
        return 1;
    }
    char buf[256];
    strncpy(buf, args, sizeof(buf)-1);
    buf[sizeof(buf)-1] = '\0';
    trim(buf);

    /* 检查是否包含 "=="（注意不要修改原始 args） */
    char *eq = strstr(buf, "==");
    if (eq) {
        /* split into left and right */
        *eq = '\0';
        char *left = buf;
        char *right = eq + 2;
        trim(left);
        trim(right);
        if (strlen(left) == 0 || strlen(right) == 0) {
            puts("Invalid watch expression");
            return 1;
        }
        /* 解析右侧目标值 */
        bool success = false;
        uint32_t target = expr(right, &success);
        if (!success) {
            puts("Invalid target expression");
            return 1;
        }
        WP *wp = new_wp();
        strncpy(wp->expr, left, sizeof(wp->expr)-1);
        wp->expr[sizeof(wp->expr)-1] = '\0';
        wp->check_eval = true;
        wp->eval = target;
        printf("Watchpoint %d set: %s == 0x%08x (%d)\n", wp->NO, wp->expr, wp->eval, wp->eval);
        return 0;
    } else {
        /* 普通“值变化”监视点：先 eval 表达式作为初值 */
        bool success = false;
        uint32_t init = expr(buf, &success);
        if (!success) {
            puts("Invalid expression");
            return 1;
        }
        WP *wp = new_wp();
        strncpy(wp->expr, buf, sizeof(wp->expr)-1);
        wp->expr[sizeof(wp->expr)-1] = '\0';
        wp->val = init;
        wp->check_eval = false;
        printf("Watchpoint %d set: %s (initial = 0x%08x (%d))\n", wp->NO, wp->expr, wp->val, wp->val);
        return 0;
    }
}

/* d N */
static int cmd_d(char *args) {
    if (!args) {
        puts("Usage: d N");
        return 1;
    }
    char buf[32];
    strncpy(buf, args, sizeof(buf)-1);
    buf[sizeof(buf)-1] = '\0';
    trim(buf);
    int num = atoi(buf);
    delete_wp(num);
    return 0;
}

/* p EXPR */
static int cmd_p(char *args) {
    if (!args) {
        puts("Usage: p EXPR");
        return 1;
    }
    char buf[256];
    strncpy(buf, args, sizeof(buf)-1);
    buf[sizeof(buf)-1] = '\0';
    trim(buf);
    bool success = false;
    uint32_t v = expr(buf, &success);
    if (!success) {
        puts("Invalid expression");
        return 1;
    }
    printf("0x%08x (%d)\n", v, v);
    return 0;
}

/* help */
static int cmd_help(char *args) {
    char *arg = NULL;
    if (args) {
        char buf[64];
        strncpy(buf, args, sizeof(buf)-1);
        buf[sizeof(buf)-1] = '\0';
        trim(buf);
        arg = buf;
    }
    if (!arg || strlen(arg) == 0) {
        printf("TEMU Commands:\n");
        printf("  help        - Display this help message\n");
        printf("  c           - Continue program execution\n");
        printf("  q           - Exit TEMU\n");
        printf("  si [N]      - Step N instructions (default: 1)\n");
        printf("  info r      - Print all registers\n");
        printf("  info w      - Print all watchpoints\n");
        printf("  x N EXPR    - Dump N 4-byte words from address EXPR\n");
        printf("  w EXPR      - Set watchpoint on EXPR (value change or equality)\n");
        printf("  d N         - Delete watchpoint N\n");
        printf("  p EXPR      - Evaluate expression EXPR\n");
    } else {
        if (strcmp(arg, "si") == 0) printf("si [N] - Step N instructions (default: 1)\n");
        else if (strcmp(arg, "info") == 0) printf("info r - Print registers; info w - Print watchpoints\n");
        else if (strcmp(arg, "x") == 0) printf("x N EXPR - Dump N 4-byte words from address EXPR\n");
        else if (strcmp(arg, "w") == 0) printf("w EXPR - Set watchpoint (e.g., w $a0 == 0x100)\n");
        else if (strcmp(arg, "d") == 0) printf("d N - Delete watchpoint N\n");
        else if (strcmp(arg, "p") == 0) printf("p EXPR - Evaluate expression EXPR\n");
        else printf("Unknown command '%s'\n", arg);
    }
    return 0;
}

/* 命令表 */
static struct {
    char *name;
    char *description;
    int (*handler) (char *);
} cmd_table [] = {
    { "help", "Display help message", cmd_help },
    { "c", "Continue program execution", cmd_c },
    { "q", "Exit TEMU", cmd_q },
    // 基础交互 (si, info, x)
    { "si", "Step N instructions (default: 1)", cmd_si },
    { "info", "Print registers (info r) or watchpoints (info w)", cmd_info },
    { "x", "Dump memory: x N EXPR", cmd_x },
    //监视点 (w, d)
    { "w", "Set watchpoint: w EXPR", cmd_w },
    { "d", "Delete watchpoint: d N", cmd_d },
    // 表达式求值 (p)
    { "p", "Evaluate expression: p EXPR", cmd_p },
};

#define NR_CMD (sizeof(cmd_table) / sizeof(cmd_table[0]))

/* 主循环 */
void ui_mainloop() {
    while (1) {
        char *str = rl_gets();
        if (str == NULL) { return; }

        char *str_end = str + strlen(str);
        char *cmd = strtok(str, " ");
        
        // 情况1：空命令
        if (cmd == NULL) {
            // free(str); // 【删除】不要释放，rl_gets 会处理
            continue;
        }

        char *args = cmd + strlen(cmd) + 1;
        if (args >= str_end) args = NULL;

        int i;
        for (i = 0; i < NR_CMD; i++) {
            if (strcmp(cmd, cmd_table[i].name) == 0) {
                // 情况2：执行命令（包括 q 退出命令）
                if (cmd_table[i].handler(args) < 0) {
                    // free(str); // 【删除】即使退出程序也不要手动释放
                    return;
                }
                break;
            }
        }

        if (i == NR_CMD) {
            printf("Unknown command '%s' (type 'help' for help)", cmd);
        }
        
        // 情况3：循环结束
        // free(str); // 【删除】绝对不要在这里释放
    }
}

