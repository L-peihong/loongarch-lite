// ########################## 直接嵌入 defines.v 宏定义（替代 include）##########################
`timescale 1ns / 1ps
/*------------------- 全局定义（覆盖代码中所有用到的宏） -------------------*/
`define RST_ENABLE      1'b0                // 复位信号有效（低电平）
`define RST_DISABLE     1'b1                // 复位信号无效（高电平）
`define ZERO_WORD       32'h00000000        // 32位零值
`define WRITE_ENABLE    1'b1                // 写使能
`define WRITE_DISABLE   1'b0                // 写禁止
`define TRUE_V          1'b1                // 逻辑"真"
`define FALSE_V         1'b0                // 逻辑"假"
`define PC_INIT         32'h80000000        // PC初始值
/*------------------- 指令/地址总线定义（代码核心依赖） -------------------*/
`define INST_ADDR_BUS   31:0                // 指令地址总线（32位）
`define REG_BUS         31:0                // 寄存器/数据总线（32位）
`define REG_ADDR_BUS    4:0                 // 寄存器地址总线（5位，32个寄存器）
`define REG_NOP         5'b00000            // 无效寄存器地址
// ##########################################################################
module Loongarch32_Lite_FullSys(
    input clk,  // 50Mhz
    input locked,
    
    input                   rxd,                // 串口接收端
    output logic            txd,                // 串口发送端
    
    input [31:0]            sw_1,               // 第一组拨码开关
    input [31:0]            sw_2,               // 第二组拨码开关
    output logic [31:0]     led,                // LED灯
    output logic [3:0]      seg_cs,             // 7段数码管选择信号
    output logic [7:0]      seg_data            // 7段数码管数据
    // 无btn端口定义，与实例化一致
);
    logic rst_n;
    // 将locked信号转为后级电路的复位信号rst_n（低电平有效）
    always_ff @(posedge clk or negedge locked) begin
        if(~locked) rst_n = `RST_ENABLE;  // 使用宏定义，避免硬编码
        else        rst_n = `RST_DISABLE;
    end
    // 7段数码管驱动（保留原示例逻辑）
    logic [3:0] seg_wdata[0:8];
    x7seg seg_cs_data_gen0 (
        .clk(clk),
        .seg_wdata(seg_wdata),
        .seg_cs(seg_cs),
        .seg_data(seg_data)
    );
    // 数码管示例（保留原逻辑）
    logic [31:0] sw_2_ff;
    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) sw_2_ff <= `ZERO_WORD;  // 使用宏定义，统一零值
        else sw_2_ff <= sw_2;
    end
    assign seg_wdata[2] = sw_2_ff[3:0];
    assign seg_wdata[3] = sw_2_ff[7:4];
    assign seg_wdata[4] = sw_2_ff[11:8];
    assign seg_wdata[5] = sw_2_ff[15:12];
    assign seg_wdata[6] = sw_2_ff[19:16];
