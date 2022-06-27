;
; ProjetoSemaforo.asm
;
; Created: 22/06/2022 14:01:58
; Author : Derek Alves
;		   Ruan Heleno
;		   Jo�o Pedro Brito
;		   Matheus G�da
;

; registrador utilizado para opera��es tempor�rias
.def temp = r16

/*
 s1, s2, s3 e s4 s�o, respectivamente, os sem�foros 1, 2, 3 e 4 (no circuito a ordem � de baixo para cima na protoboard)
*/
.def s1s2 = r0
.def s3s4 = r1

; Registrador time ser� respons�vel por armazenar o tempo at� o pr�ximo estado (4s, 20s ou 52s)
.def time = r2

;Display 0 � o display de 7-seg que representa as unidades, enquanto o Display 1 representa o display das dezenas
.def display0 = r3
.def display1 = r4

; Registrador count � respons�vel por contar (l�gicamente) o endere�o de mem�ria dos estados (explica��o abaixo)
.def count = r5


.cseg
;Colocando a interrup��o de reset na primeira posi��o da mem�ria de programa
JMP reset
;Colocando a interrup��o Delay de 1 segundo na posi��o OC1Aaddr
.org OC1Aaddr
JMP OCI1A_Interrupt

; Todo o c�digo foi armazenado na mem�ria ap�s a interrup��o Timer


/* 
Primeiramente foi armazenado na mem�ria de programa as informa��es dos estados, essas informa��es s�o descritas
da seguinte forma:

Um estado � representado por 3 bytes, onde:
- O 1� byte tem: 2 bits que selecionam o primeiro transistor e 3 bits para cada um dos dois primeiros sem�foros (s1 e s2)
- O 2� byte tem: 2 bits selecionando o segundo transistor e 3 bits para cada um dos dois �ltimos sem�foros (s3 e s4)
- O 3� byte � respons�vel por armazenar o tempo necess�rio para ir ao pr�ximo estado

Exemplos: 0b01001010 -> 01 selecionam o primeiro transistor (sem�foros s1 e s2) 001 acende o sinal verde para s1
						e 010 que acende o sinal amarelo para s2
		  0b10100001 -> 10 selecionam o segundo transistor (sem�foros s1 e s2) 100 acende o sinal vermelho para s3
						e 001 que acende o sinal verde para s4

t1, t2: transistores 1 e 2
s1,s2,s3,s4: sem�foros 1,2,3 e 4
R: sinal vermelho
G: verde
Y: amarelo
T: Tempo at� o pr�ximo estado
*/

;			  t1,s1,s2    t2,s3,s4    Tempo
states: .db 0b01001100, 0b10100001, 0b00010100, /*; Estado 1: s1:R / s2:G / s3:G / s4:R / T:20s */ \
			0b01001100, 0b10100010, 0b00000100, /*; Estado 2: s1:R / s2:G / s3:Y / s4:R / T:4s */ \
			0b01001100, 0b10001100, 0b00110100, /*; Estado 3: s1:R / s2:G / s3:R / s4:G / T:52s */ \
			0b01010100, 0b10010100, 0b00000100, /*; Estado 4: s1:R / s2:Y / s3:R / s4:Y / T:4s */ \
			0b01100001, 0b10100100, 0b00010100, /*; Estado 5: s1:G / s2:R / s3:R / s4:R / T:20s */ \
			0b01100010, 0b10100100, 0b00000100, /*; Estado 6: s1:Y / s2:R / s3:R / s4:R / T:4s */ \
			0b01100100, 0b10100100, 0b00010100, /*; Estado 7: s1:R / s2:R / s3:R / s4:R / T:20s */ \
			0b00000000 /*; padding para completar a palavra na mem�ria */ \

; Interrup��o do Delay de 1
OCI1A_Interrupt:
	;Salvando o contexto
	PUSH temp ;Salvando r16(temp) na pilha 				
	IN temp, SREG ;Colocando o conte�do de SREG (Status Register) em temp			
	PUSH temp ; Salvando o conte�do de SREG que est� em temp na pilha.

	; a cada 1 segundo, time � decrementado em 1
	DEC time

	; Verifica se o tempo at� o pr�ximo estado � zero, se sim ele deve avan�ar para o pr�ximo estado
	LDI temp, 0
	CP time, temp
	BRNE no_update; Se for diferente ele n�o altera o estado atual e vai atualizar o display

	/*
	Antes de avan�ar para o pr�ximo estado � feita a verifica��o para saber se j� est� no �ltimo estado.
	Essa verfica��o ocorre da seguinte maneira:
	Somando todos os estados armazenados na mem�ria, temos 21 bytes, e para cada estado 'count' � incrementado em 3
	Ent�o quando 'count' for igual a 21 estaremos no �ltimo estado e o pr�ximo estado ser� o inicial
	*/

	RCALL NextState ;Rotina para atualizar o estado
	
	no_update:
		RCALL SplitDig ; Rotina para separar os d�gitos e colocar os digitos nos registradores esp�c�ficos para cada d�gito

	;Recuperando o contexto
	POP temp ;Recuperando o conte�do de SREG que est� na pilha e colocando em temp.
	OUT SREG, temp ;Recuperando o contexto de SREG que estava na pilha para sair da interru��o
	POP temp ; Recuperando o valor de temp anterior a interrup��o.

	RETI ; Retorno da interrup��o

