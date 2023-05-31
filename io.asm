_print:
    ; string: rsi
    ; no return
    xor rdx, rdx
print_count_chars_loop:
    cmp byte [rsi + rdx], 0
    je end
    inc rdx
    jmp print_count_chars_loop
end:
    mov rax, sys_write
    mov rdi, stdout
    ; rsi is already set
    ; rdx is already set
    syscall

    ; TODO: get rid of the 2nd syscall
    mov rax, sys_write
    mov rdi, stdout
    mov rsi, new_line
    mov rdx, 1
    ; rsi is already set
    ; rdx is already set
    syscall

    ret
