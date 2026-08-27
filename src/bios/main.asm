; ==============================================================================
; main.asm - Dashboard interactivo con Modo Reloj y Cronómetro
; ==============================================================================

[bits 16]                       ; Modo real de 16 bits

; Incluye todos los módulos necesarios
%include "src/bios/screen.asm"  ; Funciones de pantalla
%include "src/bios/rtc.asm"     ; Lectura y formateo del RTC
%include "src/bios/input.asm"   ; Verificación de tecla presionada (sin espera)
%include "src/bios/chrono.asm"  ; Lógica y variables del cronómetro

main_start:
    call show_welcome_screen    ; Muestra pantalla de bienvenida
    call wait_user_confirmation ; Espera ENTER para continuar
    call draw_dashboard_ui      ; Dibuja la interfaz principal
    call main_loop              ; Bucle principal de actualización y teclas

    ; Pantalla de salida (al salir del bucle)
    call screen_clear           ; Limpia pantalla
    mov dh, 10                  ; Fila 10
    mov dl, 25                  ; Columna 25
    call set_cursor_pos         ; Posiciona cursor
    mov si, msg_exit            ; Puntero al mensaje de salida
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
    mov si, msg_line2           ; Puntero a institución
    call print_string           ; Imprime
    mov dh, 8                   ; Fila 8
    mov dl, 18                  ; Columna 18
    call set_cursor_pos         ; Posiciona cursor
    mov si, msg_line3           ; Puntero a título de tarea
    call print_string           ; Imprime
    mov dh, 14                  ; Fila 14
    mov dl, 14                  ; Columna 14
    call set_cursor_pos         ; Posiciona cursor
    mov si, msg_prompt          ; Puntero a mensaje "Presione ENTER"
    call print_string           ; Imprime
    ret                         ; Vuelve al llamador

wait_user_confirmation:
.wait_key:
    call check_key_pressed      ; Verifica si hay tecla presionada (ZF=1 si no)
    jz .wait_key                ; Si no hay tecla, repite
    cmp al, 0x0D                ; Compara con código de ENTER (0x0D)
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
    mov si, msg_separator       ; Puntero a línea separadora
    call print_string           ; Imprime
    
    ; Dibujar controles generales en la parte inferior
    mov dh, 22                  ; Fila 22 (casi al final)
    mov dl, 2                   ; Columna 2
    call set_cursor_pos         ; Posiciona cursor
    mov si, msg_help            ; Puntero a la ayuda de controles
    call print_string           ; Imprime
    
    call draw_mode_label        ; Dibuja la etiqueta del modo actual (Reloj o Cronómetro)
    ret                         ; Vuelve al llamador

draw_mode_label:
    mov dh, 5                   ; Fila 5
    mov dl, 22                  ; Columna 22
    call set_cursor_pos         ; Posiciona cursor
    cmp byte [current_mode], 0  ; Compara current_mode con 0 (Reloj)
    je .draw_clock              ; Si es 0, salta a dibujar "Reloj"
    mov si, msg_mode_chrono     ; Si es 1, carga mensaje de Cronómetro
    jmp .print                  ; Salta a imprimir
.draw_clock:
    mov si, msg_mode_clock      ; Carga mensaje de Reloj
.print:
    call print_string           ; Imprime la etiqueta del modo
    ; Limpiar la línea de la hora para evitar residuos al cambiar de modo
    mov dh, 8                   ; Fila 8 (donde se muestra la hora/cronómetro)
    mov dl, 35                  ; Columna 35
    call set_cursor_pos         ; Posiciona cursor
    mov si, msg_clear_time      ; Puntero a cadena de espacios para limpiar
    call print_string           ; Borra la línea anterior
    ret                         ; Vuelve al llamador

; ------------------------------------------------------------------------------
; main_loop: Bucle principal (Refresco y Entradas)
; ------------------------------------------------------------------------------
main_loop:
.refresh:
    ; Actualizar lógica y pantalla según el modo actual
    cmp byte [current_mode], 0  ; ¿Modo Reloj (0) o Cronómetro (1)?
    je .do_clock                ; Si es 0, salta a actualizar reloj
    
.do_chrono:                     ; Si es 1, actualiza cronómetro
    call chrono_update          ; Incrementa tiempo si está corriendo
    mov di, chrono_buffer       ; DI apunta al buffer del cronómetro
    call chrono_format_string   ; Escribe "MM:SS" en el buffer
    mov dh, 8                   ; Fila 8
    mov dl, 37                  ; Columna 37 (centrado para "MM:SS")
    call set_cursor_pos         ; Posiciona cursor
    mov si, chrono_buffer       ; Puntero al buffer formateado
    call print_string           ; Imprime el cronómetro
    jmp .check_input            ; Salta a verificar entrada de teclado

