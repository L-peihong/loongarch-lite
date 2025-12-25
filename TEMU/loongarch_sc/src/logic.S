#include "trap.h"    
.org 0x0
.text
.global _start
_start:
    # a0=a1=0x100，beq跳转到label1，设置a2=1（不跳转则a2=0）
    ori         $a0, $zero, 0x100  # a0=0x100
    ori         $a1, $zero, 0x100  # a1=0x100（与a0相等）
    beq         $a0, $a1, label1   # 预期跳转
    ori         $a2, $zero, 0x0    # 不跳转则执行（实际不执行）
label1:
    ori         $a2, $zero, 0x1    # 预期a2=1
    HIT_GOOD_TRAP
