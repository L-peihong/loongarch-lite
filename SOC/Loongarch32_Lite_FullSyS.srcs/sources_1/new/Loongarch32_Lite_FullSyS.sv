module Loongarch32_Lite_FullSyS(
    input clk,  // 50Mhz
    input locked,
    
    input                   rxd,                // 串口接收端
    output logic            txd,                // 串口发送端
    
    input [31:0]            sw_1,               // 第一组拨码开关
    input [31:0]            sw_2,               // 第二组拨码开关
    output logic [31:0]     led,                // LED灯
    output logic [3:0]      seg_cs,             // 7段数码管选择信号
    output logic [7:0]      seg_data,           // 7段数码管数据
    input [7:0]            btn                 // 按键
);
    logic rst_n;
    // 将locked信号转为后级电路的复位信号rst_n（低电平有效）
    always_ff @(posedge clk or negedge locked) begin
        if(~locked) rst_n = 1'b0; 
        else        rst_n = 1'b1;
    end

    // 7段数码管驱动（保留原示例逻辑，不影响测试）
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

    logic [7:0] btn_ff;
    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) btn_ff <= 0;
        else btn_ff <= btn;
    end
    assign seg_wdata[7] = btn_ff[3:0];
    assign seg_wdata[8] = btn_ff[7:4];

    // -------------------------- 核心模块实例化与总线逻辑 --------------------------
    // 1. 调试信号（CPU输出）
    wire [31:0] debug_wb_pc;
    wire        debug_wb_rf_wen;
    wire [4:0]  debug_wb_rf_wnum;
    wire [31:0] debug_wb_rf_wdata;

    // 2. CPU核接口信号（无重复声明）
    wire [31:0] iaddr;          // CPU取指地址（访问inst_rom）
    wire [31:0] inst;           // CPU指令输入（来自inst_rom）
    wire [31:0] daddr;          // CPU访存地址（数据/外设）
    wire [31:0] din;           // CPU写数据
    wire [31:0] dout;          // CPU读数据（仅声明一次）
    wire        we;             // CPU写使能
    wire [1:0]  mem_sel;        // CPU字节选择

    // 3. 存储器实例化
    // 指令存储器（.text段：0x80000000~0x8000FFFF，64KB）
    inst_rom inst_rom0 (
        .a(iaddr[15:2]),      // 取指阶段：按字寻址（忽略低2位）
        .spo(inst)
    );

    // 4. 串口外设逻辑（存储器映射I/O）
    logic [7:0] uart_data_reg;   // 数据寄存器（0xBFD003F8）
    logic [1:0] uart_status_reg;// 状态寄存器（0xBFD003FC）：bit0=发送空闲，bit1=接收就绪
    logic uart_rx_ready;        // 串口接收就绪（来自async_receiver）
    logic [7:0] uart_rx_data;  // 串口接收数据
    logic uart_tx_busy;         // 串口发送忙（来自async_transmitter）
    logic uart_tx_start;        // 串口发送启动
    logic [7:0] uart_tx_data;   // 串口发送数据

    // 串口接收模块实例化（保持不变）
    async_receiver #(.ClkFrequency(50000000), .Baud(9600)) ext_uart_r(
        .clk(clk),
        .RxD(rxd),
        .RxD_data_ready(uart_rx_ready),
        .RxD_clear(uart_rx_ready & (daddr == 32'hBFD003F8) & ~we),
        .RxD_data(uart_rx_data)
    );

    // 串口发送模块实例化（保持不变）
    async_transmitter #(.ClkFrequency(50000000), .Baud(9600)) ext_uart_t(
        .clk(clk),
        .TxD(txd),
        .TxD_busy(uart_tx_busy),
        .TxD_start(uart_tx_start),
        .TxD_data(uart_tx_data)
    );

    // 串口寄存器更新（保持不变）
    always_ff @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            uart_data_reg <= 8'h00;
            uart_status_reg <= 2'b00;
        end else begin
            uart_status_reg[0] <= ~uart_tx_busy;
            uart_status_reg[1] <= uart_rx_ready;
            if(uart_rx_ready && ~(daddr == 32'hBFD003F8 & ~we)) begin
                uart_data_reg <= uart_rx_data;
            end
            if(daddr == 32'hBFD003F8 && we && mem_sel == 2'b10) begin
                uart_tx_data <= din[7:0];
                uart_tx_start <= 1'b1;
            end else begin
                uart_tx_start <= 1'b0;
            end
        end
    end

    // 5. 总线地址译码：选择CPU读数据来源（已修正dout赋值）
    wire [31:0] inst_rom_dout;   // 访存阶段访问inst_rom的数据
    wire [31:0] data_ram_dout;    // 字节处理后的data_ram读数据
    wire [31:0] data_ram_dout_raw;// data_ram原始读数据（对接IP核spo）
    wire [31:0] uart_dout;

    inst_rom inst_rom_mem (
        .a(daddr[15:2]),
        .spo(inst_rom_dout)
    );

    assign uart_dout = (daddr == 32'hBFD003F8) ? {24'h000000, uart_data_reg} :
                    (daddr == 32'hBFD003FC) ? {30'h00000000, uart_status_reg} : 32'h00000000;

    assign dout = (daddr >= 32'h80000000 && daddr <= 32'h8000FFFF) ? inst_rom_dout :
                (daddr >= 32'h80010000 && daddr <= 32'h8001FFFF) ? data_ram_dout :
                (daddr == 32'hBFD003F8 || daddr == 32'hBFD003FC) ? uart_dout :
                32'h00000000;

    // 6. CPU核实例化（保持不变）
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
        .debug_wb_pc(debug_wb_pc),
        .debug_wb_rf_wen(debug_wb_rf_wen),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata)
    );

    // 数码管显示串口数据（示例，不影响测试）
    assign seg_wdata[0] = uart_data_reg[3:0];
    assign seg_wdata[1] = uart_data_reg[7:4];

    // -------------------------- 补充：data_ram 字节访存逻辑 --------------------------
    wire [3:0] data_ram_we;  // 字节写使能（we0=第0字节，we1=第1字节，we2=第2字节，we3=第3字节）
    wire [31:0] data_ram_din; // 字节拼接后的写数据

    // 1. 字节写使能生成（根据 mem_sel 和 we）
    assign data_ram_we = (we && (daddr >= 32'h80010000 && daddr <= 32'h8001FFFF)) ? 
                        (mem_sel == 2'b01 ? 4'b0001 :  // 地址0x0 → 第0字节
                        mem_sel == 2'b10 ? 4'b0010 :  // 地址0x1 → 第1字节
                        mem_sel == 2'b11 ? 4'b0100 :  // 地址0x2 → 第2字节
                        mem_sel == 2'b00 ? 4'b1000 :  // 地址0x3 → 第3字节
                        4'b0000) : 4'b0000;

    // 2. 写数据拼接（仅对应字节为 din[7:0]，其他字节保持原始数据）
    reg [31:0] data_ram_old_dout;
    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) data_ram_old_dout <= 32'h00000000;
        else if (!we) data_ram_old_dout <= data_ram_dout_raw; // 未写时保存当前数据
    end

    assign data_ram_din = (mem_sel == 2'b01) ? {data_ram_old_dout[31:8], din[7:0]} :
                        (mem_sel == 2'b10) ? {data_ram_old_dout[31:16], din[7:0], data_ram_old_dout[7:0]} :
                        (mem_sel == 2'b11) ? {data_ram_old_dout[31:24], din[7:0], data_ram_old_dout[15:0]} :
                        (mem_sel == 2'b00) ? {din[7:0], data_ram_old_dout[23:0]} :
                        data_ram_old_dout;

    // 3. data_ram IP 核实例化（唯一有效实例化，保留）
    data_ram data_ram0 (
        .a(daddr[15:2]),      // 按字寻址（忽略低2位）
        .d(data_ram_din),     // 拼接后的写数据
        .clk(clk),
        .we(data_ram_we),     // 字节写使能（替代原 we）
        .spo(data_ram_dout_raw) // 原始读数据
    );

    // 4. 读数据提取+符号扩展（ld.b 处理）
    assign data_ram_dout = (mem_sel == 2'b01) ? {{24{data_ram_dout_raw[7]}}, data_ram_dout_raw[7:0]} :  // 第0字节
                        (mem_sel == 2'b10) ? {{24{data_ram_dout_raw[15]}}, data_ram_dout_raw[15:8]} : // 第1字节
                        (mem_sel == 2'b11) ? {{24{data_ram_dout_raw[23]}}, data_ram_dout_raw[23:16]} : // 第2字节
                        (mem_sel == 2'b00) ? {{24{data_ram_dout_raw[31]}}, data_ram_dout_raw[31:24]} : // 第3字节
                        data_ram_dout_raw; // 字访问直接输出
    // -----------------------------------------------------------------------------
endmodule