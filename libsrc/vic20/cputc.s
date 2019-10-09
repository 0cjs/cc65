;
; Ullrich von Bassewitz, 06.08.1998
;
; void cputcxy (unsigned char x, unsigned char y, char c);
; void cputc (char c);
;

        .export         _cputcxy, _cputc, cputdirect, putchar
        .export         newline, plot
        .import         gotoxy
        .import         PLOT

        .include        "vic20.inc"


; VIC-20 KERNAL routines (such as PLOT) do not always leave the color RAM
; pointer CRAM_PTR pointing at the color RAM location matching the screen
; RAM pointer SCREEN_PTR. Instead they update it when they need it to be
; correct by calling UPDCRAMPTR.
;
; We make things more efficient by having conio always update CRAM_PTR when
; we move the screen pointer to avoid extra calls to ensure it's updated
; before doing screen output. (Among other things, We replace the ROM
; version of PLOT with our own in libsrc/vic20/kplot.s to ensure this
; precondition.)
;
; However, this means that CRAM_PTR may be (and is, after a cold boot)
; incorrect for us at program startup, causing cputc() not to work. We fix
; this with a constructor that ensures CRAM_PTR matches SCREEN_PTR.
;
        .constructor    UPDCRAMPTR

_cputcxy:
        pha                     ; Save C
        jsr     gotoxy          ; Set cursor, drop x and y
        pla                     ; Restore C

; Plot a character - also used as internal function

_cputc: cmp     #$0A            ; CR?
        bne     L1
        lda     #0
        sta     CURS_X
        beq     plot            ; Recalculate pointers

L1:     cmp     #$0D            ; LF?
        beq     newline         ; Recalculate pointers

; Printable char of some sort

        cmp     #' '
        bcc     cputdirect      ; Other control char
        tay
        bmi     L10
        cmp     #$60
        bcc     L2
        and     #$DF
        bne     cputdirect      ; Branch always
L2:     and     #$3F

cputdirect:
        jsr     putchar         ; Write the character to the screen

; Advance cursor position

advance:
        iny
        cpy     #XSIZE
        bne     L3
        jsr     newline         ; new line
        ldy     #0              ; + cr
L3:     sty     CURS_X
        rts

newline:
        clc
        lda     #XSIZE
        adc     SCREEN_PTR
        sta     SCREEN_PTR
        bcc     L4
        inc     SCREEN_PTR+1
        clc
L4:     lda     #XSIZE
        adc     CRAM_PTR
        sta     CRAM_PTR
        bcc     L5
        inc     CRAM_PTR+1
L5:     inc     CURS_Y
        rts

; Handle character if high bit set

L10:    and     #$7F
        cmp     #$7E            ; PI?
        bne     L11
        lda     #$5E            ; Load screen code for PI
        bne     cputdirect
L11:    ora     #$40
        bne     cputdirect



; Set cursor position, calculate RAM pointers

plot:   ldy     CURS_X
        ldx     CURS_Y
        clc
        jmp     PLOT            ; Set the new cursor



; Write one character to the screen without doing anything else, return X
; position in Y

putchar:
        ora     RVS             ; Set revers bit
        ldy     CURS_X
        sta     (SCREEN_PTR),y  ; Set char
        lda     CHARCOLOR
        sta     (CRAM_PTR),y    ; Set color
        rts
