; ==============================================================================
; src/uefi/main.asm - Aplicación y Dashboard UEFI en x86_64
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
; draw_mode_label: Dibuja la etiqueta según current_mode (0=Reloj, 1=Cronómetro)
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

.draw_chrono:
    lea rdx, [msg_mode_chrono]
    call uefi_print_string
    jmp .clear_time_line

.draw_clock:
    lea rdx, [msg_mode_clock]
    call uefi_print_string

.clear_time_line:
    ; Limpiar la línea central para evitar caracteres residuales
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

    ; 3. Renderizar según el modo actual
    cmp byte [current_mode], 0
    je .render_clock

.render_chrono:
    call chrono_format_string
    mov rdx, 37                         ; Columna 37 para "MM:SS"
    mov r8, 8                           ; Fila 8
    call uefi_set_cursor
    mov rdx, COLOR_GREEN_ON_BLACK
    call uefi_set_color
    lea rdx, [chrono_buffer]
    call uefi_print_string
    jmp .check_input

.render_clock:
    call uefi_format_time_string
    mov rdx, 36                         ; Columna 36 para "HH:MM:SS"
    mov r8, 8                           ; Fila 8
    call uefi_set_cursor
    mov rdx, COLOR_YELLOW_ON_BLACK
    call uefi_set_color
    lea rdx, [time_buffer]
    call uefi_print_string

.check_input:
    ; 4. Comprobar si el usuario presionó una tecla (sin bloqueo)
    call uefi_check_key
    jz .delay_and_repeat                ; Si ZF = 1 (no hay tecla), pasar al retardo

    ; 5. Procesar tecla
    cmp al, 'q'
    je .exit
    cmp al, 'Q'
    je .exit

    cmp al, 'm'
    je .toggle_mode
    cmp al, 'M'
    je .toggle_mode

    ; Teclas exclusivas del Cronómetro (o globales)
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

; Variable de modo actual
current_mode    db 0                    ; 0 = Reloj, 1 = Cronómetro

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
    dw __utf16__('CE4303 - SISTEMA EMBEBIDO BOOTEABLE (MODO UEFI x86_64)'), 13, 10, 0
msg_separator:
    dw __utf16__('----------------------------------------------------------------------------'), 13, 10, 0

msg_mode_clock:
    dw __utf16__('[ MODO ACTUAL: RELOJ EN TIEMPO REAL ]   '), 13, 10, 0
msg_mode_chrono:
    dw __utf16__('[ MODO ACTUAL: CRONOMETRO ]             '), 13, 10, 0
msg_clear_time:
    dw __utf16__('                  '), 13, 10, 0

msg_help:
    dw __utf16__(' [M] Modo | [S] Start/Stop | [R] Reset | [Q] Salir'), 13, 10, 0
msg_exit:
    dw __utf16__('Sistema Finalizado con Exito.'), 13, 10, 0
