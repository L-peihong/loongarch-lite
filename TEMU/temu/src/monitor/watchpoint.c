#include "watchpoint.h"
#include "expr.h"
#include "reg.h"
#include "monitor.h"
#include <stdio.h>

#define NR_WP 32

static WP wp_pool[NR_WP];
static WP *head, *free_;  /* head: 使用中链表；free_: 空闲链表 */

/* 初始化监视点池 */
void init_wp_pool() {
    for (int i = 0; i < NR_WP; i++) {
        wp_pool[i].NO = i;
        wp_pool[i].next = (i < NR_WP - 1) ? &wp_pool[i + 1] : NULL;
        wp_pool[i].val = 0;
        wp_pool[i].eval = 0;
        wp_pool[i].check_eval = false;
        wp_pool[i].expr[0] = '\0';
    }
    head = NULL;
    free_ = wp_pool;
}

/* 从空闲池申请新监视点（返回指针） */
WP *new_wp() {
    if (free_ == NULL) {
        Assert(0, "No free watchpoint available!");
    }
    WP *node = free_;
    free_ = free_->next;

    /* 初始化 node 字段 */
    node->next = NULL;
    node->val = 0;
    node->eval = 0;
    node->check_eval = false;
    node->expr[0] = '\0';

    /* 加入 head 链表尾部 */
    if (head == NULL) head = node;
    else {
        WP *p = head;
        while (p->next) p = p->next;
        p->next = node;
    }
    return node;
}

/* 释放监视点（归还给空闲池） */
void free_wp(WP *wp) {
    if (wp == NULL) return;
    /* 从 head 链表中移除 */
    if (head == NULL) {
        Assert(0, "free_wp called but no watchpoint in use");
    }
    if (head == wp) {
        head = head->next;
    } else {
        WP *prev = head;
        while (prev->next && prev->next != wp) prev = prev->next;
        if (prev->next == NULL) {
            Assert(0, "watchpoint %d not found in list", wp->NO);
        }
        prev->next = prev->next->next;
    }

    /* 重置并放回空闲池头 */
    wp->val = 0;
    wp->eval = 0;
    wp->check_eval = false;
    wp->expr[0] = '\0';
    wp->next = free_;
    free_ = wp;
}

/* 删除给定序号的监视点 */
void delete_wp(int num) {
    if (num < 0 || num >= NR_WP) {
        printf("Invalid watchpoint number %d!\n", num);
        return;
    }
    WP *wp = &wp_pool[num];
    /* 确认在 head 链表中 */
    WP *p = head;
    while (p != NULL && p != wp) p = p->next;
    if (p == NULL) {
        printf("Watchpoint %d is not set!\n", num);
        return;
    }
    free_wp(wp);
    printf("Watchpoint %d deleted.\n", num);
}

/* 打印所有使用中的监视点 */
void info_wp() {
    WP *p = head;
    if (!p) {
        puts("No watchpoints currently set.");
        return;
    }
    printf("Watchpoint List:\n");
    while (p) {
        if (p->check_eval) {
            printf("NO.%d: %s == 0x%08x (%d)\n", p->NO, p->expr, p->eval, p->eval);
        } else {
            printf("NO.%d: %s  (value snapshot = 0x%08x (%d))\n", p->NO, p->expr, p->val, p->val);
        }
        p = p->next;
    }
}

/* 检查所有监视点：若触发则打印并返回 false（表示执行应暂停）；
   若没有触发则返回 true（继续执行）。 */
bool check_wp() {
    WP *p = head;
    bool any_trigger = false;
    bool success;
    while (p) {
        uint32_t cur = expr(p->expr, &success);
        if (!success) {
            printf("Invalid expression for watchpoint %d: %s\n", p->NO, p->expr);
            p = p->next;
            continue;
        }
        if (p->check_eval) {
            if (cur == p->eval) {
                printf("\nHit watchpoint %d at pc = 0x%08x:\n", p->NO, cpu.pc);
                printf("Expression %s equals target value 0x%08x (%d)\n", p->expr, cur, cur);
                any_trigger = true;
            }
        } else {
            if (cur != p->val) {
                printf("\nHit watchpoint %d at pc = 0x%08x:\n", p->NO, cpu.pc);
                printf("Old value: 0x%08x (%d)\n", p->val, p->val);
                printf("New value: 0x%08x (%d)\n", cur, cur);
                p->val = cur;
                any_trigger = true;
            }
        }
        p = p->next;
    }
    return !any_trigger;
}

