# 新增变量约定：
# $0(zero): 保留
# $1(at): 计数器专用
# $2(v0): 返回值
# $3(v1): PS2按键地址
# $4(a0): 颜色的地址
# $5(a1): 参数地址
# $6(a2): IO地址
# $7(a3): 图片地址
# $8-$13:(t0-t5)临时用的
# $14: 当前分数/取值位数
# $15: 小球半径
# $16: 小球x
# $17: 小球y
# $18: 当前板半径
# $19: 当前板x
# $20: 当前板y
# $21: 下一板半径
# $22: 下一板x  
# $23: 下一板y
# $24: 死亡与否
# $25: 移动速度
# $26: 剩余距离
# $27: 剩余的按键时长
# $gp: 是否在飞
# $sp: 是否在按
# $30: 存被乘数
# $31: $ra, 不可使用

add $zero, $zero, $zero; # 4
add $zero, $zero, $zero; # 8
add $zero, $zero, $zero; # C
add $zero, $zero, $zero; # 10
add $zero, $zero, $zero; # 14
add $zero, $zero, $zero; # 18
add $zero, $zero, $zero; # 1C

initialize_constants:
    # 初始化参数
    addi $v1, $zero, 0x0700	#按键的地址
    addi $a0, $zero, 0x0728	#颜色的地址
    addi $a1, $zero, 0x0748	#各种参数的地址
    addi $a2, $zero, 0x0734	#IO地址的地址

start:
    # 看看是否重置游戏(SW4)了，是的话跳到最开始
    lw $t3, 0($a2); #sw与LED地址
    lw $t1, 0($t3); # sw
    add $t4, $t1, $t1; # 左移对齐
    add $t4, $t4, $t4;
    sw $t4, 0($t3); # 存LED
    andi $t2, $t1, 4096;
    bne $t2, $zero, start;
    lw $t3, 8($a2);		#读取存储的keyboard地址
    lw $t1, 0($t3);		#读取keyboard输入
    lw $t2, 16($v1);		#读取kbenter 回车数值
    bne $t1, $t2, start;

game_var_initialize:
    # 初始化小球位置、飞行状态、计数等
    lui $at, 0x2; # 2A
    addi $14, $zero, 1;
    addi $15, $zero, 0x14;
    addi $16, $zero, 0x140; # PC:20
    addi $17, $zero, 0x0f0;
    addi $18, $zero, 0x028;
    addi $19, $zero, 0x140;
    addi $20, $zero, 0x0f0;
    addi $21, $zero, 0x20;
    addi $22, $zero, 0x140;
    addi $23, $zero, 0x160;
    add $24, $zero, $zero;
    addi $25, $zero, 28;
    add $26, $zero, $zero;
    add $27, $zero, $zero;
    add $gp, $zero, $zero;
    add $sp, $zero, $zero;
    jal vga_background;
    jal show_current_plate;
    jal show_next_plate;
    jal show_new_ball;

main_logic_loop:
    # 看看是否重置游戏(SW12)了，是的话跳到最开始
    # 读取SW
    lw $t3, 0($a2); #sw与LED地址
    lw $t1, 0($t3); # sw
    add $t4, $t1, $t1; # 左移对齐
    add $t4, $t4, $t4;
    sw $t4, 0($t3); # 存LED
    andi $t2, $t1, 4096; # 30
    bne $t2, $zero, start;
    # 看看是否仍然在飞，是的话调到fly
    bne $gp, $zero, fly;
    # 否则到rest
    j rest;

rest:
    # 如果上一个周期没有按的话去not_pressing
    beq $sp, $zero, not_pressing; # 83
    # 如果上一个周期已经按了，去pressing
    j pressing; # 84

not_pressing:
    #读取keyboard
    lw $t3, 8($a2)	#85 	#读取存储的keyboard地址
    lw $t1, 0($t3)	#86	#读取keyboard输入
    lw $t2, 0($v1)	#87	#读取kbenter UP数值
    bne $t1, $t2, rest; #88 # 如果没在按的话回到rest
    # 否则按键时长（剩余飞行时长）设为1 并将$sp置位1
    addi $27, $zero, 0x1; # 89
    addi $sp, $zero, 0x1; # 8A
    j main_logic_loop; # 8B

