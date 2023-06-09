%include "print.mac"
%include "syscall.mac"

%define MAIN _start

%define MOVE_EVERY_TICK   2           ; 每 MOVE_EVERY_TICK 帧移动一次
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
; 定义按键
%define KEY_W 119
%define KEY_A 97
%define KEY_S 115
%define KEY_D 100
%define KEY_ESC 27

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
DEF_STR_DATA text_controls, "使用 WSAD 移动，使用 Q 退出游戏", 10
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

section .bss

map_free_buf resq SIZE_N 				; 定义地图缓冲区大小
map_free_buf_len resq 1					; 定义地图元素缓冲区大小

PRINT_BUFFER print_buf					; 定义打印缓冲区大小
print_buf_len resq 1						; 定义打印元素缓冲区大小

snake_cells_buf resq SIZE_N 		; 定义蛇身缓冲区大小

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
; 更新游戏状态
update_state:
	mov dl, [map+rax] ; 获取地图单元格类型

	; 根据地图单元格类型跳转到对应的标签中
	UPDATE_STATE die, MAP_WALL
	UPDATE_STATE die, MAP_BODY
	UPDATE_STATE grow, MAP_APPLE
	; UPDATE_STATE free, MAP_FREE ;狂欢模式
	jmp .exit

	.die:
		mov byte [status], STATUS_DIE
		jmp .exit
	.free:
		call place_apple
		jmp .exit
	.grow:
		inc qword [eaten]
		inc qword [score]
		call place_apple
		jmp .exit

	.exit:
		ret

update:
	call move_snake
	call clear_screen
	call draw_map

	inc qword [frame]

	ret

get_free_cells:
	mov rcx, 0 ; counter
	mov [map_free_buf_len], rcx

	.loop:
		cmp byte [map+rcx], MAP_FREE
		jne .loop_inc

		mov rax, [map_free_buf_len]
		mov [map_free_buf+rax*8], rcx
		inc qword [map_free_buf_len]

	.loop_inc:
		inc rcx
		cmp rcx, SIZE_N
		jne .loop

	ret

place_apple:
	call get_free_cells

	; amount of free cells
	mov rax, [map_free_buf_len]

	cmp rax, 0
	je .exit

	; stores rand num from 0 to rax in rax
	call rand

	mov rdx, [map_free_buf+rax*8]

	mov byte [map+rdx], MAP_APPLE

	.exit:
		ret

run:
	push rbx

	; update count
	mov rbx, 0

	.loop:
		mov rax, input
		mov rdx, 1
		call poll

		call handle_key

		cmp byte [status], STATUS_EXIT
		je .exit

		cmp byte [status], STATUS_DIE
		je .die

		cmp rbx, MOVE_EVERY_TICK
		je .update

		inc rbx

		mov rax, UPD_DEL_SEC
		mov rdx, UPD_DEL_NANO
		call sleep

		jmp .loop

	.update:
		call update
		mov rbx, 0
		jmp .loop

	.die:
		PRINT_STR_DATA text_game_over

	.exit:
		pop rbx
		ret

init:
	mov rax, [snake_x]
	mov rdx, [snake_y]
	call map_coord_to_index ;snake pos in rax

	; add snake to map
	mov byte [map+rax], MAP_HEAD

	; init snake_cells_buf
	mov qword [snake_cells_buf], rax

	; add first apple
	call place_apple

	; init print buffer
	mov qword [print_buf_len], 0

	call set_noncanon

	PRINT_BUF_APPEND cur_home_seq
	PRINT_BUF_APPEND clear_seq
	PRINT_BUF_APPEND text_controls
	PRINT_BUF_APPEND cur_hide_seq

	ret

shutdown:
	PRINT_STR_DATA cur_show_seq
	call set_canon
	ret

MAIN:
	call init

	call draw_map

	call run

	call shutdown

	mov rax, 0
	call exit

; vim:ft=nasm
