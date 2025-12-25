#include "trap.h"    
.org 0x0
.text
.global _start
_start:
    # a0=0x1FF，andi a1,a0,0x0F0（立即数0x0F0≤0xFFF合规）
    ori         $a0, $zero, 0x1FF  # a0=0x1FF
    andi        $a1, $a0, 0x0F0     # 预期a1=0x1FF&0x0F0=0x1F0
    HIT_GOOD_TRAP