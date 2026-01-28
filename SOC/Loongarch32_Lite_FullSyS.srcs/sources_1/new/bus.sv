// ########################## 直接嵌入 bus 模块依赖的宏定义 ##########################
// 1. 总线宽度宏（bus模块核心依赖，对应地址/数据总线宽度）
`define INST_ADDR_BUS   31:0                // 指令/访存地址总线（32位）
`define REG_BUS         31:0                // 寄存器/数据总线（32位）
// 2. 常量值宏（初始化、使能控制用）
`define ZERO_WORD       32'h00000000        // 32位零值（信号初始化用）
`define WRITE_ENABLE    1'b1                // 写使能（LED/串口/数据存储器写控制）
`define WRITE_DISABLE   1'b0                // 写禁止（初始化、只读寄存器用）
// 3. 逻辑值宏（stall_if 状态控制用）
`define TRUE_V          1'b1                // 逻辑“真”（stall_if 置1表示暂停）
`define FALSE_V         1'b0                // 逻辑“假”（stall_if 置0表示不暂停）
// ##########################################################################

module bus(
    // CPU 接口
    input  wire [`INST_ADDR_BUS] cpu_addr,    // 取指/访存地址（32位，依赖 INST_ADDR_BUS）
    input  wire [`REG_BUS]       cpu_wdata,   // CPU写数据（32位，依赖 REG_BUS）
    input  wire                  cpu_we,      // CPU写使能
    input  wire [1:0]            cpu_mem_sel, // 字节选择
    input  wire                  is_if_stage, // 1=取指阶段，0=访存阶段
    output reg [`REG_BUS]        cpu_rdata,   // CPU读数据（32位，依赖 REG_BUS）
    output reg                   stall_if,    // 取指暂停（访存优先时置1）
    
    // 指令存储器接口
    output reg [`INST_ADDR_BUS]  inst_rom_addr, // 指令存储器地址（32位，依赖 INST_ADDR_BUS）
    input  wire [`REG_BUS]       inst_rom_rdata, // 指令存储器读数据（32位，依赖 REG_BUS）
    
    // 数据存储器接口
    output reg [`INST_ADDR_BUS]  data_ram_addr, // 数据存储器地址（32位，依赖 INST_ADDR_BUS）
    output reg [`REG_BUS]        data_ram_wdata, // 数据存储器写数据（32位，依赖 REG_BUS）
    output reg [3:0]             data_ram_we,  // 字节写使能
    input  wire [`REG_BUS]       data_ram_rdata, // 数据存储器读数据（32位，依赖 REG_BUS）
    
    // 串口接口寄存器
    output reg [`REG_BUS]        uart_wdata,   // 串口写数据（32位，依赖 REG_BUS）
    output reg                   uart_we,      // 串口写使能
    input  wire [`REG_BUS]       uart_rdata,   // 串口读数据（32位，依赖 REG_BUS）
    
    // 新增：LED接口寄存器
    output reg [`REG_BUS]        led_wdata,    // LED写数据（32位，依赖 REG_BUS）
    output reg                   led_we,       // LED写使能
    input  wire [`REG_BUS]       led_rdata     // LED读数据（32位，依赖 REG_BUS）
);
// 地址空间划分（新增LED地址，与实验要求一致）
localparam TEXT_BASE    = 32'h80000000;  // .text段基地址（指令存储器）
localparam TEXT_END     = 32'h8000FFFF;  // .text段结束地址（64KB）
localparam DATA_BASE    = 32'h80010000;  // .data段基地址（数据存储器）
localparam DATA_END     = 32'h8001FFFF;  // .data段结束地址（64KB）
localparam UART_DATA    = 32'hBFD003F8;  // 串口数据寄存器地址（固定）
localparam UART_STATUS  = 32'hBFD003FC;  // 串口状态寄存器地址（固定）
localparam LED_CTRL     = 32'hBFD00400;  // LED控制寄存器地址（新增，与SOC设计一致）

// 组合逻辑译码（地址译码+数据转发，原有逻辑完全保留）
always @(*) begin
    // 信号初始化：使用内部宏定义，避免硬编码
    inst_rom_addr  = `ZERO_WORD;    // 指令存储器地址初始化为0
    data_ram_addr  = `ZERO_WORD;    // 数据存储器地址初始化为0
    data_ram_wdata = `ZERO_WORD;    // 数据存储器写数据初始化为0
    data_ram_we    = 4'b0000;       // 数据存储器写使能初始化为0
    uart_wdata     = `ZERO_WORD;    // 串口写数据初始化为0
    uart_we        = `WRITE_DISABLE;// 串口写使能初始化为禁止
    led_wdata      = `ZERO_WORD;    // LED写数据初始化为0
    led_we         = `WRITE_DISABLE;// LED写使能初始化为禁止
    cpu_rdata      = `ZERO_WORD;    // CPU读数据初始化为0
    stall_if       = `FALSE_V;      // 取指暂停初始化为不暂停

    if (cpu_addr >= TEXT_BASE && cpu_addr <= TEXT_END) begin
        // 指令存储器访问：取指/访存阶段均支持（实验要求）
        inst_rom_addr = cpu_addr;
        if (is_if_stage && cpu_we) begin
            // 取指阶段同时写指令存储器：访存优先，置位暂停
            stall_if = `TRUE_V;
        end else begin
            // 读指令存储器：返回指令数据
            cpu_rdata = inst_rom_rdata;
            // 访存阶段写指令存储器（预留逻辑，保持原有）
            if (!is_if_stage && cpu_we) begin
                // 若需支持指令存储器写，可在此补充逻辑（实验暂不要求）
            end
        end
    end else if (cpu_addr >= DATA_BASE && cpu_addr <= DATA_END) begin
        // 数据存储器访问：仅访存阶段支持
        data_ram_addr = cpu_addr;
        data_ram_wdata = cpu_wdata;
        // 字节选择译码（小端模式：2'b01=第0字节，2'b10=第1字节，2'b11=第2字节，2'b00=第3字节）
        case (cpu_mem_sel)
            2'b01: data_ram_we = 4'b0001;
            2'b10: data_ram_we = 4'b0010;
            2'b11: data_ram_we = 4'b0100;
            2'b00: data_ram_we = 4'b1000;
            default: data_ram_we = 4'b0000;
        endcase
        // 读数据存储器：返回数据
        cpu_rdata = data_ram_rdata;
    end else if (cpu_addr == UART_DATA || cpu_addr == UART_STATUS) begin
        // 串口访问：数据寄存器可读写，状态寄存器只读
        if (cpu_addr == UART_STATUS) begin
            uart_we = `WRITE_DISABLE; // 状态寄存器只读，禁止写
        end else begin
            uart_we = cpu_we;         // 数据寄存器：跟随CPU写使能
            uart_wdata = cpu_wdata;   // 传递CPU写数据到串口
        end
        // 读串口：返回串口数据（数据/状态寄存器共用读接口）
        cpu_rdata = uart_rdata;
    end else if (cpu_addr == LED_CTRL) begin
        // LED访问：32位字访问（实验要求，1位对应1个LED）
        if (cpu_we) begin
            led_we = `WRITE_ENABLE;  // CPU写使能：允许写LED寄存器
            led_wdata = cpu_wdata;   // 传递CPU写数据到LED（32位控制所有LED）
        end else begin
            led_we = `WRITE_DISABLE;// CPU读使能：禁止写，返回当前LED状态
            cpu_rdata = led_rdata;   // 返回LED寄存器当前值
        end
    end else begin
        // 非法地址：返回0
        cpu_rdata = `ZERO_WORD;
    end
end
endmodule