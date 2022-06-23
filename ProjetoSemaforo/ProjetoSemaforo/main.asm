;
; ProjetoSemaforo.asm
;
; Created: 22/06/2022 14:01:58
; Author : Derek Alves
;		   Ruan Heleno
;		   João Pedro Brito
;		   Matheus Gêda
;

; registrador utilizado para operações temporárias
.def temp = r16

/*
 s1, s2, s3 e s4 são, respectivamente, os semáforos 1, 2, 3 e 4 (no circuito a ordem é de baixo para cima)
*/
.def s1s2 = r0
.def s3s4 = r1

; Registrador time será responsável por armazenar o tempo até o próximo estado (4s, 20s ou 52s)
.def time = r2

;Display 0 é o display de 7-seg que representa as unidades, enquanto o Display 1 representa o display dos decimais
.def display0 = r3
.def display1 = r4

; Registrador count é responsável por contar (lógicamente) o endereço de memória dos estados (explicação abaixo)
.def count = r5


.cseg
;Colocando a interrupção de reset na primeira posição da memória de programa
jmp reset
;Colocando a interrupção Delay de 1 segundo na posição OC1Aaddr
.org OC1Aaddr
jmp OCI1A_Interrupt

; Todo o código foi armazenado na memória após a interrupção Timer


/* 
Primeiramente foi armazenado na memória de programa as informações dos estados, essas informações são descritas
da seguinte forma:

Um estado é representado por 3 bytes, onde:
- O 1º byte tem: 2 bits que selecionam o primeiro transistor e 3 bits para cada um dos dois primeiros semáforos (s1 e s2)
- O 2º byte tem: 2 bits selecionando o segundo transistor e 3 bits para cada um dos dois últimos semáforos (s3 e s4)
- O 3º byte é responsável por armazenar o tempo necessário para ir ao próximo estado

Exemplos: 0b01001010 -> 01 selecionam o primeiro transistor (semáforos s1 e s2) 001 acende o sinal verde para s1
						e 010 que acende o sinal amarelo para s2
		  0b10100001 -> 10 selecionam o segundo transistor (semáforos s1 e s2) 100 acende o sinal vermelho para s3
						e 001 que acende o sinal verde para s4

t1, t2: transistores 1 e 2
s1,s2,s3,s4: semáforos 1,2,3 e 4
R: sinal vermelho
G: verde
Y: amarelo
T: Tempo até o próximo estado
*/

;			  t1,s1,s2    t2,s3,s4    Tempo
states: .db 0b01001100, 0b10100001, 0b00010100, /*; Estado 1: s1:R / s2:G / s3:G / s4:R / T:20s */ \
			0b01001100, 0b10100010, 0b00000100, /*; Estado 2: s1:R / s2:G / s3:Y / s4:R / T:4s */ \
			0b01001100, 0b10001100, 0b00110100, /*; Estado 3: s1:R / s2:G / s3:R / s4:G / T:52s */ \
			0b01010100, 0b10010100, 0b00000100, /*; Estado 4: s1:R / s2:Y / s3:R / s4:Y / T:4s */ \
			0b01100001, 0b10100100, 0b00010100, /*; Estado 5: s1:G / s2:R / s3:R / s4:R / T:20s */ \
			0b01100010, 0b10100100, 0b00000100, /*; Estado 6: s1:Y / s2:R / s3:R / s4:R / T:4s */ \
			0b01100100, 0b10100100, 0b00010100, /*; Estado 7: s1:R / s2:R / s3:R / s4:R / T:20s */ \
			0b00000000 /*; padding para completar a palavra na memória */ \

; Interrupção do Delay de 1
OCI1A_Interrupt:
	;TODO STACK

	; a cada 1 segundo, time é decrementado em 1
	dec time

	; Verifica se o tempo até o próximo estado é zero, se sim ele deve avançar para o próximo estado
	ldi temp, 0
	cp time, temp
	brne no_update; Se for diferente ele não altera o estado atual e vai atualizar o display

	/*
	Antes de avançar para o próximo estado é feita a verificação para saber se já está no último estado.
	Essa verficação ocorre da seguinte maneira:
	Somando todos os estados armazenados na memória, temos 21 bytes, e para cada estado 'count' é incrementado em 3
	Então quando 'count' for igual a 21 estaremos no último estado e o próximo estado será o inicial
	*/

	next_state:
		; Verificação do último estado, se não for o último ele avança, senão ele volta para o inicial
		ldi temp, 21
		cp count, temp
		brne update_state ; Avança o estado

		; Volta para o estado inicial
		; Z será usado para receber as informações do estados
		ldi ZL, low(states*2)
		ldi ZH, high(states*2)
		; Reseta o contador de estados (que conta em bytes [cada estado são 3 bytes])
		ldi temp, 0
		mov count, temp

		; Amazena as informações do estado atual e atualiza Z e 'count' de modo que eles já apontem para o próximo estado
		; Exemplo: Z -> state[0] -> Recebe os dados do estado 0 e incrementa 3 -> state[3] (já preparado para
		;					receber os dados do estado 1)
		update_state:
			lpm s1s2, Z+
			inc count
			lpm s3s4, Z+
			inc count
			lpm time, Z+
			inc count


	no_update:

		ldi temp, 0
		mov display1, temp
		mov temp, time

	splitDigits:

		cpi temp, 10
		brlt dig0
		inc display1
		subi temp, 10
		rjmp splitDigits

		dig0:
		mov display0, temp

		ldi temp, 0b00100000
		add display1, temp
		ldi temp, 0b00010000
		add display0, temp


		;TODO STACK
	reti

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

	ldi ZL, low(states*2)
	ldi ZH, high(states*2)
	ldi temp, 0
	mov count, temp
	lpm s1s2, Z+
	inc count
	lpm s3s4, Z+
	inc count
	lpm time, Z+
	inc count

	sei

main:
	out PORTD, s1s2
	out PORTB, display0

	Rcall Delay5ms
	out PORTD, s3s4
	out PORTB, display1

	Rcall Delay5ms
	
	rjmp main

