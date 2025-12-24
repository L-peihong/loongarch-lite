#include "temu.h"
#include "reg.h"
#include <sys/types.h>
#include <regex.h>
#include <stdio.h>
#include <ctype.h>

/* Token 类型 */
enum {
    NOTYPE = 256, EQ, NEQ, AND, OR, MINUS, POINTER, DEX, HEX, VARIABLE, REGISTER
};

/* 运算符优先级（数值越小优先级越低，越靠外层） */
static struct rule {
    char *regex;
    int token_type;
    int prior;
} rules[] = {
    {"\\b0[xX][0-9a-fA-F]+\\b", HEX,   0},  /* 0x... */
    {"\\b[0-9]+\\b",            DEX,   0},  /* decimal */
    {"\\$[a-zA-Z_][a-zA-Z0-9_]*", REGISTER, 0}, /* $a0, $t1, $ra etc. */
    {" +",                     NOTYPE, 0},  /* spaces */
    {"\\+",                    '+',    4},
    {"\\-",                    '-',    4},
    {"\\*",                    '*',    5},
    {"/",                      '/',    5},
    {"==",                     EQ,     3},
    {"!=",                     NEQ,    3},
    {"!",                      '!',    6},
    {"&&",                     AND,    2},
    {"\\|\\|",                 OR,     1},
    {"\\(",                    '(',    7},
    {"\\)",                    ')',    7},
    {"[a-zA-Z_][a-zA-Z0-9_]*", VARIABLE,0},
};

#define NR_REGEX (sizeof(rules) / sizeof(rules[0]))
static regex_t re[NR_REGEX];

void init_regex() {
    int i;
    char error_msg[128];
    int ret;
    for (i = 0; i < NR_REGEX; i++) {
        ret = regcomp(&re[i], rules[i].regex, REG_EXTENDED);
        if (ret != 0) {
            regerror(ret, &re[i], error_msg, sizeof(error_msg));
            Assert(ret == 0, "regex compilation failed: %s\n%s", error_msg, rules[i].regex);
        }
    }
}

typedef struct token {
    int type;
    char str[64];
    int prior;
} Token;

Token tokens[64];
int nr_token;

/* 词法分析 */
static bool make_token(char *e) {
    int position = 0;
    int i;
    regmatch_t pmatch;
    nr_token = 0;

    while (e[position] != '\0') {
        for (i = 0; i < NR_REGEX; i++) {
            if (regexec(&re[i], e + position, 1, &pmatch, 0) == 0 && pmatch.rm_so == 0) {
                char *substr_start = e + position;
                int substr_len = pmatch.rm_eo;

                if (substr_len >= (int)sizeof(tokens[0].str)) {
                    puts("Expression token too long!");
                    return false;
                }

                position += substr_len;
                if (rules[i].token_type == NOTYPE) break;  /* 忽略空格 */

                Token *t = &tokens[nr_token];
                t->type = rules[i].token_type;
                t->prior = rules[i].prior;
                strncpy(t->str, substr_start, substr_len);
                t->str[substr_len] = '\0';

                if (t->type == REGISTER) {
                    /* 去掉 '$' 前缀，便于和 regfile[] 比较 */
                    memmove(t->str, t->str + 1, substr_len);
                    t->str[substr_len - 1] = '\0';
                }
                nr_token++;
                break;
            }
        }
        if (i == NR_REGEX) {
            printf("No match at position %d\n%s\n%*.s^\n", position, e, position, "");
            return false;
        }
    }
    return true;
}

/* 检查 [l,r] 是否被一对外层括号完整包裹 */
static bool check_parentheses(int l, int r) {
    if (tokens[l].type != '(' || tokens[r].type != ')') return false;
    int cnt = 0;
    for (int i = l; i <= r; i++) {
        if (tokens[i].type == '(') cnt++;
        else if (tokens[i].type == ')') cnt--;
        if (cnt == 0 && i < r) return false;
    }
    return cnt == 0;
}

