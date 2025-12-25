#include "trap.h"
.org 0x0
.text
.global _start
_start:
    ori         $a0, $zero, 0x100  # a0=0x100（ui12合规）
    addi.w      $a1, $a0, 0x200     # a1=0x300（si12合规）
    HIT_GOOD_TRAP
