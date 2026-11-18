`default_nettype none

// Bit 6 is opacity: black and white are both available as opaque colors.
module sprite_rom (
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire [3:0] sprite_id,
    input wire [1:0] pose,
    input wire [3:0] x,
    input wire [4:0] y,
    output reg [5:0] color,
    output reg opaque
);
    reg [6:0] pixels [0:3839];
    initial $readmemh("../data/sprites.mem", pixels);
    wire [11:0] address = {8'b0,sprite_id} * 12'd384 + {7'b0,y} * 12'd16 + {8'b0,x};
    always @(posedge clk) begin
        if (!rst_n || !enable || sprite_id >= 10 || y >= 24)
            {opaque, color} <= 7'b0;
        else begin
            {opaque, color} <= pixels[address];
            if (sprite_id < 6) begin
                // Repose the existing artwork; no extra sprite-frame memory.
                if (pose == 1 && (sprite_id == 0 || sprite_id == 2 || sprite_id >= 4)) begin
                    if (x >= 13 && y < 16) {opaque, color} <= 7'b0;
                    if (x >= 9 && y == 12) {opaque, color} <= {1'b1,6'h3f};
                    if (x == 10 && y >= 10 && y <= 14) {opaque, color} <= {1'b1,6'h38};
                end
                if (pose == 2 && x >= 10 && y >= 10 && y <= 20) begin
                    if (y <= 17 || (x >= 11 && x <= 14))
                        {opaque, color} <= {1'b1,(x == 10 || x == 15 || y == 10 || y == 20) ? 6'h3c : 6'h16};
                end
                if (pose == 3 && ((x == 7 && y >= 10 && y <= 16) || (y == 13 && x >= 4 && x <= 10)))
                    {opaque, color} <= {1'b1,6'h0c};
            end
        end
    end
endmodule
