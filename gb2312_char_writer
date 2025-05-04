`timescale 1ns / 1ps

// 10x13 点阵 GB2312 汉字字符单点刷新模块
// 基于 st7789_spi_memctrl 的屏幕架构，对特定字符刷新像素区域
// 使用 24x24 点阵汉字库，内存中按 [字索引][行] 地址组织

module gb2312_char_writer #(
    parameter SCREEN_W = 240,
    parameter SCREEN_H = 320,
    parameter FONT_W   = 24,
    parameter FONT_H   = 24
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire [15:0] char_code,     // GB2312 编码
    input  wire [9:0]  x_pos,         // 左上角 X 坐标（最大 SCREEN_W - FONT_W）
    input  wire [9:0]  y_pos,         // 左上角 Y 坐标（最大 SCREEN_H - FONT_H）
    input  wire        start,         // 开始写入信号

    output reg         busy,          // 写入中
    output reg         req_pixel,     // 请求像素刷新（每时钟发一个点）
    output reg [15:0]  pixel_color,   // 当前像素颜色
    output reg [9:0]   pixel_x,
    output reg [9:0]   pixel_y
);

// 假设字库使用二维 ROM，按 [字索引][行] 取出 3 字节 = 24bit（每行）
// 示例：字库ROM接口
reg [12:0] font_row_addr;
wire [23:0] font_row_bits;

font_rom u_font_rom(
    .clk(clk),
    .addr(font_row_addr),
    .data(font_row_bits)
);

// 状态机
localparam S_IDLE = 0, S_FETCH = 1, S_DRAW = 2, S_DONE = 3;
reg [1:0] state;

reg [4:0] row_idx;     // 0 ~ 23
reg [4:0] col_idx;     // 0 ~ 23
reg [23:0] curr_row_bits;

// 字库地址编码
wire [12:0] font_base = (char_code - 16'hA1A1); // 根据编码偏移算索引

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        req_pixel <= 0;
        busy <= 0;
        font_row_addr <= 0;
    end else begin
        case (state)
            S_IDLE: begin
                if (start) begin
                    busy <= 1;
                    row_idx <= 0;
                    col_idx <= 0;
                    font_row_addr <= font_base * FONT_H + 0; // 初始行地址
                    state <= S_FETCH;
                end
                req_pixel <= 0;
            end
            S_FETCH: begin
                curr_row_bits <= font_row_bits;
                col_idx <= 0;
                state <= S_DRAW;
            end
            S_DRAW: begin
                // 逐列取位判断是否显示
                pixel_x <= x_pos + col_idx;
                pixel_y <= y_pos + row_idx;
                pixel_color <= curr_row_bits[23 - col_idx] ? 16'hFFFF : 16'h0000; // 白/黑
                req_pixel <= 1;

                if (col_idx == FONT_W - 1) begin
                    col_idx <= 0;
                    row_idx <= row_idx + 1;
                    if (row_idx == FONT_H - 1)
                        state <= S_DONE;
                    else begin
                        font_row_addr <= font_base * FONT_H + row_idx + 1;
                        state <= S_FETCH;
                    end
                end else begin
                    col_idx <= col_idx + 1;
                end
            end
            S_DONE: begin
                req_pixel <= 0;
                busy <= 0;
                state <= S_IDLE;
            end
        endcase
    end
end

endmodule
