`timescale 1ns / 1ps

// 简化版 ST7789V2 驱动框架，适用于 FPGA SPI 控制器
// 假设 SPI 控制器提供 task 接口 send_byte(cmd/data)
// 字符点阵数据使用 .mem 文件初始化 ROM
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 集成模块：ST7789 SPI驱动 + 内存控制器
// 功能：通过内存映射方式直接驱动屏幕，支持背景+字符混合显示
//////////////////////////////////////////////////////////////////////////////////

module st7789_spi_memctrl #(
    parameter MEM_FILE  = "display.mem",  // 显示数据内存文件
    parameter SCREEN_W  = 240,            // 屏幕宽度
    parameter SCREEN_H  = 320             // 屏幕高度
)(
    input  wire        clk,               // 主时钟 (建议20-40MHz)
    input  wire        rst_n,             // 异步复位
    // SPI物理接口
    output wire        spi_cs,            // 片选（固定使能）
    output wire        spi_sck,           // SPI时钟
    output wire        spi_mosi,          // SPI数据输出
    output wire        spi_dc,            // 命令/数据选择
    // 控制信号
    input  wire        refresh_en,        // 刷新触发信号
    output wire        busy               // 忙指示
);

//---------------- 内存控制器实例化 ----------------
wire [15:0] pixel_data;      // RGB565像素数据
wire        mem_ready;       // 内存数据就绪
wire        mem_empty;       // 内存数据发送完成

mem_driver #(
    .MEM_FILE(MEM_FILE),
    .MEM_DEPTH(SCREEN_W*SCREEN_H)
) u_memctrl (
    .clk(clk),
    .rst_n(rst_n),
    .ready(mem_ready),
    .wr(spi_wr),
    .data_out(pixel_data),
    .done(mem_empty)
);

//---------------- SPI状态机控制 ----------------
typedef enum logic [3:0] {
    S_INIT_RESET,
    S_INIT_CMD1,
    S_INIT_DELAY,
    S_SET_ADDRESS,
    S_SEND_PIXELS,
    S_IDLE
} state_t;

state_t curr_state, next_state;

reg [15:0] delay_cnt;
reg [31:0] pixel_cnt;
reg        spi_dc_reg;
reg        spi_wr;
reg [7:0]  spi_cmd_buf;

//---------------- SPI命令序列定义 ----------------
localparam CMD_CASET  = 8'h2A;  // 列地址设置
localparam CMD_RASET  = 8'h2B;  // 行地址设置
localparam CMD_RAMWR  = 8'h2C;  // 内存写入

//---------------- 时钟分频器（20MHz -> 10MHz SPI） ----------------
reg spi_clk_en;
reg [1:0] clk_div;

always @(posedge clk) begin
    clk_div <= clk_div + 1;
    spi_clk_en <= (clk_div == 2'b11);
end

//---------------- 主状态机 ----------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        curr_state  <= S_INIT_RESET;
        delay_cnt   <= 0;
        pixel_cnt   <= 0;
        spi_dc_reg  <= 0;
        spi_wr      <= 0;
        spi_cmd_buf <= 0;
    end else if (spi_clk_en) begin
        case (curr_state)
            S_INIT_RESET: begin
                spi_dc_reg <= 0;
                if (delay_cnt < 1000) begin
                    delay_cnt <= delay_cnt + 1;
                end else begin
                    curr_state <= S_INIT_CMD1;
                    spi_cmd_buf <= CMD_CASET;
                end
            end
            
            S_INIT_CMD1: begin
                spi_wr <= 1;
                if (mem_ready) begin
                    spi_wr <= 0;
                    curr_state <= S_SET_ADDRESS;
                end
            end
            
            S_SET_ADDRESS: begin
                if (pixel_cnt == 0) begin
                    // 发送列地址命令
                    spi_dc_reg <= 0;
                    spi_cmd_buf <= CMD_CASET;
                    curr_state <= S_SEND_PIXELS;
                end
                // ... 类似处理行地址设置
            end
            
            S_SEND_PIXELS: begin
                spi_dc_reg <= 1;  // 数据模式
                if (mem_ready && !mem_empty) begin
                    spi_wr <= 1;
                    pixel_cnt <= pixel_cnt + 1;
                    if (pixel_cnt == SCREEN_W*SCREEN_H-1) begin
                        curr_state <= S_IDLE;
                    end
                end
            end
            
            S_IDLE: begin
                if (refresh_en) begin
                    curr_state <= S_SET_ADDRESS;
                    pixel_cnt <= 0;
                end
            end
        endcase
    end
end

//---------------- SPI物理层接口 ----------------
spi_controller_wrapper u_spi (
    .clk(clk),
    .rst_n(rst_n),
    .spi_wr(spi_wr),
    .spi_data(curr_state == S_INIT_CMD1 ? {8'h00, spi_cmd_buf} : pixel_data),
    .spi_ready(mem_ready),
    .spi_mosi(spi_mosi),
    .spi_sck(spi_sck),
    .spi_cs(spi_cs)
);

assign spi_dc = spi_dc_reg;
assign busy = (curr_state != S_IDLE);

endmodule
