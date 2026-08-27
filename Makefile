# ==============================================================================
# Makefile - CE4303 Sistemas Operativos
# ==============================================================================

ASM = nasm
ASM_FLAGS = -f bin
BIN_DIR = bin

BIOS_IMAGE = $(BIN_DIR)/bios_clock.img

.PHONY: all clean run-bios

all: $(BIOS_IMAGE)

$(BIOS_IMAGE): src/bios/boot.asm src/bios/main.asm src/bios/screen.asm src/bios/rtc.asm src/bios/input.asm
	@mkdir -p $(BIN_DIR)
	$(ASM) $(ASM_FLAGS) src/bios/boot.asm -o $(BIOS_IMAGE)
	@# Expandir a tamaño exacto de un Floppy estándar de 1.44 MB
	truncate -s 1440k $(BIOS_IMAGE)
	@echo "==> [BIOS] Imagen generada: $(BIOS_IMAGE)"

run-bios: $(BIOS_IMAGE)
	env -u LD_LIBRARY_PATH -u LD_PRELOAD qemu-system-x86_64 -fda $(BIOS_IMAGE) -rtc base=localtime

clean:
	rm -rf $(BIN_DIR)
	@echo "==> Directorio bin limpiado."