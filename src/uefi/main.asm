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

    ; Etiqueta de Modo (Fila 5, Columna 22)
    mov rdx, 22
    mov r8, 5
    call uefi_set_cursor
    mov rdx, COLOR_WHITE_ON_BLACK
    call uefi_set_color
    lea rdx, [msg_mode_clock]
    call uefi_print_string

    ; Ayuda de Controles (Fila 22, Columna 2)
    mov rdx, 2
    mov r8, 22
    call uefi_set_cursor
    mov rdx, COLOR_LIGHTGRAY
    call uefi_set_color
    lea rdx, [msg_help]
    call uefi_print_string

    add rsp, 40
    ret

; ==============================================================================
; main_loop: Bucle interactivo en tiempo real
; ==============================================================================
main_loop:
    sub rsp, 40

.refresh:
    ; 1. Formatear la hora actual en time_buffer
    call uefi_format_time_string

    ; 2. Posicionar cursor en la zona central de tiempo (Fila 8, Columna 36)
    mov rdx, 36                         ; Columna 36
    mov r8, 8                           ; Fila 8
    call uefi_set_cursor

    ; 3. Imprimir hora actual en color amarillo brillante
    mov rdx, COLOR_YELLOW_ON_BLACK
    call uefi_set_color
    lea rdx, [time_buffer]
    call uefi_print_string

    ; 4. Comprobar si el usuario presionó una tecla (sin bloqueo)
    call uefi_check_key
    test rax, rax
    jnz .delay_and_repeat               ; Si no hay tecla, pasar al retardo

    ; 5. Procesar tecla presionada
    cmp al, 'q'
    je .exit
    cmp al, 'Q'
    je .exit

.delay_and_repeat:
    ; Pausa de 50 ms (50,000 microsegundos) para no saturar CPU y refrescar fluido
    mov rcx, 50000
    call uefi_stall
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
    dw __utf16__('[ MODO ACTUAL: RELOJ EN TIEMPO REAL ]'), 13, 10, 0
msg_help:
    dw __utf16__(' [Q] Salir del Sistema'), 13, 10, 0
msg_exit:
    dw __utf16__('Sistema Finalizado con Exito.'), 13, 10, 0
