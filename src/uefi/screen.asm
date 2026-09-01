; ==============================================================================
; src/uefi/screen.asm - Manejo de Pantalla y Video en UEFI (ConOut Protocol)
; ==============================================================================
; En UEFI no existen las interrupciones de BIOS (como INT 10h).
; Todas las operaciones de salida de texto y cursor se realizan llamando
; a las funciones del protocolo EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL (ConOut)
; a través de su tabla de punteros a función.
; ==============================================================================

default rel
bits 64

; ------------------------------------------------------------------------------
; Offsets en la estructura EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL (ConOut)
; Según la especificación UEFI (punteros de 64 bits = 8 bytes cada uno):
; ------------------------------------------------------------------------------
%define OFFSET_CONOUT_RESET         0x00        ; Reset(This, ExtendedVerification)
%define OFFSET_CONOUT_OUTPUT_STRING 0x08        ; OutputString(This, *String)
%define OFFSET_CONOUT_TEST_STRING   0x10        ; TestString(This, *String)
%define OFFSET_CONOUT_QUERY_MODE    0x18        ; QueryMode(This, ModeNum, *Cols, *Rows)
%define OFFSET_CONOUT_SET_MODE      0x20        ; SetMode(This, ModeNum)
%define OFFSET_CONOUT_SET_ATTRIBUTE 0x28        ; SetAttribute(This, Attribute)
%define OFFSET_CONOUT_CLEAR_SCREEN  0x30        ; ClearScreen(This)
%define OFFSET_CONOUT_SET_CURSOR    0x38        ; SetCursorPosition(This, Column, Row)
%define OFFSET_CONOUT_ENABLE_CURSOR 0x40        ; EnableCursor(This, Visible)

; ------------------------------------------------------------------------------
; Atributos de Color de Texto y Fondo para ConOut->SetAttribute
; Formato: Nibble superior = Fondo (0-7), Nibble inferior = Texto (0-F)
; ------------------------------------------------------------------------------
%define COLOR_BLACK                 0x00
%define COLOR_BLUE                  0x01
%define COLOR_GREEN                 0x02
%define COLOR_CYAN                  0x03
%define COLOR_RED                   0x04
%define COLOR_MAGENTA               0x05
%define COLOR_BROWN                 0x06
%define COLOR_LIGHTGRAY             0x07
%define COLOR_DARKGRAY              0x08
%define COLOR_LIGHTBLUE             0x09
%define COLOR_LIGHTGREEN            0x0A
%define COLOR_LIGHTCYAN             0x0B
%define COLOR_LIGHTRED              0x0C
%define COLOR_LIGHTMAGENTA          0x0D
%define COLOR_YELLOW                0x0E
%define COLOR_WHITE                 0x0F

; Combinaciones predefinidas de texto y fondo
%define COLOR_WHITE_ON_BLACK        0x0F        ; Fondo Negro, Texto Blanco
%define COLOR_YELLOW_ON_BLACK       0x0E        ; Fondo Negro, Texto Amarillo
%define COLOR_CYAN_ON_BLACK         0x0B        ; Fondo Negro, Texto Cyan
%define COLOR_GREEN_ON_BLACK        0x0A        ; Fondo Negro, Texto Verde
%define COLOR_WHITE_ON_BLUE         0x1F        ; Fondo Azul, Texto Blanco

section .text

; ------------------------------------------------------------------------------
; uefi_clear_screen: Limpia toda la pantalla de la consola UEFI
; Convención Microsoft x64:
;   RCX = ConOut (Puntero 'This' obligatorio en llamadas a métodos UEFI)
; ------------------------------------------------------------------------------
uefi_clear_screen:
    sub rsp, 40                         ; Reserva 32 bytes shadow space + 8 bytes para alinear RSP a 16
    mov rax, [ConOut]                   ; RAX = Puntero al protocolo ConOut
    mov rcx, rax                        ; RCX = Arg 1 ('This')
    call [rax + OFFSET_CONOUT_CLEAR_SCREEN]
    add rsp, 40                         ; Restaura la pila
    ret

; ------------------------------------------------------------------------------
; uefi_hide_cursor: Oculta el cursor de texto
;   RCX = ConOut (This), RDX = 0 (Visible = FALSE)
; ------------------------------------------------------------------------------
uefi_hide_cursor:
    sub rsp, 40
    mov rax, [ConOut]
    mov rcx, rax                        ; RCX = Arg 1 ('This')
    xor rdx, rdx                        ; RDX = Arg 2 (0 = Ocultar)
    call [rax + OFFSET_CONOUT_ENABLE_CURSOR]
    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; uefi_show_cursor: Muestra el cursor de texto
;   RCX = ConOut (This), RDX = 1 (Visible = TRUE)
; ------------------------------------------------------------------------------
uefi_show_cursor:
    sub rsp, 40
    mov rax, [ConOut]
    mov rcx, rax                        ; RCX = Arg 1 ('This')
    mov rdx, 1                          ; RDX = Arg 2 (1 = Mostrar)
    call [rax + OFFSET_CONOUT_ENABLE_CURSOR]
    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; uefi_set_cursor: Posiciona el cursor en coordenadas específicas (Columna, Fila)
; Entrada:
;   RDX = Columna (eje X, base 0)
;   R8  = Fila (eje Y, base 0)
; Convención Microsoft x64:
;   RCX = ConOut (This), RDX = Column, R8 = Row
; ------------------------------------------------------------------------------
uefi_set_cursor:
    sub rsp, 40
    mov rax, [ConOut]
    mov rcx, rax                        ; RCX = Arg 1 ('This')
    ; RDX ya contiene Columna (Arg 2)
    ; R8 ya contiene Fila (Arg 3)
    call [rax + OFFSET_CONOUT_SET_CURSOR]
    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; uefi_set_color: Establece los colores de texto y fondo de la consola
; Entrada:
;   RDX = Atributo de color (ej: COLOR_YELLOW_ON_BLACK)
; Convención Microsoft x64:
;   RCX = ConOut (This), RDX = Attribute
; ------------------------------------------------------------------------------
uefi_set_color:
    sub rsp, 40
    mov rax, [ConOut]
    mov rcx, rax                        ; RCX = Arg 1 ('This')
    ; RDX ya contiene el atributo de color (Arg 2)
    call [rax + OFFSET_CONOUT_SET_ATTRIBUTE]
    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; uefi_print_string: Imprime una cadena en formato UTF-16LE terminada en 0x0000
; Entrada:
;   RDX = Puntero a la cadena UTF-16
; Convención Microsoft x64:
;   RCX = ConOut (This), RDX = Puntero a CHAR16*
; ------------------------------------------------------------------------------
uefi_print_string:
    sub rsp, 40
    mov rax, [ConOut]
    mov rcx, rax                        ; RCX = Arg 1 ('This')
    ; RDX ya contiene el puntero a la cadena UTF-16 (Arg 2)
    call [rax + OFFSET_CONOUT_OUTPUT_STRING]
    add rsp, 40
    ret
