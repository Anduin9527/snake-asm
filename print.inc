%ifndef PRINT_INC 
%define PRINT_INC
;宏定义字符串
%macro DEF_STR_DATA 2+ 
	%1 db %2 				; name db value
	%1_len equ $-%1 ; 定义一个以 _len 为后缀的符号，表示该字符串的长度
%endmacro
; 宏定义打印字符串
%macro PRINT_STR_DATA 1 
	mov rax, %1 		; 将字符串的地址存入 rax 寄存器
	mov rdx, %1_len ; 将对应的字符串长度存入 rdx 寄存器
	call print 			; 调用 print 函数来打印字符串
%endmacro
; 宏定义换行
%macro PRINT_NEW_LINE 0 	
	PRINT_STR_DATA newline  
%endmacro

%endif 
