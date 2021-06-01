;If you want to interaction with ISA devices, you have to make following steps:
;1) send 10h value to port 1FFDh(system port);
;2) send control byte to port 0E2h(third memory window port);
;control byte:
;D7...should be 1
;D6...should be 1
;D5...should be 0
;D4...should be 1
;D3...should be 0
;D2...specify number of ISA slot
;D1...specify access mode (0 - ISA memory, 1 - ISA ports)
;D0...should be 0

;The read/write signals are forming from read/write signals memory range 0C000h-0FFFFh.
;And the address lines A13...A0 has taken from processor data-BUS.
;The other ISA-signals such as RESET, AEN, A19...A14 can be set in port 9FBDh. And default value is 00h.
;port 9FBDh:
;D7...RESET
;D6...AEN
;D5...A19
;D4...A18
;D3...A17
;D2...A16
;D1...A15
;D0...A14

isa_adr_base    equ 0xc000

isa_init:
        call reset_isa
        call open_isa_ports
        ret

; reset ISA device
reset_isa:
        ld bc,Port.ISA
        ld a,0xc0
        out (c),a
        push bc
        ld hl,20
        call __delay
        pop bc
        ld a,0
        out (c),a
        ret

open_isa_ports:
        push af
        push bc
        in a,(EmmWin.P3)
        ld (save_mmu3),a
        ld bc,Port.System
        ld a,0x11
        out (c),a
        ld a,0xd4
        out (EmmWin.P3),a
        ld bc,Port.ISA
        ld a,0
        out (c),a
        pop bc
        pop af
        ret


close_isa_ports:
        push af
        push bc
        ld bc,Port.System
        ld a,1
        out (c),a
        ld a,(save_mmu3)
        out (EmmWin.P3),a
        pop bc
        pop af
        ret
save_mmu3       db 0