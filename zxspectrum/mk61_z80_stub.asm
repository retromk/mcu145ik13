; MK-61 variant for ZX Spectrum (Z80 Assembler profile)
; -----------------------------------------------------
; Practical RPN core for core keys: 0..9, ENTER, +, CX, NEG, PI
; Keyboard mapping:
;   1..0  -> digits
;   ENTER -> V
;   P     -> +
;   C     -> CX
;   N     -> NEG
;   I     -> PI
; Build example (sjasmplus):
;   sjasmplus --syntax=abfw zxspectrum/mk61_z80_stub.asm

                DEVICE ZXSPECTRUM48
                ORG 32768

KEY_NONE        EQU 0
KEY_DIGIT0      EQU 1
KEY_DIGIT1      EQU 2
KEY_DIGIT2      EQU 3
KEY_DIGIT3      EQU 4
KEY_DIGIT4      EQU 5
KEY_DIGIT5      EQU 6
KEY_DIGIT6      EQU 7
KEY_DIGIT7      EQU 8
KEY_DIGIT8      EQU 9
KEY_DIGIT9      EQU 10
KEY_ENTER       EQU 11
KEY_PLUS        EQU 12
KEY_CLEAR       EQU 13
KEY_NEG         EQU 14
KEY_PI          EQU 15

Start:
                xor a
                ld (edit_mode),a
                ld (edit_sign),a
                ld hl,0
                ld (reg_x),hl
                ld (reg_y),hl
                ld (reg_z),hl
                ld (reg_t),hl

MainLoop:
                call Render
                call ScanKey
                or a
                jr z,MainLoop
                call HandleKey
                call WaitRelease
                jr MainLoop

HandleKey:
                cp KEY_DIGIT0
                jr c,.not_digit
                cp KEY_DIGIT9+1
                jr nc,.not_digit
                sub KEY_DIGIT0
                call PressDigit
                ret

.not_digit:
                cp KEY_ENTER
                jr nz,.not_enter
                call PressEnter
                ret
.not_enter:
                cp KEY_PLUS
                jr nz,.not_plus
                call PressPlus
                ret
.not_plus:
                cp KEY_CLEAR
                jr nz,.not_clear
                call PressClear
                ret
.not_clear:
                cp KEY_NEG
                jr nz,.not_neg
                call PressNeg
                ret
.not_neg:
                cp KEY_PI
                jr nz,.done
                call PressPi
.done:
                ret

PressDigit:
                ; A = digit 0..9
                ld b,a
                ld a,(edit_mode)
                or a
                jr nz,.append
                ld a,1
                ld (edit_mode),a
                xor a
                ld (edit_sign),a
                ld h,0
                ld l,b
                ld (edit_val),hl
                ret
.append:
                ld hl,(edit_val)
                call MulHL10
                ld a,b
                ld e,a
                ld d,0
                add hl,de
                ld (edit_val),hl
                ret

PressEnter:
                call CommitEdit
                ld hl,(reg_z)
                ld (reg_t),hl
                ld hl,(reg_y)
                ld (reg_z),hl
                ld hl,(reg_x)
                ld (reg_y),hl
                ret

PressPlus:
                call CommitEdit
                ld hl,(reg_x)
                ld de,(reg_y)
                add hl,de
                ld (reg_x),hl
                ld hl,(reg_z)
                ld (reg_y),hl
                ld hl,(reg_t)
                ld (reg_z),hl
                ret

PressClear:
                xor a
                ld (edit_mode),a
                ld (edit_sign),a
                ld hl,0
                ld (edit_val),hl
                ld (reg_x),hl
                ret

PressNeg:
                ld a,(edit_mode)
                or a
                jr z,.neg_x
                ld a,(edit_sign)
                xor 1
                ld (edit_sign),a
                ret
.neg_x:
                ld hl,(reg_x)
                call NegHL
                ld (reg_x),hl
                ret

PressPi:
                xor a
                ld (edit_mode),a
                ld (edit_sign),a
                ld hl,3
                ld (reg_x),hl
                ret

CommitEdit:
                ld a,(edit_mode)
                or a
                ret z
                ld hl,(edit_val)
                ld a,(edit_sign)
                or a
                jr z,.store
                call NegHL
