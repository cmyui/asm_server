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

%include "http.asm"

_start:

_socket:
    ; sys_socket(AF_UNIX, SOCK_STREAM, 0)
    mov rax, sys_socket
    mov rdi, AF_UNIX
    mov rsi, SOCK_STREAM
    mov rdx, 0
    syscall

    cmp rax, 0
    jl _exit_fail

    ; save listening socket fd
    mov [server + server_t.listening_fd], eax

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
    ; delete socket file if it exists
    mov rax, sys_unlink
    mov rdi, socket_file
    syscall

    ; copy sockaddr_in to sockaddr_un
    mov rsi, socket_file
    lea rdi, [sockaddr_un + sockaddr_un_t.sun_path]
    mov rcx, socket_file_len
    cld
    rep movsb

    ; sys_bind(fd, &sockaddr_un, addrlen)
    mov rax, sys_bind
    mov rdi, [server + server_t.listening_fd]
    mov rsi, sockaddr_un
    mov rdx, sockaddr_un_t_size
    syscall

    cmp rax, 0
    jl _exit_fail

    ; give the socket file the correct permissions
    mov rax, sys_chmod
    mov rdi, socket_file
    mov rsi, 0o777
    syscall

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

_close_listening_socket:
    ; sys_close(fd)
    mov rax, sys_close
    mov rdi, [server + server_t.listening_fd]
    syscall

    mov qword [server + server_t.listening_fd], 0

_program_finalization:
    ; exit with code 0
    jmp _exit_success

_exit_success:
    xor rdi, rdi
    jmp _exit
_exit_fail:
    mov rdi, 1
_exit:
    ; close socket if it's open
    cmp byte [server + server_t.connecting_fd], 0
    jne _close_listening_socket

    ; sys_exit(0)
    mov rax, sys_exit
    syscall
