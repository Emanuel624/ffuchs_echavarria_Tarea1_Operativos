# CE4303 - Principios de Sistemas Operativos
## Tarea 1: Reloj / Cronómetro con Alarma Booteable
**Instituto Tecnológico de Costa Rica**  
**Escuela de Ingeniería en Computadores**  
Emanuel Chavarría Hernández y Fernando Fuchs Mora


## Descripción del Proyecto

El presente repositorio cuenta con un **sistema embebido booteable** implementado en **Lenguaje Ensamblador (x86 / x86_64)**, capaz de ejecutarse directamente sobre el hardware sin intermediación de un sistema operativo subyacente.

El sistema cuenta con dos versiones:
1. **Versión Legacy (BIOS clásica de 16 bits):** Utiliza interrupciones clásicas de BIOS y un cargador de arranque MBR de 512 bytes.
2. **Versión UEFI (Modo Largo de 64 bits):** Aplicación (`BOOTX64.EFI`) para hardware real, comunicándose con el firmware mediante tablas de punteros, servicios (`RuntimeServices`, `BootServices`) y protocolos (`ConOut`, `ConIn`).

---

## Funcionalidades Principales

* **Pantalla de Bienvenida Institucional:** Presenta los datos formales, requiriendo confirmación del usuario (`ENTER`) para entrar al modo interactivo.
* **Modo Reloj en Tiempo Real (RTC):** Consulta la hora del hardware en formato `HH:MM:SS`.
* **Modo Cronómetro:** Conteo de tiempo desacoplado, con soporte para inicio/pausa (`S`), reinicio (`R`) y persistencia en segundo plano.
* **Sistema de Alarma Configurable:** Permite programar una hora (`HH:MM`) desde el teclado (`A`). Al coincidir con la hora del sistema, muestra un **aviso con parpadeo visual en pantalla**, se cancela mediante la tecla `C`.
* **Finalización Controlada:** Salida del sistema mediante la tecla `Q`.

---

## Controles del Sistema

| Tecla | Acción | Descripción |
| :---: | :--- | :--- |
| **`ENTER`** | **Confirmar Entrada** | Avanza desde la pantalla de bienvenida a la funcionalidad interactiva. |
| **`M` / `m`** | **Alternar Modo** | Cambia entre Modos  |
| **`S` / `s`** | **Start / Stop** | Inicia o pausa el cronómetro. |
| **`R` / `r`** | **Reset** | Reinicia el cronómetro . |
| **`A` / `a`** | **Configurar Alarma** | Entra al modo de alarma . |
| **`C` / `c`** | **Cancelar Alarma** | Desactiva la alarma. |
| **`Q` / `q`** | **Salir** | Finaliza la aplicación. |

---

## Estructura del Repositorio

```text
Tarea1/
├── Makefile                    # Reglas de compilación y emulación
├── Readme.md                   # Documentación
├── scripts/
│   └── make_uefi_img.py        # Generador de disco virtual para pruebas UEFI en QEMU
├── bin/
│   ├── bios_clock.img          # Imagen booteable BIOS
│   ├── BOOTX64.EFI             # Binario ejecutable UEFI para hardware real
│   └── uefi_clock.img          # Imagen booteable UEFI 
└── src/
    ├── bios/                   # Código fuente versión Legacy (16-bit)
    │   ├── boot.asm            # MBR y cargador de segunda etapa
    │   ├── main.asm            # Dashboard y bucle principal
    │   ├── screen.asm          # Manejo de video BIOS y VRAM
    │   ├── rtc.asm             # Lectura y conversión BCD de RTC
    │   ├── input.asm           # Input de teclado BIOS
    │   ├── chrono.asm          # Temporizador de cronómetro 
    │   └── alarm.asm           # Lógica y parpadeo de alarma BIOS
    └── uefi/                   # Código fuente versión UEFI
        ├── main.asm            # efi_main, Dashboard y despachador UEFI
        ├── screen.asm          # Protocolo ConOut
        ├── rtc.asm             # GetTime y formateo UTF-16
        ├── input.asm           # Protocolo ConIn y Stall
        ├── chrono.asm          # Cronómetro 
        └── alarm.asm           # Configuración, detección y seteo alarma
```

---

## Requisitos para ejecución

Para compilar y ejecutar el proyecto en Linux:

```bash
sudo apt update
sudo apt install nasm binutils qemu-system-x86 ovmf python3 make
```

---

## Compilación y Ejecución

### 1. Compilación Completa
Para compilar ambas versiones (BIOS y UEFI) a la vez:
```bash
make all
```

### 2. Pruebas en Emulador (QEMU)

* **Ejecutar Versión UEFI (x86_64):**
  ```bash
  make run-uefi
  ```

* **Ejecutar Versión Legacy (BIOS):**
  ```bash
  make run-bios
  ```

### 3. Limpieza de Binarios generados
```bash
make clean
```

---

## Ejecución en Hardware Real (Memoria USB)

Para ejecutar la versión **UEFI en una computadora real**:

1. Se necesita una memoria USB con sistema de archivos **FAT32**.
2. Crear la siguiente estructura de carpetas en la raíz de la memoria USB:
   ```text
   USB/
   └── EFI/
       └── BOOT/
   ```
3. Copie el archivo generado `bin/BOOTX64.EFI` dentro de `USB/EFI/BOOT/`:
   ```text
   USB/EFI/BOOT/BOOTX64.EFI
   ```
4. Conectar la memoria USB en la computadora e ingrese a la BIOS, dentro de esta busque **Boot Menu** 
5. Seleccione la opción de arranque **`UEFI: <Nombre de la USB>`**.
