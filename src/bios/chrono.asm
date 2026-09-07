; ==============================================================================
; chrono.asm - Lógica del Cronómetro Independiente
; ==============================================================================

[bits 16]                       ; Modo real de 16 bits

; ------------------------------------------------------------------------------
; chrono_update: Actualiza los contadores si el cronómetro está corriendo
; ------------------------------------------------------------------------------
chrono_update:
    cmp byte [chrono_running], 1   ; Compara el estado del cronómetro con 1 (corriendo)
    jne .done                      ; Si no está corriendo (0), salta a .done

    ; Leer el Timer Tick del BIOS (aprox 18.2 ticks por segundo)
    mov ah, 0x00                   ; Función 0x00: leer contador de ticks (INT 1Ah)
    int 0x1A                       ; Devuelve CX:DX = ticks desde medianoche
    
    cmp dx, [last_tick]            ; Compara el tick actual con el guardado
    je .done                       ; Si no ha cambiado, no hay actualización
    mov [last_tick], dx            ; Guarda el nuevo tick para futuras comparaciones

    ; Incrementar garrapateo (ticks acumulados)
    inc byte [chrono_ticks]        ; Aumenta el contador de ticks del cronómetro
    cmp byte [chrono_ticks], 18    ; ¿Llegó a 18 ticks? (≈1 segundo)
    jl .done                       ; Si es menor, no hay cambio de segundo

    ; Incrementar segundos
    mov byte [chrono_ticks], 0     ; Reinicia el contador de ticks
    inc byte [chrono_s]            ; Aumenta segundos
    cmp byte [chrono_s], 60        ; ¿Llegó a 60 segundos?
    jl .done                       ; Si no, termina

    ; Incrementar minutos
    mov byte [chrono_s], 0         ; Reinicia segundos a 0
    inc byte [chrono_m]            ; Aumenta minutos
    cmp byte [chrono_m], 60        ; ¿Llegó a 60 minutos?
    jl .done                       ; Si no, termina
    mov byte [chrono_m], 0         ; Si llegó a 60, reinicia minutos a 0 (sin horas)

.done:
    ret                            ; Vuelve al llamador

; ------------------------------------------------------------------------------
; chrono_start_stop: Alterna entre Iniciar y Pausar
; ------------------------------------------------------------------------------
chrono_start_stop:
    xor byte [chrono_running], 1   ; Invierte el bit: 0→1, 1→0 (inicia/pausa)
    ; Al reanudar, sincronizar el last_tick para evitar saltos
    mov ah, 0x00                   ; Lee el tick actual
    int 0x1A                       ; CX:DX = ticks
    mov [last_tick], dx            ; Guarda el tick actual como referencia
    ret                            ; Vuelve al llamador

; ------------------------------------------------------------------------------
; chrono_reset: Detiene y pone a cero el cronómetro
; ------------------------------------------------------------------------------
chrono_reset:
    mov byte [chrono_running], 0   ; Detiene el cronómetro (pausado)
    mov byte [chrono_ticks], 0     ; Reinicia ticks acumulados
    mov byte [chrono_s], 0         ; Reinicia segundos
    mov byte [chrono_m], 0         ; Reinicia minutos
    ret                            ; Vuelve al llamador

; ------------------------------------------------------------------------------
; bin_to_ascii: Convierte número binario (0-59) a dos caracteres ASCII
; Entrada: AL = Número (0-59)
; Salida:  AH = ASCII de decenas, AL = ASCII de unidades
; ------------------------------------------------------------------------------
bin_to_ascii:
    mov ah, 0                      ; AH = 0 (para división de 16 bits)
    mov cl, 10                     ; Divisor = 10
    div cl                         ; AL = cociente (decenas), AH = residuo (unidades)
    add al, '0'                    ; Convierte cociente a ASCII
    add ah, '0'                    ; Convierte residuo a ASCII
    xchg ah, al                    ; Intercambia: AH ahora tiene decenas, AL unidades
    ret                            ; Vuelve al llamador

; ------------------------------------------------------------------------------
; chrono_format_string: Llena el buffer con formato "MM:SS"
; Entrada: DI = Puntero al buffer (debe tener al menos 6 bytes)
; ------------------------------------------------------------------------------
chrono_format_string:
    pusha                          ; Guarda todos los registros
    ; ---- Minutos ----
    mov al, [chrono_m]             ; AL = minutos (0-59)
    call bin_to_ascii              ; AH=decenas ASCII, AL=unidades ASCII
    mov [di], ah                   ; Escribe decena de minutos en buffer[0]
    mov [di+1], al                 ; Escribe unidad de minutos en buffer[1]
    mov byte [di+2], ':'           ; Escribe ':' en buffer[2]

    ; ---- Segundos ----
    mov al, [chrono_s]             ; AL = segundos (0-59)
    call bin_to_ascii              ; AH=decenas ASCII, AL=unidades ASCII
    mov [di+3], ah                 ; Escribe decena de segundos en buffer[3]
    mov [di+4], al                 ; Escribe unidad de segundos en buffer[4]
    mov byte [di+5], 0             ; Escribe terminador nulo al final

    popa                           ; Restaura todos los registros
    ret                            ; Vuelve al llamador

; ------------------------------------------------------------------------------
; Variables del Cronómetro (datos estáticos en memoria)
; ------------------------------------------------------------------------------
chrono_running db 0     ; 0 = Pausado, 1 = Corriendo
chrono_ticks   db 0     ; Acumulador de ticks (0-17)
chrono_s       db 0     ; Segundos actuales (0-59)
chrono_m       db 0     ; Minutos actuales (0-59)
last_tick      dw 0     ; Último valor de DX leído (para detectar cambio de tick)