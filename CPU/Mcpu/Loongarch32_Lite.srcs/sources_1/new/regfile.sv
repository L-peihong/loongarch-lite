`include "defines.v"
module regfile(
    input  wire                  cpu_clk_50M,
    input  wire                  cpu_rst_n,
    // 写端口
    input  wire [`REG_ADDR_BUS]  wa,
    input  wire [`REG_BUS]       wd,
    input  wire                  we,
    // 读端口1（rs1）
    input  wire [`REG_ADDR_BUS]  ra1,
    output reg [`REG_BUS]        rd1,
    // 读端口2（rs2）
    input  wire [`REG_ADDR_BUS]  ra2,
    output reg [`REG_BUS]        rd2
);
    reg [`REG_BUS] regs[0:`REG_NUM-1];

    // 寄存器写操作
    always @(posedge cpu_clk_50M) begin
        if (cpu_rst_n == `RST_ENABLE) begin
            for (int i=0; i<`REG_NUM; i++) regs[i] <= `ZERO_WORD;
        end else begin
            if ((we == `WRITE_ENABLE) && (wa != 5'h0)) begin
                regs[wa] <= wd;
            end
        end
    end

    // 读端口1操作
    always @(*) begin
        if (cpu_rst_n == `RST_ENABLE) begin
            rd1 <= `ZERO_WORD;
        end else if (ra1 == `REG_NOP) begin
            rd1 <= `ZERO_WORD;
        end else begin
            rd1 <= regs[ra1];
        end
    end

    // 读端口2操作
    always @(*) begin
        if (cpu_rst_n == `RST_ENABLE) begin
            rd2 <= `ZERO_WORD;
        end else if (ra2 == `REG_NOP) begin
            rd2 <= `ZERO_WORD;
        end else begin
            rd2 <= regs[ra2];
        end
    end
endmodule