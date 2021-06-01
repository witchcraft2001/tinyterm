; rs232.inc
; Процедуры работы с портом RS232 для ZX_MCard
;------------------------------------------------
base_com1_addr	equ 0x3f8
base_com2_addr	equ 0x2f8
base_com3_addr	equ 0x3e8
base_com4_addr	equ 0x2e8

SER_P	equ	isa_adr_base + base_com1_addr	;Порт COM1
P_KBD	equ	0FEh	;Порт клавиатуры Спектрума
;------------------------------------------------
;	передать байт (A)
; CY=0 передача успешна
; CY=1 выход по <BREAK>
tx_byte:PUSH	BC
	LD	C,A	;байт для передачи
;/-----
sen1byt:CALL	tst_tx	   ;готов к передаче ?
	JR	NZ,sen2byt ; да
; проверить нажатие клавиши <BREAK>
	CALL	tst_brk	   ;CY=1 если нажата
	jr	nc,sen1byt ;ждать до упора
; выход по нажатию <BREAK>
	POP	BC	   ;CY=1,Z=0
	RET
;\-----
;	Передатчик готов
sen2byt:LD	A,C	;байт здесь
	CALL	dat_ou	;передать байт (A)
	OR	A	;CY=0 OK
	POP	BC
	RET
;---------------------------------------------------------
; tx_ack - wait until the line is clear (i.e. we time out
;	   while receiving chars), and then send an <ack>
;---------------------------------------------------------
tx_ack:	call	rx_t1		; get a char, with 1 second timeout
	jr	nc,tx_ack	; if no timeout, keep gobbling chars
; истек тайм-аут
	ld	a,ack		; <ack> char
	jr	tx_byte		; send it
;---------------------------------------------------------
; tx_nak - wait until the line is clear (i.e. we time out
;	   while receiving chars), and then send a <nak>
;---------------------------------------------------------
tx_nak:	call	rx_t1		; get a char, with 1 second timeout
	jr	nc,tx_nak	; if no timeout, keep gobbling chars
; истек тайм-аут
	ld	a,nak		; <nak> char
	jr	tx_byte		; send it
;---------------------------------------------
; Прием с тайм-аутом в 1 сек
rx_t10:	push	DE
	ld	DE,0000h	; 1 сек
	jr	rec_b3
;-------------------------
; Принять байт с тайм-аутом в 0.1 сек
;	CY=0	прием OK
;	CY=1 	истек тайм-аут
rx_t1:	PUSH	DE
	LD	DE,2000h  	;тайм-аут
;/-----
rec_b3:	CALL	tst_rx	  	;готовность приемника
	JR	NZ,rec_b2	; готов
;
	DEC	DE
	LD	A,D
	OR	E
	JR	NZ,rec_b3
; истек тайм-аут
	scf			;CY=1 - признак тайм-аута
	pop	de
	ret
rec_b2:	call	dat_in		;принять байт
	or	a		;CY=0 - признак OK
	pop	de
	ret
;---------------------------------
;------ Работа с портами ---------
;---------------------------------
; Принять байт из порта RS232
dat_in:	PUSH	hl
	call	open_isa_ports
	LD	hl,SER_P	;Регистр данных
	ld	A,(hl)
	call	close_isa_ports
	POP	hl
	RET
;==============================
; Передать байт в порт RS232
dat_ou:	PUSH	hl
	call	open_isa_ports
	LD	hl,SER_P
	ld	(hl),A
	call	close_isa_ports
	POP	hl
	RET
;==============================
; Проверить на получение байта
tst_rx:	push	hl
	call	open_isa_ports
	LD	hl,SER_P+5	;Чтение (base+5)
	ld	A,(hl)		;
	AND	01h		;RDY_RX(0)
	call	close_isa_ports
	POP	hl
	RET
;=====================================
; Проверить на готовность передать
tst_tx:	push	hl
	call	open_isa_ports
	ld	hl,SER_P+6	;Modem Status Register
	ld	A,(hl)		;(base+6)
	and	10h		;CTS ?
	JR	Z,no_tx		;не готов
; проверить Bufer передатчика
	DEC	hl		;BC=SER_P+5*100h
	ld	A,(hl)		;(base+5)
	and	20h		;Bufer empty ?
no_tx:	call	close_isa_ports
	pop	hl
	RET
;============================
res_rts:push	hl
	call	open_isa_ports
	ld	hl,SER_P+4	;Modem Control Register
	LD	A,01h		;RTS=0,DTR=1
	jr	set_reg
;============================
set_rts:push	hl
	call	open_isa_ports
	ld	hl,SER_P+4	;Modem Control Register
	ld	a,03h		;RTS=1,DTR=1
set_reg:ld	(hl),a
	call	close_isa_ports
	pop	hl
	RET
