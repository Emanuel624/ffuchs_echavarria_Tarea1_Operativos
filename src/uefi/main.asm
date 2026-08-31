; ==============================================================================
; src/uefi/main.asm - Aplicación y Dashboard UEFI Completo en x86_64
; Tarea 1: Reloj/Cronómetro con Alarma (CE4303 - Sistemas Operativos)
; ==============================================================================

default rel
bits 64

; ------------------------------------------------------------------------------
; Offsets en EFI_SYSTEM_TABLE (64 bits)
; ------------------------------------------------------------------------------
%define OFFSET_CONIN                0x30        ; SystemTable -> ConIn
%define OFFSET_CONOUT               0x40        ; SystemTable -> ConOut
%define OFFSET_RUNTIME_SERVICES     0x58        ; SystemTable -> RuntimeServices
%define OFFSET_BOOT_SERVICES        0x60        ; SystemTable -> BootServices

; ------------------------------------------------------------------------------
; Inclusión de Módulos UEFI
; ------------------------------------------------------------------------------
%include "src/uefi/screen.asm"                  ; Funciones de pantalla y colores
%include "src/uefi/input.asm"                   ; Manejo de teclado y retardos
%include "src/uefi/rtc.asm"                     ; Lectura de hora RTC y formateo
%include "src/uefi/chrono.asm"                  ; Lógica de cronómetro independiente
%include "src/uefi/alarm.asm"                   ; Lógica de alarma y parpadeo visual

section .text
global efi_main

; ==============================================================================
; Punto de Entrada UEFI (efi_main)
; ==============================================================================
efi_main:
    ; Reserva de shadow space y alineación de pila (RSP % 16 == 0)
    sub rsp, 40

    ; Guardar punteros fundamentales entregados por el firmware UEFI
    mov [ImageHandle], rcx
    mov [SystemTable], rdx

    mov rax, [rdx + OFFSET_CONOUT]
    mov [ConOut], rax

    mov rax, [rdx + OFFSET_CONIN]
    mov [ConIn], rax

    mov rax, [rdx + OFFSET_RUNTIME_SERVICES]
    mov [RuntimeServices], rax

    mov rax, [rdx + OFFSET_BOOT_SERVICES]
    mov [BootServices], rax

    ; 1. Limpiar pantalla y ocultar cursor
    call uefi_clear_screen
    call uefi_hide_cursor

    ; 2. Mostrar la pantalla de bienvenida institucional
    call show_welcome_screen

    ; 3. Esperar confirmación del usuario (tecla ENTER)
    call uefi_wait_enter

    ; 4. Dibujar el marco del Dashboard principal
    call draw_dashboard_ui

    ; 5. Iniciar bucle principal de actualización
    call main_loop

    ; 6. Finalización limpia del programa
    call uefi_clear_screen
    mov rdx, 25                         ; Columna 25
    mov r8, 10                          ; Fila 10
    call uefi_set_cursor
    mov rdx, COLOR_WHITE_ON_BLACK
    call uefi_set_color
    lea rdx, [msg_exit]
    call uefi_print_string

    ; Pausa de 2 segundos antes de retornar
    mov rcx, 2000000                    ; 2,000,000 microsegundos = 2 segundos
    call uefi_stall

    call uefi_show_cursor
    call uefi_clear_screen

    ; Retornar EFI_SUCCESS (0) al firmware
    add rsp, 40
    xor rax, rax
    ret