/* 查找主导运算符（最外层、优先级最低） */
static int dominant_operator(int l, int r) {
    int pos = -1;
    int min_prior = 100;
    int cnt = 0;
    for (int i = l; i <= r; i++) {
        if (tokens[i].type == '(') { cnt++; continue; }
        if (tokens[i].type == ')') { cnt--; continue; }
        if (cnt != 0) continue;

        /* 跳过非运算符的 token */
        if (tokens[i].type == DEX || tokens[i].type == HEX || tokens[i].type == REGISTER || tokens[i].type == VARIABLE) continue;

        if (tokens[i].prior <= min_prior) {
            min_prior = tokens[i].prior;
            pos = i;
        }
    }
    return pos;
}

/* 递归求值 */
static uint32_t eval(int l, int r, bool *success) {
    if (l > r) { *success = false; return 0; }
    if (l == r) {
        Token *t = &tokens[l];
        uint32_t val = 0;
        if (t->type == DEX) {
            sscanf(t->str, "%u", &val);
        } else if (t->type == HEX) {
            sscanf(t->str, "%x", &val);
        } else if (t->type == REGISTER) {
            int reg_idx = -1;
            for (int i = 0; i < 32; i++) {
                if (strcmp(t->str, regfile[i]) == 0) {
                    reg_idx = i;
                    break;
                }
            }
            if (reg_idx == -1) {
                printf("Unknown register: $%s\n", t->str);
                *success = false;
                return 0;
            }
            val = reg_w(reg_idx);
        } else if (t->type == VARIABLE) {
            printf("Variable %s not supported (no symbol table)\n", t->str);
            *success = false;
            return 0;
        } else {
            *success = false;
            return 0;
        }
        *success = true;
        return val;
    }

    if (check_parentheses(l, r)) {
        return eval(l + 1, r - 1, success);
    }

    int op_pos = dominant_operator(l, r);
    if (op_pos == -1) {
        *success = false;
        return 0;
    }

    /* 单目运算（负号、逻辑非、指针解引用）检测：
       若主导运算符位置为 l 且为单目符号 */
    if (op_pos == l && (tokens[op_pos].type == MINUS || tokens[op_pos].type == '!' || tokens[op_pos].type == POINTER)) {
        uint32_t v = eval(l + 1, r, success);
        if (!*success) return 0;
        switch (tokens[op_pos].type) {
            case MINUS: return (uint32_t)(-(int32_t)v);
            case '!': return (!v) ? 1 : 0;
            case POINTER: {
                uint32_t paddr = v & 0x7FFFFFFF;
                return mem_read(paddr, 4);
            }
            default: *success = false; return 0;
        }
    }

    /* 双目运算 */
    uint32_t v1 = eval(l, op_pos - 1, success);
    if (!*success) return 0;
    uint32_t v2 = eval(op_pos + 1, r, success);
    if (!*success) return 0;

    switch (tokens[op_pos].type) {
        case '+': return v1 + v2;
        case '-': return v1 - v2;
        case '*': return v1 * v2;
        case '/':
            if (v2 == 0) {
                printf("Division by zero\n");
                *success = false;
                return 0;
            }
            return v1 / v2;
        case EQ:  return v1 == v2;
        case NEQ: return v1 != v2;
        case AND: return (v1 && v2) ? 1 : 0;
        case OR:  return (v1 || v2) ? 1 : 0;
        default: *success = false; return 0;
    }
}

/* 入口：区分单目和双目 '-' '*' */
uint32_t expr(char *e, bool *success) {
    if (!make_token(e)) {
        *success = false;
        return 0;
    }

    /* 区分单目 '-' 和 '*'（指针解引用） */
    for (int i = 0; i < nr_token; i++) {
        if (tokens[i].type == '-' || tokens[i].type == '*') {
            bool is_unary = (i == 0) ||
                (tokens[i-1].type != DEX && tokens[i-1].type != HEX && tokens[i-1].type != REGISTER && tokens[i-1].type != VARIABLE && tokens[i-1].type != ')');
            if (is_unary) {
                if (tokens[i].type == '-') {
                    tokens[i].type = MINUS;
                    tokens[i].prior = 6;
                } else {
                    tokens[i].type = POINTER;
                    tokens[i].prior = 6;
                }
            }
        }
    }

    *success = true;
    return eval(0, nr_token - 1, success);
}

