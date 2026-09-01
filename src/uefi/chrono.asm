; ==============================================================================
; src/uefi/chrono.asm - Lógica del Cronómetro Independiente en UEFI
; ==============================================================================
; Mantiene un conteo de tiempo desacoplado del reloj principal, sincronizado
; con los cambios de segundo del RTC para asegurar exactitud.
; ==============================================================================

default rel
bits 64

section .text

; ------------------------------------------------------------------------------
; chrono_update: Actualiza los contadores de tiempo del cronómetro
;
; Estrategia:
;   En cada ciclo del bucle principal, se lee el segundo actual del RTC.
;   Cuando el segundo cambia respecto al último visto (transición de 1 segundo),
;   si el cronómetro está en estado "corriendo" (chrono_running == 1),
;   se incrementan los segundos y, en cascada, los minutos al llegar a 60.
; ------------------------------------------------------------------------------
chrono_update:
    sub rsp, 40

    ; Obtener el segundo actual reportado por la estructura EFI_TIME
    mov al, [efi_time_data + EFI_TIME_SECOND]

    ; Si es la primera ejecución, inicializar el último segundo registrado
    cmp byte [last_rtc_sec], 0xFF
    je .sync_init

    ; Comprobar si ya transcurrió un segundo real
    cmp al, [last_rtc_sec]
    je .done                            ; Si el segundo no ha cambiado, no hacer nada

    ; El segundo cambió: actualizar segundo de referencia
    mov [last_rtc_sec], al

    ; Verificar si el cronómetro está activo (corriendo)
    cmp byte [chrono_running], 1
    jne .done                           ; Si está en pausa, no incrementar contadores

    ; Incrementar segundos del cronómetro
    inc byte [chrono_s]
    cmp byte [chrono_s], 60
    jl .done

    ; Al alcanzar 60 segundos: reiniciar segundos a 0 e incrementar minutos
    mov byte [chrono_s], 0
    inc byte [chrono_m]
    cmp byte [chrono_m], 60
    jl .done
    mov byte [chrono_m], 0              ; Reiniciar a 0 tras completar 60 minutos

    jmp .done

.sync_init:
    mov [last_rtc_sec], al

.done:
    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; chrono_start_stop: Alterna el estado del cronómetro entre Play y Pausa
; ------------------------------------------------------------------------------
chrono_start_stop:
    sub rsp, 40

    xor byte [chrono_running], 1        ; Invierte bandera: 0 -> 1 (Play), 1 -> 0 (Pausa)

    ; Sincronizar con el segundo actual para evitar saltos inmediatos al reanudar
    mov al, [efi_time_data + EFI_TIME_SECOND]
    mov [last_rtc_sec], al

    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; chrono_reset: Detiene el cronómetro y restablece los contadores a cero
; ------------------------------------------------------------------------------
chrono_reset:
    sub rsp, 40

    mov byte [chrono_running], 0        ; Detiene el cronómetro (pausado)
    mov byte [chrono_s], 0              ; Segundos = 0
    mov byte [chrono_m], 0              ; Minutos = 0

    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; chrono_format_string: Escribe la cadena "MM:SS\0" en UTF-16 en chrono_buffer
; ------------------------------------------------------------------------------
chrono_format_string:
    sub rsp, 40

    ; 1. Formatear Minutos (MM)
    mov al, [chrono_m]
    lea rdi, [chrono_buffer + 0]
    call bin_to_utf16_digits

    ; Separador ':'
    mov word [chrono_buffer + 4], ':'

    ; 2. Formatear Segundos (SS)
    mov al, [chrono_s]
    lea rdi, [chrono_buffer + 6]
    call bin_to_utf16_digits

    ; 3. Terminador nulo UTF-16
    mov word [chrono_buffer + 10], 0

    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; Datos del módulo Cronómetro
; ------------------------------------------------------------------------------
section .data

align 8
chrono_running  db 0                    ; 0 = Pausado, 1 = Corriendo
chrono_s        db 0                    ; Segundos acumulados (0-59)
chrono_m        db 0                    ; Minutos acumulados (0-59)
last_rtc_sec    db 0xFF                 ; Último segundo de hardware registrado

; Búfer de salida UTF-16: "MM:SS\0" (5 caracteres + null = 6 words)
align 8
chrono_buffer:
    times 8 dw 0
