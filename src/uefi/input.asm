; ==============================================================================
; src/uefi/input.asm - Manejo de Teclado y Tiempo en UEFI (ConIn / BootServices)
; ==============================================================================

default rel
bits 64

; ------------------------------------------------------------------------------
; Offsets en EFI_SIMPLE_TEXT_INPUT_PROTOCOL (ConIn)
; ------------------------------------------------------------------------------
%define OFFSET_CONIN_RESET          0x00
%define OFFSET_CONIN_READ_KEY       0x08
%define OFFSET_CONIN_WAIT_FOR_KEY   0x10

; Offsets en EFI_BOOT_SERVICES
%define OFFSET_BOOTSERVICES_STALL   0xF8        ; Stall(UINTN Microseconds) -> offset 248

; ------------------------------------------------------------------------------
; uefi_check_key: Consulta no bloqueante de tecla presionada en el buffer
; Salida:
;   ZF = 1 (Zero Flag = 1): NO hay tecla presionada en el buffer.
;   ZF = 0 (Zero Flag = 0): SÍ hay tecla presionada.
;   AL = Carácter ASCII/Unicode de la tecla presionada.
;   DX = ScanCode de la tecla (para teclas especiales como flechas/F1-F12).
; ------------------------------------------------------------------------------
uefi_check_key:
    sub rsp, 40

    mov rax, [ConIn]
    mov rcx, rax                        ; RCX = ConIn (This)
    lea rdx, [uefi_key_data]            ; RDX = &EFI_INPUT_KEY
    call [rax + OFFSET_CONIN_READ_KEY]

    ; Si RAX != 0 (EFI_NOT_READY u otro error), no hay tecla lista
    test rax, rax
    jnz .no_key

    ; Si se leyó una tecla exitosamente:
    movzx edx, word [uefi_key_data + 0] ; DX = ScanCode
    movzx eax, word [uefi_key_data + 2] ; AL = UnicodeChar (ASCII)

    ; Asegurar que ZF = 0 (indicando que hay tecla válida)
    or rsp, 0                           ; No modifica registros, pero asegura ZF=0 (RSP nunca es 0)
    cmp al, -1                          ; AL nunca es -1, asegura ZF=0
    jmp .done

.no_key:
    xor al, al
    cmp al, 0                           ; Establece ZF = 1 (indicando que no hay tecla)

.done:
    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; uefi_wait_enter: Espera de forma bloqueante hasta que el usuario pulse ENTER
; ------------------------------------------------------------------------------
uefi_wait_enter:
    sub rsp, 40

.poll_enter:
    mov rax, [ConIn]
    mov rcx, rax
    lea rdx, [uefi_key_data]
    call [rax + OFFSET_CONIN_READ_KEY]

    test rax, rax
    jnz .poll_enter                     ; Si no hay tecla, seguir esperando

    movzx eax, word [uefi_key_data + 2] ; UnicodeChar
    cmp ax, 0x000D                      ; Carriage Return (ENTER)
    je .enter_pressed
    cmp ax, 0x000A                      ; Line Feed
    je .enter_pressed
    jmp .poll_enter

.enter_pressed:
    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; uefi_stall: Pausa la ejecución durante N microsegundos
; Entrada: RCX = Microsegundos (ej: 50000 = 50 ms, 1000000 = 1 segundo)
; ------------------------------------------------------------------------------
uefi_stall:
    sub rsp, 40
    mov rax, [BootServices]
    ; RCX ya contiene el número de microsegundos
    call [rax + OFFSET_BOOTSERVICES_STALL]
    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; Datos del módulo de entrada
; ------------------------------------------------------------------------------
section .data
align 8
uefi_key_data:
    dw 0                                ; ScanCode (2 bytes)
    dw 0                                ; UnicodeChar (2 bytes)
    dd 0                                ; Padding a 8 bytes
