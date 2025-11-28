section .data
    ; Códigos de color ANSI
    color_reset db 27, "[0m", 0
    color_red db 27, "[31m", 0
    color_green db 27, "[32m", 0
    color_yellow db 27, "[33m", 0
    color_blue db 27, "[34m", 0
    color_cyan db 27, "[36m", 0
    color_magenta db 27, "[35m", 0

    ; Palabras del juego (cada una de exactamente 5 letras, terminada en 0)
    words db "casas", 0, "perro", 0, "gatos", 0, "soles", 0, "lunas", 0
    word_len equ 5
    num_words equ 5

    ; Mensajes
    prompt db "Ingresa una letra: ", 0
    win_msg db "¡Ganaste! La palabra era: ", 0
    lose_msg db "¡Perdiste! La palabra era: ", 0
    already_guessed db "Ya adivinaste esa letra. Intenta otra.", 10, 0
    wrong_letter db "Letra incorrecta.", 10, 0
    correct_letter db "¡Bien!", 10, 0
    newline db 10, 0

    ; Dibujo del ahorcado (7 etapas: 0-6)
    hangman0 db "  +---+", 10, "  |   |", 10, "      |", 10, "      |", 10, "      |", 10, "      |", 10, "=========", 10, 0
    hangman1 db "  +---+", 10, "  |   |", 10, "  O   |", 10, "      |", 10, "      |", 10, "      |", 10, "=========", 10, 0
    hangman2 db "  +---+", 10, "  |   |", 10, "  O   |", 10, "  |   |", 10, "      |", 10, "      |", 10, "=========", 10, 0
    hangman3 db "  +---+", 10, "  |   |", 10, "  O   |", 10, " /|   |", 10, "      |", 10, "      |", 10, "=========", 10, 0
    hangman4 db "  +---+", 10, "  |   |", 10, "  O   |", 10, " /|\  |", 10, "      |", 10, "      |", 10, "=========", 10, 0
    hangman5 db "  +---+", 10, "  |   |", 10, "  O   |", 10, " /|\  |", 10, " /    |", 10, "      |", 10, "=========", 10, 0
    hangman6 db "  +---+", 10, "  |   |", 10, "  O   |", 10, " /|\  |", 10, " / \  |", 10, "      |", 10, "=========", 10, 0

    hangman_ptrs dq hangman0, hangman1, hangman2, hangman3, hangman4, hangman5, hangman6

section .bss
    selected_word resb 10
    guessed resb 26
    display resb 10
    input resb 10
    errors resb 1
    current_letter resb 1
    actual_word_len resb 1

section .text
    global _start

_start:
    mov byte [errors], 0
    call init_guessed
    call select_random_word
    call init_display

game_loop:
    call print_hangman
    call print_display
    call print_prompt

    call read_input
    mov al, [input]
    call to_lower
    mov [current_letter], al

    call check_already_guessed
    cmp rax, 1
    je already_guessed_msg

    mov al, [current_letter]
    call check_letter
    cmp rax, 1
    je correct

    ; Letra incorrecta
    inc byte [errors]
    call print_wrong
    cmp byte [errors], 6
    je lose
    jmp game_loop

correct:
    call print_correct
    call check_win
    cmp rax, 1
    je win
    jmp game_loop

already_guessed_msg:
    call print_already_guessed
    jmp game_loop

win:
    call print_hangman
    call print_display
    call print_win
    jmp exit

lose:
    call print_hangman
    call print_display
    call print_lose
    jmp exit

exit:
    mov rax, 60
    xor rdi, rdi
    syscall

; -----------------------
; Subrutinas
; -----------------------
init_guessed:
    mov rcx, 26
    mov rdi, guessed
    xor al, al
    rep stosb
    ret

select_random_word:
    mov rax, 201  ; syscall clock_gettime
    xor rdi, rdi
    syscall
    xor rdx, rdx
    mov rbx, num_words
    div rbx
    
    ; Calcular offset
    mov rsi, words
    mov rcx, rdx
    imul rcx, 6
    add rsi, rcx
    
    ; Copiar palabra y calcular longitud real
    mov rdi, selected_word
    xor rcx, rcx
.copy_loop:
    mov al, [rsi + rcx]
    test al, al
    jz .done
    mov [rdi + rcx], al
    inc rcx
    cmp rcx, 10
    je .done
    jmp .copy_loop
.done:
    mov byte [rdi + rcx], 0
    mov [actual_word_len], cl
    ret

init_display:
    movzx rcx, byte [actual_word_len]
    mov rdi, display
    mov al, '_'
.loop:
    test rcx, rcx
    jz .done
    mov [rdi], al
    inc rdi
    dec rcx
    jmp .loop
