#include "trap.h"
.org 0x0
.text
.global _start
_start:
    ori         $a0, $zero, 0x0FF  # a0=0xFF（255）
    sltui       $a1, $a0, 0x100     # a1=1（0xFF < 0x100）
    HIT_GOOD_TRAP
