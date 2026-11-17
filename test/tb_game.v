`timescale 1ns/1ps
module tb_game;
    reg clk=0, rst_n=0;
    always #5 clk=~clk;
    reg [7:0] ui=0;
    reg [9:0] x=0,y=0;
    wire [5:0] rgb;
    game_logic dut(ui,clk,rst_n,x,y,rgb);
    integer i, turns;
    task check;
        input condition;
        input [511:0] message;
        begin if (condition !== 1'b1) begin $display("FAIL: %0s",message); $fatal(1); end end
    endtask
    task tick;
        begin
            @(negedge clk); x=0; y=480;
            @(negedge clk); y=0;
        end
    endtask
    // Exercise the real serial receiver, including its synchronizers.
    task packet;
        input [11:0] bits;
        integer bit_number;
        begin
            for(bit_number=11;bit_number>=0;bit_number=bit_number-1) begin
                @(negedge clk); ui[6]=bits[bit_number]; ui[5]=0;
                repeat(4) @(negedge clk);
                ui[5]=1; repeat(4) @(negedge clk);
            end
            ui[5]=0; ui[4]=1; repeat(5) @(negedge clk);
            ui[4]=0; repeat(5) @(negedge clk);
        end
    endtask
    task press;
        input [11:0] bits;
        begin packet(bits); tick; packet(0); tick; end
    endtask
    task finish_enemy;
        integer n;
        begin
            for(n=0;n<16;n=n+1) tick;
            check(dut.state != 2, "Enemy turn did not finish");
        end
    endtask
    task check_enemy_bar;
        input [2:0] room_number;
        input [5:0] current_hp, max_hp;
        integer px, filled;
        begin
            @(negedge clk); dut.room=room_number; dut.enemy_hp=current_hp; dut.state=1;
            y=219;
            for(px=638;px<800;px=px+1) begin
                x=px;
                @(negedge clk);
            end
            x=0; y=0;
            filled=(current_hp*20+max_hp-1)/max_hp;
            check(dut.enemy_max_hp==max_hp,"Enemy maximum matches room encounter");
            for(px=0;px<20;px=px+1)
                check(dut.line_buffer[106+px]==(px<filled ? 6'h30 : 6'h10),"Enemy bar is proportional to max HP");
        end
    endtask
    initial begin
        repeat(4) @(negedge clk); rst_n=1; tick;
        check(dut.state==0,"Reset must stay on title");
        press(12'hfff); check(dut.state==0,"Absent controller must not press buttons");
        press(12'h008); check(dut.state==1 && dut.hp==30,"A starts game");
        press(12'h400); check(dut.state==1 && dut.potions==5,"Full-health potion is a no-op");
        press(12'h020); check(dut.state==1 && dut.hp==30 && dut.enemy_hp==6,"Left does not select or act");
        press(12'h010); check(dut.state==1 && dut.hp==30 && dut.enemy_hp==6,"Right does not select or act");
        // A held across many frames causes exactly one attack.
        packet(12'h008); tick;
        check(dut.enemy_hp==2 && dut.state==2,"Attack damage and enemy phase");
        finish_enemy;
        check(dut.hp==26 && dut.charged,"First enemy hit and heavy telegraph");
        repeat(20) tick;
        check(dut.enemy_hp==2 && dut.state==1,"Held A must not repeat");
        packet(0); tick;
        press(12'h008); check(dut.state==3 && dut.hp==26,"Lethal hit has no retaliation");
        press(12'h008); check(dut.room==1 && dut.hp==30 && dut.enemy_hp==9,"Next room reward");
        press(12'h800); finish_enemy;
        check(dut.hp==29 && dut.enemy_hp==6,"B guard counter and reduced damage");
        press(12'h400); check(dut.potions==4 && dut.hp==30,"Y potion caps healing at 30");
        finish_enemy; check(dut.hp==20,"Potion consumes a turn; heavy hit doubles damage");
        // Guard telegraphed heavy hits and clear all five rooms.
        press(12'h100); check(dut.room==0 && dut.hp==30 && dut.potions==5,"Start fully resets run");
        turns=0;
        while(dut.state != 4 && turns < 40) begin
            if(dut.state==1 && dut.charged && dut.enemy_hp > dut.attack) press(12'h800);
            else if(dut.state==1 || dut.state==3) press(12'h008);
            else if(dut.state==2) finish_enemy;
            else check(0,"Unexpected state on five-room path");
            turns=turns+1;
        end
        check(dut.state==4 && dut.room==4 && dut.enemy_hp==0 && dut.hp==6,"Five-room victory path");
        press(12'h008); check(dut.state==1 && dut.room==0,"A restarts victory screen");
        // Blindly attacking should now lose to the boss.
        turns=0;
        while(dut.state != 5 && turns < 40) begin
            if(dut.state==1 || dut.state==3) press(12'h008);
            else if(dut.state==2) finish_enemy;
            else check(0,"Unexpected state on attack-only path");
            turns=turns+1;
        end
        check(dut.state==5 && dut.room==4,"Higher damage defeats attack-only play");
        press(12'h008);
        // Boundary fixtures: insufficient HP, empty potions and guarded heavy hit.
        @(negedge clk); dut.hp=1;
        press(12'h008); finish_enemy;
        check(dut.state==5 && dut.hp==0,"Lethal enemy damage saturates HP at zero");
        press(12'h008); check(dut.state==1 && dut.hp==30,"A restarts game over");
        @(negedge clk); dut.hp=10; dut.potions=0;
        press(12'h400); check(dut.state==1 && dut.hp==10,"Empty potion does not consume turn");
        @(negedge clk); dut.charged=1;
        press(12'h800); finish_enemy;
        check(dut.hp==9 && dut.enemy_hp==3,"Guard blocks heavy damage");
        press(12'h800); check(dut.state==3 && dut.hp==9,"Guard counter can clear a room");
        // Normal/heavy damage increases in every room; A remains a direct attack.
        for(i=0;i<5;i=i+1) begin
            @(negedge clk); dut.state=1; dut.room=i; dut.hp=30; dut.enemy_hp=20; dut.charged=0;
            press(12'h008); finish_enemy;
            check(dut.hp==26-i,"Room normal damage is 4 plus room index");
            @(negedge clk); dut.hp=30; dut.enemy_hp=20; dut.charged=1;
            press(12'h008); finish_enemy;
            check(dut.hp==22-2*i,"Room heavy damage doubles normal damage");
        end
        // Every room starts with a full-width bar and scales down to empty.
        for(i=0;i<5;i=i+1) begin
            check_enemy_bar(i, i==4 ? 20 : 6+3*i, i==4 ? 20 : 6+3*i);
            check_enemy_bar(i, (i==4 ? 20 : 6+3*i)/2, i==4 ? 20 : 6+3*i);
            check_enemy_bar(i, 1, i==4 ? 20 : 6+3*i);
            check_enemy_bar(i, 0, i==4 ? 20 : 6+3*i);
        end
        press(12'h100);
        for(i=0;i<5;i=i+1) begin
            @(negedge clk); dut.hp=10;
            press(12'h400); finish_enemy;
            check(dut.potions==4-i,"All five potions can be used without wrapping");
        end
        press(12'h400); check(dut.state==1 && dut.potions==0,"Sixth potion is a no-op");
        // A short press entirely between frame ticks is retained.
        press(12'h100);
        packet(12'h008); packet(0); tick;
        check(dut.enemy_hp==2 && dut.state==2,"Short press between frames is retained");
        $display("PASS: serial controls, five rooms, turns, health, victory and defeat");
        $finish;
    end
endmodule
