%include "print.mac"
%include "syscall.inc"

%define READ      0  ; 函数原型：ssize_t read(int fd, void *buf, size_t count);
%define WRITE     1  ; 函数原型：ssize_t write(int fd, const void *buf, size_t count);
%define POLL      7  ; 函数原型：int poll(struct pollfd *fds, nfds_t nfds, int timeout);
%define IOCTL     16 ; 函数原型：int ioctl(int fd, unsigned long request, ...);
%define NANOSLEEP 35 ; 函数原型：int nanosleep(const struct timespec *req, struct timespec *rem);
%define EXEC      59 ; 函数原型：int execve(const char *filename, char *const argv[], char *const envp[]);
%define FORK      57 ; 函数原型：pid_t fork(void);
%define EXIT      60 ; 函数原型：void exit(int status);
%define KILL      62 ; 函数原型：int kill(pid_t pid, int sig);

; rax: syscall number
; 封装系统调用syscall
%macro SYS 1
	mov rax, %1
	syscall
	test rax, rax
	js syscall_err
%endmacro

section .data

sleep_tv:		 ; sleep_tv 结构体
	.sec  dq 0 ; sleep 秒数
	.usec dq 0 ; sleep 纳秒数

section .text

global sleep

; 函数名: sleep
; 参数:
;   - rax: 秒数
;   - rdx: 纳秒数
; 用于程序休眠
sleep:
	push rdi
	push rsi
	; 将秒数和纳秒数存储在 sleep_tv 结构体中
	mov qword [sleep_tv.sec], rax
	mov qword [sleep_tv.usec], rdx
	mov rdi, sleep_tv ; sleep_tv 结构体的指针
	mov rsi, 0        ; 不需要返回剩余时间
	SYS NANOSLEEP     ; int nanosleep(const struct timespec *req, struct timespec *rem);

	pop rsi
	pop rdi
	ret

global ioctl

%define TCGETS 21505 ; get 获取终端属性的宏值
%define TCPUTS 21506 ; put 设置终端属性的宏值


; 函数名: ioctl
; 参数:
;   - rax: termios 结构体指针
;   - rdx: 0(TCGETS) or 1(TCPUTS)
; 用于获取或设置终端属性
ioctl:
	push rdi
	push rsi

	add rdx, TCGETS 			; 将参数 rdx 加上 TCGETS 宏值，以判断本次调用是获取还是设置终端属性
	mov rsi, rdx					; get or put
	mov rdx, rax          ; termios 结构体指针
	mov rdi, STDIN			  ; fd=0, 标准输入STDIN
	SYS IOCTL							; int ioctl(int fd, unsigned long request, ...);

	pop rsi
	pop rdi
	ret

global exit
; 函数名: exit
; 参数:
;  - rax: 退出码
; 用于退出程序并返回退出码
exit:
	mov rdi, rax          
	mov rax, EXIT
	syscall
	ret

section .data

; poll 结构体
poll_fd:
	dd STDIN ; fd 需要被检测或选择的文件描述符，此处设置为标准输入
	dw 1     ; events  表示想要等待的事件，此处设置为 POLLIN，表示有数据可读
	dw 0     ; revents 表示实际发生的事件，此处设置为 0，表示没有事件发生

section .text

global poll

; 函数名：poll
; 参数：
; - rax: buffer
; - rdx: count
; 用于轮询事件 
poll:
    push rdi
    push rsi

    push rax     ; 保存 buffer
    push rdx     ; 保存 count

    ; 调用系统调用 POLL 进行事件轮询
    mov rdi, poll_fd   ; 结构体指针
    mov rsi, 1         ; 监视的文件描述符数量
    mov rdx, 0         ; 超时时间设为0，表示立即返回不阻塞
    SYS POLL					 ; int poll(struct pollfd *fds, nfds_t nfds, int timeout);
    mov rsi, rax       ; 将返回值存储在 rsi 中，检查是否有事件发生
		;成功时，返回文件描述符个数
		;如果在超时前没有任何事件发生，poll()返回0

		;恢复参数
    pop rdx           
    pop rax           

    test rsi, rsi      ; 检查 rsi 是否为零，即是否没有事件发生
    jz .no_event       ; 若没有事件发生，则跳转到 .no_event 

    ; 有事件发生，调用 read 函数读取输入
    call read

    jmp .exit          ; 跳转到 .exit 标签处

