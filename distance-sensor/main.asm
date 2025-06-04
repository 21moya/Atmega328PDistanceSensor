;
; distance-sensor.asm
;
; Created: 23.05.2025 14:19:23
; Author : ESLab_NetLab-Student
;




.equ trigPin= 2
.equ echoPin= 3

    sbi DDRD, trigPin      ; TRIG = output
    cbi DDRD, echoPin  

start:
	cbi PORTD, trigPin
    rcall Delay_2microsec
    sbi PORTD, trigPin
    rcall Delay_10microsec
    cbi PORTD, trigPin
    

   
wait_echo_high:
    sbis PIND, echoPin    
    rjmp wait_echo_high

    
    ldi r16, 0
    sts TCNT1H, r16
    sts TCNT1L, r16

    
    ldi r16, (1 << 0)      
    sts TCCR1B, r16


wait_echo_low:
    sbic PIND, echoPin     
    rjmp wait_echo_low

    ldi r16, 0
    sts TCCR1B, r16

    lds r18, TCNT1L 
    lds r19, TCNT1H


    rjmp start


Delay_10microsec:                
Delay1_10:
    LDI     r16,   10     ; One clock cycle
Delay2_10:
    LDI     r17,   6     ; One clock cycle
Delay3_10:
    DEC     r17            ; One clock cycle
    NOP                     ; One clock cycle
    BRNE    Delay3_10          ; Two clock cycles when jumping to Delay3, 1 clock when continuing to DEC

    DEC     r16            ; One clock cycle
    BRNE    Delay2_10          ; Two clock cycles when jumping to Delay2, 1 clock when continuing to DEC
RET 
	

Delay_2microsec:                
Delay1_2:
    LDI     r18,   2     ; One clock cycle
Delay2:
    LDI     r19,   4     ; One clock cycle
Delay3:
    DEC     r19            ; One clock cycle
    NOP                     ; One clock cycle
    BRNE    Delay3          ; Two clock cycles when jumping to Delay3, 1 clock when continuing to DEC

    DEC     r18            ; One clock cycle
    BRNE    Delay2          ; Two clock cycles when jumping to Delay2, 1 clock when continuing to DEC
RET 