%include "print.inc" 
%include "syscall.mac" 

section .data

DEF_STR_DATA newline, 10 ; 换行符ASCII 码（10）

section .bss 

print_num_buf resb 8 ; 打印数字的缓冲区
print_num_buf_end equ $ ; 表示缓冲区末尾

section .text 

global print 
global print_num 

global newline 
global newline_len 
; 函数名：print
; 参数：
; - rax：指向字符串的指针
; - rdx：字符串长度
; 调用write函数打印字符串到标准输出
print:
	mov rcx, STDOUT ; 将标准输出的文件描述符存入 rcx 寄存器
	call write      ; 调用 write 系统调用来写入字符串
	ret           

; 函数名：print_num
; 参数：
; - rax：要打印的数字
; 将数字转换为字符串并调用 print 函数打印到标准输出
print_num:
	push rbx ; 保存 rbx 寄存器的值
	push rsi ; 保存 rsi 寄存器的值

	mov rbx, 10 ; 用于 idiv 的除数
	mov rcx, 0 ; 用于记录数字的位数的计数器

	.loop:
		mov rdx, 0 ; 清零 rdx 寄存器
		idiv rbx ; 除法运算，商在 rax，余数在 rdx

		add dl, '0' ; 将余数转换为对应的 ASCII 字符码

		inc rcx ; 递增位数计数器
		mov rsi, print_num_buf_end ; 将缓冲区末尾地址保存到 rsi
		sub rsi, rcx ; 计算当前数字应存储的位置
		mov [rsi], dl ; 存储数字到缓冲区

		cmp rax, 0 ; 检查商是否为 0
		jne .loop ; 如果不为 0，则继续循环

	mov rax, print_num_buf_end ; 将结果存储在 rax 中
	sub rax, rcx ; 计算数字的起始位置
	mov rdx, rcx ; 将位数传递给 rdx
	call print ; 调用 print 函数打印结果

	pop rsi ; 恢复 rsi 寄存器的值
	pop rbx ; 恢复 rbx 寄存器的值
	ret ; 返回
