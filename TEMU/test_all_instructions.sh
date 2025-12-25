#!/bin/bash
set -euo pipefail

# 前置检查：依赖工具
check_dependency() {
    local tools=("loongarch32r-linux-gnusf-gcc" "loongarch32r-linux-gnusf-objcopy" "loongarch32r-linux-gnusf-ld" "expect" "grep" "awk")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            echo "错误：缺少依赖工具 $tool，请先安装配置"
            exit 1
        fi
    done
    if [ ! -f "./build/temu" ]; then
        echo "错误：未找到TEMU可执行文件，请先编译TEMU（make）"
        exit 1
    fi
    if [ ! -d "./loongarch_sc/include" ]; then
        echo "错误：缺少loongarch_sc/include目录，请确认路径正确"
        exit 1
    fi
}

# 环境清理
clean_env() {
    echo "=== 清理测试环境 ==="
    rm -rf test_build/ test_logs/ test_reports/
    mkdir -p test_build/ test_logs/ test_reports/
    rm -f inst.bin data.bin golden_trace.txt log.txt
}

# 生成测试代码文件
generate_test_code() {
    local inst_name=$1
    local code_file=$2
    case $inst_name in
        "addi.w")
            cat > $code_file <<EOF
#include "trap.h"
.org 0x0
.text
.global _start
_start:
    ori         \$a0, \$zero, 0x100  # a0=0x100（ui12合规）
    addi.w      \$a1, \$a0, 0x200     # a1=0x300（si12合规）
    HIT_GOOD_TRAP
EOF
            ;;
        "add.w")
            cat > $code_file <<EOF
#include "trap.h"
.org 0x0
.text
.global _start
_start:
    ori         \$a0, \$zero, 0x100  # a0=0x100
    ori         \$a1, \$zero, 0x200  # a1=0x200
    add.w       \$a2, \$a0, \$a1      # a2=0x300
    HIT_GOOD_TRAP
EOF
            ;;
        "lu12i.w")
            cat > $code_file <<EOF
#include "trap.h"
.org 0x0
.text
.global _start
_start:
    lu12i.w     \$a0, 0x1234         # a0=0x1234<<12=0x12340000
    HIT_GOOD_TRAP
EOF
            ;;
        "pcaddu12i")
            cat > $code_file <<EOF
#include "trap.h"
.org 0x0
.text
.global _start
_start:
    pcaddu12i   \$a0, 0x1           # a0=PC+0x1000（PC=0x80000000→0x80001000）
    HIT_GOOD_TRAP
EOF
            ;;
        "or")
            cat > $code_file <<EOF
#include "trap.h"
.org 0x0
.text
.global _start
_start:
    ori         \$a0, \$zero, 0x0F   # a0=0x0F
    ori         \$a1, \$zero, 0xF0   # a1=0xF0
    or          \$a2, \$a0, \$a1      # a2=0xFF
    HIT_GOOD_TRAP
EOF
            ;;
        "ori")
            cat > $code_file <<EOF
#include "trap.h"
.org 0x0
.text
.global _start
_start:
    ori         \$a0, \$zero, 0x100  # a0=0x100
    ori         \$a1, \$a0, 0x0FF     # a1=0x1FF（ui12合规）
    HIT_GOOD_TRAP
EOF
            ;;
        "andi")
            cat > $code_file <<EOF
#include "trap.h"
.org 0x0
.text
.global _start
_start:
    ori         \$a0, \$zero, 0x1FF  # a0=0x1FF
    andi        \$a1, \$a0, 0x0F0     # a1=0x1F0（ui12合规）
    HIT_GOOD_TRAP
EOF
            ;;
        "xor")
            cat > $code_file <<EOF
#include "trap.h"
.org 0x0
.text
.global _start
_start:
    ori         \$a0, \$zero, 0x0F   # a0=0x0F
    ori         \$a1, \$zero, 0xF0   # a1=0xF0
    xor         \$a2, \$a0, \$a1      # a2=0xFF
    HIT_GOOD_TRAP
EOF
            ;;
        "beq")
            cat > $code_file <<EOF
