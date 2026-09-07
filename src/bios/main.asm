; ==============================================================================
; main.asm - Dashboard interactivo con Reloj, Cronómetro y Alarma
; ==============================================================================

[bits 16]                       ; Genera código para modo real de 16 bits

; Inclusión de todos los módulos necesarios
%include "src/bios/screen.asm"  ; Funciones de pantalla (limpiar, posicionar, imprimir, colores)
%include "src/bios/rtc.asm"     ; Lectura y formateo del RTC (hora actual)
%include "src/bios/input.asm"   ; Verificación de tecla presionada (sin bloqueo)
%include "src/bios/chrono.asm"  ; Lógica del cronómetro (variables y actualización)
%include "src/bios/alarm.asm"   ; Lógica de alarma (configuración, activación, efectos)

main_start:
    call show_welcome_screen    ; Muestra pantalla de bienvenida institucional
    call wait_user_confirmation ; Espera a que el usuario presione ENTER
    call draw_dashboard_ui      ; Dibuja la interfaz principal (títulos, modos, ayuda)
    call main_loop              ; Bucle principal de actualización y manejo de teclas

    ; Al salir del bucle (por 'q' o 'Q'), mostrar mensaje de despedida
    call screen_clear           ; Limpia la pantalla
    mov dh, 10                  ; Fila 10
    mov dl, 25                  ; Columna 25
    call set_cursor_pos         ; Posiciona el cursor
    mov si, msg_exit            ; Puntero al mensaje de salida
    call print_string           ; Imprime "Sistema Finalizado con Exito."
    cli                         ; Deshabilita interrupciones (fin del sistema)
    hlt                         ; Detiene el procesador (no retorna)

; ------------------------------------------------------------------------------
; Muestra la pantalla de bienvenida con el logo y el prompt
; ------------------------------------------------------------------------------
show_welcome_screen:
    call screen_clear           ; Limpia toda la pantalla y oculta cursor
    mov dh, 4                   ; Fila 4 (línea del separador superior)
    mov dl, 12                  ; Columna 12 (para centrar)
    call set_cursor_pos         ; Posiciona el cursor
    mov si, msg_line1           ; Puntero a "====================================="
    call print_string           ; Imprime
    mov dh, 6                   ; Fila 6 (institución)
    mov dl, 16                  ; Columna 16
    call set_cursor_pos         ; Posiciona
    mov si, msg_line2           ; Puntero a "INSTITUTO TECNOLOGICO DE COSTA RICA..."
    call print_string           ; Imprime
    mov dh, 8                   ; Fila 8 (título de la tarea)
    mov dl, 18                  ; Columna 18
    call set_cursor_pos         ; Posiciona
    mov si, msg_line3           ; Puntero a "TAREA 1: RELOJ / CRONOMETRO CON ALARMA"
    call print_string           ; Imprime
    mov dh, 14                  ; Fila 14 (prompt)
    mov dl, 14                  ; Columna 14 (centrado aproximado)
    call set_cursor_pos         ; Posiciona
    mov si, msg_prompt          ; Puntero a "[ Presione ENTER ... ]"
    call print_string           ; Imprime
    ret                         ; Vuelve al llamador

; ------------------------------------------------------------------------------
; Espera hasta que el usuario presione la tecla ENTER (0x0D)
; ------------------------------------------------------------------------------
wait_user_confirmation:
.wait_key:
    call check_key_pressed      ; Verifica si hay tecla presionada (ZF=1 si no)
    jz .wait_key                ; Si no hay tecla, sigue esperando
    cmp al, 0x0D                ; Compara el código ASCII con ENTER
    jne .wait_key               ; Si no es ENTER, sigue esperando
    ret                         ; Si es ENTER, retorna

