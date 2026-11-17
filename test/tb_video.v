`timescale 1ns/1ps
module tb_video;
    reg clk=0, rst_n=0;
    always #5 clk=~clk;
    wire [7:0] out,unused_out,unused_oe;
    tt_um_vga_example dut(8'b0,out,8'b0,unused_out,unused_oe,1'b1,clk,rst_n);
    integer scene,x,y,fd;
    reg [1023:0] filename;
    reg [5:0] color;
    task sample;
        input integer px,py;
        begin
            if(dut.pix_x !== px || dut.pix_y !== py) $fatal(1,"Counter mismatch");
            @(posedge clk); #1;
            if(out[7] !== !(px>=656 && px<752)) $fatal(1,"HSYNC alignment");
            if(out[3] !== !(py>=490 && py<492)) $fatal(1,"VSYNC alignment");
            color={out[0],out[4],out[1],out[5],out[2],out[6]};
            if(^color === 1'bx) $fatal(1,"Unknown RGB");
            if(px>=640 || py>=480) begin
                if(color !== 0) $fatal(1,"Nonblack blanking");
            end else begin
                $fwrite(fd,"%c%c%c",{6'b0,color[5:4]}*85,{6'b0,color[3:2]}*85,{6'b0,color[1:0]}*85);
            end
            @(negedge clk);
        end
    endtask
    initial begin
        repeat(4) @(negedge clk); rst_n=1;
        while(!(dut.pix_x==0 && dut.pix_y==480)) @(negedge clk);
        for(scene=0;scene<9;scene=scene+1) begin
            // Fixed scene fixtures set in vertical blank; raster runs normally.
            dut.game_logic.state = scene==0 ? 0 : scene<=5 ? 1 : scene==6 ? 3 : scene==7 ? 4 : 5;
            dut.game_logic.room = scene>=1 && scene<=5 ? scene-1 : scene==6 ? 3 : 4;
            dut.game_logic.hp = scene==8 ? 0 : 23;
            dut.game_logic.enemy_hp = scene>=6 ? 0 : scene==5 ? 20 : 3+3*scene;
            dut.game_logic.potions = 5;
            dut.game_logic.charged = scene%2;
            for(y=480;y<525;y=y+1)
                for(x=0;x<800;x=x+1) sample(x,y);
            $sformat(filename,"../test/output/scene%0d.ppm",scene);
            fd=$fopen(filename,"wb");
            if(fd==0) $fatal(1,"Cannot open frame output");
            $fwrite(fd,"P6\n640 480\n255\n");
            for(y=0;y<480;y=y+1)
                for(x=0;x<800;x=x+1) sample(x,y);
            $fclose(fd);
        end
        $display("PASS: nine VGA frames, sync alignment, blanking and initialized pixels");
        $finish;
    end
endmodule
