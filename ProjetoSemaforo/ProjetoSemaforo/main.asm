;
; ProjetoSemaforo.asm
;
; Created: 22/06/2022 14:01:58
; Author : Derek Alves
;		   Ruan Heleno
;		   João Pedro Brito
;		   Matheus Gêda
;

.def temp = r16
.def leds = r17 ;current LED value

.def sinais0 = r0
.def sinais1 = r1
.def display0 = r2
.def display1 = r3
.def state = r4

.cseg

jmp reset
.org OC1Aaddr
jmp OCI1A_Interrupt

OCI1A_Interrupt:
cpi r17, 0
breq case0
rcall s2
ldi r17, 0
rjmp return

case0:
rcall s1
ldi r17, 1


	
return:
reti

s1:
ldi temp, 0b01001001
mov sinais0, temp
ldi temp, 0b10100100
mov sinais1, temp
ldi temp, 0b00011001
mov display0, temp
ldi temp, 0b00100001
mov display1, temp

ret

s2:
ldi temp, 0b01010010
mov sinais0, temp
ldi temp, 0b10001001
mov sinais1, temp
ldi temp, 0b00010111
mov display0, temp
ldi temp, 0b00100011
mov display1, temp

ret

.equ ClockMHz = 16
.equ DelayMs = 5
Delay5ms:
	ldi r22, byte3(ClockMHz * 1000 * DelayMs / 5)
	ldi r21, high(ClockMHz * 1000 * DelayMs / 5)
	ldi r20, low(ClockMHz * 1000 * DelayMs / 5)

	subi r20, 1
	sbci r21, 0
	sbci r22, 0
	brcc pc-3

	ret

reset:
	;Stack initialization
	ldi temp, low(RAMEND)
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp
	

	#define CLOCK 16.0e6 ;clock speed
	#define DELAY 1.0 ;seconds
	.equ PRESCALE = 0b100 ;/128 prescale
	.equ PRESCALE_DIV = 256
	.equ WGM = 0b0100 ;Waveform generation mode: CTC
	;you must ensure this value is between 0 and 65535
	.equ TOP = int(0.5 + ((CLOCK/PRESCALE_DIV)*DELAY))
	.if TOP > 65535
	.error "TOP is out of range"
	.endif

	;On MEGA series, write high byte of 16-bit timer registers first
	ldi temp, high(TOP) ;initialize compare value (TOP)
	sts OCR1AH, temp
	ldi temp, low(TOP)
	sts OCR1AL, temp
	ldi temp, ((WGM&0b11) << WGM10) ;lower 2 bits of WGM
	; WGM&0b11 = 0b0100 & 0b0011 = 0b0000 
	sts TCCR1A, temp
	;upper 2 bits of WGM and clock select
	ldi temp, ((WGM>> 2) << WGM12)|(PRESCALE << CS10)
	; WGM >> 2 = 0b0100 >> 2 = 0b0001
	; (WGM >> 2) << WGM12 = (0b0001 << 3) = 0b0001000
	; (PRESCALE << CS10) = 0b100 << 0 = 0b100
	; 0b0001000 | 0b100 = 0b0001100
	sts TCCR1B, temp ;start counter

	lds r16, TIMSK1
	sbr r16, 1 <<OCIE1A
	sts TIMSK1, r16

	ldi temp, 0xFF		;configure PORTB as output
	out DDRD, temp
	out DDRB, temp

	ldi temp, 0
	mov state, temp
	sei

main:
	ldi r16, 0
	ldi r17, 0
	main_lp:
	out PORTD, r0
	out PORTB, r2

	Rcall Delay5ms
	out PORTD, r1
	out PORTB, r3

	Rcall Delay5ms
	
	rjmp main_lp