.done:
    mov byte [rdi], 0
    ret

print_hangman:
    ; Imprimir en rojo
    mov rsi, color_red
    call print_string
    
    movzx rax, byte [errors]
    cmp rax, 6
    jle .ok
    mov rax, 6
.ok:
    mov rsi, [hangman_ptrs + rax * 8]
    call print_string
    
    ; Resetear color
    mov rsi, color_reset
    call print_string
    ret

print_display:
    ; Imprimir en cyan
    mov rsi, color_cyan
    call print_string
    
    mov rsi, display
    xor rcx, rcx
    movzx rdx, byte [actual_word_len]
.loop:
    cmp rcx, rdx
    je .done
    ; Imprimir letra o guión
    mov al, [rsi + rcx]
    push rcx
    push rsi
    push rdx
    call print_char
    ; Imprimir espacio
    mov al, ' '
    call print_char
    pop rdx
    pop rsi
    pop rcx
    inc rcx
    jmp .loop
.done:
    ; Resetear color
    mov rsi, color_reset
    call print_string
    mov rsi, newline
    call print_string
    ret

print_prompt:
    ; Imprimir en amarillo
    mov rsi, color_yellow
    call print_string
    mov rsi, prompt
    call print_string
    mov rsi, color_reset
    call print_string
    ret

read_input:
    mov rax, 0
    mov rdi, 0
    mov rsi, input
    mov rdx, 10
    syscall
    ret

to_lower:
    cmp al, 'A'
    jl .done
    cmp al, 'Z'
    jg .done
    add al, 32
.done:
    mov [input], al
    ret

check_already_guessed:
    mov al, [current_letter]
    cmp al, 'a'
    jl .invalid
    cmp al, 'z'
    jg .invalid
    sub al, 'a'
    movzx rax, al
    cmp byte [guessed + rax], 1
    je .yes
    mov byte [guessed + rax], 1
    xor rax, rax
    ret
.yes:
    mov rax, 1
    ret
.invalid:
    xor rax, rax
    ret

check_letter:
    mov rsi, selected_word
    mov rdi, display
    xor rcx, rcx
    xor rbx, rbx
    movzx r8, byte [actual_word_len]
.loop:
    cmp rcx, r8
    je .done
    mov dl, [rsi + rcx]
    test dl, dl
    jz .done
    cmp dl, al
    jne .next
    mov [rdi + rcx], al
    mov rbx, 1
.next:
    inc rcx
    jmp .loop
.done:
    mov rax, rbx
    ret

check_win:
    mov rsi, display
    xor rcx, rcx
    movzx rdx, byte [actual_word_len]
.loop:
    cmp rcx, rdx
    je .yes
    cmp byte [rsi + rcx], '_'
    je .no
    inc rcx
    jmp .loop
.yes:
    mov rax, 1
    ret
.no:
    xor rax, rax
    ret

print_win:
    ; Imprimir en verde
    mov rsi, color_green
    call print_string
    mov rsi, win_msg
    call print_string
    mov rsi, color_magenta
    call print_string
    mov rsi, selected_word
    call print_string
    mov rsi, color_reset
    call print_string
    mov rsi, newline
    call print_string
    ret

print_lose:
    ; Imprimir en rojo
    mov rsi, color_red
    call print_string
    mov rsi, lose_msg
    call print_string
    mov rsi, color_magenta
    call print_string
    mov rsi, selected_word
    call print_string
    mov rsi, color_reset
    call print_string
    mov rsi, newline
    call print_string
    ret

print_correct:
    ; Imprimir en verde
    mov rsi, color_green
    call print_string
    mov rsi, correct_letter
    call print_string
    mov rsi, color_reset
    call print_string
    ret

print_wrong:
    ; Imprimir en rojo
    mov rsi, color_red
    call print_string
    mov rsi, wrong_letter
    call print_string
    mov rsi, color_reset
    call print_string
    ret

print_already_guessed:
    ; Imprimir en amarillo
    mov rsi, color_yellow
    call print_string
    mov rsi, already_guessed
    call print_string
    mov rsi, color_reset
    call print_string
    ret

print_string:
    push rsi
    mov rdx, 0
.count:
    cmp byte [rsi + rdx], 0
    je .print
    inc rdx
    jmp .count
.print:
    pop rsi
    mov rax, 1
    mov rdi, 1
    syscall
    ret

print_char:
    ; Guardar el carácter en la pila
    sub rsp, 8
    mov [rsp], al
    mov rsi, rsp
    mov rdx, 1
    mov rax, 1
    mov rdi, 1
    syscall
    add rsp, 8
    ret
