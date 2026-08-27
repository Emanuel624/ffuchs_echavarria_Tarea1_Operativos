; ==============================================================================
; screen.asm - Funciones de Pantalla (BIOS INT 10h)
; ==============================================================================

[bits 16]                       ; Modo real de 16 bits

; ------------------------------------------------------------------------------
; screen_clear: Limpia pantalla y establece modo texto 80x25
; ------------------------------------------------------------------------------
screen_clear:
    pusha                       ; Guarda todos los registros
    mov ah, 0x00                ; Función BIOS: "Set Video Mode"
    mov al, 0x03                ; Modo texto 80x25, 16 colores
    int 0x10                    ; Llama a la BIOS para cambiar el modo (limpia pantalla)
    popa                        ; Restaura los registros
    ret                         ; Vuelve al llamador

; ------------------------------------------------------------------------------
; set_cursor_pos: Posiciona el cursor en DH=fila, DL=columna
; ------------------------------------------------------------------------------
set_cursor_pos:
    pusha                       ; Guarda todos los registros
    mov ah, 0x02                ; Función BIOS: "Set Cursor Position"
    mov bh, 0x00                ; Página de video 0 (la activa por defecto)
    int 0x10                    ; Llama a la BIOS para mover el cursor
    popa                        ; Restaura los registros
    ret                         ; Vuelve al llamador

; ------------------------------------------------------------------------------
; print_string: Imprime cadena terminada en 0 apuntada por SI
; ------------------------------------------------------------------------------
print_string:
    pusha                       ; Guarda todos los registros
    mov ah, 0x0E                ; Función BIOS: "Teletype Output" (escribe carácter)
    mov bh, 0x00                ; Página de video 0
.loop:
    lodsb                       ; Carga byte de [SI] en AL e incrementa SI
    cmp al, 0                   ; ¿Es el terminador nulo?
    je .done                    ; Si es nulo, termina
    int 0x10                    ; Llama a BIOS para imprimir el carácter en AL
    jmp .loop                   ; Siguiente carácter
.done:
    popa                        ; Restaura los registros
    ret                         ; Vuelve al llamador