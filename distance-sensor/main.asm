.equ fcpu = 16000000
.equ baud = 9600
.equ ubbr = (fcpu / 16 / baud - 1) 
.equ exec_delay = 40
.equ button = 2
.equ sensor = 3
.equ light = 4
.equ measure_delay_time = 137143

.set reg_N = 116                  ; {N}
.set reg_Kd=(2*256*256/reg_N+1)/2 ; {Kd}
.set reg_Kr=(1-reg_N)/2           ; {Kr}

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
	ldi cnt, exec_delay
	sbi DDRD, sensor
	sbi PORTD, sensor
	rcall short_delay
	cbi PORTD, sensor
	cbi DDRD, sensor
	rcall await_signal
	sbi PORTD, light
	rcall start_timer
	rcall sensor_activity
	rcall convert_to_cm
	rcall transmit_distance
	rcall long_delay_init
 	cbi PORTD, light
	ret

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

transmit_distance:
	lds r17, UCSR0A
	sbrs r17, UDRE0
	rjmp transmit_distance
	sts UDR0, r20
	ret

convert_to_cm:
    ldi r18, low(reg_Kd)
    mov r13, r18 
    ldi r18, high(reg_Kd) 
    mov r14, r18
 
    mul r17, r14
    movw r21:r20, r1:r0
    mul r16, r13
    movw r19:r18, r1:r0
    mul r17, r13
    clr r13
    add r19, r0
    adc r20, r1
    adc r21, r13
    mul r14, r16
    add r19, r0
    adc r20, r1
    adc r21, r13
; for rounding
    ldi r18, reg_N
    mov r13, r18
 
    mul r20, r13
    mov r18, r0
    mov r19, r1
    mul r21, r13
    add r19, r0
; the following conditions were deduced empirically
    sub r18, r16
    sbc r19, r17

    brcc convert_ret
    subi r18,  low(reg_Kr)
    sbci r19, high(reg_Kr)
    breq convert_ret
    brcc convert_ret
 
    subi r20,  low(-1)
    sbci r21, high(-1)

convert_ret:
    ret