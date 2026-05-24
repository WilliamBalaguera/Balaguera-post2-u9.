; =============================================================================
; ISR_CHAIN.ASM — ISR con encadenamiento al handler original de IRQ1
; Autor  : William Balaguera | Código: 1152439
; Curso  : Arquitectura de Computadores — Unidad 9 Post-Contenido 2
; Compila: nasm -f bin ISR_CHAIN.ASM -o ISR_CHAIN.COM
; Uso    : ISR_CHAIN  (ejecutar en DOSBox desde C:\U9P2\)
;
; Descripción:
;   En lugar de reemplazar completamente el handler original de INT 09h,
;   el encadenamiento (chaining) ejecuta el código propio y LUEGO llama
;   al handler anterior. Esto permite interceptar la interrupción sin
;   romper el comportamiento normal del sistema operativo.
;
;   Técnica de encadenamiento:
;     PUSHF               ; Simular el comportamiento de una INT (push FLAGS)
;     CALL FAR [old_isr]  ; Llamar al handler original como far call
;     IRET                ; Retornar al código que fue interrumpido
;
;   Aplicación real: keyloggers de depuración, filtros de teclado,
;   accesibilidad — el SO sigue funcionando normalmente mientras
;   el ISR propio registra o modifica las pulsaciones.
;
;   Flujo:
;   1. Guarda el vector original de INT 09h
;   2. Instala mi_isr_chain como nuevo handler
;   3. Espera 5 pulsaciones, registrándolas en el contador propio
;   4. El eco de DOS sigue funcionando (encadenamiento correcto)
;   5. Restaura el handler original y termina
; =============================================================================

[BITS 16]
[ORG 0x100]

; -----------------------------------------------------------------------------
; Sección de datos
; -----------------------------------------------------------------------------
section .data

    contador    DW 0                            ; Contador propio de teclas
    MAX_KEYS    EQU 5                           ; Pulsaciones a interceptar

    old_isr     DD 0                            ; SEG:OFF del handler original

    msg_inicio  DB "Laboratorio ISR_CHAIN — William Balaguera (1152439)", 0Dh, 0Ah,
                DB "ISR con encadenamiento activo.", 0Dh, 0Ah,
                DB "Presione 5 teclas (el eco de DOS debe seguir funcionando)...",
                DB 0Dh, 0Ah, "$"

    msg_tecla   DB 0Dh, 0Ah,
                DB "  [CHAIN-ISR] Tecla interceptada — contador propio activo$"

    msg_fin     DB 0Dh, 0Ah,
                DB "  [OK] ISR encadenado restaurado. Fin del programa.$"

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
    MOV  AX, 3509h          ; AH=35h: obtener handler actual de INT 09h
    INT  21h                ; ES:BX = dirección del handler actual
    MOV  [old_isr],   BX   ; Guardar offset
    MOV  [old_isr+2], ES   ; Guardar segmento

    ; ── Instalar ISR con encadenamiento ──────────────────────────────────────
    PUSH DS
    MOV  AX, CS
    MOV  DS, AX             ; DS = CS (donde reside mi_isr_chain)
    MOV  DX, mi_isr_chain   ; DX = offset del nuevo handler
    MOV  AX, 2509h          ; AH=25h: fijar vector INT 09h
    INT  21h
    POP  DS

    STI                     ; Interrupciones habilitadas (IF = 1)

    ; ── Bucle de espera hasta 5 pulsaciones ──────────────────────────────────
.esperar:
    MOV  AX, [contador]
    CMP  AX, MAX_KEYS
    JL   .esperar

    ; ── Restaurar handler original ───────────────────────────────────────────
    CLI
    LDS  DX, [old_isr]
    MOV  AX, 2509h
    INT  21h
    STI

    ; ── Mostrar mensaje de fin y terminar ────────────────────────────────────
    MOV  AH, 09h
    MOV  DX, msg_fin
    INT  21h

    MOV  AH, 4Ch
    MOV  AL, 0
    INT  21h

; =============================================================================
; mi_isr_chain — ISR encadenada para IRQ1
;
; DIFERENCIA CLAVE respecto a ISR_KB:
;   En ISR_KB se enviaba el EOI manualmente y se terminaba con IRET.
;   En ISR_CHAIN NO se envía EOI propio — el handler original se encarga
;   de enviarlo. Tampoco se llama INT 21h para mostrar el mensaje antes del
;   encadenamiento (podría causar reentrada en DOS). El mensaje se muestra
;   desde el handler original a través del encadenamiento.
;
;   Secuencia de encadenamiento:
;     1. Código propio (leer scancode, incrementar contador)
;     2. PUSHF              — simula el push de flags que hace INT
;     3. CALL FAR [old_isr] — simula el CALL que hace INT (push CS:IP + jmp)
;        El handler original termina con IRET, que retorna aquí
;     4. IRET               — retornar al código interrumpido
; =============================================================================
mi_isr_chain:
    PUSH AX                 ; Preservar registros
    PUSH DX
    PUSH DS

    ; Apuntar DS al segmento de datos del programa
    MOV  AX, CS
    MOV  DS, AX

    ; ── Leer el scancode del buffer del teclado ──────────────────────────────
    ; Es obligatorio leerlo ANTES del encadenamiento; de lo contrario,
    ; el handler original lo leería y el buffer del 8042 se leería dos veces.
    ; Sin embargo, algunos handlers originales esperan leer el scancode ellos
    ; mismos — en DOSBox este enfoque (leer aquí) funciona correctamente.
    IN   AL, 60h            ; AL = scancode

    ; ── Incrementar contador propio ──────────────────────────────────────────
    INC  WORD [contador]

    ; ── Mostrar mensaje de intercepción ──────────────────────────────────────
    MOV  AH, 09h
    MOV  DX, msg_tecla
    INT  21h

    POP  DS                 ; Restaurar DS antes del encadenamiento
    POP  DX
    POP  AX

    ; ── Encadenar con el handler original ────────────────────────────────────
    ; PUSHF simula el push de FLAGS que realiza la instrucción INT.
    ; CALL FAR simula el push de CS:IP y el salto al handler.
    ; El handler original terminará con IRET (que saca FLAGS, CS, IP).
    ; Al regresar de CALL FAR, ejecutamos nuestro propio IRET.
    PUSHF
    CALL FAR [cs:old_isr]   ; Llamar al handler original de INT 09h
                            ; El handler original envía el EOI al PIC

    IRET                    ; Retornar al contexto interrumpido
