#include "trap.h"
.org 0x0
.text
.global _start
_start:
    ori         $a0, $zero, 0x100  # a0=0x100
    ori         $a1, $zero, 0x200  # a1=0x200
    add.w       $a2, $a0, $a1      # a2=0x300
    HIT_GOOD_TRAP
