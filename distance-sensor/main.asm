; ### Definitionen der Konstanten
.equ fcpu = 16000000			    ; CPU-Frequenz in Hz
.equ baud = 9600					; Baudrate für UART-Kommunikation
.equ ubrr = (fcpu / 16 / baud - 1)  ; Berechnung des UBRR-Wertes für die Baudrate
.equ exec_delay = 40				; Zählerwert für kurze Verzögerung (ca. 10ms)
.equ button = 2						; Pin-Nummer für den Button (Eingang)
.equ sensor = 3						; Pin-Nummer für den Sensor (Ein-/Ausgang)
.equ light = 4						; Pin-Nummer für das Licht (Ausgang)
.equ measure_delay_time = 137143	; Zählerwert für lange Verzögerung (ca. 0,5 Sekunden)

; ### Konstanten für die Distanzumrechnung
.equ Divisor = 116                  ; Konstanter Divisor für Umrechnung (Ticks in cm)
.equ reg_Kd=(2*256*256/Divisor+1)/2 ; 2^16 / Konstante = 11314 das ist der multiplikative Kehrwert von N (mit welcher Zahl muss multipliziert werden um 1 zu erhalten)
.equ reg_Kr=(1-Divisor)/2           ; = -57 Ist eine Rundungs bzw. Korrektur Konstante

; ### Registerdefinitionen
.def input_L 	= r16     ; Low-Byte des Eingabewerts (gemessene Zeit in Ticks)
.def input_H 	= r17     ; High-Byte des Eingabewerts
.def Kd_L       = r13     ; Low-Byte von Kd (multiplikativer Kehrwert)
.def Kd_H       = r14     ; High-Byte von Kd
.def tmp_L      = r18	  ; Temporäres Register Low-Byte
.def tmp_H      = r19	  ; Temporäres Register High-Byte
.def result_L   = r20 	  ; Low-Byte des Ergebnisses (Distanz in cm)
.def result_H   = r21	  ; High-Byte des Ergebnisses

.def cnt = r22			  ; Zähler für kurze Verzögerung
.def cnt_low = r23		  ; Low-Byte Zähler für lange Verzögerung
.def cnt_mid = r24		  ; Mid-Byte Zähler für lange Verzögerung
.def cnt_high = r25		  ; High-Byte Zähler für lange Verzögerung

; ### Konfiguration der I/O-Ports
cbi DDRD, sensor	; Setze Sensor-Pin als Eingang
sbi DDRD, light		; Setze Licht-Pin als Ausgang
cbi PORTD, light	; Schalte Licht aus (Low-Level)

; ### Initialisierung der UART-Schnittstelle
initUART :
	ldi r17, LOW (ubrr)						; Lade unteres Byte von UBRR in r17
	sts UBRR0L, r17							; Setze UBRR0L für Baudrate
	ldi r17, HIGH (ubrr)					; Lade oberes Byte von UBRR in r17
	sts UBRR0H, r17							; Setze UBRR0H für Baudrate
	ldi r16, (1 << RXEN0 ) | (1 << TXEN0 )	; Aktiviere UART-Sender und Empfänger
	sts UCSR0B, r16							; Setze Steuerregister UCSR0B

; ### Hauptprogramm: Überwache Button und starte Messung
start:
	sbic PIND, button	; Überspringe nächsten Befehl, wenn Button nicht gedrückt
	rcall measure		; Rufe Messroutine auf, wenn Button gedrückt ist
	rjmp start			; Springe zurück zur Schleife