pressing:
    #读取keyboard
    addi $at, $at, -1;
    bne $at, $zero, pressing;
    lui $at, 0x2; # 2A
    lw $t3, 8($a2)		#读取存储的keyboard地址
    lw $t1, 0($t3)		#读取keyboard输入
    lw $t2, 0($v1)		#读取kbenter UP数值
    bne $t1, $t2, finish_press; # 如果没在按的话结束计数
    # 否则计数加一，回到main_logic
    addi $27, $27, 0x1;
    # 传给七段码显示
    lw $t3, 4($a2)  # 读取seg7地址
    sw $27, 0x0($t3);
    j main_logic_loop;

finish_press:
    # 是否在飞置位1
    addi $gp, $zero, 0x1;
    # 是否在按置位0
    add $sp, $zero, $zero;
    j main_logic_loop;

fly:
    # 飞行中的逻辑
    # 剩余飞行时间-1
    addi $27, $27, -1;
    # 判断是否结束飞行，是的话跳转end_flying
    beq $27, $zero, end_flying;
    # 否则处理飞行逻辑
    # 如果x坐标相等，那么是上下飞
    beq $19, $22, up_down;
    # 否则是左右飞
    j left_right;
    # 最后跳转回main_logic
up_down:
    # 修正小球轨迹
    jal erase_last_ball; 
    add $t4, $16, $19;
    srl $16, $t4, 0x1;
    # 判断上飞还是下飞
    slt $t0, $20, $23;
    beq $t0, $zero, up;
    jal show_current_plate;
    add $17, $17, $25;
    jal show_next_plate;
    jal show_new_ball;
    j main_logic_loop;
up: # 上飞
    jal show_current_plate;
    sub $17, $17, $25;
    jal show_next_plate;
    jal show_new_ball;
    j main_logic_loop;
left_right:
    # 修正小球轨迹
    jal erase_last_ball; 
    add $t4, $17, $20;
    srl $17, $t4, 0x1;
    # 判断左飞还是右飞
    slt $t0, $19, $22;
    bne $t0, $zero, right;
    # 左飞
    jal show_current_plate;
    sub $16, $16, $25;   
    jal show_next_plate;
    jal show_new_ball;
    j main_logic_loop;
right: # 右飞
    jal show_current_plate;
    add $16, $16, $25;
    jal show_next_plate;
    jal show_new_ball;
    j main_logic_loop;

end_flying:
    # 将在飞设置为0
    add $gp, $zero, $zero;
    # 判断是否游戏失败
    # 检测是否开了作弊（SW11）
    lw $t3, 0($a2); #sw与LED地址
    lw $t1, 0($t3); # sw
    add $t4, $t1, $t1; # 左移对齐
    add $t4, $t4, $t4;
    sw $t4, 0($t3); # 存LED
    andi $t2, $t1, 2048;
    # 暂时屏蔽作弊接口
    bne $t2, $zero, finish_judge_end;
    # 如果SW[0]开启，那么直接跳回main_logic
    # 判断是否跳出界
    # $16 < $22 - $21
    sub $t4, $22, $21;
    slt $t4, $16, $t4;
    bne $t4, $zero, end_game;
    # $16 > $22 + $21
    add $t4, $22, $21;
    slt $t4, $t4, $16;
    bne $t4, $zero, end_game;
    # $17 < $23 - $21
    sub $t4, $23, $21;
    slt $t4, $17, $t4;
    bne $t4, $zero, end_game;
    # $17 > $23 + $21
    add $t4, $21, $23;
    slt $t4, $t4, $17;
    bne $t4, $zero, end_game;
    # ball_x > 640;
    addi $t4, $zero, 0x280;
    slt $t4, $t4, $16;
    bne $t4, $zero, end_game;
    # ball_x < 0;
    slt $t4, $16, $zero;
    bne $t4, $zero, end_game;
    # ball_y > 480;
    addi $t4, $zero, 0x1e0;
    slt $t4, $t4, $17;
    bne $t4, $zero, end_game;
    # ball_y < 0;
    slt $t4, $17, $zero;
    bne $t4, $zero, end_game;
