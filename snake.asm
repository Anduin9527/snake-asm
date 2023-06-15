%include "print.mac"
%include "syscall.mac"

%define MAIN _start
; 定义基本参数
%define MOVE_EVERY_TICK   2           ; 移动间隔(帧)
%define MOVE_SPEED_TICK   1           ; 加速间隔(帧)
%define SIZE_X            21          ; 地图宽度
%define SIZE_Y            21					; 地图高度
%define EATEN_APPLES_INIT 3						; 初始苹果数量(蛇身长度)
%define UPD_DEL_SEC       0						; 帧与帧的更新间隔(秒)	
%define UPD_DEL_NANO      50000000    ; 帧与帧的更新间隔(纳秒)

%assign SIZE_N SIZE_X*SIZE_Y          ; 地图大小
%assign SNAKE_X_INIT SIZE_X/2         ; 蛇头初始位置X
%assign SNAKE_Y_INIT SIZE_Y/2         ; 蛇头初始位置Y
; 定义移动方向
%define DIR_UP    0 
%define DIR_RIGHT 1
%define DIR_DOWN  2
%define DIR_LEFT  3
; 定义地图元素
%define MAP_FREE  0
%define MAP_WALL  1
%define MAP_HEAD  2
%define MAP_BODY  3
%define MAP_APPLE 4
; 定义游戏状态
%define STATUS_RUN  0
%define STATUS_EXIT 1
%define STATUS_DIE  2
%define STATUS_FUN  3
; 定义按键
%define KEY_W   119
%define KEY_A   97
%define KEY_S   115
%define KEY_D   100
%define KEY_ESC 27
%define KEY_Q   113
%define KEY_C   99

%define CELL_TEXT '  ' 							; 地图单元格样式
%strlen CELL_TEXT_LEN CELL_TEXT     ; 地图单元格长度

; 宏定义ANSI转义序列
%macro DEF_ESC_SEQ 3+
	DEF_STR_DATA %1, 27, '[', %3, %2
%endmacro

; 宏定义ANSI颜色序列
%macro DEF_COLOR_SEQ 3
	DEF_ESC_SEQ color_%1_seq, 'm', '1', ';', %2, ';', %3
%endmacro

%macro MAP_BUFFER  1 							; 宏定义地图缓冲区 %1 为缓冲区名
	%1:
		times SIZE_X db MAP_WALL 			; 使用times重复SIZE_X次MAP_WALL，完成顶墙
		%rep SIZE_Y-2 								; 使用rep重复SIZE_Y-2次，完成中间部分
			db MAP_WALL 								; 左墙
			times SIZE_X-2 db MAP_FREE  ; 中间自由区域
			db MAP_WALL 								; 右墙
		%endrep
		times SIZE_X db MAP_WALL 			; 底墙
%endmacro

%define ESC_SEQ_MAX_LEN 10 ; 转义序列最大长度

%assign MAX_CELL_PRINT_SIZE ESC_SEQ_MAX_LEN*2+CELL_TEXT_LEN ; 地图元素最大打印长度

%macro PRINT_BUFFER 1	; 定义打印缓冲区大小
	%1 resb SIZE_N*MAX_CELL_PRINT_SIZE
%endmacro

section .data

%assign SCREEN_Y SIZE_Y+1 		; 屏幕高度
%defstr SCREEN_Y_STR SCREEN_Y ; defstr 定义字符串常量 

; ANSI 转义序列
DEF_ESC_SEQ cur_reset_seq, 'A', SCREEN_Y_STR ; 重置光标位置 
DEF_ESC_SEQ cur_home_seq, 'H', '0', ';', '0' ; 光标回到左上角
DEF_ESC_SEQ cur_hide_seq, 'l', '?', '25' 		 ; 隐藏光标
DEF_ESC_SEQ cur_show_seq, 'h', '?', '25'     ; 显示光标
DEF_ESC_SEQ clear_seq, 'J', '0'              ; 清屏
DEF_ESC_SEQ color_reset_seq, 'm', '0'        ; 重置颜色
; ANSI 颜色序列
DEF_COLOR_SEQ bright_red, '91', '101'        ; 亮红色
DEF_COLOR_SEQ blue, '34', '44'               ; 蓝色
DEF_COLOR_SEQ yellow, '33', '43'						 ; 黄色
DEF_COLOR_SEQ bright_yellow, '93', '103'     ; 亮黄色
DEF_COLOR_SEQ bright_gray, '90', '100'       ; 亮灰色
DEF_COLOR_SEQ miku,'36','46'                 ; 青色