; ### Messroutine: Führe Distanzmessung durch
measure:
	ldi cnt, exec_delay			; Setze Zähler für kurze Verzögerung (exec_delay)
	sbi DDRD, sensor			; Setze Sensor-Pin als Ausgang
	sbi PORTD, sensor			; Sende Signal an Sensor (High-Level)
	rcall short_delay			; Warte kurze Zeit (ca. 10ms)
	cbi PORTD, sensor			; Stoppe das Senden des Signals (Low-Level)
	cbi DDRD, sensor			; Setze Sensor-Pin zurück auf Eingang
	rcall await_signal			; Warte auf Rücksignal vom Sensor
	sbi PORTD, light 			; Schalte Licht ein (High-Level)
	rcall start_timer			; Starte Timer mit Vorteiler 8 (0,5us pro Tick)
	rcall sensor_activity		; Warte, bis Sensor kein Signal mehr sendet
	rcall convert_to_cm			; Rechne gemessene Zeit in Distanz (cm) um: Ticks / (((1us/0,0343cm)/0.5) * 2) = Ticks / 116 
	rcall transmit_distance		; Sende Distanz über UART
	rcall long_delay_init		; Initialisiere lange Verzögerung gegen zu viele Eingaben
 	cbi PORTD, light			; Schalte Licht aus (Low-Level)
	ret							; Kehre zur Hauptschleife zurück

; ### Warte auf Sensorsignal
await_signal:
	sbis PIND, sensor	; Überspringe nächsten Befehl, wenn Sensor-Pin gesetzt
	rjmp await_signal	; Springe zurück, wenn kein Signal
	ret					; Kehre zurück, wenn Signal erkannt

; ### Starte Timer 1 mit Vorteiler 8
start_timer:
	ldi r26,0			; Setze r26 auf 0
	sts TCNT1H, r26		; Setze Timer 1 High-Byte auf 0
	sts TCNT1L, r26		; Setze Timer 1 Low-Byte auf 0
	ldi r26, (1 << 1)	; Setze CS11-Bit für Vorteiler 8
	sts TCCR1B, r26		; Starte Timer 1
	ret					; Kehre zurück

; ### Stoppe Timer 1 und lese Zählerwert
stop_timer:
	ldi r26,0				; Setze r26 auf 0
	sts TCCR1B, r26			; Stoppe Timer 1
	lds input_L, TCNT1L		; Lade Timer 1 Low-Byte in r16 (input_L)
	lds input_H, TCNT1H		; Lade Timer 1 High-Byte in r17 (input_H)
	ret						; Kehre zurück

; ### Warte auf Sensor-Aktivität
sensor_activity:
	sbic PIND, sensor		; Überspringe nächsten Befehl, wenn Sensor-Pin nicht gesetzt
	rjmp sensor_activity	; Springe zurück, wenn Signal aktiv
	rcall stop_timer		; Stoppe Timer, wenn Signal endet
	ret						; Kehre zurück

; ### Kurze Verzögerung (ca. 10ms)
short_delay:
	dec cnt				; Dekrementiere Zähler
	tst cnt				; Teste, ob Zähler Null ist
	brne short_delay	; Wenn nicht Null, wiederhole
	ret					; Kehre zurück, wenn Zähler Null

; ### Initialisiere lange Verzögerung
long_delay_init:
	ldi cnt_low, byte1 ( measure_delay_time )	; Lade unteres Byte von measure_delay_time
	ldi cnt_mid, byte2 ( measure_delay_time )	; Lade mittleres Byte von measure_delay_time
	ldi cnt_high, byte3 ( measure_delay_time )	; Lade oberes Byte von measure_delay_time

; ### Lange Verzögerung (ca. 0,5 Sekunden)
long_delay:
	clc					; Lösche Carry-Flag
	sbci cnt_low ,1		; Subtrahiere 1 von cnt_low mit Carry
	sbci cnt_mid ,0		; Subtrahiere 0 von cnt_mid mit Carry
	sbci cnt_high ,0	; Subtrahiere 0 von cnt_high mit Carry
	tst cnt_high		; Teste cnt_high
	brne long_delay		; Wenn nicht Null, wiederhole
	tst cnt_mid			; Teste cnt_mid
	brne long_delay		; Wenn nicht Null, wiederhole
	tst cnt_low			; Teste cnt_low
	brne long_delay		; Wenn nicht Null, wiederhole
	ret					; Kehre zurück, wenn Zähler Null

; ### Sende Distanz über UART
transmit_distance:
	lds r17, UCSR0A				; Lade UART-Statusregister
	sbrs r17, UDRE0				; Überspringe, wenn Sendepuffer leer
	rjmp transmit_distance		; Warte, bis Sendepuffer leer
	sts UDR0, result_H			; Sende High-Byte der Distanz
