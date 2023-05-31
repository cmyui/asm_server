
_exit_success:
    xor rdi, rdi
    jmp exit
_exit_fail:
    mov rdi, 1
exit:
    ; close socket if it's open
    cmp byte [server + server_t.connecting_fd], 0
    jne _close_listening_socket

    ; sys_exit(0)
    mov rax, sys_exit
    syscall
