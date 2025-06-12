.equ exec_delay = 40
;.equ delay_2mikrosec = 8
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

	ldi r26,0
	sts TCNT1H, r26
	sts TCNT1L, r26
	ldi r26, (1 << 1)
	sts TCCR1B, r26 

	rcall indicate_activity
 	cbi PORTD, light
	ret

indicate_activity:
	sbic PIND, sensor
	rjmp indicate_activity
	
	ldi r26,0
	sts TCCR1B, r26

	lds r16, TCNT1L
	lds r17, TCNT1H

	sbi PORTD, light
	rcall D16_nnn
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



D16_nnn:
    LDI   r18,  low(reg_Kd)     ;1abcd
    MOV   r13, r18              ;1abcd
    LDI   r18, high(reg_Kd)     ;1abcd
    MOV   r14, r18              ;1abcd, 4abcd
; r14:r13 = reg_Kd
 
; multiplicand in r17:r16 = {A}
; multiplier   in r14:r13 = {Kd}
; mul. result  in r21:r20:r19:r18
; valid result in r21:r20
    MUL   r17, r14              ;2abcd
    MOVW  r21:r20, r1:r0        ;1abcd
    MUL   r16, r13              ;2abcd
    MOVW  r19:r18, r1:r0        ;1abcd
    MUL   r17, r13              ;2abcd
    CLR   r13                   ;1abcd
    ADD   r19, r0               ;1abcd
    ADC   r20, r1               ;1abcd
    ADC   r21, r13              ;1abcd
    MUL   r14, r16              ;2abcd
    ADD   r19, r0               ;1abcd
    ADC   r20, r1               ;1abcd
    ADC   r21, r13              ;1abcd +17abcd= 21abcd
; {B} = r21:r20 = r17:r16 * r14:r13 /256/256 = {A}*{Kd}/256/256
; {R} = {B} or {B}+1
 
; for rounding
    LDI   r18, reg_N            ;1abcd
    MOV   r13, r18              ;1abcd
; r13 = {N}
 
    MUL   r20, r13              ;2abcd
    MOV   r18, r0               ;1abcd
    MOV   r19, r1               ;1abcd
    MUL   r21, r13              ;2abcd
    ADD   r19, r0               ;1abcd, +9abcd= 30abcd
; {C} = r19:r18 = {B}*{N} = r21:r20 * r13
 
; the following conditions were deduced empirically
; if( Carry_1=0, {R}={B}, if( Zero_2=1 OR Carry_2=0, {R}={B}, {R}={B}+1 ) )
 
    SUB   r18, r16              ;1abcd
    SBC   r19, r17              ;1abcd
; {D1} = r19:r18 = {C} - {A} = r19:r18 - r17:r16
 
    BRCC  DIV_ret               ;2a|1bcd +4a=[34a]
; if Carry_1=0, {R}={B}
 
    SUBI  r18,  low(reg_Kr)     ;1bcd
    SBCI  r19, high(reg_Kr)     ;1bcd
; {D2} = r19:r18 = {D1} - {Kr} = r19:r18 - {Kr}
 
    BREQ  DIV_ret               ;2b|1cd, +7b=[37b]
; if Zero_2=1, {R}={B}
 
    BRCC  DIV_ret               ;2c|1d, +8c=[38c]
; if Carry_2=0, {R}={B}
 
    SUBI  r20,  low(-1)         ;1d
    SBCI  r21, high(-1)         ;1d, +9d=[39d]
; {R}={B}+1
 
DIV_ret:
    RET                         ;4