.do_clock:                      ; Actualiza reloj
    mov di, time_buffer         ; DI apunta al buffer del reloj
    call rtc_format_time_string ; Escribe "HH:MM:SS" desde RTC
    mov dh, 8                   ; Fila 8
    mov dl, 35                  ; Columna 35 (centrado)
    call set_cursor_pos         ; Posiciona cursor
    mov si, time_buffer         ; Puntero al buffer con la hora
    call print_string           ; Imprime la hora

.check_input:                   ; Verifica teclas
    call check_key_pressed      ; ¿Hay tecla presionada? (ZF=1 si no)
    jz .refresh                 ; Si no hay tecla, sigue actualizando

    ; Procesar atajos globales (válidos en cualquier modo)
    cmp al, 'q'                 ; ¿Tecla 'q' minúscula?
    je .exit                    ; Salir del bucle
    cmp al, 'Q'                 ; ¿Tecla 'Q' mayúscula?
    je .exit                    ; Salir del bucle

    cmp al, 'm'                 ; ¿Tecla 'm' minúscula?
    je .toggle_mode             ; Cambiar modo
    cmp al, 'M'                 ; ¿Tecla 'M' mayúscula?
    je .toggle_mode             ; Cambiar modo

    ; Controles del Cronómetro (solo se aplican si estamos en modo cronómetro)
    cmp byte [current_mode], 1  ; ¿Está en modo cronómetro?
    jne .refresh                ; Si no, ignora S y R y vuelve a refrescar

    cmp al, 's'                 ; ¿Tecla 's' (Start/Stop)?
    je .chrono_toggle           ; Alterna play/pausa
    cmp al, 'S'                 ; ¿Tecla 'S' mayúscula?
    je .chrono_toggle           ; Alterna play/pausa

    cmp al, 'r'                 ; ¿Tecla 'r' (Reset)?
    je .chrono_reset_key        ; Reinicia cronómetro
    cmp al, 'R'                 ; ¿Tecla 'R' mayúscula?
    je .chrono_reset_key        ; Reinicia cronómetro

    jmp .refresh                ; Si es otra tecla, ignora y refresca

.toggle_mode:                   ; Cambia entre Reloj y Cronómetro
    xor byte [current_mode], 1  ; Invierte el bit (0→1, 1→0)
    call draw_mode_label        ; Actualiza la etiqueta en pantalla
    jmp .refresh                ; Vuelve al bucle

.chrono_toggle:                 ; Inicia/Pausa el cronómetro
    call chrono_start_stop      ; Alterna running flag y sincroniza ticks
    jmp .refresh                ; Vuelve al bucle

.chrono_reset_key:              ; Reinicia el cronómetro a 0 y lo detiene
    call chrono_reset           ; Pone a cero todas las variables
    jmp .refresh                ; Vuelve al bucle

.exit:
    ret                         ; Vuelve al llamador (main_start, que muestra salida)

; ------------------------------------------------------------------------------
; Datos Generales (variables y cadenas)
; ------------------------------------------------------------------------------
current_mode   db 0     ; 0 = Reloj, 1 = Cronómetro (selección actual)

; Mensajes de bienvenida
msg_line1      db "=======================================================", 0
msg_line2      db "INSTITUTO TECNOLOGICO DE COSTA RICA - CE4303", 0
msg_line3      db "TAREA 1: RELOJ / CRONOMETRO CON ALARMA (BIOS)", 0
msg_prompt     db "[ Presione ENTER para ingresar al modo interactivo ]", 0

; Mensajes del dashboard
msg_dash_title  db "CE4303 - SISTEMA EMBEBIDO BOOTEABLE (MODO BIOS)", 0
msg_separator   db "----------------------------------------------------------------------------", 0
msg_mode_clock  db "[ MODO ACTUAL: RELOJ EN TIEMPO REAL ]   ", 0  ; Incluye espacios para limpiar
msg_mode_chrono db "[ MODO ACTUAL: CRONOMETRO ]             ", 0
msg_clear_time  db "          ", 0  ; 10 espacios para borrar la línea de tiempo

msg_help       db "[M] Modo  |  [S] Play/Pause (Crono)  |  [R] Reset (Crono)  |  [Q] Salir", 0
msg_exit       db "Sistema Finalizado con Exito.", 0

; Buffers para mostrar tiempo
time_buffer    db "00:00:00", 0    ; Reloj: "HH:MM:SS"
chrono_buffer  db "00:00", 0       ; Cronómetro: "MM:SS"