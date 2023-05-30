; TODO: this doesn't really align with behaviour
; from the C standard library's strcmp
_string_compare:
    ; string1: rdi
    ; string2: rsi
    ; return: rdx
    push rax
    xor rax, rax

__loop:
    mov byte dl, [rdi + rax]
    mov byte dh, [rsi + rax]

    inc rax
    cmp dl, 0 ; expect null teminated strings
    je __match

    cmp dl, dh
    je __loop

    jmp __mismatch
__match:
    pop rax
    xor rdx, rdx
    ret

__mismatch:
    pop rax
    mov rdx, 1
    ret
