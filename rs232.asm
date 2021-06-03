; rs232.asm
; Routines for RS232
;------------------------------------------------
base_com1_addr	equ 0x3f8
base_com2_addr	equ 0x2f8
base_com3_addr	equ 0x3e8
base_com4_addr	equ 0x2e8

SER_P	equ	isa_adr_base + base_com2_addr	;Port COM
;------------------------------------------------
;	send byte (A)
; CY=0 successful
; CY=1 canceled by user <BREAK>
tx_byte:PUSH	BC
	; push	af
	; call	prn_a
	; pop	af
	LD	C,A	;byte for tranceive
;/-----
sen1byt:CALL	tst_tx	   ;ready to tranceive?
	JR	NZ,sen2byt ; yes
; check BREAK key
	CALL	tst_brk	   ;CY=1 if pressed
	jr	nc,sen1byt ;wait
; exit when canceled by <BREAK>
	POP	BC	   ;CY=1,Z=0
	RET
;\-----
;	Tranceiver is ready
sen2byt:LD	A,C	;byte here
	CALL	dat_ou	;send byte (A)
	OR	A	;CY=0 OK
	POP	BC
	RET
;---------------------------------------------------------
; tx_ack - wait until the line is clear (i.e. we time out
;	   while receiving chars), and then send an <ack>
;---------------------------------------------------------
tx_ack:	call	rx_t1		; get a char, with 1 second timeout
	jr	nc,tx_ack	; if no timeout, keep gobbling chars
; time out
	ld	a,ack		; <ack> char
	jr	tx_byte		; send it
;---------------------------------------------------------
; tx_nak - wait until the line is clear (i.e. we time out
;	   while receiving chars), and then send a <nak>
;---------------------------------------------------------
tx_nak:	call	rx_t1		; get a char, with 1 second timeout
	jr	nc,tx_nak	; if no timeout, keep gobbling chars
; time out
	ld	a,nak		; <nak> char
	jr	tx_byte		; send it
;---------------------------------------------
; Receive with time out of 1 sec
rx_t10:	push	DE
	ld	DE,0000h	; 1 sec
	jr	rec_b3
;-------------------------
; Receive byte with time out of 0.1 sec
;	CY=0	receive OK
;	CY=1 	time out
rx_t1:	PUSH	DE
	LD	DE,2000h  	;time out
;/-----
rec_b3:	CALL	tst_rx	  	;receiver is ready
	JR	NZ,rec_b2	; ready
;
	DEC	DE
	LD	A,D
	OR	E
	JR	NZ,rec_b3
; time out
	scf			;CY=1 - time out
	pop	de
	ret
rec_b2:	call	dat_in		;get byte
	or	a		;CY=0 - OK
	pop	de
	ret
;-----------------------------------
;------ Working with ports ---------
;-----------------------------------
; Get byte from RS232 port
dat_in:	PUSH	hl
	call	open_isa_ports
	LD	hl,SER_P	;Receiver buffer register (Read Base)
	ld	A,(hl)
	call	close_isa_ports
	POP	hl
	RET
;==============================
; Send byte to RS232 port
dat_ou:	PUSH	hl
	call	open_isa_ports
	LD	hl,SER_P	;Transmitter holding register (Write Base)
	ld	(hl),A
	call	close_isa_ports
	POP	hl
	RET
;==============================
; Check for received byte
tst_rx:	push	hl
	call	open_isa_ports
	LD	hl,SER_P+5	;Line status register (Read Base+5)
	ld	A,(hl)		;
	AND	01h		;RDY_RX(0)
	call	close_isa_ports
	POP	hl
	RET
;=====================================
; Check for ready to transmit
tst_tx:	push	hl
	call	open_isa_ports
	ld	hl,SER_P+6	;Modem Status Register
	ld	A,(hl)		;(Read Base+6)
	and	10h		;CTS ?
	JR	Z,no_tx		;not ready
; check transmitter Bufer
	DEC	hl		;Line status register (Read Base+5)
	ld	A,(hl)		;(base+5)
	and	20h		;Bufer empty ?
no_tx:	call	close_isa_ports
	pop	hl
	RET
;============================
res_rts:push	hl
	call	open_isa_ports
	ld	hl,SER_P+4	;Modem Control Register (Write Base+4)
	LD	A,01h		;RTS=0,DTR=1
	jr	set_reg
;============================
set_rts:push	hl
	call	open_isa_ports
	ld	hl,SER_P+4	;Modem Control Register (Write Base+4)
	ld	a,03h		;RTS=1,DTR=1
set_reg:ld	(hl),a
	call	close_isa_ports
	pop	hl
	RET
;115200
set_ip_conf:
	call	open_isa_ports
	ld	hl,SER_P+2	;FCR (Write+2)
	ld	(hl),%10000001	;Set 8 bytes FIFO buffer

	ld	hl,SER_P+3	;Line Control Register (Read Base+3)
	ld	a,(hl)
	push	af
	ld	a,%10000011	;enable Baud Rate Generator Latch
	ld	(hl),a
	;set 115200 baud speed
	ld	hl,SER_P	
	ld	c,(hl)
	ld	(hl),1		;DLL(LSB)
	inc	hl
	ld	b,(hl)
	ld	(hl),0		;DLM(MSB)
	and	#7f		;disable Baud Rate Generator Latch
	inc	hl
	inc	hl
	ld	(hl),a		;SER_P+3
	pop	af
	call	close_isa_ports
	ret

;57600
set_ip_conf2:
	call	open_isa_ports
	ld	hl,SER_P+2	;FCR (Write+2)
	ld	(hl),%10000001	;Set 8 bytes FIFO buffer

	ld	hl,SER_P+3	;Line Control Register (Read Base+3)
	ld	a,(hl)
	push	af
	ld	a,%10000011	;enable Baud Rate Generator Latch
	ld	(hl),a
	;set 115200 baud speed
	ld	hl,SER_P	
	ld	c,(hl)
	ld	(hl),2		;DLL(LSB)
	inc	hl
	ld	b,(hl)
	ld	(hl),0		;DLM(MSB)
	and	#7f		;disable Baud Rate Generator Latch
	inc	hl
	inc	hl
	ld	(hl),a		;SER_P+3
	pop	af
	call	close_isa_ports
	ret

get_ip_port:
	call	open_isa_ports
	ld	a,(hl)
	call	close_isa_ports
	RET
