module Loongarch32_Lite_FullSyS(
    input clk,  // 50Mhz
    input locked,
    
    input                   rxd,                // 串口接收端
    output logic            txd,                // 串口发送端
    
    input [31:0]            sw_1,               // 第一组拨码开关
    input [31:0]            sw_2,               // 第二组拨码开关
    output logic [31:0]     led,                // LED灯
    output logic [3:0]      seg_cs,             // 7段数码管选择信号
    output logic [7:0]      seg_data            // 7段数码管数据
);
    logic rst_n;
    // 将locked信号转为后级电路的复位信号rst_n（低电平有效）
    always_ff @(posedge clk or negedge locked) begin
        if(~locked) rst_n = 1'b0; 
        else        rst_n = 1'b1;
    end

    // 7段数码管驱动（保留原示例逻辑）
    logic [3:0] seg_wdata[0:8];
    x7seg seg_cs_data_gen0 (
        .clk(clk),
        .seg_wdata(seg_wdata),
        .seg_cs(seg_cs),
        .seg_data(seg_data)
    );

    // LED示例（保留原逻辑）
    logic [31:0] sw_1_ff;
    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) sw_1_ff <= 0;
        else sw_1_ff <= sw_1;
    end
    assign led = sw_1_ff;

    // 数码管示例（保留原逻辑）
    logic [31:0] sw_2_ff;
    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) sw_2_ff <= 0;
        else sw_2_ff <= sw_2;
    end
    assign seg_wdata[2] = sw_2_ff[3:0];
    assign seg_wdata[3] = sw_2_ff[7:4];
    assign seg_wdata[4] = sw_2_ff[11:8];
    assign seg_wdata[5] = sw_2_ff[15:12];
    assign seg_wdata[6] = sw_2_ff[19:16];

// -------------------------- 核心模块实例化 --------------------------
// 1. CPU核接口信号
wire [31:0] iaddr;          // 取指地址
wire [31:0] inst;           // 指令
wire [31:0] daddr;          // 访存地址
wire [31:0] din;            // 写数据
wire [31:0] dout;           // 读数据
wire        we;             // 写使能
wire [1:0]  mem_sel;        // 字节选择
wire        stall_if;       // 取指暂停（来自总线）
wire [`INST_ADDR_BUS] debug_wb_pc;
wire        debug_wb_rf_wen;
wire [4:0]  debug_wb_rf_wnum;
wire [31:0] debug_wb_rf_wdata;

// 2. 指令存储器（仅实例化1个，支持双阶段访问）
inst_rom inst_rom0 (
    .a(inst_rom_addr[15:2]),  // 字寻址（64KB，低2位无效）
    .spo(inst_rom_rdata)
);
wire [`INST_ADDR_BUS] inst_rom_addr;
wire [`REG_BUS]       inst_rom_rdata;

// 3. 数据存储器
data_ram data_ram0 (
    .a(data_ram_addr[15:2]),
    .d(data_ram_wdata),
    .clk(clk),
    .we(data_ram_we),
    .spo(data_ram_rdata)
);
wire [`INST_ADDR_BUS] data_ram_addr;
wire [`REG_BUS]       data_ram_wdata;
wire [3:0]            data_ram_we;
wire [`REG_BUS]       data_ram_rdata;

// 4. 串口模块
wire [`REG_BUS] uart_rdata;
wire [`REG_BUS] uart_wdata;
wire            uart_we;
uart_reg uart_reg0(
    .clk(clk),
    .rst_n(rst_n),
    .bus_addr(daddr),
    .bus_wdata(din),
    .bus_we(uart_we),
    .bus_rdata(uart_rdata),
    .uart_rx_done(ext_uart_r.RxD_data_ready),
    .uart_rx_data(ext_uart_r.RxD_data),
    .uart_tx_start(ext_uart_t.TxD_start),
    .uart_tx_data(ext_uart_t.TxD_data),
    .uart_tx_busy(ext_uart_t.TxD_busy)
);

// 串口硬件模块（保留原实例化）
async_receiver #(.ClkFrequency(50000000), .Baud(9600)) ext_uart_r(
    .clk(clk),
    .RxD(rxd),
    .RxD_data_ready(),
    .RxD_clear(1'b0),
    .RxD_data()
);
async_transmitter #(.ClkFrequency(50000000), .Baud(9600)) ext_uart_t(
    .clk(clk),
    .TxD(txd),
    .TxD_busy(),
    .TxD_start(),
    .TxD_data()
);

// 5. 总线模块（组合逻辑，实现地址译码和访问优先级）
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
    .uart_rdata(uart_rdata)
);

// 6. 取指阶段标记（区分取指/访存访问）
wire is_if_stage = 1'b1; // 取指阶段访问时置1，访存阶段置0（由CPU核输出控制）

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
    .stall_if(stall_if),  // 新增：传入取指暂停信号
    .debug_wb_pc(debug_wb_pc),
    .debug_wb_rf_wen(debug_wb_rf_wen),
    .debug_wb_rf_wnum(debug_wb_rf_wnum),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);

// 数码管显示串口数据（示例）
assign seg_wdata[0] = uart_rdata[3:0];
assign seg_wdata[1] = uart_rdata[7:4];

endmodule