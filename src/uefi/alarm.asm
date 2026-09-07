; ==============================================================================
; src/uefi/alarm.asm - Lógica de Configuración y salto de Alarma 
; ==============================================================================
; Maneja el almacenamiento de la hora programada, la comparación con el RTC,
; el disparo del efecto de parpadeo visual y la cancelación.
; ==============================================================================

default rel
bits 64

section .text

; ------------------------------------------------------------------------------
; save_alarm_from_buffer: Convierte los dígitos UTF-16 ingresados ("HH:MM")
;                         a valores numéricos enteros binarios y arma la alarma.
; ------------------------------------------------------------------------------
save_alarm_from_buffer:
    sub rsp, 40

    lea rsi, [alarm_input_buf]           ; Puntero base a la cadena "HH:MM\0"

    ; ---- Convertir Horas (Posiciones 0 y 1) ----
    movzx eax, word [rsi + 0]            ; Decenas de hora en UTF-16
    sub al, '0'                          ; Convertir a número (0-9)
    mov cl, 10
    mul cl                               ; AL = Decenas * 10
    mov dl, al

    movzx eax, word [rsi + 2]            ; Unidades de hora en UTF-16
    sub al, '0'
    add dl, al                           ; DL = Horas totales (0-23)
    mov [alarm_h], dl                    ; Guardar hora en variable de alarma

    ; ---- Convertir Minutos (Posiciones 3 y 4) ----
    movzx eax, word [rsi + 6]            ; Decenas de minuto en UTF-16
    sub al, '0'
    mov cl, 10
    mul cl
    mov dl, al

    movzx eax, word [rsi + 8]            ; Unidades de minuto en UTF-16
    sub al, '0'
    add dl, al                           ; DL = Minutos totales (0-59)
    mov [alarm_m], dl

    ; ---- Armar la Alarma ----
    mov byte [alarm_active], 1           ; Activa la bandera de alarma armada
    mov byte [alarm_triggered], 0        ; Reinicia estado de disparo
    mov byte [blink_counter], 0

    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; check_alarm: Compara la hora actual del RTC con la hora de la alarma
; ------------------------------------------------------------------------------
check_alarm:
    sub rsp, 40

    ; Si la alarma no está armada, no hacer nada
    cmp byte [alarm_active], 1
    jne .done

    ; Si ya se encuentra disparada, solo incrementar el contador de parpadeo
    cmp byte [alarm_triggered], 1
    je .increment_blink

    ; Comparar hora actual con la hora de alarma
    mov al, [efi_time_data + EFI_TIME_HOUR]
    cmp al, [alarm_h]
    jne .done

    ; Comparar minuto actual con el minuto de alarma
    mov al, [efi_time_data + EFI_TIME_MINUTE]
    cmp al, [alarm_m]
    jne .done

    ; ---- trigger ----
    mov byte [alarm_triggered], 1

.increment_blink:
    inc byte [blink_counter]             ; Avanza el contador de parpadeo

.done:
    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; cancel_alarm: Desactiva la alarma 
; ------------------------------------------------------------------------------
cancel_alarm:
    sub rsp, 40

    mov byte [alarm_active], 0           ; Desactiva la alarma
    mov byte [alarm_triggered], 0        ; Reinicia estado

    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; Datos del módulo de Alarma
; ------------------------------------------------------------------------------
section .data

align 8
alarm_active    db 0                    ; 1 = Alarma armada, 0 = Inactiva
alarm_triggered db 0                    ; 1 = Alarma disparada
alarm_h         db 0                    ; Hora configurada (0-23)
alarm_m         db 0                    ; Minuto configurado (0-59)
alarm_input_idx db 0                    ; Posición del cursor para ingreso de dígitos (0-4)
blink_counter   db 0                    ; Contador de ciclos para alternar colores de alerta

; Búfer para el ingreso numérico en pantalla: "00:00\0" (UTF-16)
align 8
alarm_input_buf:
    dw '0', '0', ':', '0', '0', 0