.store:
                ld (reg_x),hl
                xor a
                ld (edit_mode),a
                ld (edit_sign),a
                ld hl,0
                ld (edit_val),hl
                ret

MulHL10:
                ; HL = HL*10 (unsigned)
                push de
                ld d,h
                ld e,l
                add hl,hl
                add hl,hl
                add hl,hl
                add hl,de
                add hl,de
                pop de
                ret

NegHL:
                ld a,h
                cpl
                ld h,a
                ld a,l
                cpl
                ld l,a
                inc hl
                ret

WaitRelease:
                call ScanKey
                or a
                jr nz,WaitRelease
                ret

ScanKey:
                ; Row 3: 1 2 3 4 5
                ld bc,$F7FE
                in a,(c)
                bit 0,a
                jr z,.k1
                bit 1,a
                jr z,.k2
                bit 2,a
                jr z,.k3
                bit 3,a
                jr z,.k4
                bit 4,a
                jr z,.k5

                ; Row 4: 0 9 8 7 6
                ld bc,$EFFE
                in a,(c)
                bit 0,a
                jr z,.k0
                bit 1,a
                jr z,.k9
                bit 2,a
                jr z,.k8
                bit 3,a
                jr z,.k7
                bit 4,a
                jr z,.k6

                ; Row 5: P O I U Y
                ld bc,$DFFE
                in a,(c)
                bit 0,a
                jr z,.kplus
                bit 2,a
                jr z,.kpi

                ; Row 6: ENTER L K J H
                ld bc,$BFFE
                in a,(c)
                bit 0,a
                jr z,.kenter

                ; Row 1: A S D F G
                ld bc,$FDFE
                in a,(c)
                bit 3,a
                jr z,.kclear ; C is on row 0 bit 3, but row1 bit3 is F; keep fallback clear on F

                ; Row 0: SHIFT Z X C V
                ld bc,$FEFE
                in a,(c)
                bit 3,a
                jr z,.kclear

                ; Row 7: SPACE SYM M N B
                ld bc,$7FFE
                in a,(c)
                bit 2,a
                jr z,.kneg ; M
                bit 3,a
                jr z,.kneg ; N

                xor a
                ret

.k0:            ld a,KEY_DIGIT0:ret
.k1:            ld a,KEY_DIGIT1:ret
.k2:            ld a,KEY_DIGIT2:ret
.k3:            ld a,KEY_DIGIT3:ret
.k4:            ld a,KEY_DIGIT4:ret
.k5:            ld a,KEY_DIGIT5:ret
.k6:            ld a,KEY_DIGIT6:ret
.k7:            ld a,KEY_DIGIT7:ret
.k8:            ld a,KEY_DIGIT8:ret
.k9:            ld a,KEY_DIGIT9:ret
.kenter:        ld a,KEY_ENTER:ret
.kplus:         ld a,KEY_PLUS:ret
.kclear:        ld a,KEY_CLEAR:ret
.kneg:          ld a,KEY_NEG:ret
.kpi:           ld a,KEY_PI:ret

Render:
                ld a,12              ; CLS control char
                rst $10
                ld hl,msg_title
                call PrintString
                ld hl,msg_x
                call PrintString
                ld hl,(reg_x)
                call PrintHex16
                ld a,13
                rst $10
                ld hl,msg_help
                call PrintString
                ret

PrintString:
                ld a,(hl)
                or a
                ret z
                rst $10
                inc hl
                jr PrintString

PrintHex16:
                push hl
                ld a,h
                call PrintHex8
                ld a,l
                call PrintHex8
                pop hl
                ret

PrintHex8:
                push af
                rrca
                rrca
                rrca
                rrca
                and $0F
                call PrintNibble
                pop af
                and $0F
                call PrintNibble
                ret

PrintNibble:
                add a,'0'
                cp '9'+1
                jr c,.out
                add a,7
.out:
                rst $10
                ret

msg_title:      db "MK-61 ZX Z80 profile",13,0
msg_x:          db "X=0x",0
msg_help:       db "1..0 ENT P(+), C(CX), N(NEG), I(PI)",13,0

reg_x:          dw 0
reg_y:          dw 0
reg_z:          dw 0
reg_t:          dw 0
edit_val:       dw 0
edit_mode:      db 0
edit_sign:      db 0

                SAVEBIN "zxspectrum/mk61_z80_stub.bin",Start,$
