#include "trap.h"    
.org 0x0  # 避免空字节填充，适配仿真环境
.text
.global _start
_start:
    # ==============================================
    # 初始化：构造分支/访存测试的基础数据（仅用指定指令：lu12i.w、ori）
    # ==============================================
    # 1. 访存基址初始化（0x100000，合规加载，小立即数无报错）
    lu12i.w     $s7, 0x100          # $s7 = 0x100<<12 = 0x100000（访存基址，指定指令）
    # 2. 分支指令测试数据构造（立即数均在ui12范围内）
    ori         $t0, $zero, 0x123   # 测试基数1：0x123（≤0xFFF，合规）
    ori         $t1, $zero, 0x123   # 与$t0相等（用于beq测试，合规）
    ori         $t2, $zero, 0x456   # 与$t0不等（用于bne测试，≤0xFFF，合规）
    ori         $t3, $zero, 0x001   # 小于$t0（用于bgeu反向测试，合规）
    ori         $t4, $zero, 0x789   # 大于$t0（用于bgeu正向测试，≤0xFFF，合规）
    # 3. 访存写入值构造（拆分0xABCD为ui12范围内，合规加载）
    lu12i.w     $t5, 0x0A           # 高20位：0x0A <<12 = 0xA000（si20=0x0A合规）
    ori         $t5, $t5, 0xBCD      # 低12位：0xBCD（≤0xFFF，组合为0xABCD，指定指令）
    # 4. 字节写入值构造（合规）
    ori         $t6, $zero, 0x7F    # 字节写入值（正数，合规）
    ori         $t7, $zero, 0x80    # 字节写入值（负数，验证符号扩展，合规）

    # ==============================================
    # 第一部分：分支指令验证（beq/bne/bgeu）- 无修改，保持原逻辑
    # ==============================================
    # 1. beq验证：$t0==$t1 → 跳转至label_beq，标记$s0=0x1（成功）
    beq         $t0, $t1, label_beq
    ori         $s0, $zero, 0x0     # 未跳转则标记0（失败）
    beq         $zero, $zero, bne_test  # 无条件跳转（复用beq，指定指令）
label_beq:
    ori         $s0, $zero, 0x1     # beq跳转成功标记（0x1）
bne_test:
    # 2. bne验证：$t0!=$t2 → 跳转至label_bne，标记$s1=0x2（成功）
    bne         $t0, $t2, label_bne
    ori         $s1, $zero, 0x0     # 未跳转则标记0（失败）
    beq         $zero, $zero, bgeu_test  # 无条件跳转（复用beq，指定指令）
label_bne:
    ori         $s1, $zero, 0x2     # bne跳转成功标记（0x2）
bgeu_test:
    # 3. bgeu验证：$t0>=0x001 → 跳转至label_bgeu1（标记$s2=0x3）；$t0>=0x789 → 不跳转（标记$s3=0x0）
    bgeu        $t0, $t3, label_bgeu1
    ori         $s2, $zero, 0x0     # 未跳转则标记0（失败）
    beq         $zero, $zero, bgeu_test2
label_bgeu1:
    ori         $s2, $zero, 0x3     # bgeu（大于等于）成功标记（0x3）
bgeu_test2:
    bgeu        $t0, $t4, label_bgeu2
    ori         $s3, $zero, 0x0     # 未跳转（正确），标记0
    beq         $zero, $zero, mem_test
label_bgeu2:
    ori         $s3, $zero, 0xFF    # 跳转则标记0xFF（失败，说明bgeu逻辑错误）

    # ==============================================
    # 第二部分：访存指令验证（简化逻辑，避免构造负数，无报错）
    # ==============================================
mem_test:
    # 1. st.w + ld.w验证：直接比较读取值与原始值，无需减法
    st.w        $t5, $s7, 0          # 字存储：0x100000 = 0xABCD（指定指令）
    ld.w        $a0, $s7, 0          # 字加载：$a0 = 0x100000的值（指定指令）
    beq         $a0, $t5, stw_ok     # 直接比较$a0与$t5（0xABCD），相等则成功（指定指令）
    ori         $s4, $zero, 0xFF     # 失败标记
    beq         $zero, $zero, stb_test
stw_ok:
    ori         $s4, $zero, 0x4      # st.w/ld.w成功标记（0x4）

    # 2. st.b + ld.b验证（字节读写，分正数/负数场景）- 无修改，保持原逻辑
stb_test:
    # 场景1：正数字节（0x7F）→ 加载后符号扩展为0x7F
    st.b        $t6, $s7, 4          # 字节存储：0x100004 = 0x7F（指定指令）
    ld.b        $a1, $s7, 4          # 字节加载：$a1 = 0x7F（指定指令）
    addi.w      $a1, $a1, -0x7F      # -0x7F在si12范围内（合规），流水线冒险测试
    beq         $a1, $zero, stb1_ok
    ori         $s5, $zero, 0xFF     # 失败标记
    beq         $zero, $zero, stb_test2
stb1_ok:
    ori         $s5, $zero, 0x5      # 正数字节读写成功标记（0x5）

    # 场景2：负数字节（0x80）→ 加载后符号扩展为0xFFFFFF80
stb_test2:
    st.b        $t7, $s7, 8          # 字节存储：0x100008 = 0x80（指定指令）
    ld.b        $a2, $s7, 8          # 字节加载：$a2 = 0xFFFFFF80（指定指令）
    addi.w      $a2, $a2, 0x80       # 0x80在si12范围内（合规），验证符号扩展
    beq         $a2, $zero, stb2_ok
    ori         $s6, $zero, 0xFF     # 失败标记
    beq         $zero, $zero, trap
stb2_ok:
    ori         $s6, $zero, 0x6      # 负数字节读写成功标记（0x6）

    # ==============================================
    # 收尾：触发陷阱（HIT_GOOD_TRAP为实验宏，非指令）
    # ==============================================
trap:
    HIT_GOOD_TRAP