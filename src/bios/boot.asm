; ==============================================================================
; boot.asm - MBR: carga sectores desde disco y salta a la 2ª etapa
; ==============================================================================

[org 0x7C00]            ; Indica al ensamblador que el código se cargará en 0x7C00
[bits 16]               ; Genera código para modo real de 16 bits

; Punto de entrada: salto far para forzar CS=0
boot_start:
    jmp 0x0000:init_boot_env   ; Salto lejano: CS=0, IP=init_boot_env

; Inicializa segmentos, pila y guarda la unidad de booteo
init_boot_env:
    cli                        ; Deshabilita interrupciones mientras configuramos
    xor ax, ax                 ; AX = 0
    mov ds, ax                 ; DS = 0 (segmento de datos)
    mov es, ax                 ; ES = 0 (segmento extra)
    mov ss, ax                 ; SS = 0 (segmento de pila)
    mov sp, 0x7C00             ; Pila justo debajo del MBR (crece hacia abajo)
    mov [BOOT_DRIVE], dl       ; Guarda la unidad de booteo (BIOS la pasa en DL)
    sti                        ; Rehabilita interrupciones

    ; Resetear controlador de disco (INT 13h AH=00h)
    mov ah, 0x00               ; Función 0x00: resetear sistema de disco
    int 0x13                   ; Llama a la BIOS para resetear el disco

    ; Leer 16 sectores desde el sector 2 a 0x7E00 (justo después del MBR)
    mov ah, 0x02               ; Función 0x02: leer sectores del disco
    mov al, 16                 ; Número de sectores a leer (16 = 8 KB)
    mov ch, 0                  ; Cilindro 0 (CHS: cilindro)
    mov cl, 2                  ; Sector de inicio 2 (el sector 1 es el MBR)
    mov dh, 0                  ; Cabeza 0 (CHS: cabeza)
    mov bx, 0x7E00             ; Dirección de destino en memoria (ES:BX = 0x0000:0x7E00)
    int 0x13                   ; Llama a la BIOS para ejecutar la lectura
    jc disk_error              ; Si hubo error (Carry Flag = 1), salta a disk_error

    ; Saltar al código cargado (main_start en 0x7E00)
    jmp main_start             ; Salta a la etiqueta main_start (definida en main.asm)

disk_error:
    mov ah, 0x0E               ; Función 0x0E: escribir carácter en modo teletype
    mov al, 'E'                ; Carácter 'E' para indicar error
    int 0x10                   ; Llama a la BIOS para imprimir
    cli                        ; Deshabilita interrupciones
    hlt                        ; Detiene el procesador

BOOT_DRIVE db 0                ; Variable de 1 byte para almacenar la unidad de booteo

; Relleno y firma MBR (510 bytes + 0xAA55)
times 510 - ($ - $$) db 0      ; Rellena con ceros hasta el byte 510 (los 2 últimos son la firma)
dw 0xAA55                      ; Firma MBR: 0x55 0xAA (en memoria little-endian)

; Incluir la segunda etapa (main.asm) – ocupará sector 2 en adelante
%include "src/bios/main.asm"   ; Inserta el contenido de main.asm aquí