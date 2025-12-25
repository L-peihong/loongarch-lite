#include "trap.h"
.org 0x0
.text
.global _start
_start:
    ori         $a0, $zero, 0x1FF  # a0=0x1FF
    andi        $a1, $a0, 0x0F0     # a1=0x1F0（ui12合规）
    HIT_GOOD_TRAP