#include "trap.h"
.org 0x0
.text
.global _start
_start:
    ori         \$a0, \$zero, 0x100  # a0=0x100
    ori         \$a1, \$zero, 0x100  # a1=0x100（相等，跳转）
    beq         \$a0, \$a1, label1   # 跳转到label1
    ori         \$a2, \$zero, 0x0    # 不跳转则执行（实际不执行）
label1:
    ori         \$a2, \$zero, 0x1    # a2=0x1
    HIT_GOOD_TRAP
EOF
            ;;
        "bne")
            cat > $code_file <<EOF
#include "trap.h"
.org 0x0
.text
.global _start
_start:
    ori         \$a0, \$zero, 0x100  # a0=0x100
    ori         \$a1, \$zero, 0x200  # a1=0x200（不相等，跳转）
    bne         \$a0, \$a1, label1   # 跳转到label1
    ori         \$a2, \$zero, 0x0    # 不跳转则执行（实际不执行）
label1:
    ori         \$a2, \$zero, 0x1    # a2=0x1
    HIT_GOOD_TRAP
EOF
            ;;
        "st.w")
            cat > $code_file <<EOF
#include "trap.h"
.org 0x0
.text
.global _start
_start:
    lu12i.w     \$t0, 0x8001        # t0=0x80010000（data段基址）
    lu12i.w     \$a0, 0x12345      # a0=0x12345000
    ori         \$a0, \$a0, 0x678   # a0=0x12345678（组合赋值，无溢出）
    st.w        \$a0, \$t0, 0       # 存储到0x80010000
    HIT_GOOD_TRAP
EOF
            ;;
        "ld.w")
            cat > $code_file <<EOF
#include "trap.h"
.org 0x0
.text
.global _start
_start:
    lu12i.w     \$t0, 0x8001        # t0=0x80010000
    lu12i.w     \$a0, 0x12345      # 组合赋值0x12345678
    ori         \$a0, \$a0, 0x678
    st.w        \$a0, \$t0, 0       # 先存储到内存
    ld.w        \$a1, \$t0, 0       # 读取内存值到a1
    HIT_GOOD_TRAP
EOF
            ;;
        "st.b")
            cat > $code_file <<EOF
#include "trap.h"
.org 0x0
.text
.global _start
_start:
    lu12i.w     \$t0, 0x8001        # t0=0x80010000
    ori         \$a0, \$zero, 0xAB    # a0=0xAB（ui12合规）
    st.b        \$a0, \$t0, 4         # 存储到0x80010004
    HIT_GOOD_TRAP
EOF
            ;;
        "ld.b")
            cat > $code_file <<EOF
#include "trap.h"
.org 0x0
.text
.global _start
_start:
    lu12i.w     \$t0, 0x8001        # t0=0x80010000
    ori         \$a0, \$zero, 0xAB    # 存储字节0xAB（符号位1）
    st.b        \$a0, \$t0, 4         # 存储到0x80010004
    ld.b        \$a1, \$t0, 4         # 符号扩展为0xFFFFFFFF
    HIT_GOOD_TRAP
EOF
            ;;
        "sltui")
            cat > $code_file <<EOF
#include "trap.h"
.org 0x0
.text
.global _start
_start:
    ori         \$a0, \$zero, 0x0FF  # a0=0xFF（255）
    sltui       \$a1, \$a0, 0x100     # a1=1（0xFF < 0x100）
    HIT_GOOD_TRAP
EOF
            ;;
        "sll.w")
            cat > $code_file <<EOF
#include "trap.h"
.org 0x0
.text
.global _start
_start:
    ori         \$a0, \$zero, 0x100  # a0=0x00000100
    ori         \$a1, \$zero, 0x4    # 移位量=4（a1[4:0]=4）
    sll.w       \$a2, \$a0, \$a1      # a2=0x00001000
    HIT_GOOD_TRAP
EOF
            ;;
        "bgeu")
            cat > $code_file <<EOF
#include "trap.h"
.org 0x0
.text
.global _start
_start:
    ori         \$a0, \$zero, 0x100  # a0=0x100（256）
    ori         \$a1, \$zero, 0x0FF  # a1=0x0FF（255）
    bgeu        \$a0, \$a1, label1   # a0>=a1，跳转
    ori         \$a2, \$zero, 0x0    # 不跳转则执行（实际不执行）
label1:
    ori         \$a2, \$zero, 0x1    # a2=0x1
    HIT_GOOD_TRAP