/*Rotina para dividir os d�gitos, a rotina funciona decrementando dezenas e incrementando o digito mais 
significativo at� que o valor seja menor que 10, sendo o valor restante o digito menos significativo.
*/
SplitDig:
	LDI temp, 0 ; Inicializando o digito mais significativo com 0 para que possamos incrementar
	MOV display1, temp
	MOV temp, time ;Utilizando a vari�vel temp para guardar temporariamente o tempo
	splitDigits:
		CPI temp, 10 ; Compara o tempo com 10
		BRLT digit0; Se for menor que 10, � desviado para a label digit0

	INC display1;Caso contr�rio, incrementamos o valor do display mais significativo, uma vez que iremos subtrair uma dezena do tempo em temp
	SUBI temp, 10; Subtraindo uma dezena de temp
	RJMP splitDigits; Itera at� que temp seja menor que 10

	digit0:
		MOV display0, temp ; Move o conet�do do digito menos significativo para o display0

	LDI temp, 0b00100000 ; Fazemos uma soma para definir qual transistor � respons�vel pelo display1 e display0
	ADD display1, temp ; Display 1, Transistor 2
	LDI temp, 0b00010000
	ADD display0, temp ; Display0, Transistor 1 
RET ; Retorno rotina

NextState:

	; Verifica��o do �ltimo estado, se n�o for o �ltimo ele avan�a, sen�o ele volta para o inicial
	LDI temp, 21 ; Inicializando o valor de temp como 21
	CP count, temp;Compara o contador com 21
	BRNE update_state ; Desvia se for diferente de 21
	;Caso contr�rio, o ponteiro � resetado para o estado inicial
	RCALL ResetPointer; Rotina reset do ponteiro
	;Estado � atualizado sempre
	update_state:
		RCALL UpdateState; Rotina de atualiza��o de estado
RET

ResetPointer:
	; Volta para o estado inicial
	; Z ser� usado para receber as informa��es do estados
	LDI ZL, low(states*2)
	LDI ZH, high(states*2)
	; Reseta o contador de estados (que conta em bytes [cada estado s�o 3 bytes])
	LDI temp, 0
	MOV count, temp
RET

/*Amazena as informa��es do estado atual e atualiza Z e 'count' de modo que eles j� apontem para o pr�ximo estado
Exemplo: Z -> state[0] -> Recebe os dados do estado 0 e incrementa 3 -> state[3] (j� preparado para
receber os dados do estado 1)*/
UpdateState:

	LPM s1s2, Z+ ; Carrega da mem�ria de programa o bin�rio correspondendo ao conte�do dos sinais 1 e 2 e incrementa o ponteiro em uma unidade
	INC count	 ; Incrementa o contador em uma unidade
	LPM s3s4, Z+ ; Carrega da mem�ria de programa o bin�rio correspondendo ao conte�do dos sinais 3 e 4 e incrementa o ponteiro em uma unidade
	INC count    ; Incrementa o contador em uma unidade
	LPM time, Z+ ; Carrega da mem�ria de programa o tempo que dura este estado
	INC count    ; Incrementa o contador em uma unidade
RET; Retorno da rotina

;Delay de 5ms, Utilizado para dar um delay entre as sa�das de valores para as portas D e B.
.equ ClockMHz = 16 ; Clock 16Mhz
.equ DelayMs = 5 ; Delay 5ms
Delay5ms:
	LDI r22, byte3(ClockMHz * 1000 * DelayMs / 5);Configurando o contador para o delay
	LDI r21, high(ClockMHz * 1000 * DelayMs / 5)
	LDI r20, low(ClockMHz * 1000 * DelayMs / 5)

	SUBI r20, 1; Subtrai imediato 1
	SBCI r21, 0; Subtrai com Carry
	SBCI r22, 0;Subtrai com Carry
	BRCC pc-3 ;Desvia para pc-3 se o carry n�o est� setado

	RET; Carry set retorna

reset:
	;Inicializando a pilha
	LDI temp, low(RAMEND)
	OUT SPL, temp
	LDI temp, high(RAMEND)
	OUT SPH, temp
	;Configurando o timer de 1s
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

	;Configura��es extras

	LDI temp, 0xFF		;Configurando PORTB and PORTD como sa�da.
	OUT DDRD, temp
	OUT DDRB, temp

	RCALL ResetPointer ; Inicializando o ponteiro dos estados
	RCALL UpdateState ; Obtendo as informa��es do estado inicial
	RCALL SplitDig ; Separando o primeiro tempo em dois d�gitos

	SEI; Ativando as interrup��es

; Na main apenas atualizamos o conte�do das portas B e D, e entre cada atualiza��o chamamos um delay de 5ms
main:
	OUT PORTD, s1s2 ; Conte�do dos sinais 1 e 2 � enviado para a porta D
	OUT PORTB, display0 ; Conte�do do display0 � enviado para a porta B
	RCALL Delay5ms; Delay de 5ms

	OUT PORTD, s3s4; Conte�do dos sinais 3 e 4 � enviado para a porta D
	OUT PORTB, display1; Conte�do do display1 � enviado para a porta B
	RCALL Delay5ms; Delay de 5ms
	
	RJMP main;Itera indefinidamente