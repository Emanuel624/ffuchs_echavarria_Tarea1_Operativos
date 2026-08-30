; ==============================================================================
; src/uefi/chrono.asm - Lógica del Cronómetro Independiente en UEFI
; ==============================================================================

default rel
bits 64

section .text

; ------------------------------------------------------------------------------
; chrono_update: Actualiza los contadores de tiempo del cronómetro
; Utiliza las transiciones de segundo del RTC para garantizar exactitud
; ------------------------------------------------------------------------------
chrono_update:
    sub rsp, 40

    ; Obtener el segundo actual reportado por el RTC
    mov al, [efi_time_data + EFI_TIME_SECOND]

    ; Si es la primera vez que se ejecuta, sincronizar last_rtc_sec
    cmp byte [last_rtc_sec], 0xFF
    je .sync_init

    ; Comparar segundo actual con el último segundo registrado
    cmp al, [last_rtc_sec]
    je .done                            ; Si no ha cambiado el segundo, salir

    ; El segundo cambió: guardar nuevo segundo de referencia
    mov [last_rtc_sec], al

    ; Verificar si el cronómetro está corriendo
    cmp byte [chrono_running], 1
    jne .done                           ; Si está pausado, no incrementar

    ; Incrementar segundos
    inc byte [chrono_s]
    cmp byte [chrono_s], 60
    jl .done

    ; Al llegar a 60 segundos, reiniciar segundos e incrementar minutos
    mov byte [chrono_s], 0
    inc byte [chrono_m]
    cmp byte [chrono_m], 60
    jl .done
    mov byte [chrono_m], 0              ; Reiniciar a 0 tras 60 minutos

    jmp .done

.sync_init:
    mov [last_rtc_sec], al

.done:
    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; chrono_start_stop: Alterna el estado del cronómetro entre Iniciar y Pausar
; ------------------------------------------------------------------------------
chrono_start_stop:
    sub rsp, 40

    xor byte [chrono_running], 1        ; Invierte bandera: 0 -> 1 (Play), 1 -> 0 (Pausa)
    ; Sincronizar segundo actual para evitar saltos al reanudar
    mov al, [efi_time_data + EFI_TIME_SECOND]
    mov [last_rtc_sec], al

    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; chrono_reset: Detiene y pone a cero los contadores del cronómetro
; ------------------------------------------------------------------------------
chrono_reset:
    sub rsp, 40

    mov byte [chrono_running], 0        ; Pausa el cronómetro
    mov byte [chrono_s], 0              ; Segundos a 0
    mov byte [chrono_m], 0              ; Minutos a 0

    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; chrono_format_string: Escribe "MM:SS" en formato UTF-16 en chrono_buffer
; ------------------------------------------------------------------------------
chrono_format_string:
    sub rsp, 40

    ; ---- Formatear Minutos (MM) ----
    mov al, [chrono_m]
    lea rdi, [chrono_buffer + 0]
    call bin_to_utf16_digits

    ; Separador ':'
    mov word [chrono_buffer + 4], ':'

    ; ---- Formatear Segundos (SS) ----
    mov al, [chrono_s]
    lea rdi, [chrono_buffer + 6]
    call bin_to_utf16_digits

    ; Terminador nulo UTF-16
    mov word [chrono_buffer + 10], 0

    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; Datos del módulo Cronómetro
; ------------------------------------------------------------------------------
section .data

align 8
chrono_running  db 0                    ; 0 = Pausado, 1 = Corriendo
chrono_s        db 0                    ; Segundos actuales (0-59)
chrono_m        db 0                    ; Minutos actuales (0-59)
last_rtc_sec    db 0xFF                 ; Último segundo del RTC observado

align 8
chrono_buffer:
    times 8 dw 0                        ; Buffer UTF-16 "MM:SS\0" (6 palabras)