EOF
            ;;
    esac
}

# 执行TEMU自动化交互（使用expect）
run_temu_expect() {
    local inst_name=$1
    local temu_cmds=$2
    local log_file="test_logs/${inst_name}_temu.log"
    cat > test_build/temu_expect.tcl <<EOF
#!/usr/bin/expect -f
set timeout 10
spawn ./build/temu logic
expect "(temu) "
send "${temu_cmds}\n"
expect eof
EOF
    chmod +x test_build/temu_expect.tcl
    ./test_build/temu_expect.tcl > $log_file 2>&1
    rm -f test_build/temu_expect.tcl
    echo "$log_file"
}

# 解析测试结果（适配TEMU info r输出格式：$a1  0x80400100 (-2143289088)）
parse_result() {
    local inst_name=$1
    local expected=$2
    local log_file=$3
    local actual="N/A"
    local status="Fail"

    # 解析寄存器值（从info r的完整输出中提取目标寄存器）
    if echo "$expected" | grep -q "="; then
        local reg=$(echo "$expected" | cut -d"=" -f1)
        local exp_val=$(echo "$expected" | cut -d"=" -f2 | sed 's/^0x//' | tr 'a-z' 'A-Z')
        # 匹配格式：$reg  0xXXXXXXXX (...)，提取十六进制值
        actual=$(grep -E "^\\\$${reg}\\s+0x" $log_file | awk '{print $2}' | sed 's/^0x//' | tr 'a-z' 'A-Z')
        # 处理空值（未提取到）
        if [ -z "$actual" ]; then actual="N/A"; fi
        # 对比结果（忽略大小写和空格）
        if [ "$actual" == "$exp_val" ]; then
            status="Pass"
        fi
    # 解析内存值（格式：0x80010000: 0x12345678）
    elif echo "$expected" | grep -q "内存"; then
        local addr=$(echo "$expected" | grep -oE "0x[0-9A-Fa-f]+" | head -n1 | sed 's/^0x//' | tr 'a-z' 'A-Z')
        local exp_val=$(echo "$expected" | grep -oE "0x[0-9A-Fa-f]+$" | sed 's/^0x//' | tr 'a-z' 'A-Z')
        # 提取内存值（忽略地址后的冒号和空格）
        actual=$(grep -E "^0x${addr}:" $log_file | awk '{print $2}' | sed 's/^0x//' | tr 'a-z' 'A-Z')
        if [ -z "$actual" ]; then actual="N/A"; fi
        if [ "$actual" == "$exp_val" ]; then
            status="Pass"
        fi
    fi
    echo "$status|$actual"
}

