; ==============================================================================
; src/uefi/rtc.asm - Lectura del RTC (RuntimeServices->GetTime) y Formateo UTF-16
; ==============================================================================
; El acceso al Real-Time Clock se realiza mediante el servicio de
; ejecución RuntimeServices->GetTime, el cual devuelve una estructura EFI_TIME
; con los campos de fecha y hora ya convertidos a números binarios enteros.
; ==============================================================================

default rel
bits 64

; ------------------------------------------------------------------------------
; Offsets
; ------------------------------------------------------------------------------
%define OFFSET_RUNTIMESERVICES_GET_TIME 0x18    ; GetTime(EFI_TIME *Time, *Caps), offset 24

; ------------------------------------------------------------------------------
; Offsets dentro de la estructura estándar EFI_TIME (16 bytes)
; ------------------------------------------------------------------------------
%define EFI_TIME_YEAR               0x00        ; UINT16 (2 bytes)
%define EFI_TIME_MONTH              0x02        ; UINT8  (1 byte, 1-12)
%define EFI_TIME_DAY                0x03        ; UINT8  (1 byte, 1-31)
%define EFI_TIME_HOUR               0x04        ; UINT8  (1 byte, 0-23 entero binario)
%define EFI_TIME_MINUTE             0x05        ; UINT8  (1 byte, 0-59 entero binario)
%define EFI_TIME_SECOND             0x06        ; UINT8  (1 byte, 0-59 entero binario)

section .text

; ------------------------------------------------------------------------------
; uefi_get_time: RuntimeServices->GetTime obtener la hora del hardware
; Salida:
;   efi_time_data queda actualizado con la hora actual.
; ------------------------------------------------------------------------------
uefi_get_time:
    sub rsp, 40

    mov rax, [RuntimeServices]
    lea rcx, [efi_time_data]            ; Arg 1: Puntero a la estructura EFI_TIME receptora
    xor rdx, rdx                        
    call [rax + OFFSET_RUNTIMESERVICES_GET_TIME]

    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; bin_to_utf16_digits: Convierte un número binario (0-59) a dos caracteres UTF-16
; Entrada:
;   AL  = Valor numérico binario (0 a 59)
;   RDI = Puntero de memoria donde se escriben
; ------------------------------------------------------------------------------
bin_to_utf16_digits:
    movzx ax, al
    mov cl, 10
    div cl                              ; Divide AX entre 10: AL = Decenas (cociente), AH = Unidades (residuo)

    ; Convertir decena a carácter UTF-16 ('0' + valor)
    movzx dx, al
    add dx, '0'                         ; ASCII, Código UTF-16 (16 bits)
    mov [rdi], dx                       ; Escribe 2 bytes en buffer[offset]

    ; Convertir unidad a carácter UTF-16
    movzx dx, ah
    add dx, '0'
    mov [rdi + 2], dx                   ; Escribe 2 bytes en buffer[offset + 2]
    ret

; ------------------------------------------------------------------------------
; uefi_format_time_string: Consulta el RTC y genera la cadena "HH:MM:SS\0" en UTF-16
; Salida:
;   time_buffer queda listo 
; ------------------------------------------------------------------------------
uefi_format_time_string:
    sub rsp, 40

    call uefi_get_time                  ; 1. Lee la hora actual del hardware

    ; 2. Formatea Horas (HH)
    mov al, [efi_time_data + EFI_TIME_HOUR]
    lea rdi, [time_buffer + 0]          ; Posición 0: Horas 
    call bin_to_utf16_digits

    ; Separador ':' (código UTF-16: 0x003A)
    mov word [time_buffer + 4], ':'

    ; 3. Formatea Minutos (MM)
    mov al, [efi_time_data + EFI_TIME_MINUTE]
    lea rdi, [time_buffer + 6]          ; Posición 3: Minutos
    call bin_to_utf16_digits

    ; Separador ':'
    mov word [time_buffer + 10], ':'

    ; 4. Formatea Segundos (SS)
    mov al, [efi_time_data + EFI_TIME_SECOND]
    lea rdi, [time_buffer + 12]         ; Posición 6: Segundos
    call bin_to_utf16_digits

    ; 5. Terminador nulo UTF-16 (0x0000)
    mov word [time_buffer + 16], 0

    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; Datos del modulo RTC
; ------------------------------------------------------------------------------
section .data

; Bufer de 16 bytes llena el firmware UEFI con la hora y fecha
align 8
efi_time_data:
    times 16 db 0

; Cadena de texto UTF-16 para despliegue: "HH:MM:SS\0" 
align 8
time_buffer:
    times 10 dw 0