finish_judge_end:
    # 最后跳转回main_logic
    # 没有失败的话
    # 换下一块板子
    # 把下一板设为当前板
    jal erase_last_plate;
    add $18, $21, $zero;
    add $19, $22, $zero;
    add $20, $23, $zero;
    # 获取下一板
    # t0 <- 14 * 4
    addi $14, $14, 1;
    add $t0, $14, $14;
    add $t0, $t0, $t0;
    addi $t1, $zero, 0x40;
    bne $t1, $t0, finish_judge_end_tmp;
    j success_game;
finish_judge_end_tmp:
    lw $21, 0x0748($t0);
    lw $22, 0x0788($t0);
    lw $23, 0x07c8($t0);
    sw $14, 4($a2);
    jal show_next_plate;
    j main_logic_loop;

end_game:
    add $t1, $zero, $zero; # 遍历x
    add $t2, $zero, $zero; # 遍历y
    addi $t3, $zero, 640;
    addi $t4, $zero, 480;
    lw $t5, 12($a2); # t5: 存储的vram地址
    lw $a3, 16($a2); # a3: 储存的图片首地址
vga_endgame:
    lw $t0, 0($a3);
    sw $t0, 0($t5);
    addi $t5, $t5, 1;
    addi $t1, $t1, 1;
    addi $a3, $a3, 1;
    bne $t1, $t3, vga_endgame;
    add $t1, $zero, $zero;
    addi $t2, $t2, 1;
    bne $t2, $t4, vga_endgame;
    j wait_for_retry;

wait_for_retry:
    lw $t3, 8($a2);		#读取存储的keyboard地址
    lw $t1, 0($t3);		#读取keyboard输入
    lw $t2, 16($v1);		#读取kbenter 回车数值
    beq $t1, $t2, game_var_initialize;
    j wait_for_retry;

erase_last_ball:
    #x: $16-$15~$16+$15; y: $17-$15~$17+$15
    add $v0, $zero, $ra;
    lw $t5, 12($a2); # t5: 存储的vram地址
    sub $t1, $16, $15;
    sub $t2, $17, $15;
    add $t3, $16, $15;
    add $t4, $17, $15;
    add $30, $zero, $t2;
    jal multi640;
    add $t5, $30, $t5;
    add $t5, $t5, $t1;
erase_last_ball_label:
    lw $t0, 4($a0); # 加载颜色
    sw $t0, 0($t5); # 存储数值
    addi $t5, $t5, 1; # 自增t5, t1;
    addi $t1, $t1, 1;
    bne $t1, $t3, erase_last_ball_label; # 判断跳转
    addi $t5, $t5, 640;
    sub $t5, $t5, $15;
    sub $t5, $t5, $15;
    sub $t1, $16, $15; # 重置t1
    addi $t2, $t2, 1; # 自增t2
    bne $t2, $t4, erase_last_ball_label; # 外层循环
    jr $v0; # 返回

show_new_ball:
    #x: $16-$15~$16+$15; y: $17-$15~$17+$15
    add $v0, $zero, $ra;
    lw $t5, 12($a2); # t5: 存储的vram地址
    sub $t1, $16, $15;
    sub $t2, $17, $15;
    add $t3, $16, $15;
    add $t4, $17, $15;
    add $30, $zero, $t2;
    jal multi640;
    add $t5, $30, $t5;
    add $t5, $t5, $t1;
show_new_ball_label:
    lw $t0, 0($a0); # 加载颜色
    sw $t0, 0($t5); # 存储数值
    addi $t5, $t5, 1; # 自增t5, t1;
    addi $t1, $t1, 1;
    bne $t1, $t3, show_new_ball_label; # 判断跳转
    addi $t5, $t5, 640;
    sub $t5, $t5, $15;
    sub $t5, $t5, $15;
    sub $t1, $16, $15; # 重置t1
    addi $t2, $t2, 1; # 自增t2
    bne $t2, $t4, show_new_ball_label; # 外层循环
    jr $v0; # 返回

