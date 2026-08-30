; ==============================================================================
; src/uefi/rtc.asm - Lectura del RTC (RuntimeServices->GetTime) y Formateo UTF-16
; ==============================================================================

default rel
bits 64

; ------------------------------------------------------------------------------
; Offsets en EFI_RUNTIME_SERVICES
; ------------------------------------------------------------------------------
%define OFFSET_RUNTIMESERVICES_GET_TIME 0x18    ; GetTime(EFI_TIME *Time, ...) -> offset 24

; Offsets dentro de la estructura EFI_TIME (16 bytes en total)
%define EFI_TIME_YEAR               0x00        ; UINT16 (2 bytes)
%define EFI_TIME_MONTH              0x02        ; UINT8  (1 byte)
%define EFI_TIME_DAY                0x03        ; UINT8  (1 byte)
%define EFI_TIME_HOUR               0x04        ; UINT8  (1 byte, 0-23 binario)
%define EFI_TIME_MINUTE             0x05        ; UINT8  (1 byte, 0-59 binario)
%define EFI_TIME_SECOND             0x06        ; UINT8  (1 byte, 0-59 binario)

; ------------------------------------------------------------------------------
; uefi_get_time: Consulta la hora actual al firmware UEFI
; Salida: RAX = EFI_STATUS (0 = EFI_SUCCESS), efi_time_data actualizado
; ------------------------------------------------------------------------------
uefi_get_time:
    sub rsp, 40

    mov rax, [RuntimeServices]
    lea rcx, [efi_time_data]            ; Arg 1: Pointer to EFI_TIME
    xor rdx, rdx                        ; Arg 2: Capabilities = NULL (0)
    call [rax + OFFSET_RUNTIMESERVICES_GET_TIME]

    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; bin_to_utf16_digits: Convierte un número binario (0-59) a 2 caracteres UTF-16
; Entrada:
;   AL = Número binario (0-59)
;   RDI = Puntero de destino donde escribir los 2 caracteres (4 bytes)
; ------------------------------------------------------------------------------
bin_to_utf16_digits:
    movzx ax, al
    mov cl, 10
    div cl                              ; AL = cociente (decenas), AH = residuo (unidades)

    ; Carácter UTF-16 de decena
    movzx dx, al
    add dx, '0'
    mov [rdi], dx                       ; Escribe 2 bytes

    ; Carácter UTF-16 de unidad
    movzx dx, ah
    add dx, '0'
    mov [rdi + 2], dx                   ; Escribe 2 bytes
    ret

; ------------------------------------------------------------------------------
; uefi_format_time_string: Lee el RTC y escribe "HH:MM:SS" en UTF-16 en time_buffer
; Salida: time_buffer contiene la cadena lista para ser impresa con OutputString
; ------------------------------------------------------------------------------
uefi_format_time_string:
    sub rsp, 40

    call uefi_get_time                  ; Obtiene hora actual en efi_time_data

    ; ---- Formatear Horas (HH) ----
    mov al, [efi_time_data + EFI_TIME_HOUR]
    lea rdi, [time_buffer + 0]
    call bin_to_utf16_digits

    ; Separador ':'
    mov word [time_buffer + 4], ':'

    ; ---- Formatear Minutos (MM) ----
    mov al, [efi_time_data + EFI_TIME_MINUTE]
    lea rdi, [time_buffer + 6]
    call bin_to_utf16_digits

    ; Separador ':'
    mov word [time_buffer + 10], ':'

    ; ---- Formatear Segundos (SS) ----
    mov al, [efi_time_data + EFI_TIME_SECOND]
    lea rdi, [time_buffer + 12]
    call bin_to_utf16_digits

    ; Terminador nulo UTF-16
    mov word [time_buffer + 16], 0

    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; Datos del módulo RTC
; ------------------------------------------------------------------------------
section .data

align 8
efi_time_data:
    times 16 db 0                       ; Estructura EFI_TIME (16 bytes)

align 8
time_buffer:
    times 10 dw 0                       ; Cadena UTF-16 "HH:MM:SS\0" (9 palabras)

