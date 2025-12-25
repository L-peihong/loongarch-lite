#include "trap.h"
.org 0x0
.text
.global _start
_start:
    ori         $a0, $zero, 0x100  # a0=0x100
    ori         $a1, $a0, 0x0FF     # a1=0x1FF（ui12合规）
    HIT_GOOD_TRAP
