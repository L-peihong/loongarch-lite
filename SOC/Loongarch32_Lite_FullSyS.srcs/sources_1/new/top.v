module top(
    input clk,  // 50Mhz
    input locked,
    
    input                   rxd,                // 串口接收端
    output                  txd,                // 串口发送端
    
    input [31:0]            sw_1,           // 第一组拨码开关
    input [31:0]            sw_2,           // 第二组拨码开关
    output [31:0]            led,            // LED灯
    output [3:0]             seg_cs,        // 7段数码管选择信号
    output [7:0]             seg_data       // 7段数码管数据
    // 注释/删除未使用的btn端口，避免冗余
    // input [7:0]             btn            // 按钮（模块未使用，删除）
);
Loongarch32_Lite_FullSys Loongarch32_Lite_FullSys0(
    .clk(clk),
    .locked(locked),
    .rxd(rxd),
    .txd(txd),
    .sw_1(sw_1),
    .sw_2(sw_2),
    .led(led),
    .seg_cs(seg_cs),
    .seg_data(seg_data)
    // 删除此处的.btn(btn)，因为Loongarch32_Lite_FullSys模块无此端口
);
endmodule