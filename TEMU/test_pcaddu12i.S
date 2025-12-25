#include "trap.h"
.org 0x0
.text
.global _start
_start:
    pcaddu12i   $a0, 0x1           # a0=PC+0x1000（PC=0x80000000→0x80001000）
    HIT_GOOD_TRAP
