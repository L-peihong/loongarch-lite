#ifndef __WATCHPOINT_H__
#define __WATCHPOINT_H__
#include "common.h"

typedef struct watchpoint {
    int NO;
    struct watchpoint *next;
    uint32_t val;        // 表达式初始值
    uint32_t eval;       // 表达式目标值（用于相等判断）
    bool check_eval;     // 是否检查“等于目标值”（而非“值变化”）
    char expr[32];       // 监视的表达式字符串
} WP;

WP* new_wp();
void free_wp(WP *wp);
bool check_wp();
void delete_wp(int num);
void info_wp();
void init_wp_pool();  // 声明初始化函数

#endif