; ==============================================================================
; src/uefi/main.asm - Aplicación UEFI Booteable en x86_64
; Tarea 1: Reloj/Cronómetro con Alarma (Paso 1: Bienvenida Institucional)
; ==============================================================================

default rel
bits 64

; ------------------------------------------------------------------------------
; Offsets en EFI_SYSTEM_TABLE (Arquitectura x86_64 de 64 bits)
; ------------------------------------------------------------------------------
%define OFFSET_CONIN                0x30        ; SystemTable -> ConIn
%define OFFSET_CONOUT               0x40        ; SystemTable -> ConOut
%define OFFSET_RUNTIME_SERVICES     0x58        ; SystemTable -> RuntimeServices
%define OFFSET_BOOT_SERVICES        0x60        ; SystemTable -> BootServices

; ------------------------------------------------------------------------------
; Offsets en EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL (ConOut)
; ------------------------------------------------------------------------------
%define OFFSET_CONOUT_RESET         0x00
%define OFFSET_CONOUT_OUTPUT_STRING 0x08
%define OFFSET_CONOUT_SET_ATTRIBUTE 0x28
%define OFFSET_CONOUT_CLEAR_SCREEN  0x30
%define OFFSET_CONOUT_SET_CURSOR    0x38
%define OFFSET_CONOUT_ENABLE_CURSOR 0x40

; ------------------------------------------------------------------------------
; Offsets en EFI_SIMPLE_TEXT_INPUT_PROTOCOL (ConIn)
; ------------------------------------------------------------------------------
%define OFFSET_CONIN_RESET          0x00
%define OFFSET_CONIN_READ_KEY       0x08
%define OFFSET_CONIN_WAIT_FOR_KEY   0x10

; Atributos de color para ConOut->SetAttribute
%define COLOR_WHITE_ON_BLACK        0x0F
%define COLOR_YELLOW_ON_BLACK       0x0E
%define COLOR_CYAN_ON_BLACK         0x0B
%define COLOR_WHITE_ON_BLUE         0x1F

section .text
global efi_main

; ==============================================================================
; Punto de Entrada UEFI (efi_main)
; Argumentos según Microsoft x64 Fastcall ABI:
;   RCX = EFI_HANDLE ImageHandle
;   RDX = EFI_SYSTEM_TABLE *SystemTable
; ==============================================================================
efi_main:
    ; Reserva de shadow space y alineación a 16 bytes (RSP % 16 == 0)
    sub rsp, 40

    ; Guardar punteros de la arquitectura UEFI
    mov [ImageHandle], rcx
    mov [SystemTable], rdx

    ; Obtener punteros a ConOut y ConIn desde SystemTable
    mov rax, [rdx + OFFSET_CONOUT]
    mov [ConOut], rax

    mov rax, [rdx + OFFSET_CONIN]
    mov [ConIn], rax

    ; 1. Limpiar pantalla y ocultar cursor
    call uefi_clear_screen
    call uefi_hide_cursor

    ; 2. Mostrar la pantalla de bienvenida institucional
    call show_welcome_screen

    ; 3. Esperar confirmación del usuario (tecla ENTER)
    call wait_for_enter_key

    ; 4. Mostrar confirmación de acceso al sistema
    call show_access_granted

    ; 5. Bucle de finalización o pausa antes de salir
.loop_wait_exit:
    ; Esperar cualquier tecla para salir limpiamente o continuar
    call wait_any_key

    ; Restaurar atributos normales y limpiar antes de salir
    mov rdx, COLOR_WHITE_ON_BLACK
    call uefi_set_color
    call uefi_clear_screen

    ; Liberar espacio de pila y retornar EFI_SUCCESS (0)
    add rsp, 40
    xor rax, rax                        ; RAX = EFI_SUCCESS (0)
    ret

; ==============================================================================
; show_welcome_screen: Dibuja la pantalla inicial con datos del TEC
; ==============================================================================
show_welcome_screen:
    sub rsp, 40

    ; Línea 1: Separador superior
    mov rdx, 12                         ; Columna 12
    mov r8, 4                           ; Fila 4
    call uefi_set_cursor
    mov rdx, COLOR_CYAN_ON_BLACK
    call uefi_set_color
    lea rdx, [msg_line1]
    call uefi_print_string

    ; Línea 2: Nombre de la Institución
    mov rdx, 16                         ; Columna 16
    mov r8, 6                           ; Fila 6
    call uefi_set_cursor
    mov rdx, COLOR_WHITE_ON_BLACK
    call uefi_set_color
    lea rdx, [msg_line2]
    call uefi_print_string

    ; Línea 3: Tarea y Modo UEFI
    mov rdx, 14                         ; Columna 14
    mov r8, 8                           ; Fila 8
    call uefi_set_cursor
    mov rdx, COLOR_YELLOW_ON_BLACK
    call uefi_set_color
    lea rdx, [msg_line3]
    call uefi_print_string

    ; Línea 4: Prompt para continuar
    mov rdx, 14                         ; Columna 14
    mov r8, 14                          ; Fila 14
    call uefi_set_cursor
    mov rdx, COLOR_WHITE_ON_BLACK
    call uefi_set_color
    lea rdx, [msg_prompt]
    call uefi_print_string

    add rsp, 40
    ret