; ------------------------------------------------------------------------------
; Dibuja el dashboard (título, separador, ayuda y la etiqueta del modo)
; ------------------------------------------------------------------------------
draw_dashboard_ui:
    call screen_clear           ; Limpia la pantalla (nuevo entorno)
    mov dh, 1                   ; Fila 1 (título del sistema)
    mov dl, 2                   ; Columna 2
    call set_cursor_pos         ; Posiciona
    mov si, msg_dash_title      ; Puntero a "CE4303 - SISTEMA EMBEBIDO..."
    call print_string           ; Imprime
    mov dh, 2                   ; Fila 2 (separador)
    mov dl, 2                   ; Columna 2
    call set_cursor_pos         ; Posiciona
    mov si, msg_separator       ; Puntero a "---------------------"
    call print_string           ; Imprime
    
    mov dh, 22                  ; Fila 22 (casi al final: controles)
    mov dl, 2                   ; Columna 2
    call set_cursor_pos         ; Posiciona
    mov si, msg_help            ; Puntero a "[M] Modo | [A] Alarma ..."
    call print_string           ; Imprime
    
    call draw_mode_label        ; Dibuja la etiqueta del modo actual (Reloj/Cronómetro/Config Alarma)
    ret                         ; Vuelve al llamador

; ------------------------------------------------------------------------------
; Dibuja la etiqueta según el modo actual (0=Reloj, 1=Cronómetro, 2=Config Alarma)
; ------------------------------------------------------------------------------
draw_mode_label:
    mov dh, 5                   ; Fila 5 (zona de la etiqueta de modo)
    mov dl, 22                  ; Columna 22 (centrada)
    call set_cursor_pos         ; Posiciona cursor
    
    cmp byte [current_mode], 0  ; Compara modo actual con 0
    je .draw_clock              ; Si es 0, salta a reloj
    cmp byte [current_mode], 1  ; Compara con 1
    je .draw_chrono             ; Si es 1, salta a cronómetro
    ; Si no es 0 ni 1, es 2 (Config Alarma)
.draw_alarm_setup:
    mov si, msg_mode_alarm      ; Carga mensaje de configuración de alarma
    jmp .print                  ; Salta a imprimir
.draw_chrono:
    mov si, msg_mode_chrono     ; Carga mensaje de cronómetro
    jmp .print
.draw_clock:
    mov si, msg_mode_clock      ; Carga mensaje de reloj
.print:
    call print_string           ; Imprime la etiqueta
    ; Limpiar la línea de tiempo (para evitar residuos al cambiar de modo)
    mov dh, 8                   ; Fila 8 (donde se muestra el tiempo)
    mov dl, 35                  ; Columna 35
    call set_cursor_pos         ; Posiciona
    mov si, msg_clear_time      ; Puntero a espacios (10 caracteres)
    call print_string           ; Limpia esa línea
    ret                         ; Vuelve al llamador

; ------------------------------------------------------------------------------
; main_loop: Bucle principal - actualiza pantalla, maneja teclas y modos
; ------------------------------------------------------------------------------
main_loop:
.refresh:
    call check_alarm            ; Verifica si la alarma debe activarse (efecto visual)
    
    ; --- Mostrar u ocultar mensaje de alarma activa ---
    mov dh, 12                  ; Fila 12 (mensaje de alarma)
    mov dl, 27                  ; Columna 27
    call set_cursor_pos         ; Posiciona
    cmp byte [alarm_triggered], 1 ; ¿La alarma está sonando?
    jne .clear_alarm_msg        ; Si no, limpia el mensaje
    mov si, msg_ringing         ; Si sí, carga " >>> ALARMA ACTIVADA <<< "
    call print_string           ; Imprime
    jmp .render_modes           ; Continúa a renderizar el modo
.clear_alarm_msg:
    mov si, msg_clear_ringing   ; Carga espacios para borrar el mensaje
    call print_string           ; Borra

.render_modes:                  ; Ahora actualiza la visualización según el modo
    cmp byte [current_mode], 0  ; ¿Modo Reloj?
    je .do_clock                ; Si es 0, salta a reloj
    cmp byte [current_mode], 1  ; ¿Modo Cronómetro?
    je .do_chrono               ; Si es 1, salta a cronómetro

