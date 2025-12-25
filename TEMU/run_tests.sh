#!/bin/bash
set -euo pipefail

# 项目根目录（脚本所在目录为TEMU工程根目录）
ROOT="$(pwd)"
LOONG_DIR="${ROOT}/loongarch_sc"

# 遵循使用步骤（1）：编译测试程序
echo "1) 编译测试程序（logic）..."
cd "${LOONG_DIR}"
# 可选清理之前的编译产物，符合重新编译逻辑
make clean || true
# 编译生成inst.bin和data.bin（自动移动到TEMU根目录）
make all
cd "${ROOT}"

# 遵循使用步骤（2）：编译并启动TEMU（使用make run，符合步骤要求）
echo "2) 编译并启动TEMU仿真器..."
# 可选清理TEMU之前的编译产物（如需重新编译，符合步骤（3））
make clean-temu || true
# 执行make run：编译TEMU并启动，同时传递测试命令序列
make run <<'EOF'
si 1
p $a0
si 1
p $a1
si 1
p $t0
si 1
p $s0

info r

x 4 0x80000000

p 0x80000000 + 4
p $a0
p $a0 == 0x80400000

w $a0 == 0x80400000
w $a1
info w

c

q
EOF

# 验证Golden Trace文件（符合实验要求）
echo -e "\n3) 查看golden_trace.txt内容："
if [ -f golden_trace.txt ]; then
  cat golden_trace.txt
else
  echo "警告：未生成golden_trace.txt！"
fi

# 基础验证：检查golden_trace.txt条目数量（logic.S应生成4条写寄存器记录）
echo -e "\n4) 验证golden_trace.txt有效性："
if [ -f golden_trace.txt ]; then
  LINES=$(wc -l < golden_trace.txt)
  echo "golden_trace.txt 条目数 = ${LINES}"
  if [ "${LINES}" -eq 4 ]; then
    echo "✅ 条目数符合预期（4条写寄存器指令）"
  elif [ "${LINES}" -ge 1 ]; then
    echo "⚠️  条目数不符预期（应为4条，实际${LINES}条），请检查指令执行或Trace生成逻辑"
  else
    echo "❌ 无有效条目，存在功能异常"
    exit 2
  fi
else
  echo "❌ 未找到golden_trace.txt，Trace生成功能异常"
  exit 1
fi

echo -e "\n🎉 所有测试步骤执行完成！请根据上述输出验证功能正确性。"
echo "提示："
echo "  - 如需重新编译所有产物：执行 make clean && ./run_tests.sh"
echo "  - 如需仅重新编译TEMU：执行 make clean-temu && ./run_tests.sh"
