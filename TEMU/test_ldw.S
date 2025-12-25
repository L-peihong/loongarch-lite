#include "trap.h"
.org 0x0
.text
.global _start
_start:
    lu12i.w     $t0, 0x8001        # t0=0x80010000
    lu12i.w     $a0, 0x12345      # 组合赋值0x12345678
    ori         $a0, $a0, 0x678
    st.w        $a0, $t0, 0       # 先存储到内存
    ld.w        $a1, $t0, 0       # 读取内存值到a1
    HIT_GOOD_TRAP