.do_alarm_setup:                ; Si es 2 (Config Alarma)
    mov dh, 8                   ; Fila 8
    mov dl, 37                  ; Columna 37 (para mostrar "HH:MM")
    call set_cursor_pos         ; Posiciona
    mov si, alarm_input_buf     ; Puntero al buffer de entrada de alarma
    call print_string           ; Imprime el buffer ("00:00" o valor ingresado)
    jmp .check_input            ; Salta a verificar teclas

.do_chrono:                     ; Modo Cronómetro
    call chrono_update          ; Actualiza los contadores si está corriendo
    mov di, chrono_buffer       ; DI apunta al buffer del cronómetro
    call chrono_format_string   ; Escribe "MM:SS" en el buffer
    mov dh, 8                   ; Fila 8
    mov dl, 37                  ; Columna 37
    call set_cursor_pos         ; Posiciona
    mov si, chrono_buffer       ; Puntero al buffer formateado
    call print_string           ; Imprime el cronómetro
    jmp .check_input            ; Salta a verificar teclas

.do_clock:                      ; Modo Reloj
    mov di, time_buffer         ; DI apunta al buffer del reloj
    call rtc_format_time_string ; Lee RTC y escribe "HH:MM:SS" en el buffer
    mov dh, 8                   ; Fila 8
    mov dl, 35                  ; Columna 35
    call set_cursor_pos         ; Posiciona
    mov si, time_buffer         ; Puntero al buffer con la hora
    call print_string           ; Imprime la hora

.check_input:                   ; Verifica si hay tecla presionada
    call check_key_pressed      ; Devuelve ZF=1 si no hay tecla, AL=carácter si hay
    jnz .process_key            ; Si hay tecla, salta a procesar
    hlt                         ; Si no hay tecla, detiene CPU hasta próxima interrupción
    jmp .refresh                ; Vuelve a actualizar (sin parpadeos)

.process_key:                   ; --- Manejo de teclas ---
    cmp al, 'q'                 ; ¿Tecla 'q'?
    je .exit                    ; Sale del bucle
    cmp al, 'Q'                 ; ¿Tecla 'Q'?
    je .exit                    ; Sale

    cmp al, 'c'                 ; ¿Tecla 'c' (cancelar alarma)?
    je .cancel_alarm            ; Cancela alarma
    cmp al, 'C'                 ; ¿Tecla 'C'?
    je .cancel_alarm            ; Cancela alarma

    cmp byte [current_mode], 2  ; ¿Estamos en modo Config Alarma?
    je .handle_alarm_input      ; Si es así, procesa entrada numérica

    ; Modos diferentes a Config Alarma:
    cmp al, 'm'                 ; ¿Tecla 'm'?
    je .toggle_mode             ; Cambia de modo (Reloj <-> Cronómetro)
    cmp al, 'M'                 ; ¿Tecla 'M'?
    je .toggle_mode             ; Cambia de modo

    cmp al, 'a'                 ; ¿Tecla 'a'?
    je .enter_alarm_setup       ; Entra a Config Alarma
    cmp al, 'A'                 ; ¿Tecla 'A'?
    je .enter_alarm_setup       ; Entra a Config Alarma

    ; Si estamos en modo Cronómetro, permitir S y R
    cmp byte [current_mode], 1  ; ¿Modo Cronómetro?
    jne .refresh                ; Si no, ignora otras teclas y refresca

    cmp al, 's'                 ; ¿Tecla 's' (Start/Stop)?
    je .chrono_toggle           ; Alterna play/pausa
    cmp al, 'S'                 ; ¿Tecla 'S'?
    je .chrono_toggle           ; Alterna
    cmp al, 'r'                 ; ¿Tecla 'r' (Reset)?
    je .chrono_reset_key        ; Reinicia cronómetro
    cmp al, 'R'                 ; ¿Tecla 'R'?
    je .chrono_reset_key        ; Reinicia
    jmp .refresh                ; Otra tecla no válida, refresca

; --- Controladores de acciones ---

.toggle_mode:                   ; Alterna entre Reloj (0) y Cronómetro (1)
    xor byte [current_mode], 1  ; Invierte el bit (0↔1)
    call draw_mode_label        ; Actualiza la etiqueta en pantalla
    jmp .refresh                ; Vuelve al bucle

