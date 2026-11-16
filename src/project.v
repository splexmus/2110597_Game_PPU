/*
 * Copyright (c) 2025 Uri Shaked
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_vga_example (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // Unused outputs assigned to 0.
  assign uio_out = 0;
  assign uio_oe  = 0;

  // Suppress unused signals warning
  wire _unused_ok = &{ena, ui_in[7], ui_in[3:0], uio_in};
  // VGA signals
  wire hsync;
  wire vsync;
  reg [1:0] R;
  reg [1:0] G;
  reg [1:0] B;
  wire video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;

  // Tiny VGA Pmod
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

  hvsync_generator vga_sync_gen (
      .clk(clk),
      .reset(~rst_n),
      .hsync(hsync),
      .vsync(vsync),
      .display_on(video_active),
      .hpos(pix_x),
      .vpos(pix_y)
  );

  wire [5:0] RGB;

  game_logic game_logic (
    .clk(clk),
    .ui_in(ui_in),
    .rst_n(rst_n),
    .RGB(RGB),
    .pix_x(pix_x),
    .pix_y(pix_y)
  );


  // RGB output logic
  always @(posedge clk) begin
    if (~rst_n) begin
      R <= 0;
      G <= 0;
      B <= 0;
    end else begin
      if (video_active) begin
        {R, G, B} <= RGB;
      end else begin
        {R, G, B} <= 0;
      end
    end
  end


endmodule
