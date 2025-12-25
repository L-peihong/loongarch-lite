#include "trap.h"
.org 0x0
.text
.global _start
_start:
    ori         $a0, $zero, 0x100  # a0=0x00000100
    ori         $a1, $zero, 0x4    # 移位量=4（a1[4:0]=4）
    sll.w       $a2, $a0, $a1      # a2=0x00001000
    HIT_GOOD_TRAP
