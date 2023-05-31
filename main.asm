[bits 64]

; a socket server implementation in pure (nasm) assembly; for learning purposes
; i am very much a noob at assembly - if you notice anything that can be improved, please let me know!
; github issues / cmyui#0425 / cmyuiosu@gmail.com

; types
; db | resb = byte (1 byte)
; dw | resw = word (2 bytes)
; dd | resd = dword (4 bytes)
; dq | resq = qword (8 bytes)

; x86-64 system v amd64 abi calling convention
; https://en.wikipedia.org/wiki/X86_calling_conventions#System_V_AMD64_ABI
; rdi, rsi, rdx, rcx, r8, r9
; return into rax(:rdx)

; syscall calling convention
; syscall number | args
; rax | rdi, rsi, rdx, r10, r8, r9

; TODO: dynamic memory allocation

section .rodata
    socket_file db "/tmp/asm_server.sock", 0
    socket_file_len equ $ - socket_file

    content_length_header_key db "Content-Length", 0
    content_type_header_key db "Content-Type", 0
    connection_header_key db "Connection", 0
    host_header_key db "Host", 0
    user_agent_header_key db "User-Agent", 0
    osu_token_header_key db "osu-token", 0

    new_line db 0xa

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
    SERVER_PORT equ word 0x1027 ; htons(10000)

    ; standard stream fds
    stdin equ 0
    stdout equ 1
    stderr equ 2

    ; syscall numbers
    sys_read equ 0
    sys_write equ 1
    sys_open equ 2
    sys_close equ 3
    sys_stat equ 4
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
    sys_unlink equ 87
    sys_chmod equ 90

    ; create sockaddr_in_t class
    struc sockaddr_in_t
        .sin_family: resw 1
        .sin_port: resw 1
        .sin_addr: resd 1
        .sin_zero: resb 8
    endstruc

    ; create sockaddr_un_t class
    struc sockaddr_un_t
        .sun_family: resw 1
        .sun_path: resb 108
    endstruc

    ; create headers_t class
    struc server_t
        .listening_fd: resd 1
        .connecting_fd: resd 1
    endstruc

    ; create headers_t class
    struc headers_t
        .content_length: resq 1
        .content_type: resq 1
        .connection: resq 1
        .host: resq 1
        .user_agent: resq 1
        .osu_token: resq 1
    endstruc

    ; create request_t class
    struc request_t
        .http_method: resq 1
        .http_path: resq 1
        .http_version: resq 1
    endstruc

section .data
    connection_data times 4096 db 0

    current_header_key times 512 db 0
    current_header_value times 512 db 0

    ; create sockaddr_in_t instance
    sockaddr_in istruc sockaddr_in_t
        at sockaddr_in_t.sin_family, dw AF_INET
        at sockaddr_in_t.sin_port, dw SERVER_PORT
        at sockaddr_in_t.sin_addr, dd SERVER_ADDR
        at sockaddr_in_t.sin_zero, times 8 db 0
    iend

    ; create sockaddr_un_t instance
    sockaddr_un istruc sockaddr_un_t
        at sockaddr_un_t.sun_family, dw AF_UNIX
        at sockaddr_un_t.sun_path, dq 0
    iend

    ; create server_t instance
    server istruc server_t
        at server_t.listening_fd, dd 0
        at server_t.connecting_fd, dd 0
    iend

    ; create headers instance
    headers istruc headers_t
        at headers_t.content_length, dq 0
        at headers_t.content_type, dq 0
        at headers_t.connection, dq 0
        at headers_t.host, dq 0
        at headers_t.user_agent, dq 0
        at headers_t.osu_token, dq 0
    iend

    ; create request instance
    request istruc request_t
        at request_t.http_method, dq 0
        at request_t.http_path, dq 0
        at request_t.http_version, dq 0
    iend

section .text
    global _start

; %include "exit.asm"
%include "http.asm"
%include "server.asm"

_start:
    call _start_server
