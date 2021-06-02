	device	zxspectrum128
	include "include\dss_equ.asm"
	include "include\head.asm"
	include "include\sp_equ.asm"
	
;========================================+
; Мини Терминал для работы в ZX_MCard	 !
; Загружается в Спектруме с адреса 6100h !
; В памяти ZXMC хранится с адреса 1200h  !
;====== 02.05.2006 ======================+
; Камиль Каримов (caro) k2k@list.ru	 !
;========================================+
; Коды клавиш, нажатых с Caps Shift
CS_1	equ	07h	;RUS/LAT
CS_2	equ	06h	;Caps Lock
CS_3	equ	04h	;Pg Up   - запуск программы
CS_4	equ	05h     ;Pg Down - загрузить файл
CS_5	equ	08h
CS_6	equ	0Ah
CS_7	equ	0Bh
CS_8	equ	09h
CS_9	equ	0Fh	;
CS_0	equ	0Ch	;<- DEL
; Коды клавиш, нажатых с Symb Shift
SS_Q	equ	0C7h	;Quit - выход в Basic
SS_W	equ	0C9h	;
SS_E	equ	0C8h	;Erase - Очистить экран
SS_A	equ	0E2h	;
SS_S	equ	0C3h	;
; Коды управления экраном
BS	equ	08h	;Возврат на шаг
TAB	equ	09h	;Табуляция
CR	equ	0Dh	;Возврат каретки
LF	equ	0Ah	;Перевод строки
ESC	equ	1Bh	;Escape
; Коды управления RS232
soh	equ	01h	; ASCII <soh> char
eot	equ	04h	; ASCII <eot> char
ack	equ	06h	; ASCII <ack> char
nak	equ	15h	; ASCII <nak> char
;---------------------------------------
; Порты ZXMC для работы с блочными устройствами
dt_dev	equ	0D8EFh	;Порт данных блочных устройств
st_dev	equ	0D9EFh	;Порт Статуса блочных устройств
run_adr	equ	0C000h	;Адрес загрузки и запуска кодового блока
;---------------------------------------
.z80
	; .phase	6100h		;Адрес загрузки и запуска
; Дозагрузка кода терминалки
; loader:	ld	hl,start	;Адрес загрузки
; c_load:	ld	bc,st_dev	;bc = Порт статуса
; 	in	a,(c)		;Если STAT=0
; 	jr	z,start         ; то конец загрузки
; 	dec	b		;bc = Порт данных
; 	ini			;(HL)=порт(C);INC HL
; 	jr	c_load		;Следующий байт
;==========================================
; Старт терминалки
begin:
start:	call	clear_screen	;CLS SCREEN
	ld	hl,txt_tt	;Заголовок
	call	prn_tx		;напечатать
	xor	a		; 0
	ld	(flg_xm),a	;-> флаг загрузки
	call	reset_isa
	call	set_ip_conf	;Конфигурируем 16550
	ld	l,a
	ld	bc,txt_baud
	call	PRNUM
	ld	hl,txt_ip_conf
	call	prn_tx
	jr	term_
;*****************************************
; Выход из терминалки
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
; SS+E - Очистка экрана и курсор в начало
clr_scr:
	call	clear_screen	;CLS SCREEN
term_:	
;//-------------------------------------------------
	ld	hl,0
	ld	(cnt_rd),hl	;Счетчик буфера = 0
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
	jr	z,clr_scr	;-> очистка экрана
	ld	a,d
	ld	hl,c_term	;адрес возврата
	push	hl		; из процедуры
	ld	hl,run_adr	; адрес загрузки и запуска
;
	cp	#3f		;F5
	jr	z,run_fl	;-> запустить файл
	; cp	CS_3		;CS+3 Page Up   ?
	; jr	z,run_fl	; -> запустить файл
	
	cp	CS_4		;CS+4 Page Down ?
	ret	nz		; в начало цикла
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
send_cr:ld	a,LF		;перевод строки
	call	tx_byte
	ld	a,CR		;возврат каретки
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
	db	'Ctrl+Z - Quit, SS+E - CLS',CR,LF
	db	'CS+4 - Load, CS+3 - RUN',CR,LF,0
txt_ip_conf:
	db	'Old 16C550 baud config: '
txt_baud:
	db	'     ',CR,LF,0
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
	end
end_addr:
	savebin "tinyterm.exe",start_addr,end_addr-start_addr
	
