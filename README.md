
# Balaguera-Post2-U9
**Arquitectura de Computadores — Unidad 9: Entrada y Salida Avanzados**
Post-Contenido 2: ISR Personalizado para IRQ1 (Teclado)

| Campo | Detalle |
|---|---|
| Estudiante | William Balaguera |
| Código | 1152439 |
| Programa | Ingeniería de Sistemas |
| Universidad | Universidad Francisco de Paula Santander |
| Año | 2026 |

---

## Descripción General
Este repositorio contiene tres programas en ensamblador x86 (modo real, 16 bits) que ilustran el manejo avanzado de interrupciones de hardware en DOSBox. Los programas interactúan directamente con el PIC 8259A y el controlador de teclado 8042 mediante instrucciones `IN`/`OUT` y la tabla de vectores de interrupción (IVT).

---

## Conceptos Clave

### PIC 8259A (Programmable Interrupt Controller)
El PIC convierte las señales físicas de IRQ en vectores de interrupción procesables por el CPU:

| IRQ | Vector | Dispositivo | Puerto IMR |
|---|---|---|---|
| IRQ0 | INT 08h | Timer | Bit 0 del puerto 21h |
| IRQ1 | INT 09h | Teclado | Bit 1 del puerto 21h |
| IRQ7 | INT 0Fh | LPT1 | Bit 7 del puerto 21h |

- `Puerto 20h` → Registro de comandos del PIC (envío de EOI)
- `Puerto 21h` → IMR: bit en 1 = IRQ deshabilitada

### Tabla de Vectores de Interrupción (IVT)
- Ocupa los primeros 1024 bytes de memoria (`0000:0000 – 0000:03FF`)
- Cada entrada usa 4 bytes (2 offset + 2 segmento en little-endian)
- `INT 21h AH=35h` → obtiene el vector actual
- `INT 21h AH=25h` → instala un nuevo handler

### EOI (End Of Interrupt)
Al terminar un ISR se debe enviar `20h` al puerto `20h` para notificar al PIC que puede recibir nuevas IRQs.

---

## Estructura del repositorio
```
Balaguera-Post2-U9/
├── README.md
├── ISR_KB.ASM
├── MASK_KB.ASM
├── ISR_CHAIN.ASM
└── capturas/
    ├── checkpoint1.png
    ├── checkpoint2.png
    └── checkpoint3.png
```

---

## Programas

### 1. ISR_KB.ASM — ISR Personalizado para IRQ1
**Descripción:**
Reemplaza temporalmente el handler del vector `INT 09h` con una rutina propia. Por cada tecla presionada muestra el mensaje "Tecla detectada por ISR propio". Al alcanzar 5 pulsaciones restaura el handler original y finaliza.

**Flujo del programa:**
```
start:
  1. Guardar vector original  → INT 21h AH=35h AL=09h → ES:BX
  2. Instalar ISR propio      → INT 21h AH=25h AL=09h con DS:DX = mi_isr
  3. STI (IF=1)
  4. Bucle activo esperando que contador >= 5
  5. CLI → restaurar vector original → STI
  6. Mostrar msg_fin → INT 21h AH=4Ch

mi_isr:
  1. PUSH AX, DX, DS
  2. IN AL, 60h              ; leer scancode del 8042
  3. Mostrar mensaje
  4. INC [contador]
  5. MOV AL, 20h / OUT 20h, AL   ; EOI al PIC
  6. POP DS, DX, AX
  7. IRET
```

**Compilación y ejecución:**
```
nasm -f bin ISR_KB.ASM -o ISR_KB.COM
ISR_KB
```
✔ **Checkpoint 1:** Muestra "Tecla detectada por ISR propio" 5 veces y termina con mensaje de restauración.

---

### 2. MASK_KB.ASM — Enmascaramiento de IRQ1
**Descripción:**
Lee el IMR actual del PIC, activa el bit 1 para deshabilitar IRQ1, espera ~3 segundos y restaura el IMR original.

**Enmascaramiento:**
```
IN  AL, 21h     ; Leer IMR actual
PUSH AX         ; Guardar para restaurar
OR  AL, 02h     ; Bit 1 = IRQ1 → 1 (enmascarar)
OUT 21h, AL     ; Escribir nuevo IMR
```

**Restauración:**
```
POP AX          ; Recuperar IMR original
OUT 21h, AL     ; Restaurar IMR
```

**Compilación y ejecución:**
```
nasm -f bin MASK_KB.ASM -o MASK_KB.COM
MASK_KB
```
✔ **Checkpoint 2:** Durante 3 segundos el teclado no produce salida. Al finalizar muestra "IRQ1 restaurado."

---

### 3. ISR_CHAIN.ASM — Encadenamiento del ISR
**Descripción:**
En lugar de reemplazar el handler original, lo llama después de ejecutar el código propio. El sistema sigue procesando teclas normalmente mientras el ISR registra las pulsaciones.

**Técnica de encadenamiento:**
```
mi_isr_chain:
    ; código propio (leer scancode, incrementar contador)
    PUSHF
    CALL FAR [cs:old_isr]   ; Llamar al handler original
    IRET
```

**Aplicaciones reales:**
- Keyloggers de depuración
- Filtros de accesibilidad
- Drivers de teclado extendidos

**Compilación y ejecución:**
```
nasm -f bin ISR_CHAIN.ASM -o ISR_CHAIN.COM
ISR_CHAIN
```
✔ **Checkpoint 3:** Registra teclas en el contador propio y el eco de DOS sigue activo.

---

## Prerrequisitos

| Software | Versión |
|---|---|
| DOSBox | 0.74 o superior |
| NASM | 2.x en el PATH de DOSBox |
| Editor de texto | Notepad, VS Code, etc. |

**Configuración en DOSBox:**
```
[autoexec]
mount c C:\ruta\a\tu\carpeta\Balaguera-Post2-U9
c:
cd U9P2
```

**Compilar todos los archivos:**
```
nasm -f bin ISR_KB.ASM    -o ISR_KB.COM
nasm -f bin MASK_KB.ASM   -o MASK_KB.COM
nasm -f bin ISR_CHAIN.ASM -o ISR_CHAIN.COM
```

---

## Rúbrica de Autoevaluación

| Criterio | Estado |
|---|---|
| ISR_KB compila sin errores | ✔ |
| Checkpoint 1: 5 mensajes al presionar 5 teclas | ✔ |
| MASK_KB compila sin errores | ✔ |
| Checkpoint 2: teclado silenciado durante 3 s | ✔ |
| ISR_CHAIN compila sin errores | ✔ |
| Checkpoint 3: encadenamiento con eco de DOS activo | ✔ |
| Código comentado en cada sección | ✔ |
| README explica funcionamiento, instalación y restauración | ✔ |
| 3+ commits descriptivos en GitHub | ✔ |

