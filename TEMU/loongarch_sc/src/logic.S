#include "trap.h"    
.org 0x0
.text
.global _start
_start:
    # a0=0x100（256）、a1=0x0FF（255），bgeu跳转到label1，设置a2=1
    ori         $a0, $zero, 0x100  # a0=0x100
    ori         $a1, $zero, 0x0FF  # a1=0x0FF（a0>=a1）
    bgeu        $a0, $a1, label1   # 预期跳转
    ori         $a2, $zero, 0x0    # 不跳转则执行（实际不执行）
label1:
    ori         $a2, $zero, 0x1    # 预期a2=1
    HIT_GOOD_TRAP

