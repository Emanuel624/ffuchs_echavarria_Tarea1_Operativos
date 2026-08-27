; ==============================================================================
; main.asm - Dashboard interactivo con Modo Reloj en Vivo
; ==============================================================================

[bits 16]                       ; Genera código para modo real de 16 bits

; Incluye los módulos necesarios
%include "src/bios/screen.asm"  ; Rutinas de pantalla (limpiar, posicionar, imprimir)
%include "src/bios/rtc.asm"     ; Funciones del RTC (lectura de hora y formateo)
%include "src/bios/input.asm"   ; Funciones de entrada (verificar tecla presionada)

main_start:
    call show_welcome_screen    ; Muestra pantalla de bienvenida
    call wait_user_confirmation ; Espera a que el usuario presione ENTER
    call draw_dashboard_ui      ; Dibuja la interfaz del dashboard
    call clock_loop             ; Entra en el bucle principal del reloj

    ; Pantalla de salida (se ejecuta al salir del bucle)
    call screen_clear           ; Limpia la pantalla
    mov dh, 10                  ; Fila 10 para el mensaje de salida
    mov dl, 25                  ; Columna 25
    call set_cursor_pos         ; Posiciona el cursor
    mov si, msg_exit            ; Carga puntero al mensaje de salida
    call print_string           ; Imprime mensaje
    cli                         ; Deshabilita interrupciones
    hlt                         ; Detiene el procesador

show_welcome_screen:
    call screen_clear           ; Limpia pantalla

    mov dh, 4                   ; Fila 4
    mov dl, 12                  ; Columna 12
    call set_cursor_pos         ; Posiciona cursor
    mov si, msg_line1           ; Puntero al separador superior
    call print_string           ; Imprime

    mov dh, 6                   ; Fila 6
    mov dl, 16                  ; Columna 16
    call set_cursor_pos         ; Posiciona cursor
    mov si, msg_line2           ; Puntero al nombre de la institución
    call print_string           ; Imprime

    mov dh, 8                   ; Fila 8
    mov dl, 18                  ; Columna 18
    call set_cursor_pos         ; Posiciona cursor
    mov si, msg_line3           ; Puntero al título de la tarea
    call print_string           ; Imprime

    mov dh, 14                  ; Fila 14
    mov dl, 14                  ; Columna 14
    call set_cursor_pos         ; Posiciona cursor
    mov si, msg_prompt          ; Puntero al mensaje "Presione ENTER"
    call print_string           ; Imprime
    ret                         ; Vuelve al llamador

wait_user_confirmation:
.wait_key:
    mov ah, 0x00                ; Función BIOS: leer tecla (espera)
    int 0x16                    ; Llama a la BIOS para obtener tecla en AL
    cmp al, 0x0D                ; Compara con código ASCII de ENTER (0x0D)
    jne .wait_key               ; Si no es ENTER, repite
    ret                         ; Vuelve al llamador

draw_dashboard_ui:
    call screen_clear           ; Limpia pantalla

    mov dh, 1                   ; Fila 1
    mov dl, 2                   ; Columna 2
    call set_cursor_pos         ; Posiciona cursor
    mov si, msg_dash_title      ; Puntero al título del dashboard
    call print_string           ; Imprime

    mov dh, 2                   ; Fila 2
    mov dl, 2                   ; Columna 2
    call set_cursor_pos         ; Posiciona cursor
    mov si, msg_separator       ; Puntero a la línea separadora
    call print_string           ; Imprime

    mov dh, 5                   ; Fila 5
    mov dl, 22                  ; Columna 22
    call set_cursor_pos         ; Posiciona cursor
    mov si, msg_mode_clock      ; Puntero al modo actual (Reloj)
    call print_string           ; Imprime

    mov dh, 22                  ; Fila 22
    mov dl, 2                   ; Columna 2
    call set_cursor_pos         ; Posiciona cursor
    mov si, msg_help            ; Puntero a la ayuda de controles
    call print_string           ; Imprime
    ret                         ; Vuelve al llamador

clock_loop:
.refresh:
    mov di, time_buffer         ; DI apunta al buffer donde se guardará la hora
    call rtc_format_time_string ; Lee el RTC y escribe "HH:MM:SS" en el buffer

    mov dh, 8                   ; Fila 8 (donde se muestra la hora)
    mov dl, 35                  ; Columna 35 (centrado aproximado)
    call set_cursor_pos         ; Posiciona cursor
    mov si, time_buffer         ; Puntero al buffer con la hora formateada
    call print_string           ; Imprime la hora

    call check_key_pressed      ; Verifica si hay una tecla presionada (sin esperar)
    jz .refresh                 ; Si no hay tecla (ZF=1), sigue mostrando la hora

    cmp al, 'q'                 ; ¿Tecla 'q' minúscula?
    je .exit                    ; Si es 'q', sale del bucle
    cmp al, 'Q'                 ; ¿Tecla 'Q' mayúscula?
    je .exit                    ; Si es 'Q', sale del bucle
    jmp .refresh                ; Si es otra tecla, ignora y sigue refrescando

.exit:
    ret                         ; Vuelve al llamador (main_start)

; Strings y buffers
msg_line1      db "=======================================================", 0
msg_line2      db "INSTITUTO TECNOLOGICO DE COSTA RICA - CE4303", 0
msg_line3      db "TAREA 1: RELOJ / CRONOMETRO CON ALARMA (BIOS)", 0
msg_prompt     db "[ Presione ENTER para ingresar al modo interactivo ]", 0

msg_dash_title db "CE4303 - SISTEMA EMBEBIDO BOOTEABLE (MODO BIOS)", 0
msg_separator  db "----------------------------------------------------------------------------", 0
msg_mode_clock db "[ MODO ACTUAL: RELOJ EN TIEMPO REAL ]", 0
msg_help       db "Controles: [M] Cambiar Modo  |  [A] Configurar Alarma  |  [Q] Salir", 0
msg_exit       db "Sistema Finalizado con Exito.", 0

time_buffer    db "00:00:00", 0   ; Buffer para almacenar la hora formateada