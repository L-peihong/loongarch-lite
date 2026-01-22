module Loongarch32_Lite_FullSyS(
input sys_clk,
input sys_rst_n
);
logic cpu_clk;
logic cpu_rst_n;
logic locked;
// 时钟分频IP核实例化
clkdiv clocking0 (
.clk_out(cpu_clk),     // 输出50MHz时钟到CPU
.resetn(sys_rst_n),    // 系统复位（高有效）
.locked(locked),       // 时钟锁定信号
.clk_in(sys_clk)       // 输入系统时钟（100MHz）
);
// 将locked信号转换为CPU复位信号（低有效）
always_ff @(posedge cpu_clk or negedge locked) begin
if (~locked) cpu_rst_n = `RST_ENABLE;  // 时钟未锁定时复位CPU
else        cpu_rst_n = `RST_DISABLE; // 时钟锁定后释放复位
end
// 调试信号（供仿真观察）
wire [31:0] debug_wb_pc;
wire        debug_wb_rf_wen;
wire [4:0]  debug_wb_rf_wnum;
wire [31:0] debug_wb_rf_wdata;
// 指令存储器接口信号
logic [31:0] iaddr;
logic [31:0] inst;
// 数据存储器接口信号（连接CPU与data_ram IP核）
wire [31:0] daddr;    // 数据地址（CPU输出）
wire [31:0] din;      // 写数据（CPU输出）
wire [31:0] dout;     // 读数据（data_ram输出）
wire        we;       // 写使能（CPU输出）
wire [1:0]  mem_sel;  // 字节选择（CPU输出）
// CPU核实例化（使用新增的访存端口）
Loongarch32_Lite Loongarch32_Lite0(
.cpu_clk_50M(cpu_clk),
.cpu_rst_n(cpu_rst_n),
.iaddr(iaddr),
.inst(inst),
// 数据存储器接口（连接外部IP核）
.daddr(daddr),
.din(din),
.we(we),
.mem_sel(mem_sel),
.dout(dout),
// 调试信号
.debug_wb_pc(debug_wb_pc),
.debug_wb_rf_wen(debug_wb_rf_wen),
.debug_wb_rf_wnum(debug_wb_rf_wnum),
.debug_wb_rf_wdata(debug_wb_rf_wdata)
);
// 指令存储器IP核实例化
inst_rom inst_rom0 (
.a(iaddr[15:2]),      // 按字寻址（64KB：16位地址，忽略低2位）
.spo(inst)            // 读出的指令
);
// 数据存储器IP核实例化（正确连接CPU访存信号）
data_ram data_ram0 (
.a(daddr[15:2]),      // 按字寻址（64KB：16位地址）
.d(din),              // 写数据（来自CPU）
.clk(cpu_clk),         // 时钟（50MHz）
.we(we),               // 写使能（来自CPU）
.spo(dout)             // 读数据（输出到CPU）
);
endmodule