; 字符串设置
DEF_STR_DATA text_score, "当前分数: "
DEF_STR_DATA text_controls, "WSAD 移动，ESC 退出游戏", 10,"Q 进入狂欢模式, C 进入加速模式"
DEF_STR_DATA text_game_over, "GAME OVER!", 10
DEF_STR_DATA cell_sym, CELL_TEXT ; 定义地图元素文本的字符串变量

; 全局变量设置
status db STATUS_RUN 						; 游戏状态

MAP_BUFFER map									; 使用宏定义定义地图map

length dq 1										  ; 蛇长度
score dq 0                      ; 分数
eaten dq EATEN_APPLES_INIT      ; 吃掉的苹果数(身体长度)
snake_x dq SNAKE_X_INIT         ; 蛇头位置X
snake_y dq SNAKE_Y_INIT         ; 蛇头位置Y

input db 0                      ; 输入
frame dq 0                      ; 当前帧

move_dir db DIR_RIGHT						; 蛇移动方向

future_move_dir db DIR_RIGHT		; 蛇下一帧移动方向
is_speed_up db 0                ; 是否开启加速

; 音乐相关变量
play  db '/usr/bin/play',0
arg1  db '-q',0
music db './res/music.mp3',0
coin  db './res/coin.mp3',0
arg3  db '-t',0
arg4  db 'alsa',0
arg5  db 'repeat',0
arg6  db '2',0
argv  dq play,arg1,music,arg3,arg4,arg5,arg6,0
argv2 dq play,arg1,coin,arg3,arg4,0
child_pid dq 0 ;child process PID
section .bss

map_free_buf resq SIZE_N 				; 定义地图空闲单元格缓冲区大小
map_free_buf_len resq 1					; 定义地图空闲单元格缓冲区大小

PRINT_BUFFER print_buf					; 定义打印缓冲区大小
print_buf_len resq 1						; 定义打印元素缓冲区大小

snake_cells_buf resq SIZE_N 		; 定义地图蛇身单元格缓冲区大小


section .text

global MAIN

extern memcpy
extern rand
extern set_noncanon
extern set_canon

; 函数名：map_coord_to_index
; 参数：
; - rax: x坐标
; - rdx: y坐标
; 返回值: rax: 地图单元格索引
; 将地图坐标转换为地图单元格索引
map_coord_to_index:
	imul rdx, SIZE_X ; y * SIZE_X
	add rax, rdx     ; x + y * SIZE_X
	ret

; 宏定义处理按键事件（蛇的移动）
%macro HANDLE_KEY 2
	cmp byte [input], %2 ; 比较输入是否为 %2
	je .%1							 ; 如果是则跳转到对应按键的处理标签中
%endmacro

; 函数名：handle_key
; 处理按键事件
handle_key:
	mov al, [move_dir]		; 获取当前移动方向
	;处理按键事件
	HANDLE_KEY quit,  KEY_ESC 
	HANDLE_KEY right, KEY_D
	HANDLE_KEY down,  KEY_S
	HANDLE_KEY left,  KEY_A
	HANDLE_KEY up,    KEY_W
	HANDLE_KEY fun,   KEY_Q
	HANDLE_KEY speed, KEY_C

	jmp .exit

	.quit:
		mov byte [status], STATUS_EXIT         ; 设置游戏状态为退出
		jmp .exit

	.right:
		cmp al, DIR_LEFT											 ; 如果当前移动方向与按键方向相反则不处理
		je .exit
		mov byte [future_move_dir], DIR_RIGHT  ; 否则设置下一帧的移动方向为按键方向
		jmp .exit

	.down:
		cmp al, DIR_UP
		je .exit
		mov byte [future_move_dir], DIR_DOWN
		jmp .exit

	.left:
		cmp al, DIR_RIGHT
		je .exit
		mov byte [future_move_dir], DIR_LEFT
		jmp .exit

	.up:
		cmp al, DIR_DOWN
		je .exit
		mov byte [future_move_dir], DIR_UP
		jmp .exit

	.fun:
		;设置游戏状态为狂欢模式
		mov byte [status], STATUS_FUN
		jmp .exit
	
	.speed:
		; 设置游戏状态为加速模式
		; 如果当前游戏状态为加速模式则关闭加速模式
		cmp byte [is_speed_up], 0
		je .speed_up
		mov byte [is_speed_up], 0
		jmp .exit
		.speed_up:
			mov byte [is_speed_up], 1
		jmp .exit



	.exit:
		ret

