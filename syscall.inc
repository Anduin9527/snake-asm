%ifndef SYSCALL_INC
%define SYSCALL_INC

%define STDIN  0
%define STDOUT 1
%define STDERR 2

struc termios_s ; 定义结构体termios
	resb 12
	.flags: resb 12 ; flags
	resb 44
endstruc

%endif
