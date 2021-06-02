;-----------------------------------------------
;  если нажат <CTRL+Z>
;	C=1, A=0FFh
tst_brk:
        ld	c,Dss.ScanKey
	rst	#10
        jr      z,.no_keys      ;Не нажата ни одна кнопка
        BIT	5,B             ;При нажатом Ctrl
        jr      z,.no_keys
        ld      a,d
        and     #7f
        cp      #2a             ;Ctrl+Z
        jr      nz,.no_keys
        xor	a
	dec	a		;Z=0, CY=0
        scf
        ret
.no_keys:
        and     a
        ret

;Процессор работает на частоте 21мгц (21000000Гц). Однако из-за задержек
;в работе с памятью итоговая частота будет в районе 12.3мгц (252896 тактов в инте).
__CPU_CLOCK		equ 13816406
;__CPU_CLOCK		equ 21000000

;hl = delay in ms
__delay:	ld e,l
		ld d,h
.ms_loop:	dec de
		ld a,d
		or e
		jr z,.last_ms

		ld hl,(__CPU_CLOCK / 1000) - 43
		call .delay_tstate

; we will be exact
.last_ms:	ld hl,+(__CPU_CLOCK / 1000) - 54

.delay_tstate:	ld bc,-141
		add hl,bc
		ld bc,-23
.loop:		add hl,bc
		jr c,.loop
		ld a,l
		add a,15
		jr nc,.g0
		cp 8
		jr c,.g1
		or 0
.g0:		inc hl
.g1:		rra
		jr c,.b0

		nop

.b0:		rra
		jr nc,.b1
		or 0
.b1:		rra
		ret nc
		ret

;=========================================
scan_key:
	ld	c,Dss.ScanKey
	rst	10h
	ret
;=========================================
prn_a:	push	hl
	ld	c,Dss.PutChar
	; cp	TAB		; TAB
	; jr	nz,no_tab
	; ld	a,' '		;заменить на пробел
no_tab:	RST	10h
	pop	hl
	RET
;=========================================
prn_tx:	ld	c,Dss.PChars
	rst	10h
	ret
;-----------------------------------------