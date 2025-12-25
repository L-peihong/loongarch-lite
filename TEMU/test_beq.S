#include "trap.h"
.org 0x0
.text
.global _start
_start:
    ori         $a0, $zero, 0x100  # a0=0x100
    ori         $a1, $zero, 0x100  # a1=0x100（相等，跳转）
    beq         $a0, $a1, label1   # 跳转到label1
    ori         $a2, $zero, 0x0    # 不跳转则执行（实际不执行）
label1:
    ori         $a2, $zero, 0x1    # a2=0x1
    HIT_GOOD_TRAP
