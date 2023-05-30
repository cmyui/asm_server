[bits 64]

; a socket server implementation in pure (nasm) assembly; for learning purposes
; if you notice anything that can be improved, please let me know!
; github issues / cmyui#0425 / cmyuiosu@gmail.com

; types
; byte  = 1 byte  (suffix b)
; word  = 2 bytes (suffix w)
; dword = 4 bytes (suffix l)
; qword = 8 bytes (suffix q)

; x86-64 system v amd64 abi calling convention
; https://en.wikipedia.org/wiki/X86_calling_conventions#System_V_AMD64_ABI
; rdi, rsi, rdx, rcx, r8, r9
; return into rax(:rdx)

; syscall calling convention
; syscall number | args
; rax | rdi, rsi, rdx, r10, r8, r9

; TODO: error handling (-1 - -4096)

%include "http.asm"

section .bss

section .data
    connection_data times 4096 db 0  ; 4k
    socket_file db "/tmp/asmsocket.sock", 0

section .rodata
    ; constants
    NULL equ 0

    SOCK_STREAM equ 1

    SOL_SOCKET equ 1

    SO_REUSEADDR equ 2
    SO_REUSEPORT equ 15

    AF_UNIX equ 1
    AF_INET equ 2

    PROT_READ equ 1
    PROT_WRITE equ 2

    MAP_PRIVATE equ 2
    MAP_ANONYMOUS equ 32

    PAGE_SIZE equ 4096 ; 4k

    SERVER_ADDR equ dword 0x00000000 ; 0.0.0.0
    SERVER_PORT equ word 0x8913 ; htons(5001)

    ; standard stream fds
    stdin equ 0
    stdout equ 1
    stderr equ 2

    ; syscall numbers
    sys_read equ 0
    sys_write equ 1
    sys_open equ 2
    sys_close equ 3
    sys_mmap equ 9
    sys_mprotect equ 10
    sys_munmap equ 11
    sys_socket equ 41
    sys_accept equ 43
    sys_recvfrom equ 45
    sys_bind equ 49
    sys_listen equ 50
    sys_setsockopt equ 54
    sys_exit equ 60

    ; create sockaddr_in_t class
    struc sockaddr_in_t
        .sin_family: resw 1
        .sin_port: resw 1
        .sin_addr: resd 1
        .sin_zero: resb 8
    endstruc

    ; create sockaddr_in_t instance
    sockaddr_in istruc sockaddr_in_t
        at sockaddr_in_t.sin_family, dw AF_INET
        at sockaddr_in_t.sin_port, dw SERVER_PORT
        at sockaddr_in_t.sin_addr, dd SERVER_ADDR
        at sockaddr_in_t.sin_zero, times 8 db 0
    iend

    ; create sockaddr_un_t class
    struc sockaddr_un_t
        .sun_family: resw 1
        .sun_path: resb 128
    endstruc

    ; create sockaddr_un_t unstance
    sockaddr_un istruc sockaddr_un_t
        at sockaddr_un_t.sun_family, dw AF_UNIX
        at sockaddr_un_t.sun_path, times 128 db 0
    iend

    ; create headers_t class
    struc server_t
        .listening_fd: resd 1
        .connecting_fd: resd 1
    endstruc

    ; create server_t instance
    server istruc server_t
        at server_t.listening_fd, dd 0
        at server_t.connecting_fd, dd 0
    iend

    ; create headers_t class
    struc headers_t
        .content_length: resq 1
        .content_type: resq 1
        .connection: resq 1
        .host: resq 1
        .user_agent: resq 1
        .osu_token: resq 1
    endstruc

    ; create headers instance
    headers istruc headers_t
        at headers_t.content_length, dq 0
        at headers_t.content_type, dq 0
        at headers_t.connection, dq 0
        at headers_t.host, dq 0
        at headers_t.user_agent, dq 0
        at headers_t.osu_token, dq 0
    iend

    ; create request_t class
    struc request_t
        .http_method: resq 1
        .http_path: resq 1
        .http_version: resq 1
    endstruc

    ; create request instance
    request istruc request_t
        at request_t.http_method, dq 0
        at request_t.http_path, dq 0
        at request_t.http_version, dq 0
    iend

section .text
    global _start

_start:

_socket:
    ; sys_socket(AF_INET, SOCK_STREAM, 0)
    mov rax, sys_socket
    mov rdi, AF_UNIX
    mov rsi, SOCK_STREAM
    mov rdx, 0
    syscall

    cmp rax, 0
    jl _exit_fail

    ; save listening socket fd
    mov qword [server + server_t.listening_fd], rax

; _setsockopt:
;     ; sys_setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &optval, optlen)
;     mov rax, sys_setsockopt
;     mov rdi, [server + server_t.listening_fd]
;     mov rsi, SOL_SOCKET
;     mov rdx, SO_REUSEPORT
;     mov rcx, 1
;     mov r8, 8
;     syscall

;     cmp rax, 0
;     jl _exit_fail

_bind:
    ; sys_bind(fd, &sockaddr_un, addrlen)
    mov rax, sys_bind
    mov rdi, [server + server_t.listening_fd]
    mov rsi, sockaddr_un
    mov rdx, 16 ; TODO: dynamically set struct size
    syscall

    cmp rax, 0
    jl _exit_fail

_listen:
    ; sys_listen(fd, backlog)
    mov rax, sys_listen
    mov rdi, [server + server_t.listening_fd]
    mov rsi, 5
    syscall

    cmp rax, 0
    jl _exit_fail

_accept:
    ; sys_accept(fd, &peer_sockaddr, peer_addrlen)
    mov rax, sys_accept
    mov rdi, [server + server_t.listening_fd]
    mov rsi, 0
    mov rdx, 0
    syscall

    cmp rax, 0
    jl _exit_fail

    ; save peer socket fd
    mov [server + server_t.connecting_fd], rax

_recv:
    ; sys_recv(rax, connection_data, 4096, 0)
    ; https://man7.org/linux/man-pages/man2/recv.2.html
    mov rax, sys_recvfrom
    mov rdi, [server + server_t.connecting_fd]
    mov rsi, connection_data
    mov rdx, 4096
    mov r10, 0
    mov r8, 0
    mov r9, 0
    syscall

    call _parse_http_request

_program_finalization:
    ; exit with code 0
    mov rdi, 0
    jmp short _exit

_close_listening_socket:
    ; sys_close(fd)
    mov rax, sys_close
    mov rdi, [server + server_t.listening_fd]
    syscall

    mov qword [server + server_t.listening_fd], 0

    cmp rax, 0
    jg _exit

_exit_fail:
    mov rdi, 1
_exit:
    ; close socket if it's open
    cmp byte [server + server_t.connecting_fd], 0
    jne _close_listening_socket

    ; sys_exit(0)
    mov rax, sys_exit
    syscall
