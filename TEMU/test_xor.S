#include "trap.h"
.org 0x0
.text
.global _start
_start:
    ori         $a0, $zero, 0x0F   # a0=0x0F
    ori         $a1, $zero, 0xF0   # a1=0xF0
    xor         $a2, $a0, $a1      # a2=0xFF
    HIT_GOOD_TRAP