; ==============================================================================
; show_welcome_screen: Pantalla institucional con datos del TEC
; ==============================================================================
show_welcome_screen:
    sub rsp, 40

    ; Separador superior (Fila 4, Columna 12)
    mov rdx, 12
    mov r8, 4
    call uefi_set_cursor
    mov rdx, COLOR_CYAN_ON_BLACK
    call uefi_set_color
    lea rdx, [msg_line1]
    call uefi_print_string

    ; Institución (Fila 6, Columna 16)
    mov rdx, 16
    mov r8, 6
    call uefi_set_cursor
    mov rdx, COLOR_WHITE_ON_BLACK
    call uefi_set_color
    lea rdx, [msg_line2]
    call uefi_print_string

    ; Título (Fila 8, Columna 14)
    mov rdx, 14
    mov r8, 8
    call uefi_set_cursor
    mov rdx, COLOR_YELLOW_ON_BLACK
    call uefi_set_color
    lea rdx, [msg_line3]
    call uefi_print_string

    ; Prompt de confirmación (Fila 14, Columna 14)
    mov rdx, 14
    mov r8, 14
    call uefi_set_cursor
    mov rdx, COLOR_WHITE_ON_BLACK
    call uefi_set_color
    lea rdx, [msg_prompt]
    call uefi_print_string

    add rsp, 40
    ret

; ==============================================================================
; draw_dashboard_ui: Dibuja el marco y las etiquetas estáticas del Dashboard
; ==============================================================================
draw_dashboard_ui:
    sub rsp, 40

    call uefi_clear_screen

    ; Título del Dashboard (Fila 1, Columna 2)
    mov rdx, 2
    mov r8, 1
    call uefi_set_cursor
    mov rdx, COLOR_CYAN_ON_BLACK
    call uefi_set_color
    lea rdx, [msg_dash_title]
    call uefi_print_string

    ; Separador (Fila 2, Columna 2)
    mov rdx, 2
    mov r8, 2
    call uefi_set_cursor
    mov rdx, COLOR_WHITE_ON_BLACK
    call uefi_set_color
    lea rdx, [msg_separator]
    call uefi_print_string

    ; Ayuda de Controles (Fila 22, Columna 2)
    mov rdx, 2
    mov r8, 22
    call uefi_set_cursor
    mov rdx, COLOR_LIGHTGRAY
    call uefi_set_color
    lea rdx, [msg_help]
    call uefi_print_string

    ; Dibujar la etiqueta del modo inicial
    call draw_mode_label

    add rsp, 40
    ret

; ==============================================================================
; draw_mode_label: Dibuja la etiqueta según current_mode (0=Reloj, 1=Crono, 2=Alarma)
; ==============================================================================
draw_mode_label:
    sub rsp, 40

    ; Posicionar en zona de etiqueta (Fila 5, Columna 22)
    mov rdx, 22
    mov r8, 5
    call uefi_set_cursor
    mov rdx, COLOR_WHITE_ON_BLACK
    call uefi_set_color

    cmp byte [current_mode], 0
    je .draw_clock
    cmp byte [current_mode], 1
    je .draw_chrono

.draw_alarm_setup:
    lea rdx, [msg_mode_alarm]
    call uefi_print_string
    jmp .clear_time_line

.draw_chrono:
    lea rdx, [msg_mode_chrono]
    call uefi_print_string
    jmp .clear_time_line

.draw_clock:
    lea rdx, [msg_mode_clock]
    call uefi_print_string

.clear_time_line:
    ; Limpiar la línea central para evitar residuos de otros modos
    mov rdx, 34
    mov r8, 8
    call uefi_set_cursor
    lea rdx, [msg_clear_time]
    call uefi_print_string

    add rsp, 40
    ret

; ==============================================================================
; main_loop: Bucle interactivo en tiempo real
; ==============================================================================
main_loop:
    sub rsp, 40

.refresh:
    ; 1. Actualizar siempre la hora del RTC
    call uefi_get_time

    ; 2. Actualizar el cronómetro si está corriendo (independiente del modo activo)
    call chrono_update

    ; 3. Verificar si la alarma coincide con la hora actual
    call check_alarm

    ; 4. Mostrar u ocultar el banner visual de alarma activa
    mov rdx, 27                         ; Columna 27
    mov r8, 12                          ; Fila 12
    call uefi_set_cursor

    cmp byte [alarm_triggered], 1
    jne .clear_alarm_banner

    ; Efecto de parpadeo: alternar color según bit 3 de blink_counter (~0.4 seg)
    test byte [blink_counter], 0x08
    jz .color_blink1

    mov rdx, COLOR_LIGHTRED
    call uefi_set_color
    lea rdx, [msg_ringing]
    call uefi_print_string
    jmp .render_modes

