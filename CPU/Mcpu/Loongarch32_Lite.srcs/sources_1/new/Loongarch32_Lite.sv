`include "defines.v"
module Loongarch32_Lite(
    input  wire                  cpu_clk_50M,
    input  wire                  cpu_rst_n,
    // 指令存储器接口
    output wire [`INST_ADDR_BUS] iaddr,
    input  wire [`INST_BUS]      inst,
    // 数据存储器接口
    output wire [`INST_ADDR_BUS] daddr,       // 数据地址
    output wire [`REG_BUS]       din,          // 写数据
    output wire                  we,           // 写使能
    output wire [1:0]            mem_sel,      // 字节选择
    input  wire [`REG_BUS]       dout,          // 读数据
    // 调试信号输出
    output wire [`INST_ADDR_BUS] debug_wb_pc,
    output wire                  debug_wb_rf_wen,
    output wire [`REG_ADDR_BUS]  debug_wb_rf_wnum,
    output wire [`WORD_BUS]      debug_wb_rf_wdata
);
    // 内部信号定义
    // IF阶段信号
    wire [`INST_ADDR_BUS] pc;
    wire [`INST_ADDR_BUS] branch_target;
    wire                  branch_valid;
    wire                  stall;
    wire                  flush;
    wire [`INST_ADDR_BUS] debug_wb_pc_if, debug_wb_pc_id, debug_wb_pc_exe, debug_wb_pc_mem;

    // IF/ID寄存器信号
    wire [`INST_ADDR_BUS] id_pc;
    wire [`INST_BUS]      id_inst;
    wire [`INST_ADDR_BUS] id_debug_wb_pc;

    // ID阶段信号
    wire [`ALUTYPE_BUS]   id_alutype;
    wire [`ALUOP_BUS]     id_aluop;
    wire [`REG_ADDR_BUS]  id_wa;
    wire                  id_wreg;
    wire [`REG_BUS]       id_src1;
    wire [`REG_BUS]       id_src2;
    wire [`INST_ADDR_BUS] id_branch_target;
    wire [`REG_ADDR_BUS]  ra1;
    wire [`REG_ADDR_BUS]  ra2;
    wire [`REG_BUS]       rd1;
    wire [`REG_BUS]       rd2;
    wire [1:0]            forward_sel1;
    wire [1:0]            forward_sel2;
    // 前推数据源（EXE/MEM/WB）
    wire [`REG_BUS]       forward_data_exe = exe_wd_o;
    wire [`REG_BUS]       forward_data_mem = mem_dreg_o;
    wire [`REG_BUS]       forward_data_wb = wb_wd_o;

    // ID/EXE寄存器信号
    wire [`ALUTYPE_BUS]   exe_alutype;
    wire [`ALUOP_BUS]     exe_aluop;
    wire [`REG_BUS]       exe_src1;
    wire [`REG_BUS]       exe_src2;
    wire [`REG_ADDR_BUS]  exe_wa;
    wire                  exe_wreg;
    wire [`INST_ADDR_BUS] exe_debug_wb_pc;
    wire [`INST_ADDR_BUS] exe_branch_target;

    // EXE阶段信号
    wire [`ALUOP_BUS]     exe_aluop_o;
    wire [`REG_ADDR_BUS]  exe_wa_o;
    wire                  exe_wreg_o;
    wire [`REG_BUS]       exe_wd_o;
    wire [`REG_BUS]       exe_mem_addr_o;
    wire [`REG_BUS]       exe_mem_wdata_o;
    wire                  exe_mem_we_o;
    wire [1:0]            exe_mem_sel_o;

    // EXE/MEM寄存器信号
    wire [`ALUOP_BUS]     mem_aluop;
    wire [`REG_ADDR_BUS]  mem_wa;
    wire                  mem_wreg;
    wire [`REG_BUS]       mem_wd;
    wire [`REG_BUS]       mem_mem_addr;
    wire [`REG_BUS]       mem_mem_wdata;
    wire                  mem_mem_we;
    wire [1:0]            mem_mem_sel;
    wire [`INST_ADDR_BUS] mem_debug_wb_pc;

    // MEM阶段信号
    wire [`REG_ADDR_BUS]  mem_wa_o;
    wire                  mem_wreg_o;
    wire [`REG_BUS]       mem_dreg_o;

    // MEM/WB寄存器信号
    wire [`REG_ADDR_BUS]  wb_wa;
    wire                  wb_wreg;
    wire [`REG_BUS]       wb_dreg;
    wire [`INST_ADDR_BUS] wb_debug_wb_pc;

    // WB阶段信号
    wire [`REG_ADDR_BUS]  wb_wa_o;
    wire                  wb_wreg_o;
    wire [`REG_BUS]       wb_wd_o;

    // 1. 实例化取指阶段模块
    if_stage if_stage0(
        .cpu_clk_50M(cpu_clk_50M),
        .cpu_rst_n(cpu_rst_n),
        .stall_i(stall),
        .flush_i(flush),
        .branch_target_i(branch_target),
        .branch_valid_i(branch_valid),
        .pc(pc),
        .iaddr(iaddr),
        .debug_wb_pc(debug_wb_pc_if)
    );

    // 2. 实例化IF/ID流水线寄存器
    ifid_reg ifid_reg0(
        .cpu_clk_50M(cpu_clk_50M),
        .cpu_rst_n(cpu_rst_n),
        .stall_i(stall),
        .flush_i(flush),
        .if_pc(pc),
        .if_debug_wb_pc(debug_wb_pc_if),
        .inst(inst),
        .id_pc(id_pc),
        .id_inst(id_inst),
        .id_debug_wb_pc(id_debug_wb_pc)
    );

    // 3. 实例化寄存器堆
    regfile regfile0(
        .cpu_clk_50M(cpu_clk_50M),
        .cpu_rst_n(cpu_rst_n),
        .wa(wb_wa_o),
        .wd(wb_wd_o),
        .we(wb_wreg_o),
        .ra1(ra1),
        .rd1(rd1),
        .ra2(ra2),
        .rd2(rd2)
    );

    // 4. 实例化冒险控制单元
    hazard_unit hazard_unit0(
        .cpu_rst_n(cpu_rst_n),
        .id_ra1_i(ra1),
        .id_ra2_i(ra2),
        .id_alutype_i(id_alutype),
        .exe_wa_i(exe_wa),
        .exe_wreg_i(exe_wreg),
        .exe_alutype_i(exe_alutype),
        .mem_wa_i(mem_wa),
        .mem_wreg_i(mem_wreg),
        .wb_wa_i(wb_wa),
        .wb_wreg_i(wb_wreg),
        .forward_sel1_o(forward_sel1),
        .forward_sel2_o(forward_sel2),
        .stall_o(stall),
        .flush_o(flush)
    );

    // 5. 实例化解码阶段模块（连接前推数据源）
    id_stage id_stage0(
        .cpu_clk_50M(cpu_clk_50M),
        .cpu_rst_n(cpu_rst_n),
        .id_pc_i(id_pc),
        .id_debug_wb_pc_i(id_debug_wb_pc),
        .id_inst_i(id_inst),
        .rd1(rd1),
        .rd2(rd2),
        .forward_data_exe(forward_data_exe),
        .forward_data_mem(forward_data_mem),
        .forward_data_wb(forward_data_wb),
        .forward_sel1_i(forward_sel1),
        .forward_sel2_i(forward_sel2),
        .id_alutype_o(id_alutype),
        .id_aluop_o(id_aluop),
        .id_wa_o(id_wa),
        .id_wreg_o(id_wreg),
        .id_src1_o(id_src1),
        .id_src2_o(id_src2),
        .id_branch_target_o(id_branch_target),
        .ra1(ra1),
        .ra2(ra2),
        .debug_wb_pc(debug_wb_pc_id)
    );

    // 6. 实例化ID/EXE流水线寄存器
    idexe_reg idexe_reg0(
        .cpu_clk_50M(cpu_clk_50M),
        .cpu_rst_n(cpu_rst_n),
        .stall_i(stall),
        .flush_i(flush),
        .id_alutype(id_alutype),
        .id_aluop(id_aluop),
        .id_src1(id_src1),
        .id_src2(id_src2),
        .id_wa(id_wa),
        .id_wreg(id_wreg),
        .id_debug_wb_pc(debug_wb_pc_id),
        .id_branch_target(id_branch_target),
        .exe_alutype(exe_alutype),
        .exe_aluop(exe_aluop),
        .exe_src1(exe_src1),
        .exe_src2(exe_src2),
        .exe_wa(exe_wa),
        .exe_wreg(exe_wreg),
        .exe_debug_wb_pc(exe_debug_wb_pc),
        .exe_branch_target(exe_branch_target)
    );

    // 7. 实例化执行阶段模块
    exe_stage exe_stage0(
        .exe_alutype_i(exe_alutype),
        .exe_aluop_i(exe_aluop),
        .exe_src1_i(exe_src1),
        .exe_src2_i(exe_src2),
        .exe_wa_i(exe_wa),
        .exe_wreg_i(exe_wreg),
        .exe_debug_wb_pc(exe_debug_wb_pc),
        .exe_branch_target_i(exe_branch_target),
        .exe_aluop_o(exe_aluop_o),
        .exe_wa_o(exe_wa_o),
        .exe_wreg_o(exe_wreg_o),
        .exe_wd_o(exe_wd_o),
        .exe_mem_addr_o(exe_mem_addr_o),
        .exe_mem_wdata_o(exe_mem_wdata_o),
        .exe_mem_we_o(exe_mem_we_o),
        .exe_mem_sel_o(exe_mem_sel_o),
        .exe_branch_valid_o(branch_valid),
        .debug_wb_pc(debug_wb_pc_exe)
    );
    assign branch_target = exe_branch_target;

    // 8. 实例化EXE/MEM流水线寄存器
    exemem_reg exemem_reg0(
        .cpu_clk_50M(cpu_clk_50M),
        .cpu_rst_n(cpu_rst_n),
        .stall_i(stall),
        .exe_aluop(exe_aluop_o),
        .exe_wa(exe_wa_o),
        .exe_wreg(exe_wreg_o),
        .exe_wd(exe_wd_o),
        .exe_mem_addr(exe_mem_addr_o),
        .exe_mem_wdata(exe_mem_wdata_o),
        .exe_mem_we(exe_mem_we_o),
        .exe_mem_sel(exe_mem_sel_o),
        .exe_debug_wb_pc(debug_wb_pc_exe),
        .mem_aluop(mem_aluop),
        .mem_wa(mem_wa),
        .mem_wreg(mem_wreg),
        .mem_wd(mem_wd),
        .mem_mem_addr(mem_mem_addr),
        .mem_mem_wdata(mem_mem_wdata),
        .mem_mem_we(mem_mem_we),
        .mem_mem_sel(mem_mem_sel),
        .mem_debug_wb_pc(mem_debug_wb_pc)
    );

    // 9. 实例化访存阶段模块
    mem_stage mem_stage0(
        .cpu_clk_50M(cpu_clk_50M),
        .cpu_rst_n(cpu_rst_n),
        .mem_aluop_i(mem_aluop),
        .mem_wa_i(mem_wa),
        .mem_wreg_i(mem_wreg),
        .mem_wd_i(mem_wd),
        .mem_mem_addr_i(mem_mem_addr),
        .mem_mem_wdata_i(mem_mem_wdata),
        .mem_mem_we_i(mem_mem_we),
        .mem_mem_sel_i(mem_mem_sel),
        .mem_debug_wb_pc_i(mem_debug_wb_pc),
        .dout(dout),
        .mem_wa_o(mem_wa_o),
        .mem_wreg_o(mem_wreg_o),
        .mem_dreg_o(mem_dreg_o),
        .debug_wb_pc(debug_wb_pc_mem),
        .daddr(daddr),
        .din(din),
        .we(we),
        .mem_sel(mem_sel)
    );

    // 10. 实例化MEM/WB流水线寄存器
    memwb_reg memwb_reg0(
        .cpu_clk_50M(cpu_clk_50M),
        .cpu_rst_n(cpu_rst_n),
        .stall_i(stall),
        .mem_wa(mem_wa_o),
        .mem_wreg(mem_wreg_o),
        .mem_dreg(mem_dreg_o),
        .mem_debug_wb_pc(debug_wb_pc_mem),
        .wb_wa(wb_wa),
        .wb_wreg(wb_wreg),
        .wb_dreg(wb_dreg),
        .wb_debug_wb_pc(wb_debug_wb_pc)
    );

    // 11. 实例化写回阶段模块
    wb_stage wb_stage0(
        .wb_wa_i(wb_wa),
        .wb_wreg_i(wb_wreg),
        .wb_dreg_i(wb_dreg),
        .wb_debug_wb_pc_i(wb_debug_wb_pc),
        .wb_wa_o(wb_wa_o),
        .wb_wreg_o(wb_wreg_o),
        .wb_wd_o(wb_wd_o),
        .debug_wb_pc(debug_wb_pc),
        .debug_wb_rf_wen(debug_wb_rf_wen),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata)
    );
endmodule