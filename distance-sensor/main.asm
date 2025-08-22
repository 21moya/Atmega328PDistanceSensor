; ### Definitions of constants
.equ fcpu = 16000000			    ; CPU frequency in Hz
.equ baud = 9600					; Baud rate for UART communication
.equ ubrr = (fcpu / 16 / baud - 1)  ; Calculation of the UBRR value for the baud rate
.equ exec_delay = 40				; Counter value for short delay (approx. 10ms)
.equ button = 2						; Pin number for the button (input)
.equ sensor = 3						; Pin number for the sensor (input/output)
.equ light = 4						; Pin number for the light (output)
.equ measure_delay_time = 137143	; Counter value for long delay (approx. 0.5 seconds)

; ### Constants for distance conversion
.equ Divisor = 116                  ; Constant divisor for conversion (ticks to cm)
.equ reg_Kd=(2*256*256/Divisor+1)/2 ; 2^16 / constant = 11314 — this is the multiplicative reciprocal of N (the number by which to multiply to get 1)
.equ reg_Kr=(1-Divisor)/2           ; = -57 is a rounding/correction constant

; ### Register definitions
.def input_L 	= r16     ; Low byte of the input value (measured time in ticks)
.def input_H 	= r17     ; High byte of the input value
.def Kd_L       = r13     ; Low byte of Kd (multiplicative reciprocal)
.def Kd_H       = r14     ; High byte of Kd
.def tmp_L      = r18	  ; Temporary register low byte
.def tmp_H      = r19	  ; Temporary register high byte
.def result_L   = r20 	  ; Low byte of the result (distance in cm)
.def result_H   = r21	  ; High byte of the result

.def cnt = r22			  ; Counter for short delay
.def cnt_low = r23		  ; Low byte counter for long delay
.def cnt_mid = r24		  ; Mid byte counter for long delay
.def cnt_high = r25		  ; High byte counter for long delay

; ### I/O port configuration
cbi DDRD, sensor	; Set sensor pin as input
sbi DDRD, light		; Set light pin as output
cbi PORTD, light	; Turn light off (low level)

; ### Initialization of the UART interface
initUART :
	ldi r17, LOW (ubrr)						; Load lower byte of UBRR into r17
	sts UBRR0L, r17							; Set UBRR0L for baud rate
	ldi r17, HIGH (ubrr)					; Load upper byte of UBRR into r17
	sts UBRR0H, r17							; Set UBRR0H for baud rate
	ldi r16, (1 << RXEN0 ) | (1 << TXEN0 )	; Enable UART receiver and transmitter
	sts UCSR0B, r16							; Set control register UCSR0B

; ### Main program: monitor button and start measurement
start:
	sbic PIND, button	; Skip next instruction if button not pressed
	rcall measure		; Call measurement routine if button is pressed
	rjmp start			; Jump back to loop

; ### Measurement routine: perform distance measurement
measure:
	ldi cnt, exec_delay			; Set counter for short delay (exec_delay)
	sbi DDRD, sensor			; Set sensor pin as output
	sbi PORTD, sensor			; Send signal to sensor (high level)
	rcall short_delay			; Wait a short time (approx. 10ms)
	cbi PORTD, sensor			; Stop sending the signal (low level)
	cbi DDRD, sensor			; Set sensor pin back to input
	rcall await_signal			; Wait for return signal from sensor
	sbi PORTD, light 			; Turn light on (high level)
	rcall start_timer			; Start timer with prescaler 8 (0.5us per tick)
	rcall sensor_activity		; Wait until sensor stops sending signal
	rcall convert_to_cm			; Convert measured time to distance (cm): Ticks / (((1us/0.0343cm)/0.5) * 2) = Ticks / 116 
	rcall transmit_distance		; Send distance via UART
	rcall long_delay_init		; Initialize long delay to prevent too many inputs
 	cbi PORTD, light			; Turn light off (low level)
	ret							; Return to main loop

; ### Wait for sensor signal
await_signal:
	sbis PIND, sensor	; Skip next instruction if sensor pin is set
	rjmp await_signal	; Jump back if no signal
	ret					; Return when signal detected

; ### Start Timer 1 with prescaler 8
start_timer:
	ldi r26,0			; Set r26 to 0
	sts TCNT1H, r26		; Set Timer1 high byte to 0
	sts TCNT1L, r26		; Set Timer1 low byte to 0
	ldi r26, (1 << 1)	; Set CS11 bit for prescaler 8
	sts TCCR1B, r26		; Start Timer1
	ret					; Return

; ### Stop Timer 1 and read counter value
stop_timer:
	ldi r26,0				; Set r26 to 0
	sts TCCR1B, r26			; Stop Timer1
	lds input_L, TCNT1L		; Load Timer1 low byte into input_L (r16)
	lds input_H, TCNT1H		; Load Timer1 high byte into input_H (r17)
	ret						; Return

