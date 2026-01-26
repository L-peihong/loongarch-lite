`include "defines.v"
module bus(
    // CPU 接口
    input  wire [`INST_ADDR_BUS] cpu_addr,    // 取指/访存地址
    input  wire [`REG_BUS]       cpu_wdata,   // CPU写数据
    input  wire                  cpu_we,      // CPU写使能
    input  wire [1:0]            cpu_mem_sel, // 字节选择
    input  wire                  is_if_stage, // 1=取指阶段，0=访存阶段
    output reg [`REG_BUS]        cpu_rdata,   // CPU读数据
    output reg                   stall_if,    // 取指暂停（访存优先时置1）
    
    // 指令存储器接口
    output reg [`INST_ADDR_BUS]  inst_rom_addr,
    input  wire [`REG_BUS]       inst_rom_rdata,
    
    // 数据存储器接口
    output reg [`INST_ADDR_BUS]  data_ram_addr,
    output reg [`REG_BUS]        data_ram_wdata,
    output reg [3:0]             data_ram_we,  // 字节写使能
    input  wire [`REG_BUS]       data_ram_rdata,
    
    // 串口接口寄存器
    output reg [`REG_BUS]        uart_wdata,
    output reg                   uart_we,
    input  wire [`REG_BUS]       uart_rdata
);

// 地址空间划分
localparam TEXT_BASE    = 32'h80000000;
localparam TEXT_END     = 32'h8000FFFF;
localparam DATA_BASE    = 32'h80010000;
localparam DATA_END     = 32'h8001FFFF;
localparam UART_DATA    = 32'hBFD003F8;
localparam UART_STATUS  = 32'hBFD003FC;

// 组合逻辑译码（实验要求总线用组合逻辑）
always @(*) begin
    // 初始化
    inst_rom_addr  = `ZERO_WORD;
    data_ram_addr  = `ZERO_WORD;
    data_ram_wdata = `ZERO_WORD;
    data_ram_we    = 4'b0000;
    uart_wdata     = `ZERO_WORD;
    uart_we        = `WRITE_DISABLE;
    cpu_rdata      = `ZERO_WORD;
    stall_if       = `FALSE_V;

    // 地址判断
    if (cpu_addr >= TEXT_BASE && cpu_addr <= TEXT_END) begin
        // 访问指令存储器：处理结构冒险（访存优先）
        inst_rom_addr = cpu_addr;
        if (is_if_stage && cpu_we) begin
            // 取指和访存同时访问，暂停取指
            stall_if = `TRUE_V;
        end else begin
            cpu_rdata = inst_rom_rdata;
            // 访存阶段写使能有效（取指阶段不写指令存储器）
            if (!is_if_stage && cpu_we) begin
                // 指令存储器写操作（仅访存阶段允许）
                // 此处根据inst_rom IP核写接口补充，若IP核不支持写可忽略
            end
        end
    end else if (cpu_addr >= DATA_BASE && cpu_addr <= DATA_END) begin
        // 访问数据存储器：字节写使能生成
        data_ram_addr = cpu_addr;
        data_ram_wdata = cpu_wdata;
        case (cpu_mem_sel)
            2'b01: data_ram_we = 4'b0001; // 第0字节
            2'b10: data_ram_we = 4'b0010; // 第1字节
            2'b11: data_ram_we = 4'b0100; // 第2字节
            2'b00: data_ram_we = 4'b1000; // 第3字节
            default: data_ram_we = 4'b0000;
        endcase
        cpu_rdata = data_ram_rdata;
    end else if (cpu_addr == UART_DATA || cpu_addr == UART_STATUS) begin
        // 访问串口：状态寄存器只读
        if (cpu_addr == UART_STATUS) begin
            uart_we = `WRITE_DISABLE; // 状态寄存器禁止写
        end else begin
            uart_we = cpu_we;
            uart_wdata = cpu_wdata;
        end
        cpu_rdata = uart_rdata;
    end else begin
        // 无效地址
        cpu_rdata = `ZERO_WORD;
    end
end

endmodule