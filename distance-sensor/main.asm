; ### Definitionen der Konstanten
.equ fcpu = 16000000			    ; CPU-Frequenz in Hz
.equ baud = 9600					; Baudrate f�r UART-Kommunikation
.equ ubrr = (fcpu / 16 / baud - 1)  ; Berechnung des UBRR-Wertes f�r die Baudrate
.equ exec_delay = 40				; Z�hlerwert f�r kurze Verz�gerung (ca. 10ms)
.equ button = 2						; Pin-Nummer f�r den Button (Eingang)
.equ sensor = 3						; Pin-Nummer f�r den Sensor (Ein-/Ausgang)
.equ light = 4						; Pin-Nummer f�r das Licht (Ausgang)
.equ measure_delay_time = 137143	; Z�hlerwert f�r lange Verz�gerung (ca. 0,5 Sekunden)

; ### Konstanten f�r die Distanzumrechnung
.equ Divisor = 116                  ; Konstanter Divisor f�r Umrechnung (Ticks in cm)
.equ reg_Kd=(2*256*256/Divisor+1)/2 ; 2^16 / Konstante = 11314 das ist der multiplikative Kehrwert von N (mit welcher Zahl muss multipliziert werden um 1 zu erhalten)
.equ reg_Kr=(1-Divisor)/2           ; = -57 Ist eine Rundungs bzw. Korrektur Konstante

; ### Registerdefinitionen
.def input_L 	= r16     ; Low-Byte des Eingabewerts (gemessene Zeit in Ticks)
.def input_H 	= r17     ; High-Byte des Eingabewerts
.def Kd_L       = r13     ; Low-Byte von Kd (multiplikativer Kehrwert)
.def Kd_H       = r14     ; High-Byte von Kd
.def tmp_L      = r18	  ; Tempor�res Register Low-Byte
.def tmp_H      = r19	  ; Tempor�res Register High-Byte
.def result_L   = r20 	  ; Low-Byte des Ergebnisses (Distanz in cm)
.def result_H   = r21	  ; High-Byte des Ergebnisses

.def cnt = r22			  ; Z�hler f�r kurze Verz�gerung
.def cnt_low = r23		  ; Low-Byte Z�hler f�r lange Verz�gerung
.def cnt_mid = r24		  ; Mid-Byte Z�hler f�r lange Verz�gerung
.def cnt_high = r25		  ; High-Byte Z�hler f�r lange Verz�gerung

; ### Konfiguration der I/O-Ports
cbi DDRD, sensor	; Setze Sensor-Pin als Eingang
sbi DDRD, light		; Setze Licht-Pin als Ausgang
cbi PORTD, light	; Schalte Licht aus (Low-Level)

; ### Initialisierung der UART-Schnittstelle
initUART :
	ldi r17, LOW (ubrr)						; Lade unteres Byte von UBRR in r17
	sts UBRR0L, r17							; Setze UBRR0L f�r Baudrate
	ldi r17, HIGH (ubrr)					; Lade oberes Byte von UBRR in r17
	sts UBRR0H, r17							; Setze UBRR0H f�r Baudrate
	ldi r16, (1 << RXEN0 ) | (1 << TXEN0 )	; Aktiviere UART-Sender und Empf�nger
	sts UCSR0B, r16							; Setze Steuerregister UCSR0B

; ### Hauptprogramm: �berwache Button und starte Messung
start:
	sbic PIND, button	; �berspringe n�chsten Befehl, wenn Button nicht gedr�ckt
	rcall measure		; Rufe Messroutine auf, wenn Button gedr�ckt ist
	rjmp start			; Springe zur�ck zur Schleife

; ### Messroutine: F�hre Distanzmessung durch
measure:
	ldi cnt, exec_delay			; Setze Z�hler f�r kurze Verz�gerung (exec_delay)
	sbi DDRD, sensor			; Setze Sensor-Pin als Ausgang
	sbi PORTD, sensor			; Sende Signal an Sensor (High-Level)
	rcall short_delay			; Warte kurze Zeit (ca. 10ms)
	cbi PORTD, sensor			; Stoppe das Senden des Signals (Low-Level)
	cbi DDRD, sensor			; Setze Sensor-Pin zur�ck auf Eingang
	rcall await_signal			; Warte auf R�cksignal vom Sensor
	sbi PORTD, light 			; Schalte Licht ein (High-Level)
	rcall start_timer			; Starte Timer mit Vorteiler 8 (0,5us pro Tick)
	rcall sensor_activity		; Warte, bis Sensor kein Signal mehr sendet
	rcall convert_to_cm			; Rechne gemessene Zeit in Distanz (cm) um: Ticks / (((1us/0,0343cm)/0.5) * 2) = Ticks / 116 
	rcall transmit_distance		; Sende Distanz �ber UART
	rcall long_delay_init		; Initialisiere lange Verz�gerung gegen zu viele Eingaben
 	cbi PORTD, light			; Schalte Licht aus (Low-Level)
	ret							; Kehre zur Hauptschleife zur�ck

