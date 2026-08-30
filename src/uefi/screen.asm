; ==============================================================================
; src/uefi/screen.asm - Manejo de Pantalla y Video en UEFI (ConOut)
; ==============================================================================

default rel
bits 64

; ------------------------------------------------------------------------------
; Offsets en EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL (ConOut)
; ------------------------------------------------------------------------------
%define OFFSET_CONOUT_RESET         0x00
%define OFFSET_CONOUT_OUTPUT_STRING 0x08
%define OFFSET_CONOUT_SET_ATTRIBUTE 0x28
%define OFFSET_CONOUT_CLEAR_SCREEN  0x30
%define OFFSET_CONOUT_SET_CURSOR    0x38
%define OFFSET_CONOUT_ENABLE_CURSOR 0x40

; Atributos de color para ConOut->SetAttribute
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

%define COLOR_WHITE_ON_BLACK        0x0F
%define COLOR_YELLOW_ON_BLACK       0x0E
%define COLOR_CYAN_ON_BLACK         0x0B
%define COLOR_GREEN_ON_BLACK        0x0A
%define COLOR_WHITE_ON_BLUE         0x1F

; ------------------------------------------------------------------------------
; uefi_clear_screen: Limpia toda la pantalla de la consola UEFI
; ------------------------------------------------------------------------------
uefi_clear_screen:
    sub rsp, 40
    mov rax, [ConOut]
    mov rcx, rax                        ; RCX = ConOut (This)
    call [rax + OFFSET_CONOUT_CLEAR_SCREEN]
    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; uefi_hide_cursor: Oculta el cursor de la pantalla
; ------------------------------------------------------------------------------
uefi_hide_cursor:
    sub rsp, 40
    mov rax, [ConOut]
    mov rcx, rax                        ; RCX = ConOut (This)
    xor rdx, rdx                        ; RDX = 0 (Visible = FALSE)
    call [rax + OFFSET_CONOUT_ENABLE_CURSOR]
    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; uefi_show_cursor: Muestra el cursor de la pantalla
; ------------------------------------------------------------------------------
uefi_show_cursor:
    sub rsp, 40
    mov rax, [ConOut]
    mov rcx, rax                        ; RCX = ConOut (This)
    mov rdx, 1                          ; RDX = 1 (Visible = TRUE)
    call [rax + OFFSET_CONOUT_ENABLE_CURSOR]
    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; uefi_set_cursor: Posiciona el cursor en Columna y Fila
; Entrada: RDX = Columna, R8 = Fila
; ------------------------------------------------------------------------------
uefi_set_cursor:
    sub rsp, 40
    mov rax, [ConOut]
    mov rcx, rax                        ; RCX = ConOut (This)
    ; RDX ya contiene Columna
    ; R8 ya contiene Fila
    call [rax + OFFSET_CONOUT_SET_CURSOR]
    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; uefi_set_color: Cambia el atributo de color (texto y fondo)
; Entrada: RDX = Atributo de color
; ------------------------------------------------------------------------------
uefi_set_color:
    sub rsp, 40
    mov rax, [ConOut]
    mov rcx, rax                        ; RCX = ConOut (This)
    call [rax + OFFSET_CONOUT_SET_ATTRIBUTE]
    add rsp, 40
    ret

; ------------------------------------------------------------------------------
; uefi_print_string: Imprime una cadena UTF-16 terminada en 0x0000
; Entrada: RDX = Puntero a cadena UTF-16
; ------------------------------------------------------------------------------
uefi_print_string:
    sub rsp, 40
    mov rax, [ConOut]
    mov rcx, rax                        ; RCX = ConOut (This)
    call [rax + OFFSET_CONOUT_OUTPUT_STRING]
    add rsp, 40
    ret