; ### Wait for sensor activity
sensor_activity:
	sbic PIND, sensor		; Skip next instruction if sensor pin not set
	rjmp sensor_activity	; Jump back while signal is active
	rcall stop_timer		; Stop timer when signal ends
	ret						; Return

; ### Short delay (approx. 10ms)
short_delay:
	dec cnt				; Decrement counter
	tst cnt				; Test if counter is zero
	brne short_delay	; If not zero, repeat
	ret					; Return when counter is zero

; ### Initialize long delay
long_delay_init:
	ldi cnt_low, byte1 ( measure_delay_time )	; Load low byte of measure_delay_time
	ldi cnt_mid, byte2 ( measure_delay_time )	; Load middle byte of measure_delay_time
	ldi cnt_high, byte3 ( measure_delay_time )	; Load high byte of measure_delay_time

; ### Long delay (approx. 0.5 seconds)
long_delay:
	clc					; Clear carry flag
	sbci cnt_low ,1		; Subtract 1 from cnt_low with carry
	sbci cnt_mid ,0		; Subtract 0 from cnt_mid with carry
	sbci cnt_high ,0	; Subtract 0 from cnt_high with carry
	tst cnt_high		; Test cnt_high
	brne long_delay		; If not zero, repeat
	tst cnt_mid			; Test cnt_mid
	brne long_delay		; If not zero, repeat
	tst cnt_low			; Test cnt_low
	brne long_delay		; If not zero, repeat
	ret					; Return when counter is zero

; ### Transmit distance via UART
transmit_distance:
	lds r17, UCSR0A				; Load UART status register
	sbrs r17, UDRE0				; Skip if transmit buffer is empty
	rjmp transmit_distance		; Wait until transmit buffer is empty
	sts UDR0, result_H			; Send high byte of distance
transmit_distance_low:
	lds r17, UCSR0A				; Load UART status register
	sbrs r17, UDRE0				; Skip if transmit buffer is empty
	rjmp transmit_distance_low	; Wait until transmit buffer is empty
	sts UDR0, result_L			; Send low byte of distance
	ret							; Return

; ### Conversion of time to distance (cm)
convert_to_cm:
; Problem: no hardware division possible --> division in software
; This is not a real division but an approximation using a scaling factor

; 16*16-bit multiplication: (input_H << 8 + input_L) * (Kd_H << 8 + Kd_L):
;	= input*Kd 
;	= input_lo * Kd_lo 
;	+ input_lo * Kd_hi << 8 
;	+ input_hi * Kd_lo << 8
;	+ input_hi * Kd_hi << 16

; Initialize reg_Kd (constant of the division) number in 2 registers / 16-bit
    ldi tmp_L, low(reg_Kd)			; Load low byte of Kd
    mov Kd_L, tmp_L					; Store in Kd_L
    ldi tmp_L, high(reg_Kd)			; Load high byte of Kd
    mov Kd_H, tmp_L					; Store in Kd_H
 
; Step 1: input_H * Kd_H
    mul input_H, Kd_H				; Multiply high bytes
    movw result_H:result_L, r1:r0	; Store result

; Step 2: input_L * Kd_L
    mul input_L, Kd_L			; Multiply low bytes
    movw tmp_H:tmp_L, r1:r0		; Store intermediate result

; Step 3: input_H * Kd_L
    mul input_H, Kd_L			; Multiply input_H with Kd_L
    clr Kd_L					; Clear Kd_L for carry
    add tmp_H, r0				; Add low byte
    adc result_L, r1			; Add high byte with carry
    adc result_H, Kd_L			; Add carry to result_H

; Step 4: Kd_H * input_L
    mul Kd_H, input_L			; Multiply Kd_H with input_L
    add tmp_H, r0				; Add low byte
    adc result_L, r1			; Add high byte with carry
    adc result_H, Kd_L			; Add carry to result_H

; Rounding of the result
    ldi tmp_L, Divisor			; Load divisor
    mov Kd_L, tmp_L				; Store in Kd_L

; Multiply result_L with Divisor
    mul result_L, Kd_L			; Multiply
    mov tmp_L, r0				; Store low byte
    mov tmp_H, r1				; Store high byte

; Multiply result_H with Divisor
    mul result_H, Kd_L			; Multiply
    add tmp_H, r0				; Approximation: add to tmp_H

; Approximately = result * N
; Compare with input value: Input * Kd (approx.) = Input * 2^16 / N
    sub tmp_L, input_L			; Subtract input_L
    sbc tmp_H, input_H			; Subtract input_H with carry

; If no overflow, finished
    brcc convert_ret			; Branch if no carry
; Correction for too large rounding
    subi tmp_L,  low(reg_Kr)	; Subtract correction low
    sbci tmp_H, high(reg_Kr)	; Subtract correction high
    breq convert_ret			; Branch if equal
    brcc convert_ret			; Branch if no carry
 
; Correct result by 1 if necessary
    subi result_L,  low(-1)		; Add 1 to result_L
    sbci result_H, high(-1)		; Add carry to result_H

convert_ret:
    ret							; Return
