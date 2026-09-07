; ==============================================================================
; rtc.asm - Lectura del RTC (BIOS INT 1Ah) y Formateo
; ==============================================================================

[bits 16]                       ; Modo real de 16 bits

; ------------------------------------------------------------------------------
; rtc_get_time: Obtiene la hora del RTC usando interrupción BIOS
; ------------------------------------------------------------------------------
rtc_get_time:
    mov ah, 0x02                ; Función 0x02: leer hora del RTC
    int 0x1A                    ; Llama a BIOS: CH=horas BCD, CL=minutos BCD, DH=segundos BCD
    ret                         ; Vuelve al llamador

; ------------------------------------------------------------------------------
; bcd_to_ascii: Convierte un byte BCD a dos caracteres ASCII (decenas y unidades)
; Entrada: AL = byte BCD (ej. 0x45)
; Salida: AH = ASCII de decenas, AL = ASCII de unidades
; ------------------------------------------------------------------------------
bcd_to_ascii:
    mov ah, al                  ; Copia el byte BCD a AH
    shr ah, 4                   ; Desplaza 4 bits a la derecha: queda la decena (0-9)
    add ah, '0'                 ; Convierte decena a ASCII (ej. 4 -> '4')
    and al, 0x0F                ; Máscara para quedarse con la unidad (0-9)
    add al, '0'                 ; Convierte unidad a ASCII
    ret                         ; Vuelve al llamador

; ------------------------------------------------------------------------------
; rtc_format_time_string: Lee el RTC y escribe "HH:MM:SS" en el buffer apuntado por DI
; Entrada: DI = puntero al buffer (debe tener al menos 9 bytes)
; ------------------------------------------------------------------------------
rtc_format_time_string:
    pusha                       ; Guarda todos los registros

    call rtc_get_time           ; Obtiene hora: CH=horas, CL=minutos, DH=segundos (BCD)

    ; ---- Formatear Horas ----
    mov al, ch                  ; AL = horas BCD
    call bcd_to_ascii           ; AH=ASCII decenas, AL=ASCII unidades
    mov [di], ah                ; Escribe decena de horas en buffer[0]
    mov [di+1], al              ; Escribe unidad de horas en buffer[1]
    mov byte [di+2], ':'        ; Escribe ':' en buffer[2]

    ; ---- Formatear Minutos ----
    mov al, cl                  ; AL = minutos BCD
    call bcd_to_ascii           ; AH=ASCII decenas, AL=ASCII unidades
    mov [di+3], ah              ; Escribe decena de minutos en buffer[3]
    mov [di+4], al              ; Escribe unidad de minutos en buffer[4]
    mov byte [di+5], ':'        ; Escribe ':' en buffer[5]

    ; ---- Formatear Segundos ----
    mov al, dh                  ; AL = segundos BCD
    call bcd_to_ascii           ; AH=ASCII decenas, AL=ASCII unidades
    mov [di+6], ah              ; Escribe decena de segundos en buffer[6]
    mov [di+7], al              ; Escribe unidad de segundos en buffer[7]
    mov byte [di+8], 0          ; Escribe terminador nulo al final (string C)

    popa                        ; Restaura todos los registros
    ret                         ; Vuelve al llamador