.enter_alarm_setup:             ; Cambia a modo Config Alarma (2)
    mov byte [current_mode], 2  ; Establece modo 2
    mov byte [alarm_input_idx], 0 ; Reinicia índice de entrada
    mov word [alarm_input_buf], "00" ; Inicializa horas a "00"
    mov word [alarm_input_buf+3], "00" ; Inicializa minutos a "00"
    call draw_mode_label        ; Actualiza etiqueta (modo alarma)
    jmp .refresh                ; Vuelve al bucle

.cancel_alarm:                  ; Cancela la alarma (desactiva y limpia efectos)
    mov byte [alarm_active], 0  ; Desactiva alarma
    mov byte [alarm_triggered], 0 ; Resetea bandera de disparo
    call screen_color_normal    ; Restaura colores normales (fondo negro)
    jmp .refresh                ; Vuelve al bucle

.handle_alarm_input:            ; Procesa dígitos (0-9) en modo Config Alarma
    cmp al, '0'                 ; ¿Menor que '0'?
    jl .refresh                 ; Si no es dígito, ignora
    cmp al, '9'                 ; ¿Mayor que '9'?
    jg .refresh                 ; Si no es dígito, ignora

    ; Lógica para insertar el dígito en el buffer respetando el separador ':'
    xor bx, bx                  ; BX = 0
    mov bl, byte [alarm_input_idx] ; BL = índice actual (0-4)
    
    cmp bl, 2                   ; ¿Índice igual a 2? (justo antes de los minutos)
    jne .save_char              ; Si no es 2, guarda normalmente
    inc bx                      ; Si es 2, avanzamos a 3 (saltamos el ':')
    inc byte [alarm_input_idx]  ; Incrementamos el índice (pasa de 2 a 3)
    
.save_char:
    mov [alarm_input_buf + bx], al ; Guarda el carácter ASCII en la posición
    inc byte [alarm_input_idx]    ; Incrementa el índice

    cmp byte [alarm_input_idx], 5 ; ¿Ya ingresamos 4 dígitos? (0,1,3,4)
    jne .refresh                  ; Si no, sigue refrescando

    ; Si ya se ingresaron 4 dígitos, guarda la alarma y vuelve a modo Reloj
    call save_alarm_from_buffer   ; Convierte el buffer a BCD y activa alarma
    mov byte [current_mode], 0    ; Vuelve a modo Reloj (0)
    call draw_mode_label          ; Actualiza la etiqueta (ahora Reloj)
    jmp .refresh                  ; Vuelve al bucle

.chrono_toggle:                 ; Inicia o pausa el cronómetro
    call chrono_start_stop      ; Alterna running flag
    jmp .refresh                ; Vuelve al bucle

.chrono_reset_key:              ; Reinicia el cronómetro a 0 y lo detiene
    call chrono_reset           ; Pone a cero todas las variables
    jmp .refresh                ; Vuelve al bucle

.exit:                          ; Sale del bucle (retorna a main_start)
    call screen_color_normal    ; Restaura colores normales antes de salir
    ret                         ; Vuelve al llamador (main_start)

; ------------------------------------------------------------------------------
; Datos Generales (variables y cadenas)
; ------------------------------------------------------------------------------
current_mode   db 0     ; 0=Reloj, 1=Cronómetro, 2=Config Alarma

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
msg_mode_alarm  db "[ MODO ACTUAL: CONFIGURAR ALARMA ]      ", 0
msg_clear_time  db "          ", 0  ; Espacios para limpiar la línea del tiempo

msg_help       db " [M] Modo | [A] Alarma | [C] Cancelar Alarma | [S/R] Crono | [Q] Salir", 0
msg_exit       db "Sistema Finalizado con Exito.", 0
msg_ringing    db " >>> ALARMA ACTIVADA <<< ", 0
msg_clear_ringing db "                         ", 0

; Buffers para mostrar tiempo
time_buffer    db "00:00:00", 0    ; Reloj: "HH:MM:SS"
chrono_buffer  db "00:00", 0       ; Cronómetro: "MM:SS"