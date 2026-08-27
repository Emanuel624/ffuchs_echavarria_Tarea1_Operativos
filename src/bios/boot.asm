; ==============================================================================
; boot.asm - Punto de Entrada BIOS Legacy
; ==============================================================================
;
; Este es el sector de arranque (boot sector) que la BIOS carga en la dirección
; física 0x7C00 (CS:IP = 0x0000:0x7C00 o 0x07C0:0x0000). Se ejecuta en modo
; real de 16 bits con interrupciones habilitadas. Su tamaño debe ser exactamente
; 512 bytes y terminar con la firma 0xAA55 en los dos últimos bytes.
; ==============================================================================

[org 0x7C00]          ; Directiva al ensamblador: todas las direcciones de
                      ; memoria se calculan a partir de 0x7C00. Esto es necesario
                      ; porque el código se carga en esa dirección física.
[bits 16]             ; El procesador arranca en modo real de 16 bits.

boot_start:
    ; --------------------------------------------------------------------------
    ; Salto far para forzar CS = 0x0000 y establecer un punto de referencia
    ; de segmento conocido. El BIOS puede haber cargado el sector con diferentes
    ; valores en CS:IP (por ejemplo, 0x0000:0x7C00 o 0x07C0:0x0000). Este salto
    ; unifica la segmentación: a partir de aquí CS = 0x0000, IP = init_segments.
    ; --------------------------------------------------------------------------
    jmp 0x0000:init_segments

init_segments:
    ; Deshabilitar interrupciones mientras se configuran los registros de segmento
    ; y la pila, para evitar que una interrupción use valores inconsistentes.
    cli

    ; Poner todos los segmentos de datos a 0x0000 (apuntan al mismo espacio lineal
    ; que CS, pues CS ya es 0). Esto simplifica el direccionamiento: direcciones
    ; de 16 bits (offset) se mapean directamente a los primeros 64 KB de memoria.
    xor ax, ax
    mov ds, ax          ; DS = 0 (segmento de datos)
    mov es, ax          ; ES = 0 (segmento extra)
    mov ss, ax          ; SS = 0 (segmento de pila)

    ; Establecer el puntero de pila (SP) justo debajo de nuestro código, es decir,
    ; en la dirección 0x7C00. La pila crece hacia direcciones decrecientes, por lo
    ; que las primeras operaciones de push escribirán en 0x7BFF, 0x7BFE, etc.
    ; Esto es seguro porque el código ocupa desde 0x7C00 hacia arriba (hasta
    ; 0x7DFF aproximadamente) y la pila no choca con él si se usa con cuidado.
    mov sp, 0x7C00

    ; Rehabilitar interrupciones después de la configuración.
    sti

    ; Saltar al flujo principal del sistema (definido en main.asm). Este salto
    ; es absoluto dentro del mismo segmento (CS = 0), por lo que solo se modifica IP.
    ; main_start debe estar definido en uno de los archivos incluidos.
    jmp main_start

; ------------------------------------------------------------------------------
; Inclusión de otros módulos que contienen el código funcional del bootloader.
; - screen.asm: probablemente contiene rutinas para imprimir caracteres y
;   manejar la pantalla en modo texto (usando interrupciones BIOS o E/S directa).
; - main.asm: contiene la lógica principal, como cargar el kernel desde el disco,
;   cambiar a modo protegido, etc.
; ------------------------------------------------------------------------------
%include "src/bios/screen.asm"
%include "src/bios/main.asm"

; ------------------------------------------------------------------------------
; Relleno del sector para que ocupe exactamente 510 bytes (sin contar la firma).
; El ensamblador calcula la diferencia entre la posición actual ($) y el inicio
; del sector ($$), y la resta de 510 para rellenar con ceros. Esto asegura que
; los dos últimos bytes sean la firma.
; ------------------------------------------------------------------------------
times 510 - ($ - $$) db 0

; Firma MBR obligatoria: 0x55 0xAA en los últimos dos bytes del sector.
; El BIOS verifica esta firma para considerar el sector como válido.
dw 0xAA55