.no_event:
    ; 将 buffer 的第一个字节设为 -1，表示没有事件发生
    mov byte [rax], -1

.exit:
    pop rsi
    pop rdi
    ret

global write

; 函数名: write
; 参数:
;   - rax: 指向字符串的指针
;   - rdx: 字符串长度
;   - rcx: 文件描述符
; 用于向fd写入字符串
write:
	push rdi
	push rsi

	mov rsi, rax ; 将字符串指针存储到 rsi 寄存器中
	mov rdi, rcx ; 将文件描述符存储到 rdi 寄存器中
	SYS WRITE     ; 调用系统调用函数 WRITE

	pop rsi
	pop rdi
	ret

global read

; 函数名: read
; 参数:
;   - rax: 缓冲区指针
;   - rdx: 读取的字节数
; 用于从标准输入读取数据
read:
	push rdi
	push rsi

	mov rsi, rax    ; 将缓冲区指针存储到 rsi 寄存器中
	mov rdi, STDIN  ; 将标准输入文件描述符存储到 rdi 寄存器中

	.loop:
		SYS READ    ; 调用系统调用函数 READ

		; 如果到达文件末尾，则退出循环
		test rax, rax
		je .exit

		; 如果已读取的字节数等于请求的字节数，则退出循环
		cmp rax, rdx
		je .exit

		; 如果读取的字节数少于请求的字节数，则重复进行系统调用
		sub rdx, rax
		jmp .loop

	.exit:
		pop rsi
		pop rdi
		ret

global exec
; 函数名: exec
; 参数:
;   - rax: 可执行文件路径字符串指针filename（以0结尾）
;   - rdx: filename, arg1, arg2...,（以0结尾）
; 注意：
;   - rdx 的值为指针数组，类型为 dq ，每个元素都是字符串指针，以0结尾
; 用于执行命令
exec:
	push rdi
	push rsi

	mov rsi, rdx ; 将参数字符串指针存储到 rsi 寄存器中
	mov rdi, rax ; 将可执行文件路径字符串指针存储到 rdi 寄存器中
	mov rdx, 0   ; 将环境变量指针存储到 rdx 寄存器中

	SYS EXEC     ; 调用系统调用函数 EXEC

	pop rsi
	pop rdi
	ret
global fork 
; 函数名: fork
; 返回值: 
;   - rax: 如果当前进程是父进程，返回子进程的 PID
;          如果当前进程是子进程，返回值为 0
;          如果创建子进程失败，返回值小于 0
; 用于创建子进程
fork:
	SYS FORK     ; 调用系统调用函数 FORK
	ret
global kill
; 函数名: kill
; 参数:
;   - rax: 要终止的进程的 PID
; 用于终止进程
kill:
	mov rdi, rax 
	mov rsi, 9 ; SIGKILL
	SYS KILL   ; 调用系统调用函数 KILL
	ret


; 用于执行命令
section .data

DEF_STR_DATA text_syscall_err, "System call failed!", 10

section .text

; 函数名: syscall_err
syscall_err:
	mov rax, text_syscall_err       ; 存储错误提示字符串的地址到 rax 寄存器中
	mov rdx, text_syscall_err_len   ; 存储错误提示字符串的长度到 rdx 寄存器中
	mov rcx, STDERR                 ; 存储标准错误输出文件描述符到 rcx 寄存器中
	call write                      ; 调用 write 函数打印错误提示字符串
	call exit                       ; 调用 exit 函数退出程序
