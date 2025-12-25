#include "trap.h"
.org 0x0
.text
.global _start
_start:
    lu12i.w     $t0, 0x8001        # t0=0x80010000（data段基址）
    lu12i.w     $a0, 0x12345      # a0=0x12345000
    ori         $a0, $a0, 0x678   # a0=0x12345678（组合赋值，无溢出）
    st.w        $a0, $t0, 0       # 存储到0x80010000
    HIT_GOOD_TRAP
