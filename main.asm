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

section .data
    NULL equ 0

    SOCK_STREAM equ 1

    AF_UNIX equ 1
    AF_INET equ 2

    PROT_READ equ 1
    PROT_WRITE equ 2

    MAP_PRIVATE equ 2
    MAP_ANONYMOUS equ 32

    PAGE_SIZE equ 4096 ; 4k

    SERVER_ADDR equ dword 0x00000000 ; 0.0.0.0
    SERVER_PORT equ word 0x8913 ; htons(5001)

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
    sys_exit equ 60

    ; create struct types

    struc sockaddr_in_t
        .sin_family: resw 1
        .sin_port: resw 1
        .sin_addr: resd 1
        .sin_zero: resb 8
    endstruc

    struc server_t
        .listening_fd: resd 1
        .connecting_fd: resd 1
    endstruc

    ; create struct instances

    sockaddr_in istruc sockaddr_in_t
        at sockaddr_in_t.sin_family, dw AF_INET
        at sockaddr_in_t.sin_port, dw SERVER_PORT
        at sockaddr_in_t.sin_addr, dd SERVER_ADDR
        at sockaddr_in_t.sin_zero, times 8 db 0
    iend

    ; create server instance
    server istruc server_t
        at server_t.listening_fd, dd 0
        at server_t.connecting_fd, dd 0
    iend

section .text
    global _start

_start:

_socket:
    ; sys_socket(AF_INET, SOCK_STREAM, 0)
    mov rax, sys_socket
    mov rdi, AF_INET
    mov rsi, SOCK_STREAM
    mov rdx, 0
    syscall

    ; save listening socket fd
    mov [server + server_t.listening_fd], rax

_bind:
    ; sys_bind(fd, &sockaddr_in, addrlen)
    mov rax, sys_bind
    mov rdi, [server + server_t.listening_fd]
    mov rsi, sockaddr_in
    mov rdx, 16 ; TODO: dynamically set struct size
    syscall

_listen:
    ; sys_listen(fd, backlog)
    mov rax, sys_listen
    mov rdi, [server + server_t.listening_fd]
    mov rsi, 5
    syscall

_accept:
    ; sys_accept(fd, &peer_sockaddr, peer_addrlen)
    mov rax, sys_accept
    mov rdi, [server + server_t.listening_fd]
    mov rsi, 0
    mov rdx, 0
    syscall

    ; save peer socket fd
    mov [server + server_t.connecting_fd], rax

_handle_conn:
    ; sys_mmap(NULL, 4096, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0)
    mov rax, sys_mmap
    mov rdi, NULL
    mov rsi, PAGE_SIZE
    mov rdx, PROT_READ | PROT_WRITE
    mov r10, MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1
    mov r9, 0
    syscall

    ; save mmap address into r12
    mov rax, r12

_read:
    ; sys_read(fd, buf, count)
    mov rax, 0
    mov rdi, rcx

_exit:
    ; sys_exit(0)
    mov rax, sys_exit
    mov rdi, 0
    syscall
