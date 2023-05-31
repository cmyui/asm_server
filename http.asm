%include "strings.asm"
%include "io.asm"

; preserve: rbx, rsp, rbp, r12, r13, r14, r15
; scratch: rdi, rsi, rdx, rcx, r8, r9, r10, r11

_parse_http_request:
    ; NOTE: this function breaks System V ABI internally
    ; by storing the offset persistently in `rbx` while parsing.
    push rbx
    xor rbx, rbx
    call _save_http_method_pointer_to_request
    call _save_http_path_pointer_to_request
    call _save_http_version_pointer_to_request
    call _save_http_headers_to_request
    call _read_http_body_to_request
    pop rbx
    ret

_save_http_method_pointer_to_request:
    ; TODO: why am i doing this here but lea/mov elsewhere?
    mov qword [request + request_t.http_method], connection_data
read_one_byte_of_http_method:
    inc rbx
    cmp byte [connection_data + rbx], 32h ; " "
    jne read_one_byte_of_http_method
null_terminate_http_method:
    mov byte [connection_data + rbx], 0
    inc rbx ; " "
    ret

_save_http_path_pointer_to_request:
    lea rdi, [connection_data + rbx]
    mov [request + request_t.http_path], rdi
read_one_byte_of_http_path:
    inc rbx
    cmp byte [connection_data + rbx], 32h ; " "
    jne read_one_byte_of_http_path
null_terminate_http_path:
    mov byte [connection_data + rbx], 0
    inc rbx ; " "
    ret

_save_http_version_pointer_to_request:
    lea rdi, [connection_data + rbx]
    mov [request + request_t.http_version], rdi
read_one_byte_of_http_version:
    inc rbx
    cmp byte [connection_data + rbx], 0Ah ; "\r"
    jne read_one_byte_of_http_version
null_terminate_http_version:
    mov byte [connection_data + rbx], 0
    inc rbx ; "\n"
    ret

; TODO: split read_headers() and read_header()?
_save_http_headers_to_request:
read_http_header_key:
    lea rdi, [connection_data + rbx]
    mov [current_header_key], rdi
read_one_byte_of_http_header_key:
    inc rbx
    cmp byte [connection_data + rbx], 3Ah ; ":"
    jne read_one_byte_of_http_header_key
null_terminate_http_header_key:
    mov byte [connection_data + rbx], 0
    inc rbx ; ":"
    inc rbx ; " "

read_http_header_value:
    lea rdi, [connection_data + rbx]
    mov [current_header_value], rdi
read_one_byte_of_http_header_value:
    inc rbx
    cmp byte [connection_data + rbx], 0Dh ; "\r"
    jne read_one_byte_of_http_header_value
null_terminate_http_header_value:
    mov byte [connection_data + rbx], 0
    inc rbx ; "\r"
    inc rbx ; "\n"

check_if_http_header_is_content_length:
    mov rdi, [current_header_key]
    mov rsi, content_length_header_key
    call _string_compare
    cmp rdx, 0
    jne check_if_http_header_is_content_type
save_http_header_to_content_length:
    ; special case: store content length as an int
    mov rdi, [current_header_value]
    call _string_to_int
    mov qword [headers + headers_t.content_length], rax
    jmp check_if_more_headers_remain

check_if_http_header_is_content_type:
    mov rdi, [current_header_key]
    mov rsi, content_type_header_key
    call _string_compare
    cmp rdx, 0
    jne check_if_http_header_is_connection
save_http_header_to_content_type:
    mov qword [headers + headers_t.content_type], current_header_value
    jmp check_if_more_headers_remain

check_if_http_header_is_connection:
    mov rdi, [current_header_key]
    mov rsi, connection_header_key
    call _string_compare
    cmp rdx, 0
    jne check_if_http_header_is_host
save_http_header_to_connection:
    mov qword [headers + headers_t.connection], current_header_value
    jmp check_if_more_headers_remain

check_if_http_header_is_host:
    mov rdi, [current_header_key]
    mov rsi, host_header_key
    call _string_compare
    cmp rdx, 0
    jne check_if_http_header_is_user_agent
save_http_header_to_host:
    mov qword [headers + headers_t.host], current_header_value
    jmp check_if_more_headers_remain

check_if_http_header_is_user_agent:
    mov rdi, [current_header_key]
    mov rsi, user_agent_header_key
    call _string_compare
    cmp rdx, 0
    jne check_if_http_header_is_osu_token
save_http_header_to_user_agent:
    mov qword [headers + headers_t.user_agent], current_header_value
    jmp check_if_more_headers_remain

check_if_http_header_is_osu_token:
    mov rdi, [current_header_key]
    mov rsi, osu_token_header_key
    call _string_compare
    cmp rdx, 0
    jne end_of_header_parsing
save_http_header_to_osu_token:
    mov qword [headers + headers_t.osu_token], current_header_value
    jmp check_if_more_headers_remain

check_if_more_headers_remain:
    ; check if we should look (did we hit "\r\n\r\n"?)
    cmp byte [connection_data + rbx], 0Dh ; "\r"
    jne read_http_header_key

end_of_header_parsing:
    ret

_read_http_body_to_request:
    ret
