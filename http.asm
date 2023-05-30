_parse_http_request:
    xor rax, rax ; offset

    ; save http_method
    mov qword [request + request_t.http_method], connection_data
__read_http_method:
    inc rax
    cmp byte [connection_data + rax], 32h ; " "
    jne __read_http_method

    ; null terminate http_method
    mov byte [connection_data + rax], 0

    ; save http_path
    lea rdi, [connection_data + rax + 1]
    mov [request + request_t.http_path], rdi
__read_http_path:
    inc rax
    cmp byte [connection_data + rax], 32h ; " "
    jne __read_http_path

    ; null terminate http_path
    mov byte [connection_data + rax], 0

    ; save http_version
    lea rdi, [connection_data + rax + 1]
    mov [request + request_t.http_version], rdi
__read_http_version:
    inc rax
    cmp byte [connection_data + rax], 0Ah ; "\r"
    jne __read_http_version

    ; null terminate http_version
    mov byte [connection_data + rax], 0

    inc rax ; "\n"

__read_http_headers:
    ; for line in read().split('\r\n'):
    ;    if header == 'Content-Length':
    ;        headers.content_length = int(value)
    ;    elif header == 'Content-Type':
    ;        headers.content_type = value
    ;    elif header == 'Connection':
    ;        headers.connection = value
    ;    elif header == 'Host':
    ;        headers.host = value
    ;    elif header == 'User-Agent':
    ;        headers.user_agent = value
    ;    elif header == 'osu-token':
    ;        headers.osu_token = value

__read_http_header:
    ; read line
    inc rax
    cmp byte [connection_data + rax], 3Ah ; ":"
    jne __read_http_headers

    inc rax ; " "

    ; save header
    ; mov rdi, [connection_data + rax]

    ret
