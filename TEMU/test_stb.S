#include "trap.h"
.org 0x0
.text
.global _start
_start:
    lu12i.w     $t0, 0x8001        # t0=0x80010000
    ori         $a0, $zero, 0xAB    # a0=0xAB（ui12合规）
    st.b        $a0, $t0, 4         # 存储到0x80010004
    HIT_GOOD_TRAP
