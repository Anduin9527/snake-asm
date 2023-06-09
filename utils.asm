section .text

global memcpy
global rand

; rax: destination
; rdx: source
; rcx: size
; 将rdx开始的rcx个字节复制到rax开始的rcx个字节
memcpy:
	mov rsi, rdx
	mov rdi, rax

	cld ; 清除方向标志位，使得rep指令从低地址向高地址复制
	rep movsb ; 将rsi开始的rcx个字节复制到rdi开始的rcx个字节
	ret

; rax: max
; returns: random num in rax
; 生成一个不大于rax的随机数
rand:
	mov rcx, rax 
	rdrand rax ; rdrand指令将随机数放入rax中

	mov rdx, 0
	div rcx   ; rdx:rax / rcx = rax ... rdx
	mov rax, rdx 
	ret