; ==============================================================================
; show_access_granted: Muestra confirmación al pulsar ENTER
; ==============================================================================
show_access_granted:
    sub rsp, 40

    call uefi_clear_screen

    mov rdx, 16                         ; Columna 16
    mov r8, 10                          ; Fila 10
    call uefi_set_cursor
    mov rdx, COLOR_CYAN_ON_BLACK
    call uefi_set_color
    lea rdx, [msg_granted]
    call uefi_print_string

    mov rdx, 14                         ; Columna 14
    mov r8, 14                          ; Fila 14
    call uefi_set_cursor
    mov rdx, COLOR_WHITE_ON_BLACK
    call uefi_set_color
    lea rdx, [msg_exit_prompt]
    call uefi_print_string

    add rsp, 40
    ret

; ==============================================================================
; wait_for_enter_key: Espera a que el usuario presione la tecla ENTER (0x000D)
; ==============================================================================
wait_for_enter_key:
    sub rsp, 40

.poll_key:
    mov rax, [ConIn]
    mov rcx, rax                        ; RCX = ConIn (This)
    lea rdx, [key_data]                 ; RDX = &EFI_INPUT_KEY
    call [rax + OFFSET_CONIN_READ_KEY]

    ; Si RAX == 0 (EFI_SUCCESS), se leyó una tecla
    test rax, rax
    jnz .poll_key                       ; Si no hay tecla lista, seguir esperando

    ; Verificar si es la tecla ENTER (UnicodeChar == 0x000D o 0x000A)
    movzx eax, word [key_data + 2]      ; UnicodeChar está en offset 2
    cmp ax, 0x000D
    je .done
    cmp ax, 0x000A
    je .done
    jmp .poll_key                       ; Si no es ENTER, seguir esperando

.done:
    add rsp, 40
    ret

; ==============================================================================
; wait_any_key: Espera cualquier tecla del usuario
; ==============================================================================
wait_any_key:
    sub rsp, 40

.poll_any:
    mov rax, [ConIn]
    mov rcx, rax
    lea rdx, [key_data]
    call [rax + OFFSET_CONIN_READ_KEY]
    test rax, rax
    jnz .poll_any

    add rsp, 40
    ret

; ==============================================================================
; Funciones Auxiliares de Interfaz UEFI
; ==============================================================================

; Limpiar Pantalla
uefi_clear_screen:
    sub rsp, 40
    mov rax, [ConOut]
    mov rcx, rax                        ; RCX = ConOut (This)
    call [rax + OFFSET_CONOUT_CLEAR_SCREEN]
    add rsp, 40
    ret

; Ocultar Cursor
uefi_hide_cursor:
    sub rsp, 40
    mov rax, [ConOut]
    mov rcx, rax                        ; RCX = ConOut (This)
    xor rdx, rdx                        ; RDX = 0 (Visible = FALSE)
    call [rax + OFFSET_CONOUT_ENABLE_CURSOR]
    add rsp, 40
    ret

; Posicionar Cursor (RDX = Columna, R8 = Fila)
uefi_set_cursor:
    sub rsp, 40
    mov rax, [ConOut]
    mov rcx, rax                        ; RCX = ConOut (This)
    ; RDX ya contiene Column
    ; R8 ya contiene Row
    call [rax + OFFSET_CONOUT_SET_CURSOR]
    add rsp, 40
    ret

; Establecer Color de Texto y Fondo (RDX = Atributo)
uefi_set_color:
    sub rsp, 40
    mov rax, [ConOut]
    mov rcx, rax                        ; RCX = ConOut (This)
    ; RDX contiene el atributo de color
    call [rax + OFFSET_CONOUT_SET_ATTRIBUTE]
    add rsp, 40
    ret

; Imprimir Cadena UTF-16 (RDX = Puntero a cadena terminada en 0x0000)
uefi_print_string:
    sub rsp, 40
    mov rax, [ConOut]
    mov rcx, rax                        ; RCX = ConOut (This)
    ; RDX contiene puntero a la cadena UTF-16
    call [rax + OFFSET_CONOUT_OUTPUT_STRING]
    add rsp, 40
    ret

; ==============================================================================
; Sección de Datos
; ==============================================================================
section .data

; Punteros UEFI globales
ImageHandle dq 0
SystemTable dq 0
ConOut      dq 0
ConIn       dq 0

; Estructura EFI_INPUT_KEY (ScanCode: 2 bytes, UnicodeChar: 2 bytes)
align 8
key_data:
    dw 0                                ; ScanCode
    dw 0                                ; UnicodeChar
    dd 0                                ; Padding a 8 bytes

; Cadenas de texto en formato UTF-16LE / UCS-2 (terminadas en 0x0000)
msg_line1:
    dw __utf16__('======================================================='), 13, 10, 0
msg_line2:
    dw __utf16__('INSTITUTO TECNOLOGICO DE COSTA RICA - CE4303'), 13, 10, 0
msg_line3:
    dw __utf16__('TAREA 1: RELOJ / CRONOMETRO CON ALARMA (UEFI x86_64)'), 13, 10, 0
msg_prompt:
    dw __utf16__('[ Presione ENTER para ingresar al modo interactivo ]'), 13, 10, 0

msg_granted:
    dw __utf16__('[+] SISTEMA UEFI INICIALIZADO CORRECTAMENTE'), 13, 10, 0
msg_exit_prompt:
    dw __utf16__('[ Presione cualquier tecla para salir/finalizar ]'), 13, 10, 0
