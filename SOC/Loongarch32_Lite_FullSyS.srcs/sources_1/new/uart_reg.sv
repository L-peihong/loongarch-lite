// ########################## 直接嵌入 uart_reg 依赖的宏定义 ##########################
// 1. 总线宽度宏（模块核心依赖，匹配地址/数据总线宽度）
`define INST_ADDR_BUS   31:0                // 总线地址宽度（32位）
`define REG_BUS         31:0                // 寄存器/数据总线宽度（32位）
// 2. 常量宏（初始化用）
`define ZERO_WORD       32'h00000000        // 32位零值（默认读数据初始化）
// ##########################################################################

module uart_reg(
    input  wire                  clk,
    input  wire                  rst_n,
    
    // 总线接口（宏定义确保总线宽度与系统一致）
    input  wire [`INST_ADDR_BUS]  bus_addr,    // 32位总线地址
    input  wire [`REG_BUS]       bus_wdata,   // 32位总线写数据
    input  wire                  bus_we,      // 总线写使能
    output reg [`REG_BUS]        bus_rdata,   // 32位总线读数据
    
    // 串口硬件接口
    input  wire                  uart_rx_done, // 串口接收完成信号
    input  wire [7:0]            uart_rx_data, // 串口接收数据（8位）
    output reg                   uart_tx_start, // 串口发送启动信号
    output reg [7:0]             uart_tx_data,  // 串口发送数据（8位）
    input  wire                  uart_tx_busy   // 串口发送忙信号
);

reg [7:0] uart_data_reg;   // 0xBFD003F8：串口数据寄存器（读写）
reg [1:0] uart_status_reg; // 0xBFD003FC：串口状态寄存器（只读，bit0=空闲，bit1=接收完成）

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        uart_data_reg  <= 8'h00;         // 初始化为0
        uart_status_reg <= 2'b00;        // 初始状态：忙+无接收数据
        uart_tx_start <= 1'b0;          // 初始不启动发送
        uart_tx_data  <= 8'h00;         // 初始发送数据为0
    end else begin
        // 状态寄存器更新：bit0=串口空闲（~tx_busy），bit1=接收完成（rx_done）
        uart_status_reg[0] <= ~uart_tx_busy;
        uart_status_reg[1] <= uart_rx_done;
        
        // 接收完成时，将8位接收数据写入数据寄存器
        if (uart_rx_done) begin
            uart_data_reg <= uart_rx_data;
        end
        
        // 总线写操作：仅地址0xBFD003F8（数据寄存器）允许写
        if (bus_we && bus_addr == 32'hBFD003F8) begin
            uart_tx_data  <= bus_wdata[7:0]; // 取总线数据低8位（串口为8位传输）
            uart_tx_start <= 1'b1;          // 启动发送
        end else begin
            uart_tx_start <= 1'b0;          // 非写数据寄存器时，关闭发送启动
        end
        
        // 总线读操作：根据地址返回对应寄存器值
        case (bus_addr)
            32'hBFD003F8: bus_rdata <= {24'h000000, uart_data_reg}; // 数据寄存器：高24位补0
            32'hBFD003FC: bus_rdata <= {30'h000000, uart_status_reg}; // 状态寄存器：高30位补0
            default:      bus_rdata <= `ZERO_WORD; // 非法地址返回0
        endcase
    end
end

endmodule