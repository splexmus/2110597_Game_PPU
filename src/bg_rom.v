`default_nettype none

// 16 reusable 16x16 tiles and five 10x5 tile maps, not screen-sized images.
module bg_rom #(
    parameter TILE_FILE = "../data/bg_tiles.mem",
    parameter MAP_FILE = "../data/room_maps.mem"
) (
    input wire clk,
    input wire rst_n,
    input wire [2:0] room,
    input wire [7:0] x,
    input wire [6:0] y,
    output reg [5:0] color
);
    reg [5:0] tiles [0:4095];
    reg [3:0] maps [0:249];
    initial begin
        $readmemh(TILE_FILE, tiles);
        $readmemh(MAP_FILE, maps);
    end
    wire in_room = room < 5 && x < 160 && y >= 16 && y < 96;
    wire [6:0] local_y = y - 7'd16;
    wire [7:0] map_addr = {5'b0, room} * 8'd50 +
                            {5'b0, local_y[6:4]} * 8'd10 + {4'b0, x[7:4]};
    wire [3:0] tile_id = maps[in_room ? map_addr : 8'd0];
    always @(posedge clk) begin
        if (!rst_n || !in_room) color <= 6'h01;
        else color <= tiles[{tile_id, local_y[3:0], x[3:0]}];
    end
endmodule
