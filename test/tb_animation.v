`timescale 1ns/1ps
module tb_animation;
    reg clk=0, rst_n=0;
    always #5 clk=~clk;
    reg [9:0] x=0,y=0;
    wire [5:0] rgb;
    game_logic dut(8'b0,clk,rst_n,x,y,rgb);
    integer room_number,frame_number,row,col,fd;
    reg [1023:0] filename;
    reg [5:0] pixel;
    initial begin
        repeat(4) @(negedge clk); rst_n=1;
        for(room_number=0;room_number<5;room_number=room_number+1) begin
            for(frame_number=0;frame_number<14;frame_number=frame_number+1) begin
                // Freeze each animation keyframe; gameplay timing is tested in tb_game.
                @(negedge clk);
                dut.room=room_number; dut.state=1; dut.hp=23;
                dut.enemy_hp=room_number==4 ? 20 : 6+3*room_number;
                dut.potions=5; dut.charged=0; dut.guarding=0;
                dut.turn_action=0; dut.enemy_wait=0;
                dut.idle_counter=frame_number<4 ? frame_number*8 : 0;
                if(frame_number>=4 && frame_number<=7) begin
                    dut.state=6;
                    case(frame_number)
                        4: dut.enemy_wait=12;
                        5: dut.enemy_wait=9;
                        6: dut.enemy_wait=6;
                        7: dut.enemy_wait=2;
                    endcase
                end
                if(frame_number>=8 && frame_number<=10) begin
                    dut.state=2; dut.enemy_wait=frame_number==8 ? 9 : 6;
                    dut.guarding=frame_number==10;
                end
                if(frame_number==11 || frame_number==12) begin
                    dut.state=6; dut.enemy_wait=6;
                    dut.turn_action=frame_number==11 ? 1 : 2;
                end
                $sformat(filename,"../test/output/animation_%0d_%0d.ppm",room_number,frame_number);
                fd=$fopen(filename,"wb");
                if(fd==0) $fatal(1,"Cannot open animation frame");
                $fwrite(fd,"P6\n160 120\n255\n");
                for(row=0;row<120;row=row+1) begin
                    // Fill the real line buffer for each logical scanline.
                    y=row==0 ? 524 : row*4-1;
                    for(col=638;col<800;col=col+1) begin
                        x=col; @(negedge clk);
                    end
                    for(col=0;col<160;col=col+1) begin
                        pixel=dut.line_buffer[col];
                        if(^pixel===1'bx) $fatal(1,"Unknown animated pixel");
                        $fwrite(fd,"%c%c%c",{6'b0,pixel[5:4]}*85,{6'b0,pixel[3:2]}*85,{6'b0,pixel[1:0]}*85);
                    end
                end
                $fclose(fd); x=0; y=0;
            end
        end
        $display("PASS: 70 animation keyframes rendered through the single line buffer");
        $finish;
    end
endmodule
