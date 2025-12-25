#include "trap.h"
.org 0x0
.text
.global _start
_start:
    lu12i.w     $t0, 0x8001        # t0=0x80010000
    ori         $a0, $zero, 0xAB    # 存储字节0xAB（符号位1）
    st.b        $a0, $t0, 4         # 存储到0x80010004
    ld.b        $a1, $t0, 4         # 符号扩展为0xFFFFFFFF
    HIT_GOOD_TRAP
