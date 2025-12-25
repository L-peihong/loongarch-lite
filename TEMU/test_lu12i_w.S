#include "trap.h"
.org 0x0
.text
.global _start
_start:
    lu12i.w     $a0, 0x1234         # a0=0x1234<<12=0x12340000
    HIT_GOOD_TRAP
