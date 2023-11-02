    *=$8000
    
    chrin=$ffcf
    getin=$ffe4
    plot=$fff0
    
    INPUT_BUFFER = $1000
    CUSTOM_STACK = $3000
    CUSTOM_SP = $f7
    
    ; 0 - Show
    ; 1 - Flagged
    ; 2 - Mine
    ; Size = 38 * 18
    ; Real size = 40 * 20 (800, $320)
    BOARD_STATES = $2000
    SCREEN = $0400
    
    jmp init
    
init
    ; Setup IRQ (Currently isn't needed)
    ;sei
    ;lda #<irq
    ;ldx #>irq
    ;sta $314
    ;stx $315
    ;cli
    
    ; Set border color to black
    lda #0
    sta $d020
    sta $d021
    
    ; Start of program
start
.block
    ; Set character color to green and clear the screen
    lda #30
    jsr $ffd2
    lda #147
    jsr $ffd2
    
    ; Set some variables
    lda #1
    sta cursorPos
    sta cursorPos+1
    lda #0
    sta bomb_count
    sta correct_flags
    
    ; Setup the custom stack pointer
    lda #<CUSTOM_STACK
    sta CUSTOM_SP
    lda #>CUSTOM_STACK
    sta CUSTOM_SP+1
    
    ; Print the welcome message
    ldx #<text_welcome
    ldy #>text_welcome
    jsr print
    lda #13
    jsr $ffd2
    
    ldx #<text_selectBombs
    ldy #>text_selectBombs
    jsr print
    
    ; User selection for the amount of mines
    ldy #0
read
    jsr chrin
    sta INPUT_BUFFER,y
    iny
    cmp #13
    bne read
    dey
    lda #0
    sta INPUT_BUFFER,y
.bend
    
; Clear the board
clearBoard
.block
    lda #0
    ldy #0
loop1
    ldx #0
loop2
    jsr set_state
    inx
    cpx #40
    bne loop2
    iny
    cpy #20
    bne loop1
.bend
    
    ; Clear the screen again
    lda #147
    jsr $ffd2

; Exctract the number of mines from the user input (in binary coded decimal)
extractNum
.block
    lda INPUT_BUFFER
    beq start
    sec
    sbc #48
    sta $ff
    lda INPUT_BUFFER+1
    beq skip
    asl $ff
    asl $ff
    asl $ff
    asl $ff
    sec
    sbc #48
    ora $ff
    sta $ff
skip
    lda $ff
    bne *+5
    jmp start
    
    ; Some input debug
    ;pha
    ;lsr
    ;lsr
    ;lsr
    ;lsr
    ;jsr hex2ascii
    ;jsr $ffd2
    ;pla
    ;and #$0f
    ;jsr hex2ascii
    ;jsr $ffd2
.bend

; Randomly place the mines
placeBombs
.block
    ; Setup sid
    lda #$6f
    ldy #$81
    ldx #$ff
    sta $d413
    sty $d412
    stx $d40e
    stx $d40f
    stx $d414
    ; Generate X value
genrnd1
    lda $d41b
    and #$3f
    beq genrnd1
    cmp #39
    bcs genrnd1
    tax
    ; Generate Y value
genrnd2
    lda $d41b
    and #$1f
    beq genrnd2
    cmp #19
    bcs genrnd2
    tay
    
    ; Place it in memory
    jsr get_state
    and #%100
    bne genrnd1
    lda #%100
    jsr set_state
    inc bomb_count
    
    ; Decrement mine counter (binary coded decimal)
    sed
    lda $ff
    sec
    sbc #1
    sta $ff
    cld
    bne genrnd1
.bend

; Draw the border around the game window
drawBorder
.block
    ; Draw corners
    lda #91
    ldx #0
    ldy #0
    jsr set_screen
    lda #91
    ldx #39
    ldy #0
    jsr set_screen
    lda #91
    ldx #0
    ldy #19
    jsr set_screen
    lda #91
    ldx #39
    ldy #19
    jsr set_screen
    
    ; Draw horizontal lines
    lda #64
    ldx #1
loop1
    ldy #0
    jsr set_screen
    ldy #19
    jsr set_screen
    inx
    cpx #39
    bne loop1
    
    ; Draw vertical lines
    lda #66
    ldy #1
loop2
    ldx #0
    jsr set_screen
    ldx #39
    jsr set_screen
    iny
    cpy #19
    bne loop2
.bend

; Display the game board
; Also the start of the main game loop
showboard
.block
    ldy #1
loop1
    ldx #1
loop2
    ; Get the state and check if it should be displayed specialy
    jsr get_state
    and #%11
    bne skip1
    lda #$a0 ; If not then make it a blank character
    jmp continue
skip1
    ; Check if it's displaying a flag or the count of mines around the square
    and #%10
    beq dispnum
    lda #90
    jmp continue
dispnum
    ; Count mines and make it an ascii number / blank if no mines surround the square
    jsr get_state
    and #%100
    beq skipbomb
    lda #81 ; Display a circle instead of a number if needed
    jmp continue
skipbomb
    jsr countBombs
    cmp #0
    bne skip2
    lda #$20    ; Blank character if 0 mines around the square
    jmp continue
skip2
    clc
    adc #48
continue
    ; Write to the screen and increment x/y values
    jsr set_screen
    inx
    cpx #39
    bne loop2
    iny
    cpy #19
    bne loop1
.bend

; Load the cursor and print it, also take in input from the user
userInput
.block
    ldx cursorPos   ; Load cursor
    ldy cursorPos+1
    jsr get_screen  ; Get and save character under cursor
    sta screenTmp
    lda #65 ; Set cursor to spade
    jsr set_screen
    ; Wait for input
inputwait
    jsr getin
    cmp #0
    beq inputwait
    pha ; Save the input
    
    ; Reload cursor position because routine change the x/y values
    ldx cursorPos
    ldy cursorPos+1
    
    lda screenTmp   ; Restore screen charater
    jsr set_screen
    pla ; Reload user input
    
    cmp #157    ; Left
    beq moveleft
    cmp #29     ; Right
    beq moveright
    cmp #145    ; Up
    beq moveup
    cmp #17     ; Down
    beq movedown
    
    cmp #13     ; Enter
    beq select
    cmp #70     ; F
    beq flag
    
    cmp #81
    beq restart
    
    jmp userInput
    
moveleft
    cpx #1
    beq userInput
    dec cursorPos
    jmp userInput
moveright
    cpx #38
    beq userInput
    inc cursorPos
    jmp userInput
moveup
    cpy #1
    beq userInput
    dec cursorPos+1
    jmp userInput
movedown
    cpy #18
    beq userInput
    inc cursorPos+1
    jmp userInput
restart
    jmp start
flag
    ; Toggle the flag state and change correct flag counter if the square is a mine
    jsr get_state
    pha
    eor #%010
    jsr set_state
    pla
    pha
    and #%100
    beq flag_skip
    pla
    and #%010
    beq set
    dec correct_flags
    jmp flag_skip
set
    inc correct_flags
    lda bomb_count
    cmp correct_flags
    beq flag_win
flag_skip
    jmp showboard
flag_win
    jmp win
select
    ; Check if selected square is a mine
    jsr get_state
    and #%100
    bne select_lost
    
    ; If not then reveal the square
    jsr subreveal
    jmp showboard
select_lost
    jmp lost
.bend

; Custom jsr ro reveal
subreveal
    sta $02
    stx $03
    sty $04
    
    pla
    jsr push
    pla
    jsr push
    
    lda $02
    ldx $03
    ldy $04
    jmp reveal
; Custom return from reveal
retreveal
    sta $02
    stx $03
    sty $04
    
    jsr pull
    pha
    jsr pull
    pha
    
    lda $02
    ldx $03
    ldy $04
    rts
; Push for custom stack
push
.block
    ldy #0
    sta (CUSTOM_SP),y
    
    lda CUSTOM_SP
    clc
    adc #1
    sta CUSTOM_SP
    lda CUSTOM_SP+1
    adc #0
    sta CUSTOM_SP+1
    
    rts
.bend
; Pull for cutstom stack
pull
.block
    lda CUSTOM_SP
    sec
    sbc #1
    sta CUSTOM_SP
    lda CUSTOM_SP+1
    sbc #0
    sta CUSTOM_SP+1
    
    ldy #0
    lda (CUSTOM_SP),y
    
    rts
.bend

; Recursively reveal empty squares
reveal
.block
    ; Check state
    jsr get_state
    sta $ff
    and #%001
    bne end ; If already revealed then return
    lda $ff
    ora #%001
    jsr set_state   ; Set state to show
    lda #102    ; Set the screen for clearing effect
    jsr set_screen
    jsr countBombs
    cmp #0
    bne end ; If there is a mine around the square then stop
    
    ; Otherwise call reveal of surrounding squares
    
    dex
    dey
    jsr validposition
    bcc *+5
    jsr subreveal
    
    inx
    jsr validposition
    bcc *+5
    jsr subreveal
    
    inx
    jsr validposition
    bcc *+5
    jsr subreveal
    
    iny
    jsr validposition
    bcc *+5
    jsr subreveal
    
    iny
    jsr validposition
    bcc *+5
    jsr subreveal
    
    dex
    jsr validposition
    bcc *+5
    jsr subreveal
    
    dex
    jsr validposition
    bcc *+5
    jsr subreveal
    
    dey
    jsr validposition
    bcc *+5
    jsr subreveal
    inx
end
    jmp retreveal
validposition
    ; Checks if position is valid and change carry flag accordingly
    cpx #0
    beq notvalid
    cpx #39
    beq notvalid
    cpy #0
    beq notvalid
    cpy #19
    beq notvalid
    sec
    rts
notvalid
    clc
    rts
.bend

; Runs if player has lost
lost
.block
    ldy #0
    ldx #22
    clc
    jsr plot
    
    ldx #<msg1
    ldy #>msg1
    jsr print
    
    lda #0
    ldx correct_flags
    jsr $bdcd
    
    ldx #<msg2
    ldy #>msg2
    jsr print
    
    ; Show all the mines
    ldy #0
loop1
    ldx #0
loop2
    jsr get_state
    and #%100
    beq nobomb
    lda #81
    jsr set_screen
nobomb
    inx
    cpx #40
    bne loop2
    iny
    cpy #20
    bne loop1
    
    ; Wait for input
wait
    jsr getin
    cmp #0
    beq wait
    jmp start
    
msg1 .text "you lost!"
    .byte 13, 0
msg2 .text " correct flags."
    .byte 13
    .null "press any key to continue."
.bend

; Run if player has won
win
.block
    ldy #0
    ldx #22
    clc
    jsr plot
    
    ldx #<msg1
    ldy #>msg1
    jsr print
    ; Wait for input
wait
    jsr getin
    cmp #0
    beq wait
    jmp start
msg1 .text "you win!"
    .byte 13
    .null "press any key to continue."
.bend

halt
    jmp halt

    
cursorPos
    .byte 0,0
screenTmp
    .byte 0

; SUBROUTINES

; Get the state at current position
get_state
.block
    jsr saveregs
    stx $fb
    
    ; Get multiplication table lookup and add the x value and load it
    tya
    asl
    tay
    lda positionLookup,y
    clc
    adc $fb
    sta $fb
    lda positionLookup+1,y
    adc #>BOARD_STATES
    sta $fc
    ldy #0
    lda ($fb),y
    
    jmp loadregs+2
.bend

; Same except sets the state instead
set_state
.block
    jsr saveregs
    stx $fb
    
    tya
    asl
    tay
    lda positionLookup,y
    clc
    adc $fb
    sta $fb
    lda positionLookup+1,y
    adc #>BOARD_STATES
    sta $fc
    ldy #0
    lda $02
    sta ($fb),y
    
    jmp loadregs
.bend

; Same except gets the character on the screen
get_screen
.block
    jsr saveregs
    stx $fb
    
    tya
    asl
    tay
    lda positionLookup,y
    clc
    adc $fb
    sta $fb
    lda positionLookup+1,y
    adc #>SCREEN
    sta $fc
    ldy #0
    lda ($fb),y
    
    jmp loadregs+2
.bend

; Same except set the character on the screen
set_screen
.block
    jsr saveregs
    stx $fb
    
    tya
    asl
    tay
    lda positionLookup,y
    clc
    adc $fb
    sta $fb
    lda positionLookup+1,y
    adc #>SCREEN
    sta $fc
    ldy #0
    lda $02
    sta ($fb),y
    
    jmp loadregs
.bend

; Save registers
saveregs
    sta $02
    stx $03
    sty $04
    rts
; Load registers
loadregs
    lda $02
    ldx $03
    ldy $04
    rts
; Debug Hex2Ascii
hex2ascii
    sed
    cmp #10
    adc #48
    cld
    rts
; Count mines around a square
countBombs
    lda #0
    sta $ff
    
    dex
    dey
    jsr get_state
    lsr
    lsr
    clc
    adc $ff
    sta $ff
    
    inx
    jsr get_state
    lsr
    lsr
    clc
    adc $ff
    sta $ff
    
    inx
    jsr get_state
    lsr
    lsr
    clc
    adc $ff
    sta $ff
    
    dex
    dex
    iny
    jsr get_state
    lsr
    lsr
    clc
    adc $ff
    sta $ff
    
    inx
    inx
    jsr get_state
    lsr
    lsr
    clc
    adc $ff
    sta $ff
    
    dex
    dex
    iny
    jsr get_state
    lsr
    lsr
    clc
    adc $ff
    sta $ff
    
    inx
    jsr get_state
    lsr
    lsr
    clc
    adc $ff
    sta $ff
    
    inx
    jsr get_state
    lsr
    lsr
    clc
    adc $ff
    
    dey
    dex
    rts
; Print string
print
.block
    stx $fb
    sty $fc
    ldy #0
loop
    lda ($fb),y
    beq stop
    jsr $ffd2
    iny
    jmp loop
stop
    rts
.bend
    
text_welcome
    .text "= minesweeper by hunter turner - 2023 ="
    .byte 13, 0
text_selectBombs
    .text "amount of mines (00-99): "
    .byte 0
text_hr
    .null "----------------------------------------"
    
positionLookup
    .word $0000
    .word $0028
    .word $0050
    .word $0078
    .word $00A0
    .word $00C8
    .word $00F0
    .word $0118
    .word $0140
    .word $0168
    .word $0190
    .word $01B8
    .word $01E0
    .word $0208
    .word $0230
    .word $0258
    .word $0280
    .word $02A8
    .word $02D0
    .word $02F8
    .word $0220
    .word $0258
    .word $0270
    .word $02A8
    .word $02C0
    
bomb_count
    .byte 0
correct_flags
    .byte 0

; IRQ routine
irq
    ; Some debug code for the custom stack
    ;lda CUSTOM_SP+1
    ;sta $400
    ;lda CUSTOM_SP
    ;sta $401
    jmp $ea31