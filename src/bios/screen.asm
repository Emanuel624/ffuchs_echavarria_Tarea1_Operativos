; ==============================================================================
; screen.asm - Funciones de Pantalla y VRAM (BIOS INT 10h)
; ==============================================================================

[bits 16]                       ; Modo real de 16 bits

; ------------------------------------------------------------------------------
; screen_clear: Limpia pantalla, establece modo 80x25 y oculta cursor
; ------------------------------------------------------------------------------
screen_clear:
    pusha                       ; Guarda todos los registros
    mov ah, 0x00                ; Función BIOS: "Set Video Mode"
    mov al, 0x03                ; Modo texto 80x25, 16 colores (fondo negro)
    int 0x10                    ; Llama BIOS para cambiar modo (limpia pantalla)
    mov ah, 0x01                ; Función BIOS: "Set Cursor Type/Size"
    mov cx, 0x2607              ; Valores para ocultar cursor (bits de inicio/fin)
    int 0x10                    ; Llama BIOS para ocultar el cursor
    popa                        ; Restaura registros
    ret                         ; Vuelve al llamador

; ------------------------------------------------------------------------------
; set_cursor_pos: Posiciona cursor en DH=fila, DL=columna
; ------------------------------------------------------------------------------
set_cursor_pos:
    pusha                       ; Guarda todos los registros
    mov ah, 0x02                ; Función BIOS: "Set Cursor Position"
    mov bh, 0x00                ; Página de video 0 (activa)
    int 0x10                    ; Llama BIOS para mover el cursor
    popa                        ; Restaura registros
    ret                         ; Vuelve al llamador

; ------------------------------------------------------------------------------
; print_string: Imprime cadena terminada en 0 apuntada por SI
; ------------------------------------------------------------------------------
print_string:
    pusha                       ; Guarda todos los registros
    mov ah, 0x0E                ; Función BIOS: "Teletype Output"
    mov bh, 0x00                ; Página de video 0
.loop:
    lodsb                       ; Carga byte de [SI] en AL e incrementa SI
    cmp al, 0                   ; ¿Byte nulo (terminador)?
    je .done                    ; Si es nulo, termina
    int 0x10                    ; Llama BIOS para imprimir carácter en AL
    jmp .loop                   ; Siguiente carácter
.done:
    popa                        ; Restaura registros
    ret                         ; Vuelve al llamador

; ------------------------------------------------------------------------------
; screen_color_red: Cambia atributo de toda la pantalla a fondo rojo (texto blanco)
; ------------------------------------------------------------------------------
screen_color_red:
    pusha                       ; Guarda todos los registros
    mov ax, 0xB800              ; Segmento de VRAM en modo texto (base de la pantalla)
    mov es, ax                  ; ES = 0xB800 (acceso a la memoria de video)
    xor di, di                  ; DI = 0 (inicio de la VRAM)
    mov cx, 2000                ; 80x25 = 2000 caracteres (cada uno usa 2 bytes)
.loop_red:
    inc di                      ; Avanza al byte de atributo (saltando el ASCII)
    mov byte [es:di], 0x4F      ; Atributo: 0x4F = fondo rojo (4), texto blanco brillante (F)
    inc di                      ; Avanza al siguiente carácter (siguiente ASCII)
    loop .loop_red              ; Repite CX veces
    popa                        ; Restaura registros
    ret                         ; Vuelve al llamador

; ------------------------------------------------------------------------------
; screen_color_normal: Restaura atributo de toda la pantalla a fondo negro (texto blanco)
; ------------------------------------------------------------------------------
screen_color_normal:
    pusha                       ; Guarda todos los registros
    mov ax, 0xB800              ; Segmento VRAM
    mov es, ax                  ; ES apunta a VRAM
    xor di, di                  ; DI = 0 (inicio)
    mov cx, 2000                ; 2000 caracteres (80x25)
.loop_normal:
    inc di                      ; Salta byte ASCII, va al byte de atributo
    mov byte [es:di], 0x0F      ; Atributo: 0x0F = fondo negro (0), texto blanco brillante (F)
    inc di                      ; Siguiente carácter
    loop .loop_normal           ; Repite CX veces
    popa                        ; Restaura registros
    ret                         ; Vuelve al llamador