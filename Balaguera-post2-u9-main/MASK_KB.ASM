; =============================================================================
; MASK_KB.ASM — Enmascarar y desenmascarar IRQ1 usando el IMR del PIC 8259A
; Autor  : Juan David Kher | Código: 1152430
; Curso  : Arquitectura de Computadores — Unidad 9 Post-Contenido 2
; Compila: nasm -f bin MASK_KB.ASM -o MASK_KB.COM
; Uso    : MASK_KB  (ejecutar en DOSBox desde C:\U9P2\)
;
; Descripción:
;   El IMR (Interrupt Mask Register) del PIC maestro reside en el puerto 21h.
;   Cada bit corresponde a una IRQ (bit 0 = IRQ0, bit 1 = IRQ1, etc.).
;   Bit en 1 → IRQ enmascarada (deshabilitada)
;   Bit en 0 → IRQ habilitada
;
;   Este programa:
;   1. Lee el IMR actual y lo guarda en la pila
;   2. Enmascara IRQ1 poniendo el bit 1 en 1 (OR con 02h)
;   3. Espera ~3 segundos usando el timer BIOS (INT 1Ah — 18.2 ticks/s)
;   4. Restaura el IMR original
;   5. Termina limpiamente
; =============================================================================

[BITS 16]
[ORG 0x100]          ; Programa tipo .COM

; -----------------------------------------------------------------------------
; Sección de datos
; -----------------------------------------------------------------------------
section .data

    msg_inicio  DB "Laboratorio MASK_KB — Juan David Kher (1152430)", 0Dh, 0Ah,
                DB "Enmascarando IRQ1 por 3 segundos...", 0Dh, 0Ah, "$"

    msg_mask    DB "  [MASK] IRQ1 enmascarado — teclado deshabilitado...$"

    msg_unmask  DB 0Dh, 0Ah,
                DB "  [OK] IRQ1 restaurado. Teclado habilitado nuevamente.", 0Dh, 0Ah,
                DB "  Fin del programa.$"

; -----------------------------------------------------------------------------
; Sección de código principal
; -----------------------------------------------------------------------------
section .text

start:
    ; ── Mostrar mensaje de inicio ────────────────────────────────────────────
    MOV  AH, 09h
    MOV  DX, msg_inicio
    INT  21h

    ; ── Leer IMR actual y conservarlo en la pila ─────────────────────────────
    ; El puerto 21h es el IMR del PIC 8259A maestro (IRQ0-IRQ7)
    IN   AL, 21h            ; AL = valor actual del IMR
    PUSH AX                 ; Guardarlo en la pila para restaurarlo luego

    ; ── Enmascarar IRQ1 (bit 1 del IMR) ─────────────────────────────────────
    ; OR con 00000010b pone el bit 1 en 1, dejando el resto sin cambios
    OR   AL, 02h            ; Bit 1 = IRQ1 (teclado)
    OUT  21h, AL            ; Escribir nuevo IMR: IRQ1 ahora enmascarada

    ; ── Informar que el teclado está deshabilitado ───────────────────────────
    MOV  AH, 09h
    MOV  DX, msg_mask
    INT  21h

    ; ── Esperar ~3 segundos usando el timer BIOS ─────────────────────────────
    ; INT 1Ah AH=00h devuelve en CX:DX el número de ticks desde el arranque
    ; El timer corre a 18.2065 ticks/segundo → 3 s ≈ 55 ticks
    ;
    ; NOTA: Solo se usa DX (parte baja) lo que es suficiente para 3 segundos.
    ; Si el contador DX desbordara (pasa de 65535 a 0) en esos 3 segundos,
    ; el bucle terminaría antes, pero eso ocurre cada ~59 minutos, aceptable.

    MOV  AH, 00h
    INT  1Ah                ; Leer ticks actuales → CX:DX
    MOV  BX, DX             ; BX = tick inicial (parte baja)
    ADD  BX, 55             ; BX = tick objetivo (inicio + 55 ticks ≈ 3 s)

.wait:
    MOV  AH, 00h
    INT  1Ah                ; Leer ticks actuales → CX:DX de nuevo
    CMP  DX, BX             ; ¿Ya alcanzamos el tick objetivo?
    JL   .wait              ; Si DX < BX, seguir esperando

    ; ── Restaurar IMR original ───────────────────────────────────────────────
    POP  AX                 ; Recuperar el IMR original de la pila
    OUT  21h, AL            ; Restaurar: IRQ1 habilitada nuevamente

    ; ── Informar y terminar ──────────────────────────────────────────────────
    MOV  AH, 09h
    MOV  DX, msg_unmask
    INT  21h

    MOV  AH, 4Ch            ; Terminar proceso DOS
    MOV  AL, 0
    INT  21h
