
build/logic:     file format elf32-loongarch
build/logic


Disassembly of section .text:

80000000 <_start>:
_start():
80000000:	1400201e 	lu12i.w	$r30,256(0x100)
80000004:	03848c0c 	ori	$r12,$r0,0x123
80000008:	03848c0d 	ori	$r13,$r0,0x123
8000000c:	0391580e 	ori	$r14,$r0,0x456
80000010:	0380040f 	ori	$r15,$r0,0x1
80000014:	039e2410 	ori	$r16,$r0,0x789
80000018:	14000151 	lu12i.w	$r17,10(0xa)
8000001c:	03af3631 	ori	$r17,$r17,0xbcd
80000020:	0381fc12 	ori	$r18,$r0,0x7f
80000024:	03820013 	ori	$r19,$r0,0x80
80000028:	58000d8d 	beq	$r12,$r13,12(0xc) # 80000034 <label_beq>
8000002c:	03800017 	ori	$r23,$r0,0x0
80000030:	58000800 	beq	$r0,$r0,8(0x8) # 80000038 <bne_test>

80000034 <label_beq>:
label_beq():
80000034:	03800417 	ori	$r23,$r0,0x1

80000038 <bne_test>:
bne_test():
80000038:	5c000d8e 	bne	$r12,$r14,12(0xc) # 80000044 <label_bne>
8000003c:	03800018 	ori	$r24,$r0,0x0
80000040:	58000800 	beq	$r0,$r0,8(0x8) # 80000048 <bgeu_test>

80000044 <label_bne>:
label_bne():
80000044:	03800818 	ori	$r24,$r0,0x2

80000048 <bgeu_test>:
bgeu_test():
80000048:	6c000d8f 	bgeu	$r12,$r15,12(0xc) # 80000054 <label_bgeu1>
8000004c:	03800019 	ori	$r25,$r0,0x0
80000050:	58000800 	beq	$r0,$r0,8(0x8) # 80000058 <bgeu_test2>

80000054 <label_bgeu1>:
label_bgeu1():
80000054:	03800c19 	ori	$r25,$r0,0x3

80000058 <bgeu_test2>:
bgeu_test2():
80000058:	6c000d90 	bgeu	$r12,$r16,12(0xc) # 80000064 <label_bgeu2>
8000005c:	0380001a 	ori	$r26,$r0,0x0
80000060:	58000800 	beq	$r0,$r0,8(0x8) # 80000068 <mem_test>

80000064 <label_bgeu2>:
label_bgeu2():
80000064:	0383fc1a 	ori	$r26,$r0,0xff

80000068 <mem_test>:
mem_test():
80000068:	298003d1 	st.w	$r17,$r30,0
8000006c:	288003c4 	ld.w	$r4,$r30,0
80000070:	58000c91 	beq	$r4,$r17,12(0xc) # 8000007c <stw_ok>
80000074:	0383fc1b 	ori	$r27,$r0,0xff
80000078:	58000800 	beq	$r0,$r0,8(0x8) # 80000080 <stb_test>

8000007c <stw_ok>:
stw_ok():
8000007c:	0380101b 	ori	$r27,$r0,0x4

80000080 <stb_test>:
stb_test():
80000080:	290013d2 	st.b	$r18,$r30,4(0x4)
80000084:	280013c5 	ld.b	$r5,$r30,4(0x4)
80000088:	02be04a5 	addi.w	$r5,$r5,-127(0xf81)
8000008c:	58000ca0 	beq	$r5,$r0,12(0xc) # 80000098 <stb1_ok>
80000090:	0383fc1c 	ori	$r28,$r0,0xff
80000094:	58000800 	beq	$r0,$r0,8(0x8) # 8000009c <stb_test2>

80000098 <stb1_ok>:
stb1_ok():
80000098:	0380141c 	ori	$r28,$r0,0x5

8000009c <stb_test2>:
stb_test2():
8000009c:	290023d3 	st.b	$r19,$r30,8(0x8)
800000a0:	280023c6 	ld.b	$r6,$r30,8(0x8)
800000a4:	028200c6 	addi.w	$r6,$r6,128(0x80)
800000a8:	58000cc0 	beq	$r6,$r0,12(0xc) # 800000b4 <stb2_ok>
800000ac:	0383fc1d 	ori	$r29,$r0,0xff
800000b0:	58000800 	beq	$r0,$r0,8(0x8) # 800000b8 <trap>

800000b4 <stb2_ok>:
stb2_ok():
800000b4:	0380181d 	ori	$r29,$r0,0x6

800000b8 <trap>:
trap():
800000b8:	80000000 	0x80000000
