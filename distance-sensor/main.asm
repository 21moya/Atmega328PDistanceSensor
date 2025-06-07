.equ exec_delay = 40
;.equ delay_2mikrosec = 8
.equ button = 2
.equ sensor = 3
.equ light = 4
.equ measure_delay_time = 137143


.def cnt = r17
.def cnt_low = r18
.def cnt_mid = r19
.def cnt_high = r20


.def	drem16uL=r24
.def	drem16uH=r25
.def	dd16uL	=r22
.def	dd16uH	=r23
.def	dv16uL	=r28
.def	dv16uH	=r29
.def	dcnt16u	=r30




cbi DDRD, sensor

sbi DDRD, light
cbi PORTD, light

ldi dv16uL, 116
ldi dv16uH, 0

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
	ret

await_signal:
	sbis PIND, sensor
	rjmp await_signal

	ldi r16,0
	sts TCNT1H, r16
	sts TCNT1L, r16
	ldi r16, (1 << 0)
	sts TCCR1B, r16 

	rcall indicate_activity
 	cbi PORTD, light
	ret

indicate_activity:
	sbic PIND, sensor
	rjmp indicate_activity
	
	ldi r16,0
	sts TCCR1B, r16

	lds r22, TCNT1L
	lds r23, TCNT1H

	sbi PORTD, light

	ldi cnt_low , byte1 ( measure_delay_time )
	ldi cnt_mid , byte2 ( measure_delay_time )
	ldi cnt_high , byte3 ( measure_delay_time )
	rcall long_delay
	rcall div16u
	nop
	ret

short_delay:
	dec cnt
	tst cnt
	brne short_delay
	ret

long_delay :
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



div16u:	clr	drem16uL		;clear remainder Low byte
	sub	drem16uH,drem16uH	;clear remainder High byte and carry
	ldi	dcnt16u,17		;init loop counter
d16u_1:	rol	dd16uL			;shift left dividend
	rol	dd16uH
	dec	dcnt16u			;decrement counter
	brne	d16u_2			;if done
	ret				;    return
d16u_2:	rol	drem16uL		;shift dividend into remainder
	rol	drem16uH
	sub	drem16uL,dv16uL		;remainder = remainder - divisor
	sbc	drem16uH,dv16uH		;
	brcc	d16u_3			;if result negative
	add	drem16uL,dv16uL		;    restore remainder
	adc	drem16uH,dv16uH
	clc				;    clear carry to be shifted into result
	rjmp	d16u_1			;else
d16u_3:	sec				;    set carry to be shifted into result
	rjmp	d16u_1
