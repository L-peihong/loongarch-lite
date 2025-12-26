
build/logic:     file format elf32-loongarch
build/logic


Disassembly of section .text:

80000000 <_start>:
_start():
80000000:	03840004 	ori	$r4,$r0,0x100
80000004:	0383fc05 	ori	$r5,$r0,0xff
80000008:	6c000885 	bgeu	$r4,$r5,8(0x8) # 80000010 <label1>
8000000c:	03800006 	ori	$r6,$r0,0x0

80000010 <label1>:
label1():
80000010:	03800406 	ori	$r6,$r0,0x1
80000014:	80000000 	0x80000000
