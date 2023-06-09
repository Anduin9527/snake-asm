;将终端的行为从规范模式(non-canonical mode)切换到规范模式(canonical mode)或者从规范模式切换到非规范模式
; 引入系统调用库
%include "syscall.mac"

; 定义两个常量
%define ICANON (1<<1) ; 规范模式的标志
%define ECHO   (1<<3) ; 回显模式的标志

section .bss
; 定义两个 termios 结构体
stty resb termios_s_size ; 用于存储旧的 termios 结构体
tty  resb termios_s_size ; 用于存储新的 termios 结构体

section .text
global set_noncanon
;用于将终端从规范模式切换到非规范模式
set_noncanon:
	; 存储旧的 termios 结构体
	mov rax, stty ; 将 stty 的地址存储在 rax 中
	mov rdx, 0   ; 将 rdx 设置为 0，表示从内核中获取 termios
	call ioctl   ; 调用 ioctl 函数，将 termios 存储在 stty 中

	; 存储新的 termios 结构体
	mov rax, tty ; 将 tty 的地址存储在 rax 中
	mov rdx, 0   ; 将 rdx 设置为 0，表示从内核中获取 termios
	call ioctl   ; 调用 ioctl 函数，将 termios 存储在 tty 中

	; 将 icanon 和 echo 标志位清除
	and dword [tty+termios_s.flags], (~ICANON) ; 清除 icanon 标志位
	and dword [tty+termios_s.flags], (~ECHO)   ; 清除 echo 标志位

	; 设置终端属性
	mov rax, tty ; 将 tty 的地址存储在 rax 中
	mov rdx, 1   ; 将 rdx 设置为 1，表示将新的 termios 写入内核
	call ioctl   ; 调用 ioctl 函数，将新的 termios 写入内核
	ret          ; 返回


global set_canon
;用于将终端从非规范模式切换到规范模式
set_canon:
	; 从旧的 termios 结构体中恢复终端属性
	mov rax, stty ; 将 stty 的地址存储
	mov rdx, 1
	call ioctl
	ret

