`default_nettype none

// Bit 6 is opacity: black and white are both available as opaque colors.
module sprite_rom #(
    parameter MEM_FILE = "../data/sprites.mem"
) (
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire [3:0] sprite_id,
    input wire [3:0] x,
    input wire [4:0] y,
    output reg [5:0] color,
    output reg opaque
);
    reg [6:0] pixels [0:3839];
    initial $readmemh(MEM_FILE, pixels);
    wire [11:0] address = {8'b0,sprite_id} * 12'd384 + {7'b0,y} * 12'd16 + {8'b0,x};
    always @(posedge clk) begin
        if (!rst_n || !enable || sprite_id >= 10 || y >= 24)
            {opaque, color} <= 7'b0;
        else {opaque, color} <= pixels[address];
    end
endmodule
