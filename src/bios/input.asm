; ==============================================================================
; input.asm - Manejo no bloqueante de teclado (BIOS INT 16h)
; ==============================================================================

[bits 16]

; ------------------------------------------------------------------------------
; check_key_pressed: Verifica si hay una tecla presionada en el buffer
; Salida: ZF = 1 si no hay tecla; ZF = 0 y AL = código ASCII si hay tecla
; ------------------------------------------------------------------------------
check_key_pressed:
    mov ah, 0x01        ; INT 16h, AH=01h: Comprobar buffer (no bloqueante)
    int 0x16
    jz .no_key          ; Si Zero Flag está activo, el buffer está vacío

    mov ah, 0x00        ; INT 16h, AH=00h: Extraer tecla del buffer
    int 0x16
    clc                 ; Limpiar carry
    ret

.no_key:
    xor al, al          ; AL = 0
    ret