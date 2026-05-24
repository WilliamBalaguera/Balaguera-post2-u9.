# Kher-Post2-U9

**Arquitectura de Computadores — Unidad 9: Entrada y Salida Avanzados**  
**Post-Contenido 2: ISR Personalizado para IRQ1 (Teclado)**

| Campo | Detalle |
|---|---|
| Estudiante | Juan David Kher |
| Código | 1152430 |
| Programa | Ingeniería de Sistemas |
| Universidad | Universidad Francisco de Paula Santander |
| Año | 2026 |

---

## Descripción General

Este repositorio contiene tres programas en ensamblador x86 (modo real, 16 bits) que demuestran el manejo avanzado de interrupciones de hardware en DOSBox. Los programas interactúan directamente con el **PIC 8259A** y el **controlador de teclado 8042** a través de instrucciones `IN`/`OUT` y la tabla de vectores de interrupción (IVT).

---

## Conceptos Clave

### PIC 8259A (Programmable Interrupt Controller)
El PIC traduce las señales físicas de IRQ a vectores de interrupción que el CPU puede procesar:

| IRQ | Vector | Dispositivo | Puerto IMR |
|-----|--------|-------------|------------|
| IRQ0 | INT 08h | Timer | Bit 0 del puerto 21h |
| IRQ1 | INT 09h | Teclado | Bit 1 del puerto 21h |
| IRQ7 | INT 0Fh | LPT1 | Bit 7 del puerto 21h |

- **Puerto 20h** → Registro de comandos del PIC (se envía EOI aquí)
- **Puerto 21h** → IMR (Interrupt Mask Register): bit en `1` = IRQ deshabilitada

### Tabla de Vectores de Interrupción (IVT)
- Reside en los primeros 1024 bytes de memoria (0000:0000 – 0000:03FF)
- Cada entrada ocupa 4 bytes (2 offset + 2 segmento en formato little-endian)
- `INT 21h AH=35h` → obtiene el vector actual de una interrupción
- `INT 21h AH=25h` → instala un nuevo handler para una interrupción

### EOI (End Of Interrupt)
Al finalizar un ISR, se debe enviar `20h` al puerto `20h` para informar al PIC que la interrupción fue atendida y puede recibir nuevas IRQs de igual o menor prioridad.

---

## Archivos del Repositorio

```
Kher-Post2-U9/
├── README.md           ← Este archivo
├── ISR_KB.ASM          ← Paso 2: ISR personalizado que reemplaza INT 09h
├── MASK_KB.ASM         ← Paso 3: Enmascaramiento de IRQ1 con el IMR
├── ISR_CHAIN.ASM       ← Paso 4: Encadenamiento del ISR con el handler original
└── capturas/
    ├── checkpoint1.png ← Salida de ISR_KB.COM (5 pulsaciones)
    ├── checkpoint2.png ← Salida de MASK_KB.COM (teclado enmascarado)
    └── checkpoint3.png ← Salida de ISR_CHAIN.COM (encadenamiento)
```

---

## ISR_KB.ASM — ISR Personalizado para IRQ1

### ¿Qué hace?
Reemplaza temporalmente el handler del vector INT 09h (IRQ1 - Teclado) con una rutina propia. Por cada tecla presionada, muestra el mensaje `"Tecla detectada por ISR propio"`. Al llegar a 5 pulsaciones, restaura el handler original y termina.

### Flujo del programa
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
  2. IN AL, 60h          ; leer scancode del 8042
  3. Mostrar mensaje
  4. INC [contador]
  5. MOV AL, 20h / OUT 20h, AL   ; EOI al PIC
  6. POP DS, DX, AX
  7. IRET
```

### Compilar y ejecutar
```
nasm -f bin ISR_KB.ASM -o ISR_KB.COM
ISR_KB
```

### Checkpoint 1 ✔
El programa muestra `"Tecla detectada por ISR propio"` exactamente **5 veces**, una por cada pulsación, y luego termina con el mensaje de restauración.

---

## MASK_KB.ASM — Enmascaramiento del IRQ1 con el IMR

### ¿Qué hace?
Lee el IMR actual del PIC (puerto 21h), pone el bit 1 en `1` para deshabilitar IRQ1, espera ~3 segundos (≈55 ticks del timer BIOS a 18.2 Hz), y restaura el IMR original.

### Mecanismo de enmascaramiento
```asm
IN  AL, 21h     ; Leer IMR actual
PUSH AX         ; Guardar para restaurar
OR  AL, 02h     ; Bit 1 = IRQ1 → 1 (enmascarar)
OUT 21h, AL     ; Escribir nuevo IMR
```

### Restauración
```asm
POP AX          ; Recuperar IMR original
OUT 21h, AL     ; Restaurar IMR
```

### Compilar y ejecutar
```
nasm -f bin MASK_KB.ASM -o MASK_KB.COM
MASK_KB
```

### Checkpoint 2 ✔
Durante los 3 segundos de ejecución, las pulsaciones de teclado **no producen salida en pantalla** (IRQ1 enmascarada). Al finalizar el retardo, muestra `"IRQ1 restaurado."` y termina.

---

## ISR_CHAIN.ASM — Encadenamiento del ISR (Chaining)

### ¿Qué hace?
En lugar de reemplazar completamente el handler original, llama al handler anterior **después** de ejecutar el código propio. El sistema operativo sigue procesando las teclas con normalidad (eco de DOS activo), mientras el ISR propio registra las pulsaciones en su contador.

### Técnica de encadenamiento
```asm
mi_isr_chain:
    ; ... código propio (leer scancode, incrementar contador) ...

    PUSHF                   ; Simular push de FLAGS que hace INT
    CALL FAR [cs:old_isr]   ; Llamar al handler original (push CS:IP + jmp)
                            ; El handler original envía su propio EOI y termina con IRET

    IRET                    ; Retornar al contexto interrumpido
```

**Por qué PUSHF + CALL FAR y no JMP FAR:**  
La instrucción `INT` hace internamente: push FLAGS, push CS, push IP, luego salta al handler. El handler termina con `IRET` que saca esos tres valores. Para simular este comportamiento desde dentro de un ISR (donde CS:IP ya están en la pila del CPU), se usa `PUSHF + CALL FAR`, que deja la pila en el estado que espera el `IRET` del handler original.

### Aplicaciones reales del encadenamiento
- Keyloggers de depuración (registrar teclas sin interrumpir el flujo normal)
- Filtros de accesibilidad (modificar teclas especiales)
- Drivers de teclado extendidos (añadir funcionalidad sin reemplazar el handler del BIOS)

### Compilar y ejecutar
```
nasm -f bin ISR_CHAIN.ASM -o ISR_CHAIN.COM
ISR_CHAIN
```

### Checkpoint 3 ✔
El programa registra las teclas en el contador propio Y el eco de DOS sigue funcionando (las teclas aparecen en pantalla normalmente), demostrando encadenamiento correcto.

---

## Prerrequisitos y Configuración

### Software necesario
- **DOSBox 0.74** o superior
- **NASM 2.x** (debe estar en el PATH dentro de DOSBox)
- Editor de texto (Notepad, VS Code, etc.)

### Configuración del entorno en DOSBox
```
# En el archivo dosbox.conf, mapear el directorio del proyecto:
[autoexec]
mount c C:\ruta\a\tu\carpeta\Kher-Post2-U9
c:
cd U9P2
```

### Compilar todos los archivos
```dos
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