// -------------------------- 核心信号声明（调整顺序：先声明后使用） --------------------------
// 1. CPU核接口信号
wire [31:0] iaddr;          // 取指地址
wire [31:0] inst;           // 指令
wire [31:0] daddr;          // 访存地址
wire [31:0] din;            // 写数据
wire [31:0] dout;           // 读数据
wire        we;             // 写使能
wire [1:0]  mem_sel;        // 字节选择
wire        stall_if;       // 取指暂停（来自总线）
wire [`INST_ADDR_BUS] debug_wb_pc;  // 使用宏定义总线宽度
wire        debug_wb_rf_wen;
wire [4:0]  debug_wb_rf_wnum;
wire [31:0] debug_wb_rf_wdata;
// 2. 指令存储器相关信号（先声明，再实例化模块）
wire [`INST_ADDR_BUS] inst_rom_addr;  // 32位地址总线
wire [`REG_BUS]       inst_rom_rdata;  // 32位数据总线
// 3. 数据存储器相关信号（先声明，再实例化模块）
wire [`INST_ADDR_BUS] data_ram_addr;
wire [`REG_BUS]       data_ram_wdata;
wire [3:0]            data_ram_we;
wire [`REG_BUS]       data_ram_rdata;
// 4. 串口相关信号（保留原声明）
wire [`REG_BUS] uart_rdata;
wire [`REG_BUS] uart_wdata;
wire            uart_we;
// 5. LED相关信号（保留原声明）
wire [`REG_BUS]  led_rdata;
wire             led_we;
wire [`REG_BUS]  led_wdata;
// 6. 取指阶段标记（提前声明，供总线使用）
wire is_if_stage = (iaddr >= 32'h80000000 && iaddr <= 32'h8000FFFF);  // 取指阶段仅访问.text段
// -------------------------- 核心模块实例化 --------------------------
// 2. 指令存储器（仅实例化1个，支持双阶段访问）
inst_rom inst_rom0 (
    .a(inst_rom_addr[15:2]),  // 字寻址（64KB，低2位无效）
    .spo(inst_rom_rdata)
);
// 3. 数据存储器
data_ram data_ram0 (
    .a(data_ram_addr[15:2]),
    .d(data_ram_wdata),
    .clk(clk),
    .we(data_ram_we),
    .spo(data_ram_rdata)
);
// 4. 串口模块（修正信号连接，无悬空）
// 串口控制寄存器（连接硬件模块信号）
uart_reg uart_reg0(
    .clk(clk),
    .rst_n(rst_n),
    .bus_addr(daddr),
    .bus_wdata(din),
    .bus_we(uart_we),
    .bus_rdata(uart_rdata),
    .uart_rx_done(ext_uart_r.RxD_data_ready),  // 接收完成信号
    .uart_rx_data(ext_uart_r.RxD_data),        // 接收数据
    .uart_tx_start(ext_uart_t.TxD_start),      // 发送启动信号
    .uart_tx_data(ext_uart_t.TxD_data),        // 发送数据
    .uart_tx_busy(ext_uart_t.TxD_busy)         // 发送忙状态
);
// 串口硬件模块
async_receiver #(.ClkFrequency(50000000), .Baud(9600)) ext_uart_r(
    .clk(clk),
    .RxD(rxd),
    .RxD_data_ready(),  // 已连接到uart_reg0
    .RxD_clear(1'b0),
    .RxD_data()         // 已连接到uart_reg0
);
async_transmitter #(.ClkFrequency(50000000), .Baud(9600)) ext_uart_t(
    .clk(clk),
    .TxD(txd),
    .TxD_busy(),         // 已连接到uart_reg0
    .TxD_start(),        // 已连接到uart_reg0
    .TxD_data()          // 已连接到uart_reg0
);
// 新增：LED控制寄存器（32位，地址0xBFD00400）
logic [`REG_BUS] led_reg;  // LED状态寄存器（32位，使用宏定义）
always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        led_reg <= `ZERO_WORD;  // 初始全灭，使用统一零值宏
    end else if (led_we) begin
        led_reg <= led_wdata;     // 总线写使能时更新LED状态
    end
end
assign led = led_reg;          // LED输出由寄存器驱动
assign led_rdata = led_reg;    // LED读数据关联状态寄存器
// 5. 总线模块（新增LED信号连接，宏定义统一常量）
bus bus0(
    // CPU接口
    .cpu_addr(is_if_stage ? iaddr : daddr),
    .cpu_wdata(din),
    .cpu_we(we),
    .cpu_mem_sel(mem_sel),
    .is_if_stage(is_if_stage),
    .cpu_rdata(dout),
    .stall_if(stall_if),
    
    // 指令存储器接口
    .inst_rom_addr(inst_rom_addr),
    .inst_rom_rdata(inst_rom_rdata),
    
    // 数据存储器接口
    .data_ram_addr(data_ram_addr),
    .data_ram_wdata(data_ram_wdata),
    .data_ram_we(data_ram_we),
    .data_ram_rdata(data_ram_rdata),
    
    // 串口接口
    .uart_wdata(uart_wdata),
    .uart_we(uart_we),
    .uart_rdata(uart_rdata),
    
    // 新增：LED接口
    .led_wdata(led_wdata),
    .led_we(led_we),
    .led_rdata(led_rdata)
);
// 7. CPU核实例化（传入stall_if处理结构冒险）
Loongarch32_Lite Loongarch32_Lite0(
    .cpu_clk_50M(clk),
    .cpu_rst_n(rst_n),
    .iaddr(iaddr),
    .inst(inst),
    .daddr(daddr),
    .din(din),
    .we(we),
    .mem_sel(mem_sel),
    .dout(dout),
    .stall_if(stall_if),  // 传入取指暂停信号
    .debug_wb_pc(debug_wb_pc),
    .debug_wb_rf_wen(debug_wb_rf_wen),
    .debug_wb_rf_wnum(debug_wb_rf_wnum),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);
// 数码管显示串口数据（示例）
assign seg_wdata[0] = uart_rdata[3:0];
assign seg_wdata[1] = uart_rdata[7:4];
endmodule