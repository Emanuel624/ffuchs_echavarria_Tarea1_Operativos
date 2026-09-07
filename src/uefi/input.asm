; ==============================================================================
; src/uefi/input.asm - Manejo de Teclado y Temporizador en UEFI
; ==============================================================================
; Utiliza el protocolo EFI_SIMPLE_TEXT_INPUT_PROTOCOL (ConIn) para leer
; teclas y el servicio Stall para generar retardos de tiempo.
; ==============================================================================

default rel
bits 64

; ------------------------------------------------------------------------------
; Offsets en la estructura EFI_SIMPLE_TEXT_INPUT_PROTOCOL (ConIn)
; ------------------------------------------------------------------------------
%define OFFSET_CONIN_RESET          0x00        ; Reset(This, ExtendedVerification)
%define OFFSET_CONIN_READ_KEY       0x08        ; ReadKeyStroke(This, *Key)
%define OFFSET_CONIN_WAIT_FOR_KEY   0x10        ; WaitForKey (Event Handle)

; ------------------------------------------------------------------------------
; Offsets en EFI_BOOT_SERVICES
; ------------------------------------------------------------------------------
%define OFFSET_BOOTSERVICES_STALL   0xF8        ; Stall offset 248 (0xF8)

section .text

; ------------------------------------------------------------------------------
; uefi_check_key: Consulta no bloqueante del buffer de teclado
;
;   Llama a ConIn->ReadKeyStroke.
;   - Si no hay tecla lista, la función retorna EFI_NOT_READY (código distinto de 0).
;   - Si hay tecla, retorna EFI_SUCCESS (0) y llena la estructura EFI_INPUT_KEY.
;
; Salida:
;   ZF = 1 (Zero Flag activo): NO hay tecla presionada.
;   ZF = 0 (Zero Flag inactivo): SÍ hay tecla presionada.
;   AL = Carácter ASCII de la tecla presionada (UnicodeChar).
;   DX = ScanCode de la tecla (para flechas o teclas especiales).
; ------------------------------------------------------------------------------
uefi_check_key:
    sub rsp, 40

    mov rax, [ConIn]
    mov rcx, rax                        ; RCX = ConIn (This)
    lea rdx, [uefi_key_data]            ; RDX = Puntero a la estructura EFI_INPUT_KEY
    call [rax + OFFSET_CONIN_READ_KEY]  ; Invoca ReadKeyStroke

    ; Si RAX != 0 (EFI_NOT_READY), no hay tecla
    test rax, rax
    jnz .no_key

    ; Si RAX == 0 (EFI_SUCCESS), tecla con éxito
    movzx edx, word [uefi_key_data + 0] ; DX = ScanCode (offset 0)
    movzx eax, word [uefi_key_data + 2] ; AL = UnicodeChar / ASCII 


    cmp al, -1                          ; AL nunca vale -1, por lo que ZF queda en 0
    jmp .done

.no_key:
    xor al, al
    cmp al, 0                           ;

.done:
    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; uefi_wait_enter: Espera bloqueante hasta que el usuario pulse la tecla ENTER
; Comprueba repetidamente el buffer 
; ------------------------------------------------------------------------------
uefi_wait_enter:
    sub rsp, 40

.poll_enter:
    mov rax, [ConIn]
    mov rcx, rax                        ; RCX = ConIn (This)
    lea rdx, [uefi_key_data]            ; RDX = &EFI_INPUT_KEY
    call [rax + OFFSET_CONIN_READ_KEY]

    ; Si no hay tecla en el buffer (RAX != 0), seguir en sondeo
    test rax, rax
    jnz .poll_enter

    ; Comprobar si la tecla pulsada es ENTER (Carriage Return = 0x0D / Line Feed = 0x0A)
    movzx eax, word [uefi_key_data + 2]
    cmp ax, 0x000D
    je .enter_pressed
    cmp ax, 0x000A
    je .enter_pressed
    jmp .poll_enter                     ; Si fue otra tecla, ignora y sigue esperando

.enter_pressed:
    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; uefi_stall: Pausa la CPU durante una cantidad exacta de microsegundos
; Utiliza el temporizador del firmware (BootServices->Stall).
; Entrada:
;   RCX = Microsegundos (50,000 us = 50 ms)
; ------------------------------------------------------------------------------
uefi_stall:
    sub rsp, 40
    mov rax, [BootServices]
    ; RCX ya contiene los microsegundos (primer argumento en x64 ABI)
    call [rax + OFFSET_BOOTSERVICES_STALL]
    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; Datos del módulo de entrada
; ------------------------------------------------------------------------------
section .data

; Estructura estándar EFI_INPUT_KEY (4 bytes según especificación UEFI)
align 8
uefi_key_data:
    dw 0                                ; Offset 0: ScanCode (UINT16)
    dw 0                                ; Offset 2: UnicodeChar (CHAR16)
    dd 0                                ; Padding a 8 bytes para alineación en memoria
