; TODO: this doesn't really align with behaviour
; from the C standard library's strcmp
_string_compare:
    ; string1: rdi
    ; string2: rsi
    ; return: rdx
    push rax
    xor rax, rax

loop:
    mov byte dl, [rdi + rax]
    mov byte dh, [rsi + rax]

    ; increment offset
    inc rax

    ; check if the strings are completed
    ; TODO: does this handle the case of one string being longer than the other?
    cmp dl, 0
    je match

    ; check if bytes are the same
    cmp dl, dh
    je loop ; continue if so

    jmp mismatch
match:
    pop rax
    xor rdx, rdx
    ret

mismatch:
    pop rax
    mov rdx, 1
    ret


_string_to_int:
    ; string: rdi
    ; return: rax
    push rax
    push rbx
    push rcx
    push rdx

    xor rax, rax
    xor rbx, rbx
    xor rcx, rcx
    xor rdx, rdx

    ; check if string is negative
    mov bl, [rdi]
    cmp bl, '-'
    jne not_negative
    inc rdi
    mov bl, [rdi]
    neg bl
    mov [rdi], bl

; loop through string
not_negative:
    mov cl, [rdi]
    cmp cl, 0
    je end_loop

    ; convert char to int
    sub cl, '0'
    movzx rcx, cl

    ; multiply current value by 10
    mov rax, 10
    mul rbx

    ; add current value
    add rax, rcx

    ; increment offset
    inc rdi

    ; save current value
    mov rbx, rax

    jmp not_negative

end_loop:
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret
