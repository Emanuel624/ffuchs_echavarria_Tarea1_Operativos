; ==============================================================================
; src/uefi/main.asm - Tarea Booteable UEFI en x86_64
; Tarea 1: Reloj/Cronómetro con Alarma (CE4303 - Principios de Sistemas Operativos)
; ==============================================================================
; Este archivo constituye el punto de entrada oficial para el estándar UEFI (64 bits).
; Se compila como aplicación PE32+ (BOOTX64.EFI) que arranca de forma nativa
; desde el firmware de la placa madre sin sistema operativo previo
; ==============================================================================

default rel
bits 64

; ------------------------------------------------------------------------------
; Offsets en EFI_SYSTEM_TABLE (Arquitectura de 64 bits = punteros de 8 bytes)
; ------------------------------------------------------------------------------
%define OFFSET_CONIN                0x30        ; SystemTable -> ConIn (Teclado)
%define OFFSET_CONOUT               0x40        ; SystemTable -> ConOut (Pantalla)
%define OFFSET_RUNTIME_SERVICES     0x58        ; SystemTable -> RuntimeServices (RTC, etc.)
%define OFFSET_BOOT_SERVICES        0x60        ; SystemTable -> BootServices (Memoria, Stall)

; ------------------------------------------------------------------------------
; Inclusión de Módulos UEFI
; ------------------------------------------------------------------------------
%include "src/uefi/screen.asm"                  ; Control de pantalla, cursor y colores
%include "src/uefi/input.asm"                   ; Teclado no bloqueante y retardos
%include "src/uefi/rtc.asm"                     ; Reloj RTC y formato
%include "src/uefi/chrono.asm"                  ; Cronómetro 
%include "src/uefi/alarm.asm"                   ; Configuración, salto y cancelación de alarma

section .text
global efi_main

; ==============================================================================
; efi_main: Punto de entrada directamente por el firmware UEFI
;
; Argumentos según x64:
;   RCX = EFI_HANDLE ImageHandle        (Maneja la imagen cargada)
;   RDX = EFI_SYSTEM_TABLE *SystemTable (Tabla principal con servicios)
; ==============================================================================
efi_main:
    ; Reserva de 32 bytes de  Space + 8 bytes para alinear RSP a 16 bytes
    sub rsp, 40

    ; 1. Guardar punteros importantes
    mov [ImageHandle], rcx
    mov [SystemTable], rdx

    ; Extrae punteros a los protocolos y servicios desde SystemTable
    mov rax, [rdx + OFFSET_CONOUT]
    mov [ConOut], rax

    mov rax, [rdx + OFFSET_CONIN]
    mov [ConIn], rax

    mov rax, [rdx + OFFSET_RUNTIME_SERVICES]
    mov [RuntimeServices], rax

    mov rax, [rdx + OFFSET_BOOT_SERVICES]
    mov [BootServices], rax

    ; 2. Preparar pantalla inicial: limpiar y ocultar cursor
    call uefi_clear_screen
    call uefi_hide_cursor

    ; 3. Mostrar la pantalla institucional de bienvenida
    call show_welcome_screen

    ; 4. Esperar confirmación del usuario (tecla ENTER) antes de entrar al modo interactivo
    call uefi_wait_enter

    ; 5. Dibujar el marco estático del Dashboard (título, separador, controles)
    call draw_dashboard_ui

    ; 6. Iniciar el bucle interactivo principal en tiempo real
    call main_loop

    ; 7. Finalización limpia del programa
    call uefi_clear_screen
    mov rdx, 25                         ; Columna 25
    mov r8, 10                          ; Fila 10
    call uefi_set_cursor
    mov rdx, COLOR_WHITE_ON_BLACK
    call uefi_set_color
    lea rdx, [msg_exit]
    call uefi_print_string

    ; Pausa de 2 segundos antes de transferir el control de regreso al firmware
    mov rcx, 2000000                    ; 2,000,000 µs = 2 segundos
    call uefi_stall

    call uefi_show_cursor
    call uefi_clear_screen

    ; Retornar EFI_SUCCESS (0)
    add rsp, 40
    xor rax, rax
    ret

