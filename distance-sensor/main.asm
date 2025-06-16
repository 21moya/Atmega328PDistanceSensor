.equ fcpu = 16000000
.equ baud = 9600
.equ ubbr = (fcpu / 16 / baud - 1) 
.equ exec_delay = 40
.equ button = 2
.equ sensor = 3
.equ light = 4
.equ measure_delay_time = 137143

.equ Divisor = 116                  ; Konstanter Divisor
.equ reg_Kd=(2*256*256/Divisor+1)/2 ; 2^16 / Konstante = 11314 das ist der multiplikative Kehrwert von N (mit welcher Zahl muss multipliziert werden um 1 zu erhalten)
.equ reg_Kr=(1-Divisor)/2           ; = -57 Ist eine Rundungs bzw. Korrektur Konstante

.def input_L 	= r16        ; low byte des Eingabewerts
.def input_H 	= r17        ; high byte des Eingabewerts
.def Kd_L       = r13     ; low byte von Kd
.def Kd_H       = r14     ; high byte von Kd
.def tmp_L      = r18	  ; Temp
.def tmp_H      = r19	  ; Temp
.def result_L   = r20 	  ; Highest Temp / Result 
.def result_H   = r21	  ; Highest Temp / Result



.def cnt = r22
.def cnt_low = r23
.def cnt_mid = r24
.def cnt_high = r25

cbi DDRD, sensor

sbi DDRD, light
cbi PORTD, light

initUART :
	ldi r17, LOW (ubbr) ; set ubbr
	sts UBRR0L, r17
	ldi r17, HIGH (ubbr)
	sts UBRR0H, r17
	ldi r16, (1 << RXEN0 ) | (1 << TXEN0 ) ; enable tx and rx
	sts UCSR0B, r16

start:
	sbic PIND, button
	rcall measure 
	rjmp start

measure:
	ldi cnt, exec_delay			; Count Setzen auf exec_Delay für short Delay
	sbi DDRD, sensor			; Sensor Port wird Output
	sbi PORTD, sensor			; Signal wird gesendet
	rcall short_delay			; 10ms Short Delay
	cbi PORTD, sensor			; Stoppe Senden des Signals
	cbi DDRD, sensor			; Ändern des Outputs --> Input
	rcall await_signal			; Warte auf Signal
	sbi PORTD, light 			; Signal --> Turn Light ON 
	rcall start_timer			; Timer mit Vorteiler 8 Wird gestartet --> Pro Count vergeht 0,5us
	rcall sensor_activity		; Warten bis der sensor kein Signal mehr sendet
	rcall convert_to_cm			; Umrechnung der gemessenen Zeit: Ticks / (((1us/0,0343cm)/0.5) * 2) = Ticks / 116 
	rcall transmit_distance		; UART Transmission of calculated Distance
	rcall long_delay_init		; Delay um zuviele Nutzereingaben zu verhindern
 	cbi PORTD, light			; Licht wird ausgemacht
	ret							; Start --> LOOP

await_signal:
	sbis PIND, sensor
	rjmp await_signal
	ret

start_timer:
	ldi r26,0
	sts TCNT1H, r26
	sts TCNT1L, r26
	ldi r26, (1 << 1)
	sts TCCR1B, r26 
	ret

stop_timer:
	ldi r26,0
	sts TCCR1B, r26

	lds r16, TCNT1L
	lds r17, TCNT1H
	ret

sensor_activity:
	sbic PIND, sensor
	rjmp sensor_activity
	rcall stop_timer
	ret

short_delay:
	dec cnt
	tst cnt
	brne short_delay
	ret

long_delay_init:
	ldi cnt_low, byte1 ( measure_delay_time )
	ldi cnt_mid, byte2 ( measure_delay_time )
	ldi cnt_high, byte3 ( measure_delay_time )

; 	0,5 Sekunden Delay
long_delay:
	clc
	sbci cnt_low ,1
	sbci cnt_mid ,0
	sbci cnt_high ,0
	tst cnt_high
	brne long_delay 
	tst cnt_mid
	brne long_delay
	tst cnt_low
	brne long_delay
	ret

; UART Transmission of Distance
transmit_distance:
	lds r17, UCSR0A
	sbrs r17, UDRE0
	rjmp transmit_distance
	sts UDR0, result_L
	ret



convert_to_cm:
;	Problem keine Hardwareseitige Division möglich --> Softwareseitiges Dividieren durch Multiplikation
; 	Das ganze ist keine wirkliche Division sondern eine Annäherung mit einem Skalierungsfaktor

;	16*16 Bit Multiplikation (a_hi << 8 + a_lo) * (b_hi << 8 + b_lo) --> 
;	= a*b 
;	= a_lo * b_lo 
;	+ a_lo * b_hi << 8 
;	+ a_hi * b_lo << 8
; 	+ a_hi * b_hi << 16

; 	Initialisieren der reg_Kd (Konstante der Division) number in 2 registern / 16Bit
    ldi tmp_L, low(reg_Kd)
    mov Kd_L, tmp_L 
    ldi tmp_L, high(reg_Kd) 
    mov Kd_H, tmp_L
 
; 	Erster Teil der Rechnung : a_hi * b_hi
    mul input_H, Kd_H
    movw result_H:result_L, r1:r0

; 	Zweiter Teil der Rechnung : a_lo * b_lo
    mul input_L, Kd_L
    movw tmp_H:tmp_L, r1:r0

; 	Dritter Teil der Rechnung : a_hi * b_lo	
    mul input_H, Kd_L
    clr Kd_L
    add tmp_H, r0
    adc result_L, r1
    adc result_H, Kd_L

; 	Vierter Teil der Rechnung : a_lo * b_hi 
    mul Kd_H, input_L
    add tmp_H, r0
    adc result_L, r1
    adc result_H, Kd_L

; 	Runden
    ldi tmp_L, Divisor
    mov Kd_L, tmp_L

;	Multipliziere mittleren Teil (r20) mit N
    mul result_L, Kd_L
    mov tmp_L, r0
    mov tmp_H, r1

;	Multipliziere oberen Teil (r21) mit N
    mul result_H, Kd_L
    add tmp_H, r0	; Näherungsprodukt

;	Näherungswert = Ergebnis * N
; 	Nun wird das Ergebnis noch mit dem Input verglichen: Input * Kd (in etwa) = Input * 2^16 / N
    sub tmp_L, input_L
    sbc tmp_H, input_H

; 	Wenn carry leer (kein Überlauf), dann fertig
    brcc convert_ret
; 	Bei zu Großer Rundung Korrektur nach Untern
    subi tmp_L,  low(reg_Kr)
    sbci tmp_H, high(reg_Kr)
    breq convert_ret
    brcc convert_ret
 
; 	Nur wenn das Produkt mit Kd minimal zu groß war, wird 1 abgezogen 
    subi result_L,  low(-1)
    sbci result_H, high(-1)

convert_ret:
    ret