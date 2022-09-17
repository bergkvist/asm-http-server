; Target architecture
cpu X64
bits 64
; Syscall numbers for Linux x86-64 (call order: rdi, rsi, rdx, r10, r8, r9)
%define sys_write       1 ; int write(unsigned int fd, const char *buf, size_t count);
%define sys_close       3 ; int close(unsigned int fd);
%define sys_socket     41 ; int socket(int family, int type, int protocol);
%define sys_accept     43 ; int accept(int fd, struct sockaddr *upeer_sockadd, int *upeer_addrlen);
%define sys_bind       49 ; int bind(int fd, struct sokaddr *umyaddr, int addrlen);
%define sys_listen     50 ; int listen(int fd, int backlog);
%define sys_setsockopt 54 ; int setsockopt(int fd, int level, int optname, char *optval, int optlen);
%define sys_exit       60 ; int exit(int error_code);

; Various constants
%define STDOUT_FILENO   1
%define AF_INET         2
%define SOCK_STREAM     1
%define IPPROTO_IP      0
%define SOL_SOCKET      1
%define SO_REUSEADDR    2


section .data
so_reuseaddr: dd 1 ; socket options: allow address reuse
so_reuseaddr.length equ $ - so_reuseaddr

sockaddr_in:
sockaddr_in.family:  dw AF_INET              ; AF_INET
sockaddr_in.port:    db 0x1f,0x40            ; 8000
sockaddr_in.host:    db 0x7f,0x00,0x00,0x01  ; 127.0.0.1
sockaddr_in.padding: dq 0                    ; 8 bytes padding
sockaddr_in.length   equ $ - sockaddr_in

listening_msg:       db 'Listening on 127.0.0.1:8000',10
listening_msg.length equ $ - listening_msg

http_msg: db 'HTTP/1.1 200 OK', 10, 'Content-Length: 12', 10, 10, 'Hello world!', 10
http_msg.length equ $ - http_msg


section .text
global _start
_start:
  ; itn sock = socket(AF_INET, SOCK_STREAM, IPPROTO_IP);
  mov rax, sys_socket
  mov rdi, AF_INET      ; family
  mov rsi, SOCK_STREAM  ; type
  mov rdx, IPPROTO_IP   ; protocol
  syscall
  cmp rax, -4095 ; Check if socket failed
  jae .error
  mov r12, rax ; store socket file descriptor
  
  ; setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, so_reuseaddr, so_reuseaddr.length);
  mov rax, sys_setsockopt
  mov rdi, r12           ; socket file descriptor
  mov rsi, SOL_SOCKET    ; level
  mov rdx, SO_REUSEADDR  ; optname
  mov r10, so_reuseaddr
  mov r8 , so_reuseaddr.length 
  syscall
  cmp rax, -4095  ; Check if setsockopt failed
  jae .error

  ; bind(sock, sockaddr_in, sockaddr_in.length);
  mov rax, sys_bind
  mov rdi, r12    ; socket file descriptor
  mov rsi, sockaddr_in
  mov rdx, sockaddr_in.length
  syscall
  cmp rax, -4095  ; Check if bind failed
  jae .error

  ; listen(sock, backlog=10);
  mov rax, sys_listen
  mov rdi, r12    ; socket file descriptor
  mov rsi, 10     ; max size for connection backlog
  syscall
  cmp rax, -4095  ; Check if listen failed
  jae .error

  ; print listening message
  mov rax, sys_write
  mov rdi, STDOUT_FILENO
  mov rsi, listening_msg
  mov rdx, listening_msg.length
  syscall

.accept_loop:
  ; int accepted_sock = accept(sock, NULL, NULL);
  mov rax, sys_accept
  mov rdi, r12    ; socket file descriptor
  mov rsi, 0
  mov rdx, 0
  syscall
  cmp rax, -4095  ; Check if accept failed
  jae .error
  mov r13, rax    ; client socket

  ; write(accepted_sock, http_msg, http_message.length);
  mov rax, sys_write
  mov rdi, r13  ; accepted_sock
  mov rsi, http_msg
  mov rdx, http_msg.length
  syscall

  ; close(accepted_sock);
  mov rax, sys_close
  mov rdi, r13  ; accepted_sock
  syscall

  jmp .accept_loop

.error:
  sub rdi, rax
  mov rax, sys_exit
  syscall