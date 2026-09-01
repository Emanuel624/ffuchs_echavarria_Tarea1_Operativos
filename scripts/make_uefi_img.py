#!/usr/bin/env python3
# ==============================================================================
# make_uefi_img.py - Empaqueta BOOTX64.EFI en una imagen FAT12/FAT16 (1.44MB)
# para arranque directo con QEMU + OVMF
# ==============================================================================

import os
import sys
import struct

def create_fat_uefi_image(efi_source_path, output_image_path):
    if not os.path.exists(efi_source_path):
        print(f"Error: No se encontro el archivo binario: {efi_source_path}")
        sys.exit(1)

    with open(efi_source_path, 'rb') as f:
        efi_data = f.read()

    # Parametros para floppy standard de 1.44 MB (2880 sectores de 512 bytes)
    sector_size = 512
    total_sectors = 2880
    sectors_per_cluster = 1
    reserved_sectors = 1
    num_fats = 2
    root_entries = 224
    fat_size_sectors = 9
    
    img = bytearray(total_sectors * sector_size)
    
    # 1. Sector de Booteo (BPB)
    img[0:3] = b'\xeb\x3c\x90'         # jmp short 0x3c, nop
    img[3:11] = b'MSWIN4.1'            # OEM ID
    struct.pack_into('<H', img, 11, sector_size)
    img[13] = sectors_per_cluster
    struct.pack_into('<H', img, 14, reserved_sectors)
    img[16] = num_fats
    struct.pack_into('<H', img, 17, root_entries)
    struct.pack_into('<H', img, 19, total_sectors)
    img[21] = 0xF0                     # Media descriptor (1.44MB 3.5")
    struct.pack_into('<H', img, 22, fat_size_sectors)
    struct.pack_into('<H', img, 24, 18) # Sectores por pista
    struct.pack_into('<H', img, 26, 2)  # Cabezas
    struct.pack_into('<I', img, 28, 0)  # Sectores ocultos
    # Extended BPB
    img[36] = 0x00                     # Unidad 0 (A:)
    img[38] = 0x29                     # Firma extendida
    struct.pack_into('<I', img, 39, 0x19283746) # Serial
    img[43:54] = b'UEFI_DRIVE '
    img[54:62] = b'FAT12   '
    img[510:512] = b'\x55\xaa'          # Firma MBR / Bootsector
    
    fat1_offset = reserved_sectors * sector_size
    fat2_offset = (reserved_sectors + fat_size_sectors) * sector_size
    root_offset = (reserved_sectors + num_fats * fat_size_sectors) * sector_size
    root_size = root_entries * 32
    data_offset = root_offset + root_size
    
    # Inicializar tablas FAT1 y FAT2
    img[fat1_offset:fat1_offset+3] = b'\xF0\xFF\xFF'
    img[fat2_offset:fat2_offset+3] = b'\xF0\xFF\xFF'
    
    def set_fat12(cluster, value):
        for f_off in [fat1_offset, fat2_offset]:
            idx = f_off + (cluster * 3) // 2
            if cluster % 2 == 0:
                img[idx] = (img[idx] & 0x00) | (value & 0xFF)
                img[idx+1] = (img[idx+1] & 0xF0) | ((value >> 8) & 0x0F)
            else:
                img[idx] = (img[idx] & 0x0F) | ((value << 4) & 0xF0)
                img[idx+1] = (value >> 4) & 0xFF

    # 2. Entrada de Directorio Raiz: "EFI" -> Cluster 2
    root_efi = bytearray(32)
    root_efi[0:11] = b'EFI        '
    root_efi[11] = 0x10                # Atributo: Directorio
    struct.pack_into('<H', root_efi, 26, 2)
    img[root_offset:root_offset+32] = root_efi
    set_fat12(2, 0xFFF)                # Cluster 2 finaliza (1 sector)
    
    # 3. Datos de Cluster 2 (Directorio EFI): '.', '..', 'BOOT' -> Cluster 3
    c2_off = data_offset + (2 - 2) * sector_size
    efi_dot = bytearray(32)
    efi_dot[0:11] = b'.          '
    efi_dot[11] = 0x10
    struct.pack_into('<H', efi_dot, 26, 2)
    
    efi_dotdot = bytearray(32)
    efi_dotdot[0:11] = b'..         '
    efi_dotdot[11] = 0x10
    struct.pack_into('<H', efi_dotdot, 26, 0)
    
    efi_boot = bytearray(32)
    efi_boot[0:11] = b'BOOT       '
    efi_boot[11] = 0x10
    struct.pack_into('<H', efi_boot, 26, 3)
    
    img[c2_off:c2_off+32] = efi_dot
    img[c2_off+32:c2_off+64] = efi_dotdot
    img[c2_off+64:c2_off+96] = efi_boot
    set_fat12(3, 0xFFF)                # Cluster 3 finaliza
    
    # 4. Datos de Cluster 3 (Directorio BOOT): '.', '..', 'BOOTX64.EFI' -> Cluster 4
    c3_off = data_offset + (3 - 2) * sector_size
    boot_dot = bytearray(32)
    boot_dot[0:11] = b'.          '
    boot_dot[11] = 0x10
    struct.pack_into('<H', boot_dot, 26, 3)
    
    boot_dotdot = bytearray(32)
    boot_dotdot[0:11] = b'..         '
    boot_dotdot[11] = 0x10
    struct.pack_into('<H', boot_dotdot, 26, 2)
    
    boot_file = bytearray(32)
    boot_file[0:11] = b'BOOTX64 EFI'
    boot_file[11] = 0x20               # Atributo: Archivo
    struct.pack_into('<H', boot_file, 26, 4)
    struct.pack_into('<I', boot_file, 28, len(efi_data))
    
    img[c3_off:c3_off+32] = boot_dot
    img[c3_off+32:c3_off+64] = boot_dotdot
    img[c3_off+64:c3_off+96] = boot_file
    
    # 5. Escribir contenido de BOOTX64.EFI a partir del Cluster 4
    written = 0
    cur_cluster = 4
    while written < len(efi_data):
        chunk = efi_data[written:written + sector_size]
        cur_off = data_offset + (cur_cluster - 2) * sector_size
        img[cur_off:cur_off+len(chunk)] = chunk
        written += len(chunk)
        if written < len(efi_data):
            next_cluster = cur_cluster + 1
            set_fat12(cur_cluster, next_cluster)
            cur_cluster = next_cluster
        else:
            set_fat12(cur_cluster, 0xFFF)
            
    os.makedirs(os.path.dirname(output_image_path), exist_ok=True)
    with open(output_image_path, 'wb') as f:
        f.write(img)
    print(f"==> [UEFI] Imagen generada con exito: {output_image_path} ({len(img)} bytes)")

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Uso: make_uefi_img.py <archivo_efi> <imagen_salida>")
        sys.exit(1)
    create_fat_uefi_image(sys.argv[1], sys.argv[2])

