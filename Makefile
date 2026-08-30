# ==============================================================================
# Makefile - CE4303 Sistemas Operativos
# Tarea 1: Reloj/Cronómetro con Alarma (Modos BIOS y UEFI)
# ==============================================================================

ASM = nasm
LD = ld
PYTHON = python3
BIN_DIR = bin

# Archivos BIOS
BIOS_IMAGE = $(BIN_DIR)/bios_clock.img

# Archivos UEFI
UEFI_SOURCES = src/uefi/main.asm src/uefi/screen.asm src/uefi/input.asm src/uefi/rtc.asm
UEFI_OBJ = $(BIN_DIR)/uefi_main.obj
UEFI_EFI = $(BIN_DIR)/BOOTX64.EFI
UEFI_IMAGE = $(BIN_DIR)/uefi_clock.img

# Ruta OVMF para QEMU
OVMF_BIOS ?= /usr/share/ovmf/OVMF.fd

.PHONY: all clean bios uefi run-bios run-uefi

all: bios uefi

# ------------------------------------------------------------------------------
# Compilación BIOS (Legacy)
# ------------------------------------------------------------------------------
bios: $(BIOS_IMAGE)

$(BIOS_IMAGE): src/bios/boot.asm src/bios/main.asm src/bios/screen.asm src/bios/rtc.asm src/bios/input.asm src/bios/chrono.asm src/bios/alarm.asm
	@mkdir -p $(BIN_DIR)
	$(ASM) -f bin src/bios/boot.asm -o $(BIOS_IMAGE)
	@# Expandir a tamaño exacto de un Floppy estándar de 1.44 MB
	truncate -s 1440k $(BIOS_IMAGE)
	@echo "==> [BIOS] Imagen generada: $(BIOS_IMAGE)"

run-bios: $(BIOS_IMAGE)
	env -u LD_LIBRARY_PATH -u LD_PRELOAD qemu-system-x86_64 -fda $(BIOS_IMAGE) -rtc base=localtime

# ------------------------------------------------------------------------------
# Compilación UEFI (x86_64 PE32+)
# ------------------------------------------------------------------------------
uefi: $(UEFI_IMAGE)

$(UEFI_OBJ): $(UEFI_SOURCES)
	@mkdir -p $(BIN_DIR)
	$(ASM) -f win64 src/uefi/main.asm -o $(UEFI_OBJ)

$(UEFI_EFI): $(UEFI_OBJ)
	$(LD) -m i386pep --oformat pei-x86-64 --subsystem 10 -e efi_main $(UEFI_OBJ) -o $(UEFI_EFI)
	@echo "==> [UEFI] Binario EFI generado: $(UEFI_EFI)"

$(UEFI_IMAGE): $(UEFI_EFI) scripts/make_uefi_img.py
	$(PYTHON) scripts/make_uefi_img.py $(UEFI_EFI) $(UEFI_IMAGE)

run-uefi: $(UEFI_IMAGE)
	env -u LD_LIBRARY_PATH -u LD_PRELOAD qemu-system-x86_64 -bios $(OVMF_BIOS) -drive file=$(UEFI_IMAGE),format=raw -rtc base=localtime -net none

# ------------------------------------------------------------------------------
# Limpieza
# ------------------------------------------------------------------------------
clean:
	rm -rf $(BIN_DIR)
	@echo "==> Directorio bin limpiado."