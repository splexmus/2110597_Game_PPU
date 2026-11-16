`timescale 1ns/1ps
module tb_game;
    reg clk=0, rst_n=0;
    always #5 clk=~clk;
    reg [7:0] ui=0;
    reg [9:0] x=0,y=0;
    wire [5:0] rgb;
    game_logic dut(ui,clk,rst_n,x,y,rgb);
    integer i, turns;
    reg [5:0] saved_hp;
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
    initial begin
        repeat(4) @(negedge clk); rst_n=1; tick;
        check(dut.state==0,"Reset must stay on title");
        press(12'hfff); check(dut.state==0,"Absent controller must not press buttons");
        press(12'h008); check(dut.state==1 && dut.hp==30,"A starts game");
        press(12'h400); check(dut.state==1 && dut.potions==3,"Full-health potion is a no-op");
        press(12'h020); check(dut.selection==2,"Left wraps to potion");
        press(12'h010); check(dut.selection==0,"Right wraps to attack");
        // A held across many frames causes exactly one attack.
        packet(12'h008); tick;
        check(dut.enemy_hp==2 && dut.state==2,"Attack damage and enemy phase");
        finish_enemy;
        check(dut.hp==28 && dut.charged,"First enemy hit and heavy telegraph");
        repeat(20) tick;
        check(dut.enemy_hp==2 && dut.state==1,"Held A must not repeat");
        packet(0); tick;
        press(12'h008); check(dut.state==3 && dut.hp==28,"Lethal hit has no retaliation");
        press(12'h008); check(dut.room==1 && dut.hp==30 && dut.enemy_hp==9,"Next room reward");
        press(12'h800); finish_enemy;
        check(dut.hp==29 && dut.enemy_hp==6,"B guard counter and reduced damage");
        press(12'h400); check(dut.potions==2 && dut.hp==30,"Y potion caps healing at 30");
        finish_enemy; check(dut.hp==24,"Potion consumes a turn; heavy hit doubles damage");
        // Restart and clear all five rooms using only normal attacks.
        press(12'h100); check(dut.room==0 && dut.hp==30 && dut.potions==3,"Start fully resets run");
        turns=0;
        while(dut.state != 4 && turns < 40) begin
            if(dut.state==1 || dut.state==3) press(12'h008);
            else if(dut.state==2) finish_enemy;
            else check(0,"Unexpected state on five-room path");
            turns=turns+1;
        end
        check(dut.state==4 && dut.room==4 && dut.enemy_hp==0 && dut.hp==1,"Five-room victory path");
        press(12'h008); check(dut.state==1 && dut.room==0,"A restarts victory screen");
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
        // A short press entirely between frame ticks is retained.
        press(12'h100);
        packet(12'h008); packet(0); tick;
        check(dut.enemy_hp==2 && dut.state==2,"Short press between frames is retained");
        $display("PASS: serial controls, five rooms, turns, health, victory and defeat");
        $finish;
    end
endmodule