transmit_distance_low:
	lds r17, UCSR0A				; Lade UART-Statusregister
	sbrs r17, UDRE0				; Überspringe, wenn Sendepuffer leer
	rjmp transmit_distance_low	; Warte, bis Sendepuffer leer
	sts UDR0, result_L			; Sende Low-Byte der Distanz
	ret							; Kehre zurück

; ### Umrechnung der Zeit in Distanz (cm)
convert_to_cm:
; Problem keine Hardwareseitige Division mÃ¶glich --> Softwareseitiges Dividieren durch Multiplikation
; Das ganze ist keine wirkliche Division sondern eine AnnÃ¤herung mit einem Skalierungsfaktor

; 16*16-Bit-Multiplikation: (input_H << 8 + input_L) * (Kd_H << 8 + Kd_L):
;	= input*Kd 
;	= input_lo * Kd_lo 
;	+ input_lo * Kd_hi << 8 
;	+ input_hi * Kd_lo << 8
;	+ input_hi * Kd_hi << 16

; Initialisieren der reg_Kd (Konstante der Division) number in 2 registern / 16Bit
    ldi tmp_L, low(reg_Kd)			; Lade Low-Byte von Kd
    mov Kd_L, tmp_L					; Speichere in Kd_L
    ldi tmp_L, high(reg_Kd)			; Lade High-Byte von Kd
    mov Kd_H, tmp_L					; Speichere in Kd_H
 
; Schritt 1: input_H * Kd_H
    mul input_H, Kd_H				; Multipliziere High-Bytes
    movw result_H:result_L, r1:r0	; Speichere Ergebnis

; Schritt 2: input_L * Kd_L
    mul input_L, Kd_L			; Multipliziere Low-Bytes
    movw tmp_H:tmp_L, r1:r0		; Speichere Zwischenergebnis

; Schritt 3: input_H * Kd_L
    mul input_H, Kd_L			; Multipliziere input_H mit Kd_L
    clr Kd_L					; Lösche Kd_L für Carry
    add tmp_H, r0				; Addiere Low-Byte
    adc result_L, r1			; Addiere High-Byte mit Carry
    adc result_H, Kd_L			; Addiere Carry zu result_H

; Schritt 4: Kd_H * input_L
    mul Kd_H, input_L			; Multipliziere Kd_H mit input_L
    add tmp_H, r0				; Addiere Low-Byte
    adc result_L, r1			; Addiere High-Byte mit Carry
    adc result_H, Kd_L			; Addiere Carry zu result_H

; Runden des Ergebnisses
    ldi tmp_L, Divisor			; Lade Divisor
    mov Kd_L, tmp_L				; Speichere in Kd_L

; Multipliziere result_L mit Divisor
    mul result_L, Kd_L			; Multipliziere
    mov tmp_L, r0				; Speichere Low-Byte
    mov tmp_H, r1				; Speichere High-Byte

; Multipliziere result_H mit Divisor
    mul result_H, Kd_L			; Multipliziere
    add tmp_H, r0				; Näherung: Addiere zu tmp_H

; Näherungsweise = Ergebnis * N
; Vergleiche mit Eingabewert: Input * Kd (in etwa) = Input * 2^16 / N
    sub tmp_L, input_L			; Subtrahiere input_L
    sbc tmp_H, input_H			; Subtrahiere input_H mit Carry

; Wenn kein Überlauf, fertig
    brcc convert_ret			; Springe, wenn kein Carry
; Korrektur bei zu großer Rundung
    subi tmp_L,  low(reg_Kr)	; Subtrahiere Korrektur Low
    sbci tmp_H, high(reg_Kr)	; Subtrahiere Korrektur High
    breq convert_ret			; Springe, wenn gleich
    brcc convert_ret			; Springe, wenn kein Carry
 
; Korrigiere Ergebnis um 1, falls nötig
    subi result_L,  low(-1)		; Addiere 1 zu result_L
    sbci result_H, high(-1)		; Addiere Carry zu result_H

convert_ret:
    ret							; Kehre zurück