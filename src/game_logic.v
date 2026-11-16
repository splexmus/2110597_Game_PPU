`default_nettype none

module game_logic (
    input wire [7:0] ui_in,
    input wire clk,
    input wire rst_n,
    input wire [9:0] pix_x,
    input wire [9:0] pix_y,
    output reg [5:0] RGB
);
    wire inp_b, inp_y, inp_start, inp_left, inp_right, inp_a, inp_x;
    gamepad_pmod_single driver (
        .rst_n(rst_n), .clk(clk), .pmod_data(ui_in[6]),
        .pmod_clk(ui_in[5]), .pmod_latch(ui_in[4]),
        .b(inp_b), .y(inp_y), .select(), .start(inp_start),
        .up(), .down(), .left(inp_left), .right(inp_right),
        .a(inp_a), .x(inp_x), .l(), .r(), .is_present()
    );

    localparam START=3'd0, PLAYER=3'd1, ENEMY=3'd2,
               CLEAR=3'd3, WIN=3'd4, GAMEOVER=3'd5;
    reg [2:0] state;
    reg [2:0] room;
    reg [5:0] hp, enemy_hp;
    reg [1:0] potions, selection;
    reg charged, guarding;
    reg [3:0] enemy_wait;
    wire frame_tick = pix_x == 0 && pix_y == 480;
    wire [6:0] buttons = {inp_start, inp_y | inp_x, inp_b, inp_a, inp_right, inp_left, 1'b0};
    reg [6:0] previous_buttons, pending;
    wire [6:0] edges = buttons & ~previous_buttons;
    wire [6:0] events = pending | edges;
    wire [1:0] action = events[4] ? 2'd1 : events[5] ? 2'd2 : selection;
    wire commit_action = events[3] | events[4] | events[5];
    wire [5:0] attack = 6'd4 + {3'b0, room};
    wire [5:0] damage = guarding ? 6'd1 :
                         charged ? ((6'd2 + {3'b0,room}) << 1) : (6'd2 + {3'b0,room});

    // Capture short presses between frames; held buttons never repeat actions.
    // State changes only in vertical blank, so every scanline sees one turn.
    always @(posedge clk) begin
        if (!rst_n) begin
            previous_buttons <= 0; pending <= 0;
            state <= START; room <= 0; hp <= 30; enemy_hp <= 6;
            potions <= 3; selection <= 0; charged <= 0;
            guarding <= 0; enemy_wait <= 0;
        end else begin
            previous_buttons <= buttons;
            pending <= pending | edges;
            if (frame_tick) begin
                pending <= 0;
                if (events[6] || ((state == START || state == WIN || state == GAMEOVER) && events[3])) begin
                    state <= PLAYER; room <= 0; hp <= 30; enemy_hp <= 6;
                    potions <= 3; selection <= 0; charged <= 0;
                    guarding <= 0; enemy_wait <= 0;
                end else case (state)
                    START, WIN, GAMEOVER: begin end
                    PLAYER: begin
                        if (events[1]) selection <= selection == 0 ? 2'd2 : selection - 1'b1;
                        else if (events[2]) selection <= selection == 2 ? 2'd0 : selection + 1'b1;
                        if (commit_action) begin
                            guarding <= action == 1;
                            if (action == 0) begin
                                if (enemy_hp <= attack) begin
                                    enemy_hp <= 0;
                                    state <= room == 4 ? WIN : CLEAR;
                                end else begin
                                    enemy_hp <= enemy_hp - attack;
                                    state <= ENEMY; enemy_wait <= 12;
                                end
                            end else if (action == 1) begin
                                // Guard counters for 3 and reduces the next hit to 1.
                                if (enemy_hp <= 3) begin
                                    enemy_hp <= 0;
                                    state <= room == 4 ? WIN : CLEAR;
                                end else begin
                                    enemy_hp <= enemy_hp - 6'd3;
                                    state <= ENEMY; enemy_wait <= 12;
                                end
                            end else if (potions != 0 && hp < 30) begin
                                hp <= hp >= 18 ? 6'd30 : hp + 6'd12;
                                potions <= potions - 1'b1;
                                state <= ENEMY; enemy_wait <= 12;
                            end
                        end
                    end
                    ENEMY: begin
                        if (enemy_wait != 0) enemy_wait <= enemy_wait - 1'b1;
                        else begin
                            charged <= ~charged;
                            if (hp <= damage) begin hp <= 0; state <= GAMEOVER; end
                            else begin hp <= hp - damage; state <= PLAYER; end
                        end
                    end
                    CLEAR: if (events[3]) begin
                        room <= room + 1'b1;
                        enemy_hp <= room == 3 ? 6'd20 : 6'd9 + {3'b0,room} * 6'd3;
                        hp <= hp >= 26 ? 6'd30 : hp + 6'd4;
                        selection <= 0; charged <= 0; guarding <= 0;
                        state <= PLAYER;
                    end
                    default: state <= START;
                endcase
            end
        end
    end

    // One 160x6 scanline RAM (960 bits), reused for all 480 physical rows.
    // Request pixels at h=638..797. Registered ROM data is written at 639..798.
    // The first write follows the last read of column 0; the last precedes h=0.
    reg [5:0] line_buffer [0:159];
    reg line_ready, fetch_valid;
    wire [9:0] fetch_offset = pix_x - 10'd638;
    wire [7:0] fetch_x = fetching ? fetch_offset[7:0] : 8'd0;
    wire [9:0] next_y = pix_y == 524 ? 10'd0 : pix_y + 10'd1;
    wire [6:0] fetch_y = next_y[8:2];
    wire fetching = pix_x >= 638 && pix_x < 798 && next_y < 480;
    reg [7:0] draw_x;
    reg [6:0] draw_y;
    wire [5:0] bg_pix, sprite_pix;
    wire sprite_opaque;
    reg sprite_enable;
    reg [3:0] sprite_id, sprite_x;
    reg [4:0] sprite_y;
    always @* begin
        sprite_enable = 0; sprite_id = 0; sprite_x = 0; sprite_y = 0;
        if (fetch_y >= 60 && fetch_y < 84 && fetch_x >= 28 && fetch_x < 44) begin
            sprite_enable = 1; sprite_id = 0;
            sprite_x = fetch_x - 8'd28; sprite_y = fetch_y - 7'd60;
        end else if (enemy_hp != 0 && fetch_y >= 60 && fetch_y < 84 && fetch_x >= 108 && fetch_x < 124) begin
            sprite_enable = 1; sprite_id = {1'b0,room} + 4'd1;
            sprite_x = fetch_x - 8'd108; sprite_y = fetch_y - 7'd60;
        end else if (fetch_y >= 40 && fetch_y < 64 && fetch_x >= 72 && fetch_x < 88) begin
            sprite_enable = 1; sprite_id = 6;
            sprite_x = fetch_x - 8'd72; sprite_y = fetch_y - 7'd40;
        end else if (fetch_y >= 28 && fetch_y < 52 && (fetch_x < 16 || fetch_x >= 144)) begin
            sprite_enable = 1; sprite_id = 8;
            sprite_x = fetch_x[3:0]; sprite_y = fetch_y - 7'd28;
        end else if (fetch_y >= 64 && fetch_y < 88 && fetch_x >= 72 && fetch_x < 88 && enemy_hp == 0) begin
            sprite_enable = 1; sprite_id = 7;
            sprite_x = fetch_x - 8'd72; sprite_y = fetch_y - 7'd64;
        end else if (fetch_y >= 64 && fetch_y < 88 && fetch_x >= 8 && fetch_x < 24 && room[0]) begin
            sprite_enable = 1; sprite_id = 9;
            sprite_x = fetch_x - 8'd8; sprite_y = fetch_y - 7'd64;
        end
    end
    bg_rom background (.clk(clk), .rst_n(rst_n), .room(room),
                       .x(fetch_x), .y(fetch_y), .color(bg_pix));
    sprite_rom sprites (.clk(clk), .rst_n(rst_n), .enable(sprite_enable && fetching),
                        .sprite_id(sprite_id), .x(sprite_x), .y(sprite_y),
                        .color(sprite_pix), .opaque(sprite_opaque));

    reg [4:0] font [0:1023];
    initial $readmemh("data/font.mem", font);
    reg [207:0] text_line;
    wire [7:0] text_x = draw_x - 8'd2;
    wire [6:0] text_y = draw_y - 7'd2;
    wire [4:0] text_col = text_x / 8'd6;
    wire [2:0] glyph_x = text_x % 8'd6;
    wire [7:0] character = text_col < 26 ? text_line[207 - text_col*8 -: 8] : 8'd32;
    wire [4:0] glyph_row = font[{character[6:0],text_y[2:0]}];
    wire ink = draw_x >= 2 && draw_x < 158 && glyph_x < 5 && glyph_row[4-glyph_x];
    reg [5:0] composed;
    always @* begin
        text_line = "                          ";
        case (text_y[6:3])
            0: case (room)
                0: text_line = "ROOM 1/5  THE GATE        ";
                1: text_line = "ROOM 2/5  BONE HALL       ";
                2: text_line = "ROOM 3/5  THE CRYPT       ";
                3: text_line = "ROOM 4/5  IRON KEEP       ";
                4: text_line = "ROOM 5/5  THRONE ROOM     ";
                default: text_line = "                          ";
            endcase
            1: begin
                text_line = "HP 30/30  FOE 06          ";
                text_line[183 -: 8] = 8'd48 + {2'b0,hp} / 8'd10;
                text_line[175 -: 8] = 8'd48 + {2'b0,hp} % 8'd10;
                text_line[95 -: 8] = 8'd48 + {2'b0,enemy_hp} / 8'd10;
                text_line[87 -: 8] = 8'd48 + {2'b0,enemy_hp} % 8'd10;
            end
            2: begin
                text_line = charged ? "POT 3  FOE: HEAVY         " : "POT 3  FOE: STRIKE        ";
                text_line[175 -: 8] = 8'd48 + {6'b0,potions};
            end
            12: text_line = " HIT    GUARD    POTION   ";
            13: text_line = "A USE   B GUARD   Y HEAL  ";
            14: begin
                if (state == ENEMY) text_line = "      ENEMY TURN...       ";
                else if (state == CLEAR) text_line = "   ROOM CLEAR - A NEXT    ";
                else if (state == PLAYER) text_line = "        YOUR TURN         ";
            end
            default: begin end
        endcase
        if (state == START) begin
            text_line = "                          ";
            case (text_y[6:3])
                0: text_line = "    FIVE SEALED ROOMS     ";
                4: text_line = "    A MEDIEVAL DUNGEON    ";
                6: text_line = "        A TO ENTER        ";
                8: text_line = " LEFT RIGHT CHOOSE ACTION ";
                10: text_line = " GUARD THE HEAVY STRIKES  ";
                13: text_line = " START RESTARTS ANY TIME  ";
                default: begin end
            endcase
        end
        if (state == WIN) begin
            text_line = "                          ";
            case (text_y[6:3])
                0: text_line = "    FIVE SEALED ROOMS     ";
                4: text_line = "     DUNGEON CLEARED      ";
                6: text_line = "    THE CROWN IS YOURS    ";
                8: text_line = " ALL FIVE ROOMS ARE SAFE  ";
                10: text_line = "     A TO PLAY AGAIN      ";
                default: begin end
            endcase
        end
        if (state == GAMEOVER) begin
            text_line = "                          ";
            case (text_y[6:3])
                0: text_line = "    FIVE SEALED ROOMS     ";
                4: text_line = "     YOU HAVE FALLEN      ";
                6: text_line = "   THE DUNGEON REMAINS    ";
                8: text_line = " GUARD OR HEAL NEXT TIME  ";
                10: text_line = "      A TO TRY AGAIN      ";
                default: begin end
            endcase
        end
        composed = sprite_opaque ? sprite_pix : bg_pix;
        if (draw_y < 26 || draw_y >= 96) composed = 6'h01;
        if (state == START || state == WIN || state == GAMEOVER) begin
            if (draw_y >= 28 && draw_y < 92) composed = 6'h01;
        end else begin
            if (draw_y >= 97 && draw_y < 105 && state == PLAYER &&
                ((selection == 0 && draw_x < 44) ||
                 (selection == 1 && draw_x >= 44 && draw_x < 92) ||
                 (selection == 2 && draw_x >= 92))) composed = 6'h16;
            // Health meters above the two combatants.
            if (draw_y >= 55 && draw_y < 57) begin
                if (draw_x >= 22 && draw_x < 52)
                    composed = (draw_x - 8'd22 < {2'b0,hp}) ? 6'h0c : 6'h10;
                if (draw_x >= 106 && draw_x < 126)
                    composed = (draw_x - 8'd106 < {2'b0,enemy_hp}) ? 6'h30 : 6'h10;
            end
        end
        if (ink) composed = state == GAMEOVER ? 6'h35 : state == WIN ? 6'h3c : 6'h3f;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            fetch_valid <= 0; draw_x <= 0; draw_y <= 0; line_ready <= 0;
        end else begin
            fetch_valid <= fetching;
            draw_x <= fetch_x; draw_y <= fetch_y;
            if (fetch_valid) begin
                line_buffer[draw_x] <= composed;
                if (draw_x == 159) line_ready <= 1;
            end
        end
    end
    always @* begin
        RGB = 0;
        if (rst_n && line_ready && pix_x < 640 && pix_y < 480)
            RGB = line_buffer[pix_x[9:2]];
    end
endmodule