erase_last_plate:
    #x: $19-$18~$19+$18; y: $20-$18~$20+$18
    add $v0, $zero, $ra;
    lw $t5, 12($a2); # t5: 存储的vram地址
    sub $t1, $19, $18;
    sub $t2, $20, $18;
    add $t3, $19, $18;
    add $t4, $20, $18;
    add $30, $zero, $t2;
    jal multi640;
    add $t5, $30, $t5;
    add $t5, $t5, $t1;
erase_last_plate_label:
    lw $t0, 4($a0); # 加载颜色
    sw $t0, 0($t5); # 存储数值
    addi $t5, $t5, 1; # 自增t5, t1;
    addi $t1, $t1, 1;
    bne $t1, $t3, erase_last_plate_label; # 判断跳转
    addi $t5, $t5, 640;
    sub $t5, $t5, $18;
    sub $t5, $t5, $18;
    sub $t1, $19, $18; # 重置t1
    addi $t2, $t2, 1; # 自增t2
    bne $t2, $t4, erase_last_plate_label; # 外层循环
    jr $v0; # 返回

show_current_plate: # 只在开头调用一次
    #x: $19-$18~$19+$18; y: $20-$18~$20+$18
    add $v0, $zero, $ra;
    lw $t5, 12($a2); # t5: 存储的vram地址
    sub $t1, $19, $18;
    sub $t2, $20, $18;
    add $t3, $19, $18;
    add $t4, $20, $18;
    add $30, $zero, $t2;
    jal multi640;
    add $t5, $30, $t5;
    add $t5, $t5, $t1;
show_current_plate_label:
    add $t0, $14, $14;
    add $t0, $t0, $t0;
    addi $30, $zero, 0x40;
    bne $30, $t0, show_current_plate_tmp;
    add $t0, $zero, $zero;
show_current_plate_tmp:
    lw $t0, 0x808($t0);
    sw $t0, 0($t5); # 存储数值
    addi $t5, $t5, 1; # 自增t5, t1;
    addi $t1, $t1, 1;
    bne $t1, $t3, show_current_plate_label; # 判断跳转
    addi $t5, $t5, 640;
    sub $t5, $t5, $18;
    sub $t5, $t5, $18;
    sub $t1, $19, $18; # 重置t1
    addi $t2, $t2, 1; # 自增t2
    bne $t2, $t4, show_current_plate_label; # 外层循环
    jr $v0; # 返回

show_next_plate:
    #x: $22-$21~$22+$21; y: $23-$21~$23+$21
    add $v0, $zero, $ra;
    lw $t5, 12($a2); # t5: 存储的vram地址
    sub $t1, $22, $21;
    sub $t2, $23, $21;
    add $t3, $22, $21;
    add $t4, $23, $21;
    add $30, $zero, $t2;
    jal multi640;
    add $t5, $30, $t5;
    add $t5, $t5, $t1;
show_next_plate_label:
    add $t0, $14, $14;
    add $t0, $t0, $t0;
    lw $t0, 0x07ac($t0);
    sw $t0, 0($t5); # 存储数值
    addi $t5, $t5, 1; # 自增t5, t1;
    addi $t1, $t1, 1;
    bne $t1, $t3, show_next_plate_label; # 判断跳转
    addi $t5, $t5, 640;
    sub $t5, $t5, $21;
    sub $t5, $t5, $21;
    sub $t1, $22, $21; # 重置t1
    addi $t2, $t2, 1; # 自增t2
    bne $t2, $t4, show_next_plate_label; # 外层循环
    jr $v0; # 返回

