	include "dss_equ.asm"
	include "head.asm"
	include "sp_equ.asm"
	
;========================================================+
; Mini terminal for working with serial port             !
;====== 02.05.2006 ======================================+
; Kamil Karimov (caro) k2k@list.ru                       !
;====== 03.06.2021 ======================================+
; Dmitry Mikhaltchenkov (Hard) mikhaltchenkov@gmail.com  !
;========================================================+
; Screen Control codes
BS	equ	08h	;Back space
TAB	equ	09h	;Tab
CR	equ	0Dh	;Caret return
LF	equ	0Ah	;Line Feed
ESC	equ	1Bh	;Escape
; RS232 Control codes
soh	equ	01h	; ASCII <soh> char
eot	equ	04h	; ASCII <eot> char
ack	equ	06h	; ASCII <ack> char
nak	equ	15h	; ASCII <nak> char
;---------------------------------------
run_adr	equ	0C000h	;Addres for load and run code
;---------------------------------------
;.z80
; Start application
begin:
start:	call	clear_screen	;CLS SCREEN
	ld	hl,txt_tt	;Print header
	call	prn_tx		;
	xor	a		; 0
	ld	(flg_xm),a	;-> loading flag
	ld	hl,txt_isa_reset
	call	prn_tx

	call	reset_isa
	call	set_ip_conf
	; ld	hl,esp_baudrate_set
	; call	send_cmd
	; call	set_ip_conf2
	; ld	hl,esp_test
	; call	send_cmd
	jp	term_

	;read all com ports
	; ld	hl,isa_adr_base + base_com1_addr
	; call	read_ports
	; ld	hl,isa_adr_base + base_com2_addr
	; call	read_ports
	; ; ld	hl,isa_adr_base + base_com3_addr
	; ; call	read_ports
	; ; ld	hl,isa_adr_base + base_com4_addr
	; ; call	read_ports

	; call	set_ip_conf
run_term:
;	call	set_ip_conf	;Configure 16550
;	ld	l,a
;	ld	bc,txt_baud
;	call	PRNUM
;	ld	hl,txt_ip_conf
;	call	prn_tx

; isa_test:
; 	push	bc
; 	pop	hl
; 	ld	bc,txt_baud
; 	push	bc
; 	call	PRNUM0
; 	pop	hl
; 	call	prn_tx

; 	ld	hl,isa_adr_base + base_com1_addr
; 	call	read_ports
; 	ld	hl,isa_adr_base + base_com2_addr
; 	call	read_ports

; 	jp	break

; read_ports:
; 	push	hl
; 	ld	hl,cr_lf
; 	call	prn_tx
; 	pop	hl
; 	ld	b,8
; .loop:	push	bc	
; 	push	hl
; 	ld	hl,txt_com_adr
; 	call	prn_tx
; 	pop	hl
; 	push	hl
; 	ld	bc,txt_baud
; 	push	bc
; 	call	PRNUM0
; 	pop	hl
; 	call	prn_tx
; 	ld	hl,txt_com_value
; 	call	prn_tx
; 	pop	hl
; 	push	hl
; 	call	get_ip_port
; 	ld	l,a
; 	ld	bc,txt_baud1
; 	push	bc
; 	call	PRNUM
; 	pop	hl
; 	call	prn_tx
; 	pop	hl
; 	pop	bc
; 	inc	hl
; 	ld	a,h
; 	push	hl
; 	cp	6
; 	ld	hl,cr_lf
; 	call	z,prn_tx
; 	pop	hl
; 	djnz	.loop
; 	ld	hl,cr_lf
; 	call	prn_tx
; 	ret	

esp_baudrate_set:
	db	'AT+UART=57600,8,1,0,0',CR,LF,0
esp_test:
	db	'AT',CR,LF,0

txt_isa_reset:
	db	'Reseting ISA ...'
cr_lf:	db	CR,LF,0
; txt_com_adr:
; 	db	' Addr: ',0
; txt_com_value:
; 	db	' = ',0

;*****************************************
; Quit from terminal
break:
	call	close_isa_ports
	LD	BC, 0x0041
	RST	0x10			; exit
clear_screen:
	ld	de,0
	xor	a
	push	de
	ld	hl,2050h
	ld	b,7
	ld	c,Dss.Clear
	rst	10h
	pop	de
	ld	c,Dss.Locate
	rst	10h
	ret
; Esc - Clear the screen and set cursor position to 0
clr_scr:
	call	clear_screen	;CLS SCREEN
term_:	
;//-------------------------------------------------
	ld	hl,0
	ld	(cnt_rd),hl	;buffer counter = 0
;/-------------------------------
z_cikl: call	set_rts		;готов к приему
	ld	hl,buf_rd	;буфер терминала
	ld	(adr_rx),hl	;-> указатели
	ld	(adr_rd),hl	;
;/--------------------------------------------------
c_term:	call	scan_key	;Клавиша нажата ?
	jr	z,no_key	;Если = 0, то нет
	ld	a,d
	cp	#44		;F10
	jr	z,break		;-> выход из программы
	BIT	5,B             ;При нажатом Ctrl
        jr      z,tst_keys
        and     #7f
        cp      #2a             ;Ctrl+Z
	jr	z,break		;-> выход из программы