.color_blink1:
    mov rdx, COLOR_YELLOW
    call uefi_set_color
    lea rdx, [msg_ringing]
    call uefi_print_string
    jmp .render_modes

.clear_alarm_banner:
    lea rdx, [msg_clear_ringing]
    call uefi_print_string

.render_modes:
    ; 5. Renderizar según el modo actual
    cmp byte [current_mode], 0
    je .render_clock
    cmp byte [current_mode], 1
    je .render_chrono

.render_alarm_setup:                    ; Modo 2: Configurar Alarma
    mov rdx, 37                         ; Columna 37 para "HH:MM"
    mov r8, 8                           ; Fila 8
    call uefi_set_cursor
    mov rdx, COLOR_LIGHTCYAN
    call uefi_set_color
    lea rdx, [alarm_input_buf]
    call uefi_print_string
    jmp .check_input

.render_chrono:                         ; Modo 1: Cronómetro
    call chrono_format_string
    mov rdx, 37                         ; Columna 37 para "MM:SS"
    mov r8, 8                           ; Fila 8
    call uefi_set_cursor
    mov rdx, COLOR_GREEN_ON_BLACK
    call uefi_set_color
    lea rdx, [chrono_buffer]
    call uefi_print_string
    jmp .check_input

.render_clock:                          ; Modo 0: Reloj
    call uefi_format_time_string
    mov rdx, 36                         ; Columna 36 para "HH:MM:SS"
    mov r8, 8                           ; Fila 8
    call uefi_set_cursor
    mov rdx, COLOR_YELLOW_ON_BLACK
    call uefi_set_color
    lea rdx, [time_buffer]
    call uefi_print_string

.check_input:
    ; 6. Comprobar si el usuario presionó una tecla (sin bloqueo)
    call uefi_check_key
    jz .delay_and_repeat                ; Si ZF = 1 (no hay tecla), pasar al retardo

    ; 7. Procesar teclas globales
    cmp al, 'q'
    je .exit
    cmp al, 'Q'
    je .exit

    cmp al, 'c'
    je .cancel_alarm_key
    cmp al, 'C'
    je .cancel_alarm_key

    ; Si estamos en modo Configurar Alarma (2), procesar entrada numérica
    cmp byte [current_mode], 2
    je .handle_alarm_input

    ; Modos 0 y 1 (Reloj y Cronómetro)
    cmp al, 'm'
    je .toggle_mode
    cmp al, 'M'
    je .toggle_mode

    cmp al, 'a'
    je .enter_alarm_setup
    cmp al, 'A'
    je .enter_alarm_setup

    ; Teclas exclusivas del Cronómetro (Modo 1)
    cmp byte [current_mode], 1
    jne .delay_and_repeat

    cmp al, 's'
    je .toggle_chrono
    cmp al, 'S'
    je .toggle_chrono

    cmp al, 'r'
    je .reset_chrono
    cmp al, 'R'
    je .reset_chrono

.delay_and_repeat:
    ; Pausa de 50 ms (50,000 microsegundos) para refresco suave
    mov rcx, 50000
    call uefi_stall
    jmp .refresh

; --- Controladores de eventos de teclado ---

.toggle_mode:
    xor byte [current_mode], 1          ; Alterna entre 0 (Reloj) y 1 (Cronómetro)
    call draw_mode_label
    jmp .refresh

.enter_alarm_setup:
    mov byte [current_mode], 2          ; Cambia a modo Configurar Alarma (2)
    mov byte [alarm_input_idx], 0       ; Reinicia índice de entrada
    lea rdi, [alarm_input_buf]
    mov word [rdi + 0], '0'             ; Reinicia buffer a "00:00"
    mov word [rdi + 2], '0'
    mov word [rdi + 4], ':'
    mov word [rdi + 6], '0'
    mov word [rdi + 8], '0'
    mov word [rdi + 10], 0
    call draw_mode_label
    jmp .refresh

