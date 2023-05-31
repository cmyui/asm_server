%include "exit.asm"

_start_server:

create_socket:
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

; set_reuseport:
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

bind_socket:
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

listen_for_connections:
    ; sys_listen(fd, backlog)
    mov rax, sys_listen
    mov rdi, [server + server_t.listening_fd]
    mov rsi, 5
    syscall

    cmp rax, 0
    jl _exit_fail

accept_loop:

accept_connection:
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

receive_data:
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

parse_http_request:
    call _parse_http_request

    ; TODO: figure out some way of registering handlers?

    jmp accept_loop

    ret

; TODO: hook SIGINT & SIGTERM with this functionality
_close_listening_socket:
    ; sys_close(fd)
    mov rax, sys_close
    mov rdi, [server + server_t.listening_fd]
    syscall

    mov qword [server + server_t.listening_fd], 0