; клавиша нажата
; проверить управляющие коды
tst_keys:
	ld	a,e
	cp	' '		;все что меньше 20h
	jr	c,tst_cc	;
	cp	80h		;и все что больше 7Fh
	jr	c,send_s	;остальное передать
; проверить коды управления 0..1F, 80h..0FFh
tst_cc:	cp	CR		;ENTER
	jr	z,send_cr
;
;	cp	SS_Q	 	;SS+Q ?	
;	jr	z,break		;-> выход из программы
;
	; cp	SS_E		;SS+E ?
	; jr	z,clr_scr	;-> очистка экрана
;
	cp	BS		;<- возврат на шаг ?
	jr	z,back_s	;
	cp	#1b		;Esc
	jr	z,clr_scr	;-> Clear screen
	ld	a,d
	ld	hl,c_term	;адрес возврата
	push	hl		; из процедуры
	ld	hl,run_adr	; адрес загрузки и запуска
;
	cp	#43		;F9
	jr	z,run_fl	;-> запустить файл
	; cp	CS_3		;CS+3 Page Up   ?
	; jr	z,run_fl	; -> запустить файл
	
	; cp	CS_4		;CS+4 Page Down ?
	; ret	nz		; 
	cp	#3f		;F5
	ret	nz		;-> to loop start

;\-------------------------------
; принять файл по протоколу XMODEM
rx_fl:	ld	(adr_fl),hl	;Адрес загрузки
	ld	hl,txt_rx	; 'XMODEM '
	call	prn_tx
	jp	rx_file		;принять файл
; запустить файл если в первом байте команда JMP
run_fl:	ld	a,(flg_xm)	;флаг загрузки
	or	a		; если = 0
	jr	z,no_jmp	;значит нет файла
	jp	(hl)		;запустить файл
no_jmp:	ld	hl,txt_jm	; 'No file'
	jp	prn_tx		;
;--------------------------------------------
; возврат на шаг
back_s:	ld	a,BS		;Back Space
	jr	send_s
; возврат каретки
send_cr:
	ld	a,CR		;CR
	call	tx_byte
	ld	a,LF		;LF
	call	tx_byte
	ld	a,CR		;возврат каретки

; send_cmd:
; 	ld	a,(hl)
; 	and	a
; 	ret	z
; 	push	hl
; 	call	send_sym
; 	pop	hl
; 	jr	send_cmd
;------
; введенный с клавиатуры символ (A) -> RS232
send_s:	call	tx_byte 	;передать
;------
no_key:
;/---  Проверить прием кода по RS232 -------
get_rx:	ld	b,100		;число попыток
get2rx:	call	tst_rx	 	;байт принят ?
	jr	nz,yes_rx	; Да
	djnz	get2rx		;
	jr	no_get		;пока нет
;------
yes_rx: call	dat_in	 	; принять байт
; принятый код пока поместить в буфер
	ld	hl,(adr_rx)	;Адрес приема
	ld	(hl),a
	inc	hl		; след.адрес
	ld	(adr_rx),hl
; счетчик приема + 1
	ld	hl,(cnt_rd)
	inc	hl
	ld	(cnt_rd),hl
; проверить, что буфер еще не переполнен
	bit	4,h		;hl < 1000h
	jr	z,get2rx	;Снова проверить прием
; иначе сбросить бит RTS
	call	res_rts		;Не готов к приему
;\-------------------------------
; Если в буфере есть принятые символы, напечатать их
no_get: ld	hl,(cnt_rd)	;Счетчик буфера
	ld	a,h
	or	l
	jp	z,z_cikl	;буфер пустой
; напечатать один символ из буфера
	dec	hl
	ld	(cnt_rd),hl	;счетчик - 1
	ld	hl,(adr_rd)	;
	ld	a,(hl)		;текущий байт из буфера
	inc	hl
	ld	(adr_rd),hl
	and	7Fh		;только ASCII
	jr	z,c1term	;если не 0
; остальные вывести на экран
	; cp	LF		;перевод строки пропустить
	; call	nz,prn_a	;
	call	prn_a	;
c1term:	jp	c_term		;
;\--- Конец цикла терминала --------------
txt_tt:	db	'** TinyTerm **',CR,LF
	db	'Ctrl+Z - Quit, Esc - CLS',CR,LF
	db	'F5 - Load, F9 - RUN',CR,LF,0
txt_ip_conf:
	db	'Old 16C550 baud config: '
txt_baud:
	db	'     ',0
txt_baud1:
	db	'     ',0
txt_ok:	db	'OK',CR,LF,0
txt_err:db	'ERR',CR,LF,0
txt_rx:	db	CR,LF,'XMODEM ',0
txt_jm:	db	CR,LF,'No file',0
;=========================================
	include "prnum.asm"	
;--------------------------------------------
	include	"isa.asm"
;--------------------------------------------
	include "rs232.asm"
;--------------------------------------------
	include	"rx_file.asm"
;--------------------------------------------
	include	"utils.asm"
;============================================
adr_rx: ds	2
adr_rd: ds	2
cnt_rd: ds	2
;
flg_xm:	ds	1	;флаг загрузки файла
adr_fl:	ds	2	;текущий адрес файла
def_dma:ds	0	;буфер для приема блока
buf_rd: ds	0	;
;------------------------------------------
end_addr:
	
