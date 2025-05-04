`timescale 1ns / 1ps

// 帧缓存模块：用于缓存全屏 RGB565 像素数据
// 支持写入单点像素 + 顺序读取（用于 SPI 刷新）
// 可后续集成仲裁逻辑与 gb2312_char_writer

module framebuffer #(
    parameter SCREEN_W = 240,
    parameter SCREEN_H = 320
)(
    input  wire        clk,
    input  wire        rst_n,

    // 写入接口（单点写入）
    input  wire        wr_en,        // 写使能
    input  wire [15:0] wr_x,         // 写入 x 坐标
    input  wire [15:0] wr_y,         // 写入 y 坐标
    input  wire [15:0] wr_data,      // 写入像素数据 (RGB565)

    // 顺序读接口（供 SPI 刷新）
    input  wire        rd_en,        // 读取使能
    input  wire [31:0] rd_index,     // 像素索引（0 ~ SCREEN_W*SCREEN_H-1）
    output wire [15:0] rd_data       // 当前像素输出
);

// 帧缓存：一维数组表示 2D 屏幕像素
localparam MEM_DEPTH = SCREEN_W * SCREEN_H;
reg [15:0] mem [0:MEM_DEPTH-1];

// 写入逻辑
always @(posedge clk) begin
    if (wr_en) begin
        if (wr_x < SCREEN_W && wr_y < SCREEN_H) begin
            mem[wr_y * SCREEN_W + wr_x] <= wr_data;
        end
    end
end

// 读取逻辑
assign rd_data = (rd_en && rd_index < MEM_DEPTH) ? mem[rd_index] : 16'h0000;

endmodule