; 宏定义：将要打印的字符串追加到打印缓冲区 print_buf 中
%macro PRINT_BUF_APPEND 1
	mov rax, print_buf
	add rax, [print_buf_len]
	mov rdx, %1
	mov rcx, %1_len
	add [print_buf_len], rcx   ; 更新打印缓冲区长度
	call memcpy                ; 将字符串追加到打印缓冲区中
%endmacro

; 宏定义：绘制地图单元格
%macro DRAW_CELL 0
	PRINT_BUF_APPEND cell_sym  ; 将地图单元格的文本追加到打印缓冲区中
%endmacro

; 宏定义：绘制彩色地图单元格
; 参数：
; - %1: 颜色序列
%macro DRAW_COLOR_CELL 1
	PRINT_BUF_APPEND color_%1_seq   ; 将颜色序列追加到打印缓冲区中
	DRAW_CELL									      ; 将地图单元格的文本追加到打印缓冲区中，
	PRINT_BUF_APPEND color_reset_seq; 将颜色重置序列追加到打印缓冲区中
%endmacro
; 函数名：print_term_buf
; 输出打印缓冲区 print_buf 中的内容
print_term_buf:
	mov rax, print_buf
	mov rdx, [print_buf_len]
	call print											; 调用 print 函数输出
	mov qword [print_buf_len], 0    ; 清空打印缓冲区
	ret

; 宏定义处理绘制地图单元格
%macro DRAW_CELL 2
	cmp rax, %2
	je .%1
%endmacro

; 函数名：draw_cell
; 参数：
; - rax: 地图单元格类型
; 绘制地图单元格
draw_cell:
	; 根据地图单元格类型跳转到对应的标签中
	DRAW_CELL wall,	MAP_WALL
	DRAW_CELL head,	MAP_HEAD
	DRAW_CELL body,	MAP_BODY
	DRAW_CELL apple, MAP_APPLE

	jmp .free

	.free:
		DRAW_CELL
		jmp .exit

	.wall:
		DRAW_COLOR_CELL bright_gray
		jmp .exit

	.head:
		DRAW_COLOR_CELL blue
		jmp .exit

	.body:
		DRAW_COLOR_CELL miku
		jmp .exit

	.apple:
		DRAW_COLOR_CELL bright_red
		jmp .exit

	.exit:
		ret
; 函数名：draw_map
; 绘制地图
draw_map:
	push rbx
	push r11

	mov bh, 0          ; x计数器
	mov bl, 0          ; y计数器
	mov r11, 0         ; map单元格索引

	.loop_y:
		.loop_x:
			mov rax, 0
			mov al, [map+r11]
			call draw_cell   ; 绘制单元格

			inc r11          ; 增加map索引

			inc bh           ; 增加x计数器
			cmp bh, SIZE_X   ; 比较x计数器和SIZE_X
			jne .loop_x      ; 如果不相等，跳转到.loop_x

		PRINT_BUF_APPEND newline    ; 添加换行符到打印缓冲区

		mov bh, 0          ; 重置x计数器

		inc bl             ; 增加y计数器
		cmp bl, SIZE_Y     ; 比较y计数器和SIZE_Y
		jne .loop_y        ; 如果不相等，跳转到.loop_y

	PRINT_BUF_APPEND text_score   ; 添加text_score到打印缓冲区

	call print_term_buf           ; 调用print_term_buf输出打印缓冲区内容

	mov rax, [score]
	call print_num                ; 调用print_num打印得分
	PRINT_NEW_LINE


	pop r11
	pop rbx
	ret

; 函数名：clear_screen
; 清屏
clear_screen:
	PRINT_BUF_APPEND cur_reset_seq
	ret
; 宏定义处理蛇移动
%macro MOVE_SNAKE 2
	cmp al ,%2
	je .%1
