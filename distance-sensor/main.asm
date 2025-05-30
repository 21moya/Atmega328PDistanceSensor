;
; distance-sensor.asm
;
; Created: 23.05.2025 14:19:23
; Author : ESLab_NetLab-Student
;

.equ trigPin = 2
.equ inputPin = 3

	sbi DDRD , trigPin

start :
	cbi	PIND, trigPin
	rcall Delay_2microsec
	sbi PIND , trigPin 
	rcall Delay_10microsec
	cbi PIND, trigPin
	LDI r20 , 1
	

	rjmp start


Delay_10microsec:                
Delay1_10:
    LDI     r16,   10     ; One clock cycle
Delay2_10:
    LDI     r17,   4     ; One clock cycle
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