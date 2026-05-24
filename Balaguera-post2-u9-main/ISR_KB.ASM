; =============================================================================
; ISR_KB.ASM — ISR personalizado para IRQ1 (Teclado)
; Autor  : Juan David Kher | Código: 1152430
; Curso  : Arquitectura de Computadores — Unidad 9 Post-Contenido 2
; Compila: nasm -f bin ISR_KB.ASM -o ISR_KB.COM
; Uso    : ISR_KB  (ejecutar en DOSBox desde C:\U9P2\)
;
; Descripción:
;   1. Guarda el vector original de INT 09h (IRQ1 - Teclado)
;   2. Instala un ISR propio que muestra un mensaje por cada tecla presionada
;   3. Espera exactamente 5 pulsaciones de tecla
;   4. Restaura el handler original y termina
; =============================================================================

[BITS 16]
[ORG 0x100]          ; Programa tipo .COM — se carga en CS:0100h

; -----------------------------------------------------------------------------
; Sección de datos
; -----------------------------------------------------------------------------
section .data

    contador    DW 0                            ; Contador de teclas atendidas
    MAX_KEYS    EQU 5                           ; Número de pulsaciones objetivo

    old_isr     DD 0                            ; Almacena SEG:OFF del handler
                                                ; original de INT 09h

    msg_tecla   DB 0Dh, 0Ah,
                DB "  [ISR PROPIO] Tecla detectada por ISR propio$"

    msg_fin     DB 0Dh, 0Ah,
                DB "  [OK] ISR restaurado. Fin del programa.$"

    msg_inicio  DB "Laboratorio ISR_KB — Juan David Kher (1152430)", 0Dh, 0Ah,
                DB "Presione 5 teclas para continuar...", 0Dh, 0Ah, "$"

; -----------------------------------------------------------------------------
; Sección de código principal
; -----------------------------------------------------------------------------
section .text

start:
    ; ── Mostrar mensaje de inicio ────────────────────────────────────────────
    MOV  AH, 09h
    MOV  DX, msg_inicio
    INT  21h

    ; ── Guardar vector original de INT 09h ───────────────────────────────────
    ; INT 21h AH=35h devuelve en ES:BX la dirección del handler actual
    MOV  AX, 3509h          ; AH=35h, AL=09h (número de interrupción)
    INT  21h                ; ES:BX = dirección del handler de INT 09h
    MOV  [old_isr],   BX   ; Guardar offset del handler original
    MOV  [old_isr+2], ES   ; Guardar segmento del handler original

    ; ── Instalar ISR propio ──────────────────────────────────────────────────
    ; INT 21h AH=25h fija el vector AL con la dirección DS:DX
    PUSH DS                 ; Conservar DS actual del programa
    MOV  AX, CS
    MOV  DS, AX             ; DS = CS (segmento donde está mi_isr)
    MOV  DX, mi_isr         ; DX = offset de la nueva rutina
    MOV  AX, 2509h          ; AH=25h, AL=09h
    INT  21h                ; Instalar: INT 09h → mi_isr
    POP  DS                 ; Restaurar DS

    STI                     ; Asegurar que las interrupciones estén habilitadas (IF=1)

    ; ── Bucle de espera activo hasta 5 pulsaciones ───────────────────────────
.esperar:
    MOV  AX, [contador]
    CMP  AX, MAX_KEYS
    JL   .esperar           ; Mientras contador < 5, seguir esperando

    ; ── Restaurar handler original ───────────────────────────────────────────
    CLI                     ; Deshabilitar interrupciones durante la restauración
    LDS  DX, [old_isr]     ; DS:DX = dirección original (carga ambos en un paso)
    MOV  AX, 2509h
    INT  21h                ; Restaurar vector INT 09h al handler original
    STI                     ; Re-habilitar interrupciones

    ; ── Mostrar mensaje de fin y terminar ────────────────────────────────────
    MOV  AH, 09h
    MOV  DX, msg_fin
    INT  21h

    MOV  AH, 4Ch            ; AH=4Ch: terminar proceso
    MOV  AL, 0              ; Código de salida 0 (éxito)
    INT  21h

; =============================================================================
; mi_isr — Rutina de Servicio de Interrupción personalizada para IRQ1
;
; El CPU guarda automáticamente FLAGS, CS y IP al invocar la interrupción.
; Esta rutina:
;   1. Preserva los registros que modifica
;   2. Lee el scancode del puerto 60h (obligatorio para limpiar el buffer)
;   3. Muestra un mensaje en pantalla
;   4. Incrementa el contador global
;   5. Envía EOI (End Of Interrupt) al PIC maestro (puerto 20h)
;   6. Restaura registros y retorna con IRET
; =============================================================================
mi_isr:
    PUSH AX                 ; Preservar registros usados
    PUSH DX
    PUSH DS

    ; Apuntar DS al segmento de datos del programa (= CS en .COM)
    MOV  AX, CS
    MOV  DS, AX

    ; ── Leer y descartar el scancode del buffer del teclado (puerto 60h) ─────
    ; Si NO se lee el scancode, el controlador 8042 no libera la línea IRQ1
    IN   AL, 60h            ; AL = scancode de la tecla presionada

    ; ── Mostrar mensaje de tecla detectada ───────────────────────────────────
    MOV  AH, 09h
    MOV  DX, msg_tecla
    INT  21h

    ; ── Incrementar el contador de teclas ────────────────────────────────────
    INC  WORD [contador]

    ; ── Enviar EOI (End Of Interrupt) al PIC 8259A maestro ───────────────────
    ; Sin EOI, el PIC bloquea todas las IRQs de igual o menor prioridad
    MOV  AL, 20h            ; Comando EOI no específico
    OUT  20h, AL            ; Puerto 20h = registro de comandos del PIC maestro

    POP  DS                 ; Restaurar registros en orden inverso
    POP  DX
    POP  AX

    IRET                    ; Retornar de interrupción (restaura IP, CS, FLAGS)