%endmacro
; 函数名：move_snake
; 蛇移动
move_snake:
	mov al, [future_move_dir] ; 获取蛇下一帧移动方向
	mov [move_dir], al				; 更新蛇移动方向

	; 根据蛇移动方向跳转到对应的标签中
	MOVE_SNAKE right, DIR_RIGHT
	MOVE_SNAKE down,  DIR_DOWN
	MOVE_SNAKE left,  DIR_LEFT
	MOVE_SNAKE up,    DIR_UP

	.right:
		inc qword [snake_x]
		jmp .exit

	.down:
		inc qword [snake_y]
		jmp .exit

	.left:
		dec qword [snake_x]
		jmp .exit

	.up:
		dec qword [snake_y]
		jmp .exit

	.exit:
		mov rax, [snake_x]			; 获取蛇头x坐标
		mov rdx, [snake_y]			; 获取蛇头y坐标
		call map_coord_to_index ; 将蛇头坐标转换为地图索引
		call update_state       ; 更新游戏状态
		call update_map_snake   ; 更新地图蛇

		ret

; 函数名：update_map_snake
; 更新地图蛇
update_map_snake:
	mov rcx, [length]         ; 获取蛇长度

	push qword [snake_cells_buf+rcx*8-8]	; 保存尾部在蛇身数组中的索引位置

	.loop:
		dec rcx
		cmp rcx, 0
		je .loop_exit

		; 从蛇尾开始，依次后移其在蛇身数组中的位置
		mov rax, [snake_cells_buf+rcx*8-8]
		mov [snake_cells_buf+rcx*8], rax

		; 设置地图单元格类型为蛇身（仍是原蛇尾至蛇头的位置）
		mov byte [map+rax], MAP_BODY

		jmp .loop
	; 退出loop时，rax保存的是蛇头在蛇身数组中的索引位置

	.loop_exit:
		mov rcx, [length]
		;获取蛇头位置
		mov rax, [snake_x]
		mov rdx, [snake_y]
		call map_coord_to_index	

		; 重新设置蛇头
		mov [snake_cells_buf], rax  	;将蛇头位置保存到蛇身数组中的第一个位置
		mov byte [map+rax], MAP_HEAD  ;设置地图单元格类型为蛇头

		; 恢复尾部位置
		pop rax

		; 检查是否需要增长蛇身
		cmp qword [eaten], 0
		jg .grow

		; 标记原蛇尾位置为空白单元格类型
		mov byte [map+rax], MAP_FREE
		jmp .exit

	.grow:
		mov byte [map+rax], MAP_BODY     ; 标记原蛇尾位置为蛇身
		mov [snake_cells_buf+rcx*8], rax ; 将原蛇尾位置保存到蛇身数组中的最后一个位置

		dec qword [eaten]
		inc qword [length]

	.exit:
		ret

; 宏定义更新游戏状态
%macro UPDATE_STATE 2
	cmp dl, %2
	je .%1
%endmacro
; 函数名：update_state
; 参数：
; - rax：地图索引
; 更新游戏状态，判断到了何种单元格
update_state:
	mov dl, [map+rax] ; 获取地图单元格类型

	; 根据地图单元格类型跳转到对应的标签中
	UPDATE_STATE die, MAP_WALL
	UPDATE_STATE die, MAP_BODY
	UPDATE_STATE grow, MAP_APPLE
	UPDATE_STATE free, MAP_FREE
	jmp .exit

	.die:
		mov byte [status], STATUS_DIE
		jmp .exit
	.free:
		cmp byte [status], STATUS_FUN
		jne .exit						  ; 如果没有开启狂欢模式，直接退出
		call place_apple   		; 否则放置新苹果
		jmp .exit            
	.grow:
		inc qword [eaten]
		inc qword [score]
		call place_apple            ; 放置新苹果
		;创建子进程播放coin音效
		call fork
		cmp rax,0
		jne .exit
		mov rax,play
		mov rdx,argv2
		call exec
		
		; jmp .exit
	.exit:
		ret
; 函数名：update
; 更新游戏状态
update:
	call move_snake      ; 更新蛇
	call clear_screen    ; 清屏
	call draw_map        ; 绘制地图

	inc qword [frame]    ; 帧数加1

	ret
