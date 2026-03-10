; MK-61 variant for dsPIC30F6014A (ASM30/XC16 profile)
; -----------------------------------------------------
; Practical integer RPN core (X/Y/Z/T) with UART command parser.
; Command bytes (ASCII):
;   '0'..'9' - digits
;   'E'      - ENTER
;   '+'      - plus
;   '-'      - minus
;   '*'      - multiply (16-bit signed, low word)
;   '/'      - divide (signed, if divisor != 0)
;   'C'      - clear X/edit
;   'N'      - negate
;   'P'      - PI -> 3
;
; This is a practical dsPIC ASM profile, not a bit-exact MK-61 microcode port.
; Integrate real UART/LCD drivers in stubs: _uart_init, _uart_getc_nonblock, _render.

        .include "p30f6014a.inc"

        .section .text,code
        .global _main

_main:
        ; Simple init. Toolchain/runtime may set W15 before _main,
        ; so this code keeps stack setup minimal and only initializes state.
        clr     w0
        mov     w0, reg_x
        mov     w0, reg_y
        mov     w0, reg_z
        mov     w0, reg_t
        mov     w0, edit_val
        mov     w0, edit_mode
        mov     w0, edit_sign

        call    _uart_init

main_loop:
        call    _render
        call    _uart_getc_nonblock      ; W0=0 if no byte, else ASCII token
        cp0     w0
        bra     z, main_loop
        call    _dispatch_key
        bra     main_loop

_dispatch_key:
        cp      w0, #'0'
        bra     nz, _chk1
        clr     w0
        bra     _digit
_chk1:
        cp      w0, #'1'
        bra     nz, _chk2
        mov     #1, w0
        bra     _digit
_chk2:
        cp      w0, #'2'
        bra     nz, _chk3
        mov     #2, w0
        bra     _digit
_chk3:
        cp      w0, #'3'
        bra     nz, _chk4
        mov     #3, w0
        bra     _digit
_chk4:
        cp      w0, #'4'
        bra     nz, _chk5
        mov     #4, w0
        bra     _digit
_chk5:
        cp      w0, #'5'
        bra     nz, _chk6
        mov     #5, w0
        bra     _digit
_chk6:
        cp      w0, #'6'
        bra     nz, _chk7
        mov     #6, w0
        bra     _digit
_chk7:
        cp      w0, #'7'
        bra     nz, _chk8
        mov     #7, w0
        bra     _digit
_chk8:
        cp      w0, #'8'
        bra     nz, _chk9
        mov     #8, w0
        bra     _digit
_chk9:
        cp      w0, #'9'
        bra     nz, _chk_enter
        mov     #9, w0
_digit:
        call    _press_digit
        return

_chk_enter:
        cp      w0, #'E'
        bra     nz, _chk_plus
        call    _press_enter
        return

_chk_plus:
        cp      w0, #'+'
        bra     nz, _chk_minus
        call    _press_plus
        return

_chk_minus:
        cp      w0, #'-'
        bra     nz, _chk_mul
        call    _press_minus
        return

_chk_mul:
        cp      w0, #'*'
        bra     nz, _chk_div
        call    _press_mul
        return

_chk_div:
        cp      w0, #'/'
        bra     nz, _chk_clear
        call    _press_div
        return

_chk_clear:
        cp      w0, #'C'
        bra     nz, _chk_neg
        call    _press_clear
        return

_chk_neg:
        cp      w0, #'N'
        bra     nz, _chk_pi
        call    _press_neg
        return

_chk_pi:
        cp      w0, #'P'
        bra     nz, _dispatch_done
        call    _press_pi
_dispatch_done:
        return

_press_digit:
        ; IN: W0=digit (0..9)
        mov     edit_mode, w1
        cp0     w1
        bra     nz, _digit_append

        mov     #1, w1
        mov     w1, edit_mode
        clr     w1
        mov     w1, edit_sign
        mov     w0, edit_val
        return

_digit_append:
        mov     edit_val, w1
        call    _mul10_w1
        add     w1, w0, w1
        mov     w1, edit_val
        return

_press_enter:
        call    _commit_edit
        mov     reg_z, w0
        mov     w0, reg_t
        mov     reg_y, w0
        mov     w0, reg_z
        mov     reg_x, w0
        mov     w0, reg_y
        return

_press_plus:
        call    _commit_edit
        mov     reg_y, w1
        mov     reg_x, w2
        add     w1, w2, w0
        mov     w0, reg_x
        mov     reg_z, w0
        mov     w0, reg_y
        mov     reg_t, w0
        mov     w0, reg_z
        return

_press_minus:
        call    _commit_edit
        mov     reg_y, w1
        mov     reg_x, w2
        sub     w1, w2, w0         ; Y - X
        mov     w0, reg_x
        mov     reg_z, w0
        mov     w0, reg_y
        mov     reg_t, w0
        mov     w0, reg_z
        return

_press_mul:
        call    _commit_edit
        mov     reg_y, w4
        mov     reg_x, w5
        mul.ss  w4, w5, w0         ; low 16-bit product in W0 (practical stub)
        mov     w0, reg_x
        mov     reg_z, w0
        mov     w0, reg_y
        mov     reg_t, w0
        mov     w0, reg_z
        return

_press_div:
        call    _commit_edit
        mov     reg_x, w1
        cp0     w1
        bra     z, _press_div_done
        mov     reg_y, w0
        repeat  #17
        div.s   w0, w1
        mov     w0, reg_x
        mov     reg_z, w0
        mov     w0, reg_y
        mov     reg_t, w0
        mov     w0, reg_z
_press_div_done:
        return

_press_clear:
        clr     w0
        mov     w0, edit_mode
        mov     w0, edit_sign
        mov     w0, edit_val
        mov     w0, reg_x
        return

_press_neg:
        mov     edit_mode, w0
        cp0     w0
        bra     z, _neg_x
        mov     edit_sign, w0
        xor     w0, #1, w0
        mov     w0, edit_sign
        return

_neg_x:
        mov     reg_x, w0
        neg     w0, w0
        mov     w0, reg_x
        return

_press_pi:
        clr     w0
        mov     w0, edit_mode
        mov     w0, edit_sign
        mov     #3, w0
        mov     w0, reg_x
        return

_commit_edit:
        mov     edit_mode, w0
        cp0     w0
        bra     z, _commit_done

        mov     edit_val, w0
        mov     edit_sign, w1
        cp0     w1
        bra     z, _commit_store
        neg     w0, w0
_commit_store:
        mov     w0, reg_x
        clr     w0
        mov     w0, edit_mode
        mov     w0, edit_sign
        mov     w0, edit_val
_commit_done:
        return

_mul10_w1:
        ; W1 = W1*10
        sl      w1, #1, w2
        sl      w1, #3, w3
        add     w2, w3, w1
        return

; --------------------------------------------------------------------------
; Platform glue stubs (replace with board-specific drivers)
; --------------------------------------------------------------------------

_uart_init:
        return

_uart_getc_nonblock:
        clr     w0
        return

_render:
        ; Typical integration:
        ; 1) convert reg_x to display format
        ; 2) send to LCD/UART
        return

        .section .bss,bss
reg_x:          .space 2
reg_y:          .space 2
reg_z:          .space 2
reg_t:          .space 2
edit_val:       .space 2
edit_mode:      .space 2
edit_sign:      .space 2
