`include "defines.v"
module uart_reg(
    input  wire                  clk,
    input  wire                  rst_n,
    
    // 总线接口
    input  wire [`INST_ADDR_BUS]  bus_addr,
    input  wire [`REG_BUS]       bus_wdata,
    input  wire                  bus_we,
    output reg [`REG_BUS]        bus_rdata,
    
    // 串口硬件接口
    input  wire                  uart_rx_done,
    input  wire [7:0]            uart_rx_data,
    output reg                   uart_tx_start,
    output reg [7:0]             uart_tx_data,
    input  wire                  uart_tx_busy
);

reg [7:0] uart_data_reg;   // 0xBFD003F8：数据寄存器
reg [1:0] uart_status_reg; // 0xBFD003FC：状态寄存器（只读）

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        uart_data_reg  <= 8'h00;
        uart_status_reg <= 2'b00;
        uart_tx_start <= 1'b0;
        uart_tx_data  <= 8'h00;
    end else begin
        // 状态寄存器更新（bit0=空闲，bit1=接收完成）
        uart_status_reg[0] <= ~uart_tx_busy;
        uart_status_reg[1] <= uart_rx_done;
        
        // 接收数据写入数据寄存器
        if (uart_rx_done) begin
            uart_data_reg <= uart_rx_data;
        end
        
        // 总线写操作（仅数据寄存器允许写）
        if (bus_we && bus_addr == 32'hBFD003F8) begin
            uart_tx_data  <= bus_wdata[7:0];
            uart_tx_start <= 1'b1;
        end else begin
            uart_tx_start <= 1'b0;
        end
        
        // 总线读操作
        case (bus_addr)
            32'hBFD003F8: bus_rdata <= {24'h000000, uart_data_reg};
            32'hBFD003FC: bus_rdata <= {30'h000000, uart_status_reg};
            default:      bus_rdata <= `ZERO_WORD;
        endcase
    end
end

endmodule