# ==============================================================================
# Makefile - CE4303 Sistemas Operativos
# ==============================================================================

ASM = nasm
ASM_FLAGS = -f bin
BIN_DIR = bin

SRC_BIOS_BOOT = src/bios/boot.asm
BIOS_IMAGE = $(BIN_DIR)/bios_clock.bin

.PHONY: all clean run-bios

all: $(BIOS_IMAGE)

$(BIOS_IMAGE): $(SRC_BIOS_BOOT) src/bios/screen.asm src/bios/main.asm
	@mkdir -p $(BIN_DIR)
	$(ASM) $(ASM_FLAGS) $(SRC_BIOS_BOOT) -o $(BIOS_IMAGE)
	@echo "==> [BIOS] Imagen generada: $(BIOS_IMAGE)"

run-bios: $(BIOS_IMAGE)
	env -u LD_LIBRARY_PATH -u LD_PRELOAD qemu-system-x86_64 -fda $(BIOS_IMAGE)

clean:
	rm -rf $(BIN_DIR)
	@echo "==> Directorio bin limpiado."