# 定义17条指令测试用例（修正：TEMU交互命令，将info r 寄存器名改为info r）
declare -A test_cases=(
    ["addi.w"]="test_addi_w.S|loongarch32r-linux-gnusf-gcc -nostdinc -nostdlib -fno-builtin -mabi=ilp32s -Iloongarch_sc/include -c test_addi_w.S -o test_build/test_addi_w.o; loongarch32r-linux-gnusf-ld -T loongarch_sc/default.ld test_build/test_addi_w.o -o test_build/test_addi_w; loongarch32r-linux-gnusf-objcopy -O binary -j .text test_build/test_addi_w inst.bin; loongarch32r-linux-gnusf-objcopy -O binary -j .data test_build/test_addi_w data.bin|si 2; info r; q|a1=0x00000300"
    ["add.w"]="test_add_w.S|loongarch32r-linux-gnusf-gcc -nostdinc -nostdlib -fno-builtin -mabi=ilp32s -Iloongarch_sc/include -c test_add_w.S -o test_build/test_add_w.o; loongarch32r-linux-gnusf-ld -T loongarch_sc/default.ld test_build/test_add_w.o -o test_build/test_add_w; loongarch32r-linux-gnusf-objcopy -O binary -j .text test_build/test_add_w inst.bin; loongarch32r-linux-gnusf-objcopy -O binary -j .data test_build/test_add_w data.bin|si 3; info r; q|a2=0x00000300"
    ["lu12i.w"]="test_lu12i_w.S|loongarch32r-linux-gnusf-gcc -nostdinc -nostdlib -fno-builtin -mabi=ilp32s -Iloongarch_sc/include -c test_lu12i_w.S -o test_build/test_lu12i_w.o; loongarch32r-linux-gnusf-ld -T loongarch_sc/default.ld test_build/test_lu12i_w.o -o test_build/test_lu12i_w; loongarch32r-linux-gnusf-objcopy -O binary -j .text test_build/test_lu12i_w inst.bin; loongarch32r-linux-gnusf-objcopy -O binary -j .data test_build/test_lu12i_w data.bin|si 1; info r; q|a0=0x12340000"
    ["pcaddu12i"]="test_pcaddu12i.S|loongarch32r-linux-gnusf-gcc -nostdinc -nostdlib -fno-builtin -mabi=ilp32s -Iloongarch_sc/include -c test_pcaddu12i.S -o test_build/test_pcaddu12i.o; loongarch32r-linux-gnusf-ld -T loongarch_sc/default.ld test_build/test_pcaddu12i.o -o test_build/test_pcaddu12i; loongarch32r-linux-gnusf-objcopy -O binary -j .text test_build/test_pcaddu12i inst.bin; loongarch32r-linux-gnusf-objcopy -O binary -j .data test_build/test_pcaddu12i data.bin|si 1; info r; q|a0=0x80001000"
    ["or"]="test_or.S|loongarch32r-linux-gnusf-gcc -nostdinc -nostdlib -fno-builtin -mabi=ilp32s -Iloongarch_sc/include -c test_or.S -o test_build/test_or.o; loongarch32r-linux-gnusf-ld -T loongarch_sc/default.ld test_build/test_or.o -o test_build/test_or; loongarch32r-linux-gnusf-objcopy -O binary -j .text test_build/test_or inst.bin; loongarch32r-linux-gnusf-objcopy -O binary -j .data test_build/test_or data.bin|si 3; info r; q|a2=0x000000FF"
    ["ori"]="test_ori.S|loongarch32r-linux-gnusf-gcc -nostdinc -nostdlib -fno-builtin -mabi=ilp32s -Iloongarch_sc/include -c test_ori.S -o test_build/test_ori.o; loongarch32r-linux-gnusf-ld -T loongarch_sc/default.ld test_build/test_ori.o -o test_build/test_ori; loongarch32r-linux-gnusf-objcopy -O binary -j .text test_build/test_ori inst.bin; loongarch32r-linux-gnusf-objcopy -O binary -j .data test_build/test_ori data.bin|si 2; info r; q|a1=0x000001FF"
    ["andi"]="test_andi.S|loongarch32r-linux-gnusf-gcc -nostdinc -nostdlib -fno-builtin -mabi=ilp32s -Iloongarch_sc/include -c test_andi.S -o test_build/test_andi.o; loongarch32r-linux-gnusf-ld -T loongarch_sc/default.ld test_build/test_andi.o -o test_build/test_andi; loongarch32r-linux-gnusf-objcopy -O binary -j .text test_build/test_andi inst.bin; loongarch32r-linux-gnusf-objcopy -O binary -j .data test_build/test_andi data.bin|si 2; info r; q|a1=0x000001F0"
    ["xor"]="test_xor.S|loongarch32r-linux-gnusf-gcc -nostdinc -nostdlib -fno-builtin -mabi=ilp32s -Iloongarch_sc/include -c test_xor.S -o test_build/test_xor.o; loongarch32r-linux-gnusf-ld -T loongarch_sc/default.ld test_build/test_xor.o -o test_build/test_xor; loongarch32r-linux-gnusf-objcopy -O binary -j .text test_build/test_xor inst.bin; loongarch32r-linux-gnusf-objcopy -O binary -j .data test_build/test_xor data.bin|si 3; info r; q|a2=0x000000FF"
    ["beq"]="test_beq.S|loongarch32r-linux-gnusf-gcc -nostdinc -nostdlib -fno-builtin -mabi=ilp32s -Iloongarch_sc/include -c test_beq.S -o test_build/test_beq.o; loongarch32r-linux-gnusf-ld -T loongarch_sc/default.ld test_build/test_beq.o -o test_build/test_beq; loongarch32r-linux-gnusf-objcopy -O binary -j .text test_build/test_beq inst.bin; loongarch32r-linux-gnusf-objcopy -O binary -j .data test_build/test_beq data.bin|si 5; info r; q|a2=0x00000001"
    ["bne"]="test_bne.S|loongarch32r-linux-gnusf-gcc -nostdinc -nostdlib -fno-builtin -mabi=ilp32s -Iloongarch_sc/include -c test_bne.S -o test_build/test_bne.o; loongarch32r-linux-gnusf-ld -T loongarch_sc/default.ld test_build/test_bne.o -o test_build/test_bne; loongarch32r-linux-gnusf-objcopy -O binary -j .text test_build/test_bne inst.bin; loongarch32r-linux-gnusf-objcopy -O binary -j .data test_build/test_bne data.bin|si 5; info r; q|a2=0x00000001"
    ["st.w"]="test_stw.S|loongarch32r-linux-gnusf-gcc -nostdinc -nostdlib -fno-builtin -mabi=ilp32s -Iloongarch_sc/include -c test_stw.S -o test_build/test_stw.o; loongarch32r-linux-gnusf-ld -T loongarch_sc/default.ld test_build/test_stw.o -o test_build/test_stw; loongarch32r-linux-gnusf-objcopy -O binary -j .text test_build/test_stw inst.bin; loongarch32r-linux-gnusf-objcopy -O binary -j .data test_build/test_stw data.bin|si 3; x 1 0x80010000; q|内存0x80010000=0x12345678"
    ["ld.w"]="test_ldw.S|loongarch32r-linux-gnusf-gcc -nostdinc -nostdlib -fno-builtin -mabi=ilp32s -Iloongarch_sc/include -c test_ldw.S -o test_build/test_ldw.o; loongarch32r-linux-gnusf-ld -T loongarch_sc/default.ld test_build/test_ldw.o -o test_build/test_ldw; loongarch32r-linux-gnusf-objcopy -O binary -j .text test_build/test_ldw inst.bin; loongarch32r-linux-gnusf-objcopy -O binary -j .data test_build/test_ldw data.bin|si 4; info r; q|a1=0x12345678"
    ["st.b"]="test_stb.S|loongarch32r-linux-gnusf-gcc -nostdinc -nostdlib -fno-builtin -mabi=ilp32s -Iloongarch_sc/include -c test_stb.S -o test_build/test_stb.o; loongarch32r-linux-gnusf-ld -T loongarch_sc/default.ld test_build/test_stb.o -o test_build/test_stb; loongarch32r-linux-gnusf-objcopy -O binary -j .text test_build/test_stb inst.bin; loongarch32r-linux-gnusf-objcopy -O binary -j .data test_build/test_stb data.bin|si 3; x 1 0x80010004; q|内存0x80010004=0x000000AB"
    ["ld.b"]="test_ldb.S|loongarch32r-linux-gnusf-gcc -nostdinc -nostdlib -fno-builtin -mabi=ilp32s -Iloongarch_sc/include -c test_ldb.S -o test_build/test_ldb.o; loongarch32r-linux-gnusf-ld -T loongarch_sc/default.ld test_build/test_ldb.o -o test_build/test_ldb; loongarch32r-linux-gnusf-objcopy -O binary -j .text test_build/test_ldb inst.bin; loongarch32r-linux-gnusf-objcopy -O binary -j .data test_build/test_ldb data.bin|si 4; info r; q|a1=0xFFFFFFFF"
    ["sltui"]="test_sltui.S|loongarch32r-linux-gnusf-gcc -nostdinc -nostdlib -fno-builtin -mabi=ilp32s -Iloongarch_sc/include -c test_sltui.S -o test_build/test_sltui.o; loongarch32r-linux-gnusf-ld -T loongarch_sc/default.ld test_build/test_sltui.o -o test_build/test_sltui; loongarch32r-linux-gnusf-objcopy -O binary -j .text test_build/test_sltui inst.bin; loongarch32r-linux-gnusf-objcopy -O binary -j .data test_build/test_sltui data.bin|si 2; info r; q|a1=0x00000001"
    ["sll.w"]="test_sllw.S|loongarch32r-linux-gnusf-gcc -nostdinc -nostdlib -fno-builtin -mabi=ilp32s -Iloongarch_sc/include -c test_sllw.S -o test_build/test_sllw.o; loongarch32r-linux-gnusf-ld -T loongarch_sc/default.ld test_build/test_sllw.o -o test_build/test_sllw; loongarch32r-linux-gnusf-objcopy -O binary -j .text test_build/test_sllw inst.bin; loongarch32r-linux-gnusf-objcopy -O binary -j .data test_build/test_sllw data.bin|si 3; info r; q|a2=0x00001000"
    ["bgeu"]="test_bgeu.S|loongarch32r-linux-gnusf-gcc -nostdinc -nostdlib -fno-builtin -mabi=ilp32s -Iloongarch_sc/include -c test_bgeu.S -o test_build/test_bgeu.o; loongarch32r-linux-gnusf-ld -T loongarch_sc/default.ld test_build/test_bgeu.o -o test_build/test_bgeu; loongarch32r-linux-gnusf-objcopy -O binary -j .text test_build/test_bgeu inst.bin; loongarch32r-linux-gnusf-objcopy -O binary -j .data test_build/test_bgeu data.bin|si 5; info r; q|a2=0x00000001"
)