; ### Warte auf Sensorsignal
await_signal:
	sbis PIND, sensor	; �berspringe n�chsten Befehl, wenn Sensor-Pin gesetzt
	rjmp await_signal	; Springe zur�ck, wenn kein Signal
	ret					; Kehre zur�ck, wenn Signal erkannt

; ### Starte Timer 1 mit Vorteiler 8
start_timer:
	ldi r26,0			; Setze r26 auf 0
	sts TCNT1H, r26		; Setze Timer 1 High-Byte auf 0
	sts TCNT1L, r26		; Setze Timer 1 Low-Byte auf 0
	ldi r26, (1 << 1)	; Setze CS11-Bit f�r Vorteiler 8
	sts TCCR1B, r26		; Starte Timer 1
	ret					; Kehre zur�ck

; ### Stoppe Timer 1 und lese Z�hlerwert
stop_timer:
	ldi r26,0				; Setze r26 auf 0
	sts TCCR1B, r26			; Stoppe Timer 1
	lds input_L, TCNT1L		; Lade Timer 1 Low-Byte in r16 (input_L)
	lds input_H, TCNT1H		; Lade Timer 1 High-Byte in r17 (input_H)
	ret						; Kehre zur�ck

; ### Warte auf Sensor-Aktivit�t
sensor_activity:
	sbic PIND, sensor		; �berspringe n�chsten Befehl, wenn Sensor-Pin nicht gesetzt
	rjmp sensor_activity	; Springe zur�ck, wenn Signal aktiv
	rcall stop_timer		; Stoppe Timer, wenn Signal endet
	ret						; Kehre zur�ck

; ### Kurze Verz�gerung (ca. 10ms)
short_delay:
	dec cnt				; Dekrementiere Z�hler
	tst cnt				; Teste, ob Z�hler Null ist
	brne short_delay	; Wenn nicht Null, wiederhole
	ret					; Kehre zur�ck, wenn Z�hler Null

; ### Initialisiere lange Verz�gerung
long_delay_init:
	ldi cnt_low, byte1 ( measure_delay_time )	; Lade unteres Byte von measure_delay_time
	ldi cnt_mid, byte2 ( measure_delay_time )	; Lade mittleres Byte von measure_delay_time
	ldi cnt_high, byte3 ( measure_delay_time )	; Lade oberes Byte von measure_delay_time

; ### Lange Verz�gerung (ca. 0,5 Sekunden)
long_delay:
	clc					; L�sche Carry-Flag
	sbci cnt_low ,1		; Subtrahiere 1 von cnt_low mit Carry
	sbci cnt_mid ,0		; Subtrahiere 0 von cnt_mid mit Carry
	sbci cnt_high ,0	; Subtrahiere 0 von cnt_high mit Carry
	tst cnt_high		; Teste cnt_high
	brne long_delay		; Wenn nicht Null, wiederhole
	tst cnt_mid			; Teste cnt_mid
	brne long_delay		; Wenn nicht Null, wiederhole
	tst cnt_low			; Teste cnt_low
	brne long_delay		; Wenn nicht Null, wiederhole
	ret					; Kehre zur�ck, wenn Z�hler Null

; ### Sende Distanz �ber UART
transmit_distance:
	lds r17, UCSR0A				; Lade UART-Statusregister
	sbrs r17, UDRE0				; �berspringe, wenn Sendepuffer leer
	rjmp transmit_distance		; Warte, bis Sendepuffer leer
	sts UDR0, result_H			; Sende High-Byte der Distanz
transmit_distance_low:
	lds r17, UCSR0A				; Lade UART-Statusregister
	sbrs r17, UDRE0				; �berspringe, wenn Sendepuffer leer
	rjmp transmit_distance_low	; Warte, bis Sendepuffer leer
	sts UDR0, result_L			; Sende Low-Byte der Distanz
	ret							; Kehre zur�ck

; ### Umrechnung der Zeit in Distanz (cm)
convert_to_cm:
; Problem keine Hardwareseitige Division möglich --> Softwareseitiges Dividieren durch Multiplikation
; Das ganze ist keine wirkliche Division sondern eine Annäherung mit einem Skalierungsfaktor

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
    clr Kd_L					; L�sche Kd_L f�r Carry
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
    add tmp_H, r0				; N�herung: Addiere zu tmp_H

; N�herungsweise = Ergebnis * N
; Vergleiche mit Eingabewert: Input * Kd (in etwa) = Input * 2^16 / N
    sub tmp_L, input_L			; Subtrahiere input_L
    sbc tmp_H, input_H			; Subtrahiere input_H mit Carry

; Wenn kein �berlauf, fertig
    brcc convert_ret			; Springe, wenn kein Carry
; Korrektur bei zu gro�er Rundung
    subi tmp_L,  low(reg_Kr)	; Subtrahiere Korrektur Low
    sbci tmp_H, high(reg_Kr)	; Subtrahiere Korrektur High
    breq convert_ret			; Springe, wenn gleich
    brcc convert_ret			; Springe, wenn kein Carry
 
; Korrigiere Ergebnis um 1, falls n�tig
    subi result_L,  low(-1)		; Addiere 1 zu result_L
    sbci result_H, high(-1)		; Addiere Carry zu result_H

convert_ret:
    ret							; Kehre zur�ck