multi640:
    add $30, $30, $30;
    add $30, $30, $30;
    add $30, $30, $30;
    add $30, $30, $30;
    add $30, $30, $30;
    add $30, $30, $30;
    add $t0, $30, $30; # t0:128 * t0
    add $30, $t0, $t0;
    add $30, $30, $30; # 30:512 * t0
    add $30, $30, $t0;
    jr $ra;

vga_background:
    add $t1, $zero, $zero; # 遍历x
    add $t2, $zero, $zero; # 遍历y
    addi $t3, $zero, 640;
    addi $t4, $zero, 480;
    lw $t5, 12($a2); # t5: 存储的vram地址
vga_background_label:
    lw $t0, 4($a0);
    sw $t0, 0($t5);
    addi $t5, $t5, 1;
    addi $t1, $t1, 1;
    addi $a3, $a3, 1;
    bne $t1, $t3, vga_background_label;
    add $t1, $zero, $zero;
    addi $t2, $t2, 1;
    bne $t2, $t4, vga_background_label;
    jr $ra;

success_game:
    add $t1, $zero, $zero; # 遍历x
    add $t2, $zero, $zero; # 遍历y
    addi $t3, $zero, 640;
    addi $t4, $zero, 480;
    lw $t5, 12($a2); # t5: 存储的vram地址
success_game_label:
    srl $t0, $t5, 3;
    add $t0, $t0, $t1;
    add $t0, $t0, $t2;
    sw $t0, 0($t5);
    addi $t5, $t5, 1;
    addi $t1, $t1, 1;
    addi $a3, $a3, 1;
    bne $t1, $t3, success_game_label;
    add $t1, $zero, $zero;
    addi $t2, $t2, 1;
    bne $t2, $t4, success_game_label;
    j start;

.data 0x0000700		#d4096
#v1
kbup: 	    .word 629	#h275上
kbdown:	    .word 626	#h272下
kbleft:	    .word 619	#h26b左
kbright:	.word 628	#h274右
kbenter:	.word 90	#h5a 回车
swup:	    .word 2048	#sw11 上
swdown:	    .word 1024	#sw10 下
swleft:	    .word 512	#sw9 左
swright:	.word 256	#sw8 右
swenter:	.word 4096	#sw12 回车

#a0
red:	.word 0x00f	#h00f红色
white:	.word 0xfff	#白色
blue:	.word 0xcc4	#蓝色背景

#a2
LEDcounter:	.word 0xf0000000	#f0000000地址 LED和硬件countersw 地址
seg7:	    .word 0xe0000000	#e0000000地址 七段显示器
keyborad:	.word 0xd0000000	#d0000000地址 keyboard
vram:	    .word 0xc0000000	#c0000000地址 vram
picend: 	.word 0xb0000000	#b0000000地址 picend

#a1
# size 748
.word 0x00000030, 0x00000025, 0x0000002f, 0x0000002c, 0x0000002f, 0x0000002a, 0x0000002a, 0x0000002f
.word 0x00000031, 0x0000002d, 0x00000020, 0x00000029, 0x00000020, 0x00000030, 0x0000002a, 0x00000016
# x (0-280) 788
.word 0x00000120, 0x00000120, 0x00000200, 0x00000200, 0x00000100, 0x00000050, 0x00000050, 0x00000050
.word 0x000001a0, 0x00000230, 0x00000230, 0x000001d0, 0x000001d0, 0x00000090, 0x000001f0, 0x000001f0
# y (0-1e0) 7c8
.word 0x000000f0, 0x00000160, 0x00000160, 0x000000d0, 0x000000d0, 0x000000d0, 0x00000060, 0x000000c0
.word 0x000000c0, 0x000000c0, 0x00000150, 0x00000150, 0x000001a0, 0x000001a0, 0x000001a0, 0x000000f0
# rgb (8bit) 808
.word 0x000005ac, 0x00000a23, 0x00000fbf, 0x0000031c, 0x00000634, 0x000001d6, 0x00000f3a, 0x000008bb
.word 0x00000999, 0x00000844, 0x0000014f, 0x00000ada, 0x000009c1, 0x00000be6, 0x00000c79, 0x00000468