; ==============================================================================
; main.asm - Flujo Principal y Bienvenida
; ==============================================================================
;
; Este módulo contiene la lógica de alto nivel del bootloader. Se encarga de
; mostrar una pantalla de bienvenida, esperar la confirmación del usuario y
; pasar al modo interactivo (reloj/cronómetro). Todas las funciones de
; pantalla (limpiar, posicionar cursor, imprimir) se definen en screen.asm.
; Se ejecuta en modo real de 16 bits, utilizando servicios de la BIOS para
; entrada por teclado y salida a pantalla.
; ==============================================================================

[bits 16]               ; Aseguramos modo real de 16 bits para todo el módulo.

; ------------------------------------------------------------------------------
; main_start: Punto de entrada principal, llamado desde boot.asm.
; ------------------------------------------------------------------------------
main_start:
    ; Llama a la rutina que dibuja la pantalla de bienvenida con el mensaje
    ; institucional y las instrucciones.
    call show_welcome_screen

    ; Espera a que el usuario presione ENTER (0x0D) para continuar.
    call wait_user_confirmation

    ; Inicializa el "dashboard" o panel principal, limpiando la pantalla y
    ; mostrando un mensaje de listo.
    call init_dashboard

    ; Bucle infinito para mantener el sistema en ejecución. HLT detiene el
    ; procesador hasta la próxima interrupción (ahorra energía y reduce ruido
    ; eléctrico). Tras cada HLT, se salta a la misma etiqueta para repetir.
.hang:
    hlt
    jmp .hang

; ------------------------------------------------------------------------------
; show_welcome_screen: Dibuja la pantalla de bienvenida con varias líneas
; centradas aproximadamente en la pantalla de 80x25 caracteres.
; ------------------------------------------------------------------------------
show_welcome_screen:
    ; Limpia toda la pantalla (probablemente usando INT 10h AH=06h o 00h).
    ; Esto borra cualquier contenido previo y deja el fondo en color negro.
    call screen_clear

    ; Posiciona el cursor en la fila 4 (dh), columna 12 (dl). Las coordenadas
    ; son base 0, por lo que fila 4 es la quinta línea visible.
    mov dh, 4
    mov dl, 12
    call set_cursor_pos

    ; Carga la dirección de la primera cadena de texto en SI y llama a la
    ; rutina que imprime caracteres hasta encontrar un byte nulo (0).
    mov si, msg_line1
    call print_string

    ; Línea 2: "INSTITUTO TECNOLOGICO DE COSTA RICA - CE4303"
    mov dh, 6
    mov dl, 16
    call set_cursor_pos
    mov si, msg_line2
    call print_string

    ; Línea 3: "TAREA 1: RELOJ / CRONOMETRO CON ALARMA (BIOS)"
    mov dh, 8
    mov dl, 18
    call set_cursor_pos
    mov si, msg_line3
    call print_string

    ; Mensaje de prompt: "[ Presione ENTER para ingresar al modo interactivo ]"
    mov dh, 14
    mov dl, 14
    call set_cursor_pos
    mov si, msg_prompt
    call print_string

    ret                 ; Vuelve al caller (main_start).

; ------------------------------------------------------------------------------
; wait_user_confirmation: Espera hasta que el usuario presione la tecla ENTER.
; Usa la interrupción BIOS INT 16h, función AH=00h (lectura de tecla con espera).
; ------------------------------------------------------------------------------
wait_user_confirmation:
.wait_key:
    ; AH = 0x00, INT 0x16: Espera una tecla y la devuelve en AL (código ASCII)
    ; y AH (código de barrido). Esta función bloquea hasta que se pulse una tecla.
    mov ah, 0x00
    int 0x16

    ; Compara el carácter ASCII recibido (AL) con 0x0D (código de retorno de carro,
    ; es decir, la tecla ENTER). Si no coincide, vuelve a esperar otra tecla.
    cmp al, 0x0D
    jne .wait_key
    ret

; ------------------------------------------------------------------------------
; init_dashboard: Prepara el entorno para el modo interactivo. Limpia la pantalla
; y muestra un mensaje de que el sistema está listo.
; ------------------------------------------------------------------------------
init_dashboard:
    call screen_clear
    mov dh, 2
    mov dl, 2
    call set_cursor_pos
    mov si, msg_ready
    call print_string
    ret

; ==============================================================================
; Datos constantes (cadenas de texto terminadas en cero)
; ==============================================================================

; Línea decorativa superior (separador)
msg_line1 db "=======================================================", 0

; Información institucional y del curso
msg_line2 db "INSTITUTO TECNOLOGICO DE COSTA RICA - CE4303", 0

; Descripción de la tarea
msg_line3 db "TAREA 1: RELOJ / CRONOMETRO CON ALARMA (BIOS)", 0

; Mensaje que invita a presionar ENTER para continuar
msg_prompt db "[ Presione ENTER para ingresar al modo interactivo ]", 0

; Mensaje que se muestra una vez iniciado el modo interactivo
msg_ready  db "Sistema iniciado. Listo para Modo Reloj / Cronometro.", 0