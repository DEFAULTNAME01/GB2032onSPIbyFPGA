`timescale 1ns / 1ps

// 顶层集成模块：整合 framebuffer + ST7789 控制器 + GB2312字符渲染器
// 实现字符叠加显示，局部刷新字符，背景保留

module st7789_char_wrapper #(
    parameter SCREEN_W = 240,
    parameter SCREEN_H = 320
)(
    input  wire        clk,
    input  wire        rst_n,

    // SPI 输出
    output wire        spi_cs,
    output wire        spi_sck,
    output wire        spi_mosi,
    output wire        spi_dc,

    // 字符写入接口（触发写入字符）
    input  wire        char_start,
    input  wire [15:0] char_code,     // GB2312 编码
    input  wire [9:0]  char_x,        // 坐标（左上）
    input  wire [9:0]  char_y,

    // 屏幕刷新
    input  wire        refresh_en,
    output wire        busy
);

//-------------------------------------------
// 帧缓存实例
//-------------------------------------------
wire        char_req_pixel;
wire [9:0]  char_pix_x, char_pix_y;
wire [15:0] char_pix_color;

wire [15:0] fb_rd_data;
wire [31:0] spi_pixel_cnt;

framebuffer #(
    .SCREEN_W(SCREEN_W),
    .SCREEN_H(SCREEN_H)
) u_fb (
    .clk         (clk),
    .rst_n       (rst_n),

    // 字符写接口
    .char_wr_en  (char_req_pixel),
    .char_x      (char_pix_x),
    .char_y      (char_pix_y),
    .char_pixel  (char_pix_color),

    // SPI读接口
    .rd_en       (1'b1),
    .rd_index    (spi_pixel_cnt),
    .rd_data     (fb_rd_data)
);

//-------------------------------------------
// 字符渲染器实例
//-------------------------------------------

gb2312_char_writer u_char_writer (
    .clk           (clk),
    .rst_n         (rst_n),
    .char_code     (char_code),
    .x_pos         (char_x),
    .y_pos         (char_y),
    .start         (char_start),
    .busy          (),
    .req_pixel     (char_req_pixel),
    .pixel_color   (char_pix_color),
    .pixel_x       (char_pix_x),
    .pixel_y       (char_pix_y)
);

//-------------------------------------------
// ST7789 SPI控制器实例（从 framebuffer 读取）
//-------------------------------------------
st7789_spi_memctrl #(
    .MEM_FILE  (""),  // 空白，使用 framebuffer
    .SCREEN_W  (SCREEN_W),
    .SCREEN_H  (SCREEN_H)
) u_lcd (
    .clk        (clk),
    .rst_n      (rst_n),
    .spi_cs     (spi_cs),
    .spi_sck    (spi_sck),
    .spi_mosi   (spi_mosi),
    .spi_dc     (spi_dc),
    .refresh_en (refresh_en),
    .busy       (busy),

    // 额外扩展输出 framebuffer 数据（由你根据内部接口整合）
    .pixel_data (fb_rd_data),
    .pixel_cnt  (spi_pixel_cnt)
);

endmodule