# 生成测试报告
generate_report() {
    local report_file="test_reports/inst_test_report.md"
    echo "# 龙芯32位17条指令测试报告（修正版）" > $report_file
    echo "## 测试环境" >> $report_file
    echo "- TEMU路径：$(pwd)/build/temu" >> $report_file
    echo "- 交叉编译器：$(loongarch32r-linux-gnusf-gcc --version | head -n1)" >> $report_file
    echo "- 测试时间：$(date +"%Y-%m-%d %H:%M:%S")" >> $report_file
    echo "## 测试结果对照表" >> $report_file
    echo "| 指令名 | 编译命令 | 验证步骤 | 预期结果 | 实际结果 | 测试状态 |" >> $report_file
    echo "|--------|----------|----------|----------|----------|----------|" >> $report_file

    local pass_count=0
    local total_count=${#test_cases[@]}
    for inst_name in "${!test_cases[@]}"; do
        IFS="|" read -r code_file compile_cmd temu_cmds expected <<< "${test_cases[$inst_name]}"
        local log_file="test_logs/${inst_name}_temu.log"
        local result=$(parse_result "$inst_name" "$expected" "$log_file")
        local status=$(echo "$result" | cut -d"|" -f1)
        local actual=$(echo "$result" | cut -d"|" -f2)
        if [ "$status" == "Pass" ]; then
            ((pass_count++))
        fi
        # 简化编译命令（替换换行）
        compile_cmd_simple=$(echo "$compile_cmd" | tr "\n" " ")
        # 简化验证步骤
        verify_step=$(echo "$temu_cmds" | sed 's/;/ /g')
        echo "| $inst_name | $compile_cmd_simple | $verify_step | $expected | $actual | $status |" >> $report_file
    done

    echo "## 汇总统计" >> $report_file
    echo "- 总测试指令数：$total_count" >> $report_file
    echo "- 通过指令数：$pass_count" >> $report_file
    echo "- 失败指令数：$((total_count - pass_count))" >> $report_file
    echo "- 通过率：$((pass_count * 100 / total_count))%" >> $report_file
    echo "报告生成完成：$report_file"
}

# 主流程
main() {
    check_dependency
    clean_env
    echo "=== 开始执行17条指令测试（修正版） ==="
    for inst_name in "${!test_cases[@]}"; do
        echo "正在测试：$inst_name"
        IFS="|" read -r code_file compile_cmd temu_cmds expected <<< "${test_cases[$inst_name]}"
        # 生成测试代码
        generate_test_code "$inst_name" "$code_file"
        # 编译测试代码
        if ! eval "$compile_cmd"; then
            echo "编译失败：$inst_name"
            continue
        fi
        # 运行TEMU并自动化交互
        log_file=$(run_temu_expect "$inst_name" "$temu_cmds")
        # 解析结果
        result=$(parse_result "$inst_name" "$expected" "$log_file")
        status=$(echo "$result" | cut -d"|" -f1)
        actual=$(echo "$result" | cut -d"|" -f2)
        echo "$inst_name 测试完成：$status（预期：$expected，实际：$actual）"
    done
    # 生成报告
    generate_report
    echo "=== 测试结束，报告已生成到 test_reports/inst_test_report.md ==="
}

# 启动主流程
main