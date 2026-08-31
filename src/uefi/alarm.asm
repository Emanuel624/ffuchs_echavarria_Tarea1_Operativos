; ==============================================================================
; src/uefi/alarm.asm - Lógica de Configuración y Disparo de Alarma en UEFI
; ==============================================================================

default rel
bits 64

section .text

; ------------------------------------------------------------------------------
; save_alarm_from_buffer: Convierte la cadena UTF-16 "HH:MM" ingresada en
;                         alarm_input_buf a valores numéricos (0-23, 0-59)
;                         y activa la alarma.
; ------------------------------------------------------------------------------
save_alarm_from_buffer:
    sub rsp, 40

    lea rsi, [alarm_input_buf]

    ; ---- Convertir Horas (Dígitos en posiciones 0 y 1 de la cadena) ----
    movzx eax, word [rsi + 0]            ; Carácter UTF-16 de decenas de hora
    sub al, '0'                          ; Valor numérico (0-9)
    mov cl, 10
    mul cl                               ; AL = decenas * 10
    mov dl, al                           ; DL = decenas * 10

    movzx eax, word [rsi + 2]            ; Carácter UTF-16 de unidades de hora
    sub al, '0'                          ; Valor numérico (0-9)
    add dl, al                           ; DL = Horas totales (0-23)
    mov [alarm_h], dl

    ; ---- Convertir Minutos (Dígitos en posiciones 3 y 4 de la cadena) ----
    ; Nota: En UTF-16, posición 3 = byte offset 6 (salta ':')
    movzx eax, word [rsi + 6]            ; Carácter UTF-16 de decenas de minuto
    sub al, '0'
    mov cl, 10
    mul cl                               ; AL = decenas * 10
    mov dl, al

    movzx eax, word [rsi + 8]            ; Carácter UTF-16 de unidades de minuto
    sub al, '0'
    add dl, al                           ; DL = Minutos totales (0-59)
    mov [alarm_m], dl

    ; ---- Activar la Alarma ----
    mov byte [alarm_active], 1           ; Marca alarma como armada
    mov byte [alarm_triggered], 0        ; Reinicia estado de disparo
    mov byte [blink_counter], 0

    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; check_alarm: Compara la hora actual con la hora de alarma programada
; ------------------------------------------------------------------------------
check_alarm:
    sub rsp, 40

    ; Si la alarma no está armada, salir
    cmp byte [alarm_active], 1
    jne .done

    ; Si ya se disparó, solo avanzar el contador de parpadeo
    cmp byte [alarm_triggered], 1
    je .increment_blink

    ; Comprobar si la hora actual coincide exactamente con la alarma
    mov al, [efi_time_data + EFI_TIME_HOUR]
    cmp al, [alarm_h]
    jne .done

    mov al, [efi_time_data + EFI_TIME_MINUTE]
    cmp al, [alarm_m]
    jne .done

    ; ---- ¡COINCIDENCIA EXACTA: DISPARAR ALARMA! ----
    mov byte [alarm_triggered], 1

.increment_blink:
    inc byte [blink_counter]

.done:
    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; cancel_alarm: Desactiva la alarma armada o disparada
; ------------------------------------------------------------------------------
cancel_alarm:
    sub rsp, 40

    mov byte [alarm_active], 0
    mov byte [alarm_triggered], 0

    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; Datos del módulo de Alarma
; ------------------------------------------------------------------------------
section .data

align 8
alarm_active    db 0                    ; 1 = Alarma armada, 0 = Inactiva
alarm_triggered db 0                    ; 1 = Alarma sonando / disparada
alarm_h         db 0                    ; Hora configurada (0-23)
alarm_m         db 0                    ; Minuto configurado (0-59)
alarm_input_idx db 0                    ; Índice de cursor para ingreso de dígitos (0-4)
blink_counter   db 0                    ; Contador para alternar parpadeo visual

align 8
alarm_input_buf:
    dw '0', '0', ':', '0', '0', 0       ; Buffer UTF-16 "00:00\0" (6 palabras)

