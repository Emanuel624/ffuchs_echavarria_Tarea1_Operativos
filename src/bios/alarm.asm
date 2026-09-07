; ==============================================================================
; alarm.asm - Lógica de Configuración y Disparo de Alarma
; ==============================================================================

[bits 16]                       ; Modo real de 16 bits

; ------------------------------------------------------------------------------
; save_alarm_from_buffer: Convierte cadena "HH:MM" (en alarm_input_buf) a BCD
;                         y activa la alarma.
; ------------------------------------------------------------------------------
save_alarm_from_buffer:
    pusha                       ; Guarda todos los registros

    ; ---- Convertir horas (dos dígitos ASCII a BCD) ----
    mov al, [alarm_input_buf + 0]  ; AL = primer dígito ASCII (decenas de hora)
    sub al, '0'                    ; AL = valor numérico (0-9)
    shl al, 4                      ; Desplaza a la izquierda 4 bits: queda en nibble superior
    mov ah, [alarm_input_buf + 1]  ; AH = segundo dígito ASCII (unidades de hora)
    sub ah, '0'                    ; AH = valor numérico (0-9)
    or al, ah                      ; AL = BCD de horas (decenas en nibble alto, unidades en bajo)
    mov [alarm_h_bcd], al          ; Guarda horas BCD

    ; ---- Convertir minutos (dos dígitos ASCII a BCD) ----
    mov al, [alarm_input_buf + 3]  ; AL = primer dígito ASCII (decenas de minuto)
    sub al, '0'                    ; AL = valor numérico
    shl al, 4                      ; Decenas al nibble superior
    mov ah, [alarm_input_buf + 4]  ; AH = segundo dígito ASCII (unidades de minuto)
    sub ah, '0'                    ; AH = valor numérico
    or al, ah                      ; AL = BCD de minutos
    mov [alarm_m_bcd], al          ; Guarda minutos BCD

    ; ---- Activar alarma ----
    mov byte [alarm_active], 1     ; Marca alarma como activa
    mov byte [alarm_triggered], 0  ; Resetea bandera de disparo (por si estaba activa)

    popa                           ; Restaura registros
    ret                            ; Vuelve al llamador

; ------------------------------------------------------------------------------
; check_alarm: Verifica si la hora actual coincide con la alarma activa.
;              Si coincide, activa efecto visual (parpadeo en rojo).
; ------------------------------------------------------------------------------
check_alarm:
    cmp byte [alarm_active], 1     ; ¿Está la alarma activa?
    jne .done                      ; Si no está activa, termina

    cmp byte [alarm_triggered], 1  ; ¿Ya se disparó la alarma?
    je .handle_visual_effect       ; Si ya se disparó, mantiene el efecto visual

    call rtc_get_time              ; Lee RTC: CH=horas BCD, CL=minutos BCD, DH=segundos
    cmp ch, [alarm_h_bcd]          ; ¿Hora actual coincide con hora de alarma?
    jne .done                      ; Si no coincide, termina
    cmp cl, [alarm_m_bcd]          ; ¿Minuto actual coincide con minuto de alarma?
    jne .done                      ; Si no coincide, termina

    ; ---- Disparar alarma (coincidencia exacta) ----
    mov byte [alarm_triggered], 1  ; Marca que ya se disparó (para no repetir)

.handle_visual_effect:              ; Entra aquí si ya está disparada
    pusha                          ; Guarda registros para usar BIOS
    mov ah, 0x00                   ; Función 0x00: leer contador de ticks (INT 1Ah)
    int 0x1A                       ; Obtiene CX:DX = ticks desde medianoche
    test dl, 0x08                  ; Prueba el bit 3 de DL (parpadeo cada ~0.4 seg)
    popa                           ; Restaura registros
    jz .normal_color               ; Si bit=0, color normal

    call screen_color_red          ; Si bit=1, cambia fondo/color a rojo
    jmp .done                      ; Salta al final

.normal_color:
    call screen_color_normal       ; Restaura colores normales

.done:
    ret                            ; Vuelve al llamador

; ------------------------------------------------------------------------------
; Variables de la Alarma (estáticas)
; ------------------------------------------------------------------------------
alarm_active    db 0     ; 1 = alarma activa, 0 = inactiva
alarm_triggered db 0     ; 1 = ya se disparó (efecto visual activo)
alarm_h_bcd     db 0     ; Hora en BCD (formato: decenas en nibble alto, unidades en bajo)
alarm_m_bcd     db 0     ; Minutos en BCD
alarm_input_idx db 0     ; (no usado aquí, posiblemente para entrada paso a paso)
alarm_input_buf db "00:00", 0  ; Buffer donde se guarda la hora ingresada (ASCII)