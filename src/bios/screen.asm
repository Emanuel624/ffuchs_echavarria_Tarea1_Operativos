; ==============================================================================
; screen.asm - Funciones de Pantalla (BIOS INT 10h)
; ==============================================================================
;
; Este módulo proporciona rutinas básicas de manipulación de pantalla en modo
; texto, utilizando los servicios de la BIOS (interrupción 10h). Todas las
; funciones preservan el estado de los registros mediante pusha/popa y se
; ejecutan en modo real de 16 bits. Están diseñadas para ser llamadas desde
; el flujo principal del bootloader (main.asm).
; ==============================================================================

[bits 16]               ; Todas las funciones se ejecutan en modo real de 16 bits.

; ------------------------------------------------------------------------------
; screen_clear: Limpia la pantalla y establece el modo de video 80x25 en color.
; ------------------------------------------------------------------------------
; Utiliza la función 0x00 de la interrupción 10h: "Set Video Mode". El modo 0x03
; corresponde a texto 80 columnas × 25 filas, con 16 colores (modo color). Este
; modo es el estándar en la mayoría de los sistemas BIOS.
; ------------------------------------------------------------------------------
screen_clear:
    ; Guarda todos los registros de propósito general en la pila para restaurarlos
    ; al final, asegurando que la rutina no afecte el estado del caller.
    pusha

    ; AH = 0x00: función "Set Video Mode"
    ; AL = 0x03: modo texto 80x25, 16 colores (color)
    mov ah, 0x00
    mov al, 0x03
    int 0x10            ; Llama al BIOS para cambiar el modo de video.
                        ; Esto limpia automáticamente la pantalla y reinicia
                        ; el cursor en la esquina superior izquierda (fila 0, col 0).

    ; Restaura todos los registros que se guardaron al inicio.
    popa
    ret

; ------------------------------------------------------------------------------
; set_cursor_pos: Mueve el cursor a la fila y columna especificadas.
; ------------------------------------------------------------------------------
; Entrada:
;   DH = Fila (0-24, donde 0 es la primera línea superior)
;   DL = Columna (0-79, donde 0 es la columna más a la izquierda)
; ------------------------------------------------------------------------------
; Utiliza la función 0x02 de INT 10h: "Set Cursor Position". El cursor se
; posiciona en la página de video actual (página 0 por defecto).
; ------------------------------------------------------------------------------
set_cursor_pos:
    pusha

    ; AH = 0x02: función "Set Cursor Position"
    ; DH = fila (ya cargada por el caller)
    ; DL = columna (ya cargada por el caller)
    ; BH = número de página de video (0 = página activa por defecto)
    mov ah, 0x02
    mov bh, 0x00        ; Página 0 (la mayoría de los sistemas usan una sola página)
    int 0x10            ; Llama al BIOS para actualizar la posición del cursor.

    popa
    ret

; ------------------------------------------------------------------------------
; print_string: Imprime una cadena de caracteres terminada en cero (0x00)
; en la posición actual del cursor, usando el servicio de teletype (TTY).
; ------------------------------------------------------------------------------
; Entrada:
;   SI = Puntero (offset) al inicio de la cadena en memoria (segmento DS).
; La cadena debe estar en formato ASCII y terminar con un byte nulo (0).
; ------------------------------------------------------------------------------
; Utiliza la función 0x0E de INT 10h: "Teletype Output". Esta función imprime
; un carácter en la posición actual del cursor, avanza el cursor y maneja
; caracteres especiales como retroceso, tabulador, salto de línea, etc.
; ------------------------------------------------------------------------------
print_string:
    pusha               ; Preserva todos los registros.

    ; AH = 0x0E: función "Write Character in Teletype Mode"
    ; BH = página de video (0)
    ; AL = carácter a imprimir (se carga desde [SI] en cada iteración)
    mov ah, 0x0E
    mov bh, 0x00        ; Página activa

.loop:
    ; Carga el byte apuntado por SI en AL y luego incrementa SI automáticamente
    ; (lodsb). Esto es equivalente a: mov al, [SI]; inc SI.
    lodsb

    ; Compara AL con 0 (terminador nulo). Si es igual, termina la cadena.
    cmp al, 0
    je .done

    ; Llama al BIOS para imprimir el carácter contenido en AL.
    int 0x10

    ; Repite el bucle para el siguiente carácter.
    jmp .loop

.done:
    ; Restaura todos los registros y retorna al caller.
    popa
    ret