; 函数名：get_free_cells
; 获取地图中的空闲单元格
; 其索引保存到空闲单元格缓冲区 map_free_buf 中
; 空闲单元格的数量保存到 map_free_buf_len 中
get_free_cells:
	mov rcx, 0 					          ; 准备递增用于遍历map
	mov [map_free_buf_len], rcx		; 初始化空闲单元格缓冲区的长度为0

	.loop:
		cmp byte [map+rcx], MAP_FREE		; 判断当前单元格是否为一个空闲单元格
		jne .loop_inc				            ; 如果不是空闲单元格，则跳转到.loop_inc标签，继续循环

		mov rax, [map_free_buf_len]		  ; rax记录目前空闲单元格缓冲区的长度
		mov [map_free_buf+rax*8], rcx		; 将当前空闲单元格的索引rcx追加到空闲单元格缓冲区的末尾
		inc qword [map_free_buf_len]		; 将空闲单元格缓冲区的长度增加1

	.loop_inc:
		inc rcx											
		cmp rcx, SIZE_N							; 判断是否遍历完所有单元格
		jne .loop										; 继续循环

	ret							

; 函数名：place_apple
; 在地图的空白单元格中随机选择一个单元格，将其标记为苹果
place_apple:
	call get_free_cells			      ; 调用get_free_cells函数获取空闲单元格
	mov rax, [map_free_buf_len] 	; 获取空闲单元格的数量

	cmp rax, 0										; 如果空闲单元格的数量为0，则结束
	je .exit					

	call rand											; 否则，调用rand函数生成一个随机数 -> rax
	mov rdx, [map_free_buf+rax*8] ; 将随机选择的空闲单元格的索引存储在rdx中
	mov byte [map+rdx], MAP_APPLE	; 将地图上该索引位置的单元格标记为苹果

.exit:
	ret							

; 函数名：run
; 游戏运行循环
run:
	push rbx					
	mov rbx, 0	            ; 移动间隔计数器 rbx

	.loop:
		mov rax, input				; 获取输入的缓冲区
		mov rdx, 1					  
		
		call poll					    ; 调用poll函数获取用户输入

		call handle_key				; 处理用户按键

		cmp byte [status], STATUS_EXIT		; 判断是否退出
		je .exit					               

		cmp byte [status], STATUS_DIE		  ; 判断是否为死亡
		je .die						              

		;如果开启加速模式，则每次循环都更新游戏状态
		cmp byte [is_speed_up], 0
		je .normal_speed
		cmp rbx, MOVE_SPEED_TICK					; 判断是否达到加速模式的移动间隔
		je .update
		.normal_speed:
		cmp rbx, MOVE_EVERY_TICK			    ; 判断是否达到规定的移动间隔
		je .update

							              

		inc rbx						                ; rbx++

		mov rax, UPD_DEL_SEC							; 设置睡眠的秒数
		mov rdx, UPD_DEL_NANO							; 设置睡眠的纳秒数
		call sleep												; 调用sleep函数制造帧与帧之间的间隔

		jmp .loop					                ; 继续循环

	.update:
		call update											  ; 调用update函数更新游戏状态
		mov rbx, 0					              ; 重置计数器rbx
		jmp .loop					                ; 继续循环

	.die:
		PRINT_STR_DATA text_game_over		  ; 打印游戏结束的提示信息

	.exit:
		pop rbx						
		ret						

; 函数名：init
; 初始化游戏
init:
	mov rax, [snake_x]				  
	mov rdx, [snake_y]				 
	call map_coord_to_index			      ; 获取蛇头位置的地图索引
	mov byte [map+rax], MAP_HEAD		  ; 将蛇头添加到地图
	mov qword [snake_cells_buf], rax	; 将蛇头的地图索引存储到snake_cells_buf缓冲区的第一个元素

	call place_apple					        ; 调用place_apple函数放置一个苹果

	mov qword [print_buf_len], 0		  ; 将打印缓冲区的长度设置为0，初始化为空

	call set_noncanon					        ; 调用set_noncanon函数设置终端为非规范模式

	PRINT_BUF_APPEND cur_home_seq		  ; 光标移动到左上角
	PRINT_BUF_APPEND clear_seq			  ; 清屏
	PRINT_BUF_APPEND text_controls	  ; 打印提示信息
	PRINT_BUF_APPEND cur_hide_seq		  ; 隐藏光标

	ret								

; 函数名：shutdown
; 游戏结束
shutdown:
	PRINT_STR_DATA cur_show_seq
	call set_canon
	ret

; 入口点
MAIN:
	; 创建子进程
	call fork
	cmp rax, 0
	je .child
.parent:
	; 父进程运行游戏
	mov [child_pid],rax ; store d
	call init
	call draw_map
	call run
	call shutdown
	mov rax, [child_pid]
	call kill
	mov rax, 0
	call exit
.child:
	; 子进程播放音乐
	mov rax, play 
	mov rdx, argv 
	call exec