.cancel_alarm_key:
    call cancel_alarm                   ; Desactiva alarma y silencia parpadeo
    ; Limpiar inmediatamente el banner de alarma
    mov rdx, 27
    mov r8, 12
    call uefi_set_cursor
    lea rdx, [msg_clear_ringing]
    call uefi_print_string
    jmp .refresh

.handle_alarm_input:
    ; Filtrar solo caracteres numéricos ('0' - '9')
    cmp al, '0'
    jl .delay_and_repeat
    cmp al, '9'
    jg .delay_and_repeat

    ; Obtener índice actual (0-4)
    xor rbx, rbx
    mov bl, byte [alarm_input_idx]

    ; Si el índice es 2, saltar el separador ':'
    cmp bl, 2
    jne .save_digit
    inc bl
    inc byte [alarm_input_idx]

.save_digit:
    ; Guardar carácter UTF-16 en la posición (offset = rbx * 2) usando base RDI
    lea rdi, [alarm_input_buf]
    movzx dx, al
    mov [rdi + rbx * 2], dx
    inc byte [alarm_input_idx]

    ; Si ya se ingresaron los 4 dígitos (índice alcanzó 5), armar alarma
    cmp byte [alarm_input_idx], 5
    jne .delay_and_repeat

    call save_alarm_from_buffer         ; Convierte cadena a enteros y arma alarma
    mov byte [current_mode], 0          ; Regresa automáticamente a Modo Reloj
    call draw_mode_label
    jmp .refresh

.toggle_chrono:
    call chrono_start_stop              ; Inicia o pausa el conteo
    jmp .refresh

.reset_chrono:
    call chrono_reset                   ; Reinicia cronómetro a 00:00
    jmp .refresh

.exit:
    add rsp, 40
    ret

; ==============================================================================
; Sección de Datos
; ==============================================================================
section .data

; Punteros globales UEFI
align 8
ImageHandle     dq 0
SystemTable     dq 0
ConOut          dq 0
ConIn           dq 0
RuntimeServices dq 0
BootServices    dq 0

; Variable de modo actual: 0=Reloj, 1=Cronómetro, 2=Config Alarma
current_mode    db 0

; Mensajes de bienvenida en formato UTF-16
msg_line1:
    dw __utf16__('======================================================='), 13, 10, 0
msg_line2:
    dw __utf16__('INSTITUTO TECNOLOGICO DE COSTA RICA - CE4303'), 13, 10, 0
msg_line3:
    dw __utf16__('TAREA 1: RELOJ / CRONOMETRO CON ALARMA (UEFI x86_64)'), 13, 10, 0
msg_prompt:
    dw __utf16__('[ Presione ENTER para ingresar al modo interactivo ]'), 13, 10, 0

; Mensajes del Dashboard en formato UTF-16
msg_dash_title:
    dw __utf16__('CE4303 - TAREA 1 (MODO UEFI x86_64)'), 13, 10, 0
msg_separator:
    dw __utf16__('----------------------------------------------------------------------------'), 13, 10, 0

msg_mode_clock:
    dw __utf16__('[ MODO ACTUAL: RELOJ EN TIEMPO REAL ]   '), 13, 10, 0
msg_mode_chrono:
    dw __utf16__('[ MODO ACTUAL: CRONOMETRO ]             '), 13, 10, 0
msg_mode_alarm:
    dw __utf16__('[ MODO ACTUAL: CONFIGURAR ALARMA ]      '), 13, 10, 0
msg_clear_time:
    dw __utf16__('                  '), 13, 10, 0

msg_ringing:
    dw __utf16__(' >>> ALARMA ACTIVADA <<< '), 0
msg_clear_ringing:
    dw __utf16__('                         '), 0

msg_help:
    dw __utf16__(' [M] Modo | [A] Alarma | [C] Cancelar Alarma | [S/R] Crono | [Q] Salir'), 13, 10, 0
msg_exit:
    dw __utf16__('Sistema Finalizado con Exito.'), 13, 10, 0
