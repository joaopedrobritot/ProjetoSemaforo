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
 s1, s2, s3 e s4 são, respectivamente, os semáforos 1, 2, 3 e 4 (no circuito a ordem é de baixo para cima na protoboard)
*/
.def s1s2 = r0
.def s3s4 = r1

; Registrador time será responsável por armazenar o tempo até o próximo estado (4s, 20s ou 52s)
.def time = r2

;Display 0 é o display de 7-seg que representa as unidades, enquanto o Display 1 representa o display das dezenas
.def display0 = r3
.def display1 = r4

; Registrador count é responsável por contar (lógicamente) o endereço de memória dos estados (explicação abaixo)
.def count = r5


.cseg
;Colocando a interrupção de reset na primeira posição da memória de programa
JMP reset
;Colocando a interrupção Delay de 1 segundo na posição OC1Aaddr
.org OC1Aaddr
JMP OCI1A_Interrupt

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
	;Salvando o contexto
	PUSH temp ;Salvando r16(temp) na pilha 				
	IN temp, SREG ;Colocando o conteúdo de SREG (Status Register) em temp			
	PUSH temp ; Salvando o conteúdo de SREG que está em temp na pilha.

	; a cada 1 segundo, time é decrementado em 1
	DEC time

	; Verifica se o tempo até o próximo estado é zero, se sim ele deve avançar para o próximo estado
	LDI temp, 0
	CP time, temp
	BRNE no_update; Se for diferente ele não altera o estado atual e vai atualizar o display

	/*
	Antes de avançar para o próximo estado é feita a verificação para saber se já está no último estado.
	Essa verficação ocorre da seguinte maneira:
	Somando todos os estados armazenados na memória, temos 21 bytes, e para cada estado 'count' é incrementado em 3
	Então quando 'count' for igual a 21 estaremos no último estado e o próximo estado será o inicial
	*/

	RCALL NextState
	
	no_update:
		RCALL SplitDig
	;Recuperando o contexto
	POP temp ;Recuperando o conteúdo de SREG que está na pilha e colocando em temp.
	OUT SREG, temp ;Recuperando o contexto de SREG que estava na pilha para sair da interrução
	POP temp ; Recuperando o valor de temp anterior a interrupção.

	RETI

SplitDig:
			LDI temp, 0
			MOV display1, temp
			MOV temp, time
		
		splitDigits:
			CPI temp, 10
			BRLT digit0
			INC display1
			SUBI temp, 10
			RJMP splitDigits

			digit0:
			MOV display0, temp

			LDI temp, 0b00100000
			ADD display1, temp
			LDI temp, 0b00010000
			ADD display0, temp
RET

NextState:

			; Verificação do último estado, se não for o último ele avança, senão ele volta para o inicial
			LDI temp, 21
			CP count, temp
			BRNE update_state ; Avança o estado
			
			RCALL ResetPointer

			; Amazena as informações do estado atual e atualiza Z e 'count' de modo que eles já apontem para o próximo estado
			; Exemplo: Z -> state[0] -> Recebe os dados do estado 0 e incrementa 3 -> state[3] (já preparado para
			;					receber os dados do estado 1)
			update_state:

			RCALL UpdateState
RET

ResetPointer:

			; Volta para o estado inicial
			; Z será usado para receber as informações do estados
			LDI ZL, low(states*2)
			LDI ZH, high(states*2)
			; Reseta o contador de estados (que conta em bytes [cada estado são 3 bytes])
			LDI temp, 0
			MOV count, temp
RET

UpdateState:
				LPM s1s2, Z+
				INC count
				LPM s3s4, Z+
				INC count
				LPM time, Z+
				INC count
RET


.equ ClockMHz = 16
.equ DelayMs = 5
Delay5ms:
	LDI r22, byte3(ClockMHz * 1000 * DelayMs / 5)
	LDI r21, high(ClockMHz * 1000 * DelayMs / 5)
	LDI r20, low(ClockMHz * 1000 * DelayMs / 5)

	SUBI r20, 1
	SBCI r21, 0
	SBCI r22, 0
	BRCC pc-3

	RET

reset:
	;Stack initialization
	LDI temp, low(RAMEND)
	OUT SPL, temp
	LDI temp, high(RAMEND)
	OUT SPH, temp
	
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
	LDI temp, high(TOP) ;initialize compare value (TOP)
	STS OCR1AH, temp
	LDI temp, low(TOP)
	STS OCR1AL, temp
	LDI temp, ((WGM&0b11) << WGM10) ;lower 2 bits of WGM
	; WGM&0b11 = 0b0100 & 0b0011 = 0b0000 
	STS TCCR1A, temp
	;upper 2 bits of WGM and clock select
	LDI temp, ((WGM>> 2) << WGM12)|(PRESCALE << CS10)
	; WGM >> 2 = 0b0100 >> 2 = 0b0001
	; (WGM >> 2) << WGM12 = (0b0001 << 3) = 0b0001000
	; (PRESCALE << CS10) = 0b100 << 0 = 0b100
	; 0b0001000 | 0b100 = 0b0001100
	STS TCCR1B, temp ;start counter

	LDS r16, TIMSK1
	SBR r16, 1 <<OCIE1A
	STS TIMSK1, r16

	LDI temp, 0xFF		;configure PORTB and PORTD as output
	OUT DDRD, temp
	OUT DDRB, temp

	RCALL ResetPointer
	RCALL UpdateState
	RCALL SplitDig

	SEI

main:
	OUT PORTD, s1s2
	OUT PORTB, display0
	RCALL Delay5ms

	OUT PORTD, s3s4
	OUT PORTB, display1
	RCALL Delay5ms
	
	RJMP main