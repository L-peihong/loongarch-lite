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
    input  wire [`REG_BUS]       uart_rdata,
    
    // 新增：LED接口寄存器
    output reg [`REG_BUS]        led_wdata,    // LED写数据
    output reg                   led_we,       // LED写使能
    input  wire [`REG_BUS]       led_rdata     // LED读数据
);
// 地址空间划分（新增LED地址）
localparam TEXT_BASE    = 32'h80000000;
localparam TEXT_END     = 32'h8000FFFF;
localparam DATA_BASE    = 32'h80010000;
localparam DATA_END     = 32'h8001FFFF;
localparam UART_DATA    = 32'hBFD003F8;
localparam UART_STATUS  = 32'hBFD003FC;
localparam LED_CTRL     = 32'hBFD00400;  // 新增LED控制寄存器地址

// 组合逻辑译码（补充LED译码）
always @(*) begin
    // 初始化
    inst_rom_addr  = `ZERO_WORD;
    data_ram_addr  = `ZERO_WORD;
    data_ram_wdata = `ZERO_WORD;
    data_ram_we    = 4'b0000;
    uart_wdata     = `ZERO_WORD;
    uart_we        = `WRITE_DISABLE;
    led_wdata      = `ZERO_WORD;
    led_we         = `WRITE_DISABLE;
    cpu_rdata      = `ZERO_WORD;
    stall_if       = `FALSE_V;

    if (cpu_addr >= TEXT_BASE && cpu_addr <= TEXT_END) begin
        // 指令存储器访问（原有逻辑不变）
        inst_rom_addr = cpu_addr;
        if (is_if_stage && cpu_we) begin
            stall_if = `TRUE_V;
        end else begin
            cpu_rdata = inst_rom_rdata;
            if (!is_if_stage && cpu_we) begin
                // 指令存储器写操作（原有逻辑不变）
            end
        end
    end else if (cpu_addr >= DATA_BASE && cpu_addr <= DATA_END) begin
        // 数据存储器访问（原有逻辑不变）
        data_ram_addr = cpu_addr;
        data_ram_wdata = cpu_wdata;
        case (cpu_mem_sel)
            2'b01: data_ram_we = 4'b0001;
            2'b10: data_ram_we = 4'b0010;
            2'b11: data_ram_we = 4'b0100;
            2'b00: data_ram_we = 4'b1000;
            default: data_ram_we = 4'b0000;
        endcase
        cpu_rdata = data_ram_rdata;
    end else if (cpu_addr == UART_DATA || cpu_addr == UART_STATUS) begin
        // 串口访问（原有逻辑不变）
        if (cpu_addr == UART_STATUS) begin
            uart_we = `WRITE_DISABLE;
        end else begin
            uart_we = cpu_we;
            uart_wdata = cpu_wdata;
        end
        cpu_rdata = uart_rdata;
    end else if (cpu_addr == LED_CTRL) begin
        // 新增：LED访问逻辑（字访问，32位）
        if (cpu_we) begin
            led_we = `WRITE_ENABLE;
            led_wdata = cpu_wdata;  // 接收CPU写数据
        end else begin
            led_we = `WRITE_DISABLE;
            cpu_rdata = led_rdata;  // 返回LED当前状态
        end
    end else begin
        cpu_rdata = `ZERO_WORD;
    end
end
endmodule