; ==============================================================================
; show_welcome_screen: Dibuja la pantalla inicial institucional
; ==============================================================================
show_welcome_screen:
    sub rsp, 40

    ; Separador superior decorativo (Fila 4, Columna 12)
    mov rdx, 12
    mov r8, 4
    call uefi_set_cursor
    mov rdx, COLOR_CYAN_ON_BLACK
    call uefi_set_color
    lea rdx, [msg_line1]
    call uefi_print_string

    ; Nombre de la institución (Fila 6, Columna 16)
    mov rdx, 16
    mov r8, 6
    call uefi_set_cursor
    mov rdx, COLOR_WHITE_ON_BLACK
    call uefi_set_color
    lea rdx, [msg_line2]
    call uefi_print_string

    ; Título del proyecto (Fila 8, Columna 14)
    mov rdx, 14
    mov r8, 8
    call uefi_set_cursor
    mov rdx, COLOR_YELLOW_ON_BLACK
    call uefi_set_color
    lea rdx, [msg_line3]
    call uefi_print_string

    ; Mensaje de solicitud de confirmación (Fila 14, Columna 14)
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
; draw_dashboard_ui: Dibuja el marco estático y las leyendas del Dashboard
; ==============================================================================
draw_dashboard_ui:
    sub rsp, 40

    call uefi_clear_screen

    ; Título superior del sistema (Fila 1, Columna 2)
    mov rdx, 2
    mov r8, 1
    call uefi_set_cursor
    mov rdx, COLOR_CYAN_ON_BLACK
    call uefi_set_color
    lea rdx, [msg_dash_title]
    call uefi_print_string

    ; Línea separadora (Fila 2, Columna 2)
    mov rdx, 2
    mov r8, 2
    call uefi_set_cursor
    mov rdx, COLOR_WHITE_ON_BLACK
    call uefi_set_color
    lea rdx, [msg_separator]
    call uefi_print_string

    ; Barra de ayuda con los controles interactivos (Fila 22, Columna 2)
    mov rdx, 2
    mov r8, 22
    call uefi_set_cursor
    mov rdx, COLOR_LIGHTGRAY
    call uefi_set_color
    lea rdx, [msg_help]
    call uefi_print_string

    ; Dibujar la etiqueta correspondiente al modo inicial (Reloj)
    call draw_mode_label

    add rsp, 40
    ret

; ==============================================================================
; draw_mode_label: Actualiza la etiqueta de modo y limpia la línea de tiempo
; current_mode: 0 = Modo Reloj, 1 = Modo Cronómetro, 2 = Modo Configurar Alarma
; ==============================================================================
draw_mode_label:
    sub rsp, 40

    ; Posicionar cursor en la zona de etiqueta (Fila 5, Columna 22)
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
    ; Limpiar la línea central para evitar caracteres sobrantes entre "HH:MM:SS" y "MM:SS"
    mov rdx, 34
    mov r8, 8
    call uefi_set_cursor
    lea rdx, [msg_clear_time]
    call uefi_print_string

    add rsp, 40
    ret

; ==============================================================================
; main_loop: Bucle interactivo
; Coordina la actualización de periféricos, timers y entrada de teclado
; ==============================================================================
main_loop:
    sub rsp, 40

.refresh:
    ; 1. Actualizar siempre la hora actual del RTC desde el hardware
    call uefi_get_time

    ; 2. Actualizar contadores del cronómetro si está corriendo
    call chrono_update

    ; 3. Verificar si coincide la hora de la alarma
    call check_alarm

    ; 4. Desplegar el banner de alerta visual de alarma
    mov rdx, 27                         ; Columna 27
    mov r8, 12                          ; Fila 12
    call uefi_set_cursor

    cmp byte [alarm_triggered], 1
    jne .clear_alarm_banner

    ; Efecto de parpadeo
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
    ; 5. Desplegar la información según el modo
    cmp byte [current_mode], 0
    je .render_clock
    cmp byte [current_mode], 1
    je .render_chrono

.render_alarm_setup:                    ; Modo 2: Configurar Alarma
    mov rdx, 37                         ; Columna 37
    mov r8, 8                           ; Fila 8
    call uefi_set_cursor
    mov rdx, COLOR_LIGHTCYAN
    call uefi_set_color
    lea rdx, [alarm_input_buf]
    call uefi_print_string
    jmp .check_input

.render_chrono:                         ; Modo 1: Cronómetro ("MM:SS")
    call chrono_format_string
    mov rdx, 37                         ; Columna 37
    mov r8, 8                           ; Fila 8
    call uefi_set_cursor
    mov rdx, COLOR_GREEN_ON_BLACK
    call uefi_set_color
    lea rdx, [chrono_buffer]
    call uefi_print_string
    jmp .check_input

.render_clock:                          ; Modo 0: Reloj ("HH:MM:SS")
    call uefi_format_time_string
    mov rdx, 36                         ; Columna 36
    mov r8, 8                           ; Fila 8
    call uefi_set_cursor
    mov rdx, COLOR_YELLOW_ON_BLACK
    call uefi_set_color
    lea rdx, [time_buffer]
    call uefi_print_string

