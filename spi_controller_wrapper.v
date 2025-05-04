`timescale 1ns / 1ps

module spi_controller_wrapper (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        spi_wr,
    input  wire [7:0]  spi_data,
    output wire        spi_ready,

    output wire        spi_mosi,
    output wire        spi_sck,
    output wire        spi_cs
);

    // 内部连接到 spi_controller
    wire [31:0] ctrl_data;
    wire        wr_ctrl;
    wire        wr_data;
    wire        read_status;
    wire [31:0] ctrl_reg_out;
    wire [31:0] status_reg_out;
    wire [31:0] data_reg_out;

    wire irq;

    wire miso = 1'b0; // dummy MISO for now

    assign ctrl_data      = 32'b00000000_00000000_00000000_00001001; // CPOL=0, CPHA=0, SPR0=1
    assign wr_ctrl        = 1'b1; // 一次写入即可
    assign wr_data        = spi_wr;
    assign read_status    = 1'b0;

    spi_controller spi_ctrl_inst (
        .clk(clk),
        .RST_N(rst_n),
        .o_IRQ(irq),

        .i_data_to_registers({24'b0, spi_data}),
        .i_wr_controll_reg(wr_ctrl),
        .i_wr_data_reg(wr_data),
        .i_read_status_reg(read_status),

        .o_controll_reg(ctrl_reg_out),
        .o_status_reg(status_reg_out),
        .o_data_reg(data_reg_out),

        .i_miso(miso),
        .o_mosi(spi_mosi),
        .o_sclk(spi_sck)
    );

    assign spi_cs    = 1'b0;      // 固定拉低，持续选择
    assign spi_ready = irq;      // IRQ 拉高表示传输完成

endmodule
