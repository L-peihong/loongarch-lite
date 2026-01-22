`timescale 1ns / 1ps
/*------------------- 全局定义 -------------------*/
`define RST_ENABLE      1'b0                // 复位信号有效（低电平）
`define RST_DISABLE     1'b1                // 复位信号无效（高电平）
`define ZERO_WORD       32'h00000000        // 32位零值
`define WRITE_ENABLE    1'b1                // 写使能
`define WRITE_DISABLE   1'b0                // 写禁止
`define READ_ENABLE     1'b1                // 读使能
`define READ_DISABLE    1'b0                // 读禁止
`define ALUOP_BUS       7:0                 // 执行阶段aluop_o宽度（8位）
`define SHIFT_ENABLE    1'b1                // 移位指令使能
`define ALUTYPE_BUS     2:0                 // 执行阶段alutype_o宽度（3位）
`define TRUE_V          1'b1                // 逻辑"真"
`define FALSE_V         1'b0                // 逻辑"假"
`define WORD_BUS        31:0                // 32位数据总线
`define DOUBLE_REG_BUS  63:0                // 双寄存器总线（用于乘法等）
`define RT_ENABLE       1'b1                // rt选择使能
`define SIGNED_EXT      1'b1                // 符号扩展使能
`define IMM_ENABLE      1'b1                // 立即数选择使能
`define UPPER_ENABLE    1'b1                // 高位扩展使能
`define MREG_ENABLE     1'b1                // 写存储器选择信号
`define BSEL_BUS        3:0                 // 数据存储器字节选择信号宽度
`define PC_INIT         32'h80000000        // PC初始值
/*------------------- 指令相关定义 -------------------*/
`define INST_ADDR_BUS   31:0                // 指令地址总线
`define INST_BUS        31:0                // 指令数据总线
// 指令类型alutype定义
`define NOP             3'b000              // 空指令
`define ARITH           3'b001              // 算术指令
`define LOGIC           3'b010              // 逻辑指令
`define MOVE            3'b011              // 移动指令（lu12i.w/pcaddu12i）
`define SHIFT           3'b100              // 移位指令
`define BRANCH          3'b101              // 分支指令
`define LOAD            3'b110              // 加载指令
`define STORE           3'b111              // 存储指令
// 内部指令操作码aluop定义
`define LoongArch32_LU12I_W         8'h05    // lu12i.w
`define LoongArch32_PCADDU12I       8'h9B    // pcaddu12i
`define LoongArch32_SLL             8'h11    // sll.w
`define LoongArch32_ADD_W           8'h18    // add.w
`define LoongArch32_ADDI_W          8'h19    // addi.w
`define LoongArch32_OR              8'h2A    // or (修复: 0x2A而不是0x1A)
`define LoongArch32_ORI             8'h1D    // ori
`define LoongArch32_ANDI            8'h1C    // andi
`define LoongArch32_XOR             8'h2B    // xor (修复: 0x2B而不是0x1E)
`define LoongArch32_SLTU            8'h27    // sltui
`define LoongArch32_BEQ             8'h46    // beq
`define LoongArch32_BNE             8'h47    // bne
`define LoongArch32_BGEU            8'h5B    // bgeu
`define LoongArch32_LD_B            8'h90    // ld.b
`define LoongArch32_LD_W            8'h92    // ld.w
`define LoongArch32_ST_B            8'h98    // st.b
`define LoongArch32_ST_W            8'h9A    // st.w
/*------------------- 通用寄存器相关定义 -------------------*/
`define REG_BUS         31:0                // 寄存器数据总线
`define REG_ADDR_BUS    4:0                 // 寄存器地址总线（32个寄存器）
`define REG_NUM         32                  // 通用寄存器数量
`define REG_NOP         5'b00000            // 无效寄存器地址