.check_input:
    ; 6. Consulta no bloqueante de tecla presionada
    call uefi_check_key
    jz .delay_and_repeat                ; Si ZF = 1 (no hay tecla), pausar y repetir ciclo

    ; 7. Despacho de comandos de teclado
    cmp al, 'q'
    je .exit
    cmp al, 'Q'
    je .exit

    cmp al, 'c'
    je .cancel_alarm_key
    cmp al, 'C'
    je .cancel_alarm_key

    ; Si esta configurando la alarma, procesar la entrada de dígitos (0-9)
    cmp byte [current_mode], 2
    je .handle_alarm_input

    ; Modos estándar (Reloj y Cronómetro)
    cmp al, 'm'
    je .toggle_mode
    cmp al, 'M'
    je .toggle_mode

    cmp al, 'a'
    je .enter_alarm_setup
    cmp al, 'A'
    je .enter_alarm_setup

    ; Teclas exclusivas del Cronómetro
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
    ; Pausa de 50 ms para generar una tasa de refresco suave
    mov rcx, 50000
    call uefi_stall
    jmp .refresh

; ------------------------------------------------------------------------------
; Manejadores de Eventos de Teclado
; ------------------------------------------------------------------------------

.toggle_mode:
    xor byte [current_mode], 1          ; Alterna el bit entre 0 (Reloj) y 1 (Cronómetro)
    call draw_mode_label
    jmp .refresh

.enter_alarm_setup:
    mov byte [current_mode], 2          ; Activa Modo Configurar Alarma
    mov byte [alarm_input_idx], 0       ; Reinicia cursor de entrada
    ; Reinicializa el buffer UTF-16
    lea rdi, [alarm_input_buf]
    mov word [rdi + 0], '0'
    mov word [rdi + 2], '0'
    mov word [rdi + 4], ':'
    mov word [rdi + 6], '0'
    mov word [rdi + 8], '0'
    mov word [rdi + 10], 0
    call draw_mode_label
    jmp .refresh

.cancel_alarm_key:
    call cancel_alarm                   ; Desactiva alarma y apaga parpadeo
    ; Limpia de inmediato el texto de alarma
    mov rdx, 27
    mov r8, 12
    call uefi_set_cursor
    lea rdx, [msg_clear_ringing]
    call uefi_print_string
    jmp .refresh

.handle_alarm_input:
    ; Filtrar solo dígitos válidos ('0' al '9')
    cmp al, '0'
    jl .delay_and_repeat
    cmp al, '9'
    jg .delay_and_repeat

    ; Obtener la posición del dígito actual
    xor rbx, rbx
    mov bl, byte [alarm_input_idx]

    ; Si la posición es el separador ':', saltar a 3
    cmp bl, 2
    jne .save_digit
    inc bl
    inc byte [alarm_input_idx]

.save_digit:
    ; Guarda el carácter UTF-16 en el buffer
    lea rdi, [alarm_input_buf]
    movzx dx, al
    mov [rdi + rbx * 2], dx
    inc byte [alarm_input_idx]

    ; Si ya se ingresaron los 4 dígitos, arma alarma
    cmp byte [alarm_input_idx], 5
    jne .delay_and_repeat

    call save_alarm_from_buffer         ; Convierte cadena a horas/minutos numéricos
    mov byte [current_mode], 0          ; Regresa automáticamente a Modo Reloj
    call draw_mode_label
    jmp .refresh

.toggle_chrono:
    call chrono_start_stop              ; Alterna entre Iniciar y Pausar cronómetro
    jmp .refresh

.reset_chrono:
    call chrono_reset                   ; Pone a cero los contadores del cronómetro
    jmp .refresh

.exit:
    add rsp, 40
    ret

; ==============================================================================
; Sección de Datos
; ==============================================================================
section .data

; Punteros globales
align 8
ImageHandle     dq 0
SystemTable     dq 0
ConOut          dq 0
ConIn           dq 0
RuntimeServices dq 0
BootServices    dq 0

; Variable de modo: 0 = Modo Reloj, 1 = Modo Cronómetro, 2 = Modo Configurar Alarma
current_mode    db 0

; Cadenas de la pantalla
msg_line1:
    dw __utf16__('======================================================='), 13, 10, 0
msg_line2:
    dw __utf16__('INSTITUTO TECNOLOGICO DE COSTA RICA - CE4303'), 13, 10, 0
msg_line3:
    dw __utf16__('TAREA 1: RELOJ / CRONOMETRO CON ALARMA (UEFI x86_64)'), 13, 10, 0
msg_prompt:
    dw __utf16__('[ Presione ENTER para ingresar al modo interactivo ]'), 13, 10, 0

; Cadenas del interactivo 
msg_dash_title:
    dw __utf16__('CE4303 - TAREA 1 (UEFI x86_64)'), 13, 10, 0
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
