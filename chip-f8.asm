; CHIP-F8
; -------
; CHIP-8 interpreter for F8
; on the Fairchild Channel F
; made by Tobias V. Langhoff

	processor f8

;===================;
; Assembly Switches ;
;===================;

switch_music	=	0					; turns music on and off

;=========;
; Equates ;
;=========;

;------------;
; BIOS Calls ;
;------------;
clrscrn         =       $00d0                                   ; uses r31
delay           =       $008f
pushk           =       $0107                                   ; used to allow more subroutine stack space
popk            =       $011e
drawchar        =       $0679

;-------------------;
; Color Definitions ;
;-------------------;
red		=	$40
blue	=	$80
green	=	$00
bkg		=	$C0
clear	=	$FF

;-----------------;
; RAM Definitions ;
;-----------------;
ram			=	$2800					; use Schach RAM to hold CHIP-8 program
screenbuffer = $2f00
chip8offset =	$2600

;--------------------;
; Register Reference ;
;--------------------;

; The registers in the f8 are used as both RAM and registers for
; this game. The reference is as follows:
;

; v0-v15 direct access
; delay timer
; sound timer


; r0: scratch
; r1-r2: current opcode
; r3: current palette
; r4-r9: scratch
; r10-r11 (H): PC
; r16-r31: CHIP-8 variables V0–VF
; r40-r41 (o50): I
; r60-63

;===================;
; Main Program Code ;
;===================;

	MAC os
	; adds missing instruction: OS r
	; modifies r0
	com
	lr 0, a
	lr a, {1}
	com
	ns 0
	com
	ENDM

;===================;
; Stack Handling    ;
;===================;

; Push a value onto the stack
pushStack:
	lisu 4
	lisl 7
	lr a, s               ; Load stack pointer
	ci $FF                ; Check for stack overflow
	bz .stackOverflow
	inc                   ; Increment stack pointer
	lr s, a
	lr is, a              ; Update ISAR
	st                    ; Store value at stack pointer
	pop
.stackOverflow:
	; Handle stack overflow (e.g., halt or reset)
	; Modify as needed for your platform
	jmp fetchDecodeLoop

; Pop a value from the stack
popStack:
	lisu 4
	lisl 7
	lr a, s               ; Load stack pointer
	ci $00                ; Check for stack underflow
	bz .stackUnderflow
	lm                    ; Load value from stack pointer
	dec                   ; Decrement stack pointer
	lr s, a
	lr is, a              ; Update ISAR
	pop
.stackUnderflow:
	; Handle stack underflow (e.g., halt or reset)
	; Modify as needed for your platform
	jmp fetchDecodeLoop

;===================;
; Stack Optimization ;
;===================;

; Initialize stack pointer to the bottom of the stack
initStack:
	lisu 4
	lisl 7
	li $01                ; Start stack pointer at 1 (no wasted space)
	lr s, a
	lr is, a              ; Update ISAR
	pop

;---------------;
; Program Entry ;
;---------------;

	org	$800

cartridgeStart:
	.byte	$55, $2B	; cartridge header

cartridgeEntry:
	lis	0				; init the h/w
	outs	1
	outs	4
	outs	5
	outs	0
	pi initStack          ; Initialize stack pointer
                
	lisu	4			; r32 = complement flag
	lisl	0
	lr	S, A
                
	li	$00				; set to one color, black background
	lr	3, A			; clear screen to black
	pi	clrscrn

copyGameToRAM subroutine
	dci gameROM
	xdc
	dci ram
.copyByte:
	xdc
	lm					; copy byte from gameROM to A and advance DC0
	xdc					; swap DC
	st					; copy byte from A to gameRAM and advance DC0
	lr q, dc
	lr a, qu			; check counter
	xi $2f
	bnz .copyByte

initInterpreter:
	dci ram			; point at start of ROM
	lr h, dc			; store PC in H (r10/r11)
	
	lisu 4				; set stack pointer
	lisl 7
	li 40
	lr s, a

fetchDecodeLoop subroutine
	lr dc, h			; load PC
	lm					; fetch [PC] into A and advance
	lr 1, a				; store first opcode byte in 1
	lm					; fetch PC into A and advance
	lr 2, a				; store second opcode byte in 2
	lr h, dc			; update PC

	dci .jumpTable
	lr a, 1
	sr 4
	adc
	adc
	lm
	lr qu, a
	lm
	lr ql, a
	lr p0, q
	
.jumpTable:
	.word firstDigitZero
	.word firstDigitOne
	.word firstDigitTwo
	.word firstDigitThree
	.word firstDigitFour
	.word firstDigitFive
	.word firstDigitSix
	.word firstDigitSeven
	.word firstDigitEight
	.word firstDigitNine
	.word firstDigitA
	.word firstDigitB
	.word firstDigitC
	.word firstDigitD
	.word firstDigitE
	.word firstDigitF

firstDigitZero subroutine
	lr a, 2
	xi $E0
	bz .clearScreen
	lr a, 2
	xi $EE
	bz .returnFromSubroutine
	jmp fetchDecodeLoop
.clearScreen:
	dci screenbuffer
	li 255				; copy 256 bytes
	lr 0, a				; use r0 as counter
.copyByte:
	li 0
	st					; copy byte from A to screen and advance DC0
	ds 0				; decrement counter
	lr a, 0				; check counter
	ns 0				; AND a with itself
	bnz .copyByte
	lr	3, A			; clear screen to palette
	pi	clrscrn			; TODO scratches several registers
	jmp fetchDecodeLoop
.returnFromSubroutine:
	lisu 4
	lisl 7
	lr a, s
	lr is, a
	
	lr a, i
	lr hu, a
	lr a, s
	lr hl, a

	lisu 4
	lisl 7
	ds s				; decrease stack pointer by two
	ds s
	
	jmp fetchDecodeLoop

firstDigitOne:
	lr a, 1				; load first byte of opcode
	ni $0F				; remove first nibble
	ai $26				; add RAM offset
	lr hu, a			; load into PC
	
	lr a, 2				; load second byte of opcode
	lr hl, a			; load into PC
	jmp fetchDecodeLoop

firstDigitTwo:
	lisu 4
	lisl 7
	lr a, s				; load stack pointer
	inc					; increase stack pointer by two
	inc
	lr s, a
	lr is, a			; load new stack pointer into ISAR

	lr a, hu			; push PC onto stack
	lr i, a
	lr a, hl
	lr s, a

	lr a, 1				; load first byte of opcode
	ni $0F				; remove first nibble
	ai $26				; add RAM offset
	lr hu, a			; load into PC
	
	lr a, 2				; load second byte of opcode
	lr hl, a			; load into PC
	jmp fetchDecodeLoop

firstDigitThree subroutine
	pi getX

	lr a, 2

	xs s

	bnz .notEqual

	lr dc, h			; load PC
	lm
	lm
	lr h, dc
.notEqual
	jmp fetchDecodeLoop

firstDigitFour subroutine
	pi getX

	lr a, 2

	xs s

	bz .equal

	lr dc, h			; load PC
	lm
	lm
	lr h, dc
.equal:
	jmp fetchDecodeLoop
	
firstDigitFive subroutine
	; TODO assert that last digit is 0

	pi getX
	lr a, s
	lr 0, a

	pi getY
	lr a, s
	xs 0

	bnz .notEqual

	lr dc, h			; load PC
	lm
	lm
	lr h, dc
.notEqual:
	jmp fetchDecodeLoop

firstDigitSix:
	pi getX

	lr a, 2				; get second byte of opcode
	lr s, a				; set it
	jmp fetchDecodeLoop

firstDigitSeven:
	pi getX

	lr a, s				; get current value of VX
	as 2				; add value of second byte of opcode
	lr s, a				; set new value of VX
	jmp fetchDecodeLoop

firstDigitEight subroutine
	dci .jumpTable
	lr a, 2				; get second byte of opcode
	ni $0f				; remove first nibble
	adc
	adc
	lm
	lr qu, a
	lm
	lr ql, a
	lr p0, q
	
.jumpTable:
	.word .lastDigitZero
	.word .lastDigitOne
	.word .lastDigitTwo
	.word .lastDigitThree
	.word .lastDigitFour
	.word .lastDigitFive
	.word .lastDigitSix
	.word .lastDigitSeven
	.word .lastDigitEight
	.word .lastDigitNine
	.word .lastDigitA
	.word .lastDigitB
	.word .lastDigitC
	.word .lastDigitD
	.word .lastDigitE
	.word .lastDigitF

.lastDigitZero:
	pi getY

	lr a, s
	lr 0, a

	pi getX

	lr a, 0
	lr s, a

	jmp fetchDecodeLoop

.lastDigitOne:
	pi getY

	lr a, s
	lr 3, a

	pi getX

	lr a, s

	os 3
	lr s, a

	jmp fetchDecodeLoop

.lastDigitTwo:
	pi getY

	lr a, s
	lr 0, a

	pi getX

	lr a, s

	ns 0
	lr s, a

	jmp fetchDecodeLoop
.lastDigitThree:
	pi getY

	lr a, s
	lr 0, a

	pi getX

	lr a, s

	xs 0
	lr s, a

	jmp fetchDecodeLoop
.lastDigitFour:
	pi getY

	lr a, s
	lr 0, a

	pi getX

	lr a, s

	as 0
	lr s, a

	; Set VF
	lisu 3
	lisl 7

	lr j, w
	lr a, j
	ni 2
	sr 1
	lr s, a

	jmp fetchDecodeLoop
.lastDigitFive:
	pi getY
	lr a, s
	com
	inc
	lr 0, a

	pi getX
	lr a, s

	as 0

	lr s, a

	; Set VF
	lisu 3
	lisl 7

	lr j, w
	lr a, j
	ni 2
	sr 1
	lr s, a

	jmp fetchDecodeLoop
.lastDigitSix:
	; TODO quirk
	pi getY

	lr a, s
	lr 0, a

	pi getX

	lr a, 0
	sr 1
	lr s, a

	; Set VF
	lisu 3
	lisl 7

	lr a, 0
	ni 1
	lr s, a

	jmp fetchDecodeLoop
.lastDigitSeven:
	pi getX
	lr a, s
	com
	inc
	lr 0, a

	pi getY
	lr a, s
	as 0
	lr 0, a

	; Set VF
	lisu 3
	lisl 7

	lr j, w
	lr a, j
	ni 2
	sr 1
	lr s, a

	pi getX
	lr a, 0
	lr s, a

	jmp fetchDecodeLoop
.lastDigitEight:
	jmp fetchDecodeLoop
.lastDigitNine:
	jmp fetchDecodeLoop
.lastDigitA:
	jmp fetchDecodeLoop
.lastDigitB:
	jmp fetchDecodeLoop
.lastDigitC:
	jmp fetchDecodeLoop
.lastDigitD:
	jmp fetchDecodeLoop
.lastDigitE:
	; TODO quirk
	pi getY

	lr a, s
	lr 0, a

	pi getX

	lr a, 0
	sl 1
	lr s, a

	; Set VF
	lisu 3
	lisl 7

	lr a, 0
	ni 8
	sr 4
	sr 1
	sr 1
	sr 1
	lr s, a

	jmp fetchDecodeLoop
.lastDigitF:
	jmp fetchDecodeLoop
	
firstDigitNine subroutine
	; TODO assert that last digit is 0

	pi getX
	lr a, s
	lr 0, a

	pi getY
	lr a, s
	xs 0

	bz .equal

	lr dc, h			; load PC
	lm
	lm
	lr h, dc
.equal:
	jmp fetchDecodeLoop

firstDigitA:
	lisu 4
	lisl 1

	lr a, 1				; load first byte of opcode
	ni $0F				; remove first nibble
	ai $26				; add RAM offset
	lr i, a				; load into I

	lr a, 2				; load second byte of opcode
	lr s, a				; load into I

	jmp fetchDecodeLoop
	
firstDigitB:
	lr a, 1				; load first byte of opcode
	ni $0F				; remove first nibble
	ai $26				; add RAM offset
	lr qu, a			; load into PC
	
	lr a, 2				; load second byte of opcode
	lr ql, a			; load into PC

	lr dc, q

	lisu 2
	lisu 0

	lr a, s

	adc					; TODO this is used as a two's complement number!!

	lr h, dc			; load into PC

	jmp fetchDecodeLoop
	
firstDigitC:
	pi getX
	li $FF                ; Load maximum random value
	pi random             ; Call random number generator
	lr a, s               ; Get random number
	lr 0, a               ; Store in scratch
	lr a, 2               ; Load NN
	ns 0                  ; AND random number with NN
	lr s, a               ; Store result in VX
	jmp fetchDecodeLoop

firstDigitD:
	pi getX

	lr a, s				; get X value
	lr 5, a				; store X in scratch 5

	ni $07				; bit offset of first bit of sprite data
	lr 7, a				; store bit offset in scratch 7
	lr a, 5				; get X again
	ni $3F				; modulo 64
	sr 1				; position in pixel row of first byte that will contain sprite data
	sr 1
	sr 1
	lr 8, a				; store position in scratch 8

	pi getY

	lr a, s				; get Y value
	ni $1F				; modulo 32
	sl 1				; position in display memory of the first row that will contain sprite data
	sl 1
	sl 1
	lr 6, a				; store Y in scratch 6

	as 8				; r6 + r8

	lr ql, a
	li $2f				; screenbuffer
	lr qu, a
	lr dc, q

	lr a, 2				; get second byte of opcode
	ni $0f				; remove first nibble
	lr 9, a				; save in scratch 9 as display row counter

	; clear VF before drawing
	lisu 3
	lisl 7
	clr
	lr s, a

	xdc

	; load I into DC
	lisu 4
	lisl 1
	lr a, i
	lr qu, a
	lr a, s
	lr ql, a

	lr dc, Q			; load I into DC

; just to recap...
; r0 scratch
; r1 first opcode
; r2 second opcode
; r3 left byte of assembled sprite
; r4 right byte of assembled sprite
; r5 X
; r6 Y position in display memory of the first row that will contain sprite data
; r7 bit offset
; r8 position in pixel row of first byte that will contain sprite data
; r9 row counter
; DC0 I
; DC1 screen buffer with offset

.nextSpriteRow:
	clr

	lisu 4
	lisl 3
	lr i, a
	lr d, a

	lr a, 9				; get row counter
	ns 9				; AND a with itself
	bz .displaySprite		; we're done, reset I and display the sprite
.dontResetI:
	ds 9				; decrease row counter
	lm					; get one byte of sprite data from I and advance I

	lr s, a				; put byte in scratch 32 ; at 0095 now...
	lr a, 7				; get bit offset for first bit of sprite data
	lr 3, a				; put byte in scratch 33 to use as bit counter

.splitSpriteRow:
	lr a, 3				; get current bit count
	ns 3				; AND a with itself
	bz .storeSpriteRow	; sprite data is now split across two rows
	lr a, s				; load byte into a
	ni 1
	bz .rightShiftWithNoCarry
	
.rightShiftWithCarry:
	lr a, s				; load byte into a
	sr 1				; shift it right once
	lr i, a				; load the shifted byte back
	lr a, s				; load new byte into a
	sr 1
	oi $80
	lr d, a				; load shifted byte into a
	ds 3
	jmp .splitSpriteRow

.rightShiftWithNoCarry:
	lr a, s				; load byte into a
	sr 1				; shift it right once
	lr i, a				; load the shifted byte back
	lr a, s				; load new byte into a
	sr 1
	lr d, a				; load shifted byte into a
	ds 3
	jmp .splitSpriteRow

.storeSpriteRow:
	xdc					; switch to screen buffer pointer

	lr q, dc			; store DC in Q so we can revert here

	lisu 4				; take the assembled bytes
	lisl 3

	lr a, s				; first assembled byte
	nm					; and with screen data to detect collision
	bz .noCollision1
	li 1
	lr 0, a
.noCollision1:
	lr dc, q			; restore dc

	lr a, i				; first assembled byte
	xm					; xor with screen data (this increments dc)
	lr dc, q			; restore dc
	st					; store xor-ed result

	; check for screen boundary, we don't wrap sprites
	lr a, ql
	lr 3, a
	lr q, dc			; store DC in Q so we can revert here
	lr a, ql
	xs 3				; xor old and new ql
	ni $08				; see if we crossed from $2F?7 to $2F?8; if so, we've wrapped around X
	li 7				; go to next row in screen data
	bnz .outOfBounds

	lr a, s
	nm					; and with screen data
	bz .noCollision2
	li 1
	lr 0, a
.noCollision2:
	lr dc, q			; restore dc

	lr a, d				; second assembled byte
	xm					; xor with screen data (this increments dc)
	lr dc, q			; restore dc
	st					; store xor-ed result
	li 6				; go to next row in screen data

.outOfBounds:
	adc
	xdc					; swap back to I pointer for next sprite row

	; load collision flag into VF
	lisu 3
	lisl 7
	lr a, 0
	lr s, a

	jmp .nextSpriteRow

.displaySprite:

.blitSprite:
	; Right now we blit the entire screen buffer
	; but we probably want to only blit the area
	; the sprite was drawn to. To do that we need
	; to change a lot of register use.

	dci screenparams
	pi blitGraphic
	jmp fetchDecodeLoop
	
firstDigitE:
	lr a, 2
	xi $9e
	bnz .ex9e
	lr a, 2
	xi $a1
	bnz .exa1
	jmp fetchDecodeLoop
.ex9e:
	pi getX
	lr a, s               ; Load VX
	pi isKeyPressed       ; Check if key is pressed
	bz .skip              ; Skip if not pressed
	lr dc, h              ; Load PC
	lm
	lm                    ; Skip next instruction
	lr h, dc
.skip:
	jmp fetchDecodeLoop
.exa1:
	pi getX
	lr a, s               ; Load VX
	pi isKeyPressed       ; Check if key is pressed
	bnz .skip             ; Skip if pressed
	lr dc, h              ; Load PC
	lm
	lm                    ; Skip next instruction
	lr h, dc
.skip:
	jmp fetchDecodeLoop
	
firstDigitF:
	; TODO convert below to jump table (or branch/offset table if space permits)

	lr a, 2				; get second byte of opcode
	xi $07
	bnz .not07
	jmp .lastNibble07
.not07:
	lr a, 2
	xi $0A
	bnz .not0A
	jmp .lastNibble0A
.not0A:
	lr a, 2
	xi $15
	bnz .not15
	jmp .lastNibble15
.not15:
	lr a, 2
	xi $18
	bnz .not18
	jmp .lastNibble18
.not18:
	lr a, 2
	xi $1E
	bnz .not1E
	jmp .lastNibble1E
.not1E:
	lr a, 2
	xi $29
	bnz .not29
	jmp .lastNibble29
.not29:
	lr a, 2
	xi $33
	bnz .not33
	jmp .lastNibble33
.not33:
	lr a, 2
	xi $55
	bnz .not55
	jmp .lastNibble55
.not55:
	lr a, 2
	xi $65
	bnz .not65
	jmp .lastNibble65
.not65:	
	jmp fetchDecodeLoop

.lastNibble07:
	pi getX
	pi getDelayTimer      ; Get delay timer value
	lr s, a               ; Store in VX
	jmp fetchDecodeLoop

.lastNibble0A:
	pi getX
.waitKey:
	pi getKey             ; Wait for key press
	bz .waitKey           ; Loop until a key is pressed
	lr s, a               ; Store key in VX
	jmp fetchDecodeLoop
	
.lastNibble15:
	pi getX
	lr a, s               ; Load VX
	pi setDelayTimer      ; Set delay timer
	jmp fetchDecodeLoop

.lastNibble18:
	pi getX
	lr a, s               ; Load VX
	pi setSoundTimer      ; Set sound timer
	jmp fetchDecodeLoop

.lastNibble1E:
	lisu 4
	lisl 1

	lr a, i
	lr qu, a
	lr a, s
	lr ql, a

	lr dc, q

	pi getX

	; Now we want to add the value in the register selected by the ISAR to the address in DC.
	; But ADC treats the value in A as a two's complement number, so we need to do this in a roundabout way:
	lr a, s				; load VX offset into A
	ns s				; AND the offset with itself to check the upper bit
	bp .adcHack			; if bit 7 is not set, we just proceed as normal
	sr 1				; if bit 7 is set, shift right
	adc					; add this offset to DC
	adc					; twice
	lr a, s				; load the original offset again
	ni 1				; get bit 0 so we can finally add that
.adcHack:
	adc					; add offset

	lisu 4				; set ISAR to I
	lisl 1

	lr q, dc			; load DC back into Q
	lr a, qu
	lr i, a
	lr a, ql
	lr s, a

	jmp fetchDecodeLoop

.lastNibble29:
	pi getX

	lr a, s				; get number in VX
	sl 1				; multiply by 4
	sl 1
	as s				; add the number, so we multiply by 5

	dci font			; set DC to the fontset's address
	adc					; add the offset for the current character

	lr q, dc			; load it into Q

	lisu 4				; set ISAR to I
	lisl 1

	lr a, qu			; load Q into I via A
	lr i, a
	lr a, ql
	lr s, a

	jmp fetchDecodeLoop

.lastNibble33:
	pi getX

	; BCD routine courtesy of https://my.eng.utah.edu/~nmcdonal/Tutorials/BCDTutorial/BCDConversion.html

	li 0
	lr 0, a				; bit counter
	lr 1, a				; hundreds (treat as nibble)
	lr 2, a				; tens (treat as nibble)
	lr 3, a				; ones (treat as nibble)

	lr a, s
	lr 4, a				; r4: the binary number to convert to BCD

	li 8
	lr 0, a

.loop:
	lr a, 1				; if hundreds > 4 then add 3
	ci 4
	bp .testTens
	ai 3
	lr 1, a
.testTens:				; if tens > 4 then add 3
	lr a, 2
	ci 4
	bp .testOnes
	ai 3
	lr 2, a
.testOnes:				; if ones > 4 then add 3
	lr a, 3
	ci 4
	bp .shift
	ai 3
	lr 3, a

.shift:
	lr a, 1				; shift hundreds nibble left
	sl 1
	ni $0f
	lr 1, a

	lr a, 2
	ni $08				; if tens most significant bit is 1, carry it over to hundreds
	bz .shiftTens
	lr a, 1
	inc
	lr 1, a
.shiftTens:				; shift tens nibble left
	lr a, 2
	sl 1
	ni $0f
	lr 2, a

	lr a, 3
	ni $08				; if ones most significant bit is 1, carry it over to tens
	bz .shiftOnes
	lr a, 2
	inc
	lr 2, a
.shiftOnes:				; shift ones nibble left
	lr a, 3
	sl 1
	ni $0f
	lr 3, a

	lr a, 4
	ni $80				; if binary number's most significant bit is 1, carry it over to ones
	bz .shiftByte
	lr a, 3
	inc
	lr 3, a
.shiftByte:				; shift binary number left
	lr a, 4
	sl 1
	lr 4, a

	ds 0				; decrement bit counter
	bnz .loop			; if we haven't processed the entire binary number, continue

	lisu 4
	lisl 1

	lr a, i
	lr qu, a
	lr a, s
	lr ql, a

	lr dc, q			; get I

	lr a, 1
	st					; store hundreds
	lr a, 2
	st					; store tens
	lr a, 3
	st					; store ones

	jmp fetchDecodeLoop

.lastNibble55:
	lisu 4
	lisl 1

	lr a, i
	lr qu, a
	lr a, s
	lr ql, a

	lr dc, q

	lr a, 1
	ni $0F
	lr 0, a

	lisu 2
	lisl 0

.storeLoop:
	lr a, i
	st
	ds 0
	bp .storeLoop		; if positive number, loop

	; TODO quirk, store DC back in I via Q

	jmp fetchDecodeLoop

.lastNibble65:
	lisu 4
	lisl 1

	lr a, i
	lr qu, a
	lr a, s
	lr ql, a

	lr dc, q

	lr a, 1
	ni $0F
	lr 0, a

	lisu 2
	lisl 0

.loadLoop:
	lm
	lr i, a
	ds 0
	bp .loadLoop		; if positive number, loop

	; TODO quirk, store DC back in I via Q
	jmp fetchDecodeLoop

getX:
	; returns ISAR pointing at VX
	lr a, 1
	ni $0f
	oi $10
	lr is, a
	pop

getY:
	; returns ISAR pointing at VY
	lr a, 2
	ni $f0
	sr 4
	oi $10
	lr is, a
	pop

;===================;
; Helper Subroutines ;
;===================;

; Random number generator (returns random number in A)
random:
	; Implement a simple random number generator
	; Modify as needed for your platform
	li $3C                ; Example seed
	xi $A7
	ns 0
	pop

; Check if a key is pressed (returns 1 if pressed, 0 otherwise in A)
isKeyPressed:
	; Implement key press check
	; Modify as needed for your platform
	clr
	pop

; Wait for a key press (returns key value in A)
getKey:
	; Implement key press wait
	; Modify as needed for your platform
	clr
	pop

; Get the delay timer value (returns value in A)
getDelayTimer:
	; Implement delay timer retrieval
	; Modify as needed for your platform
	clr
	pop

; Set the delay timer
setDelayTimer:
	; Implement delay timer setting
	; Modify as needed for your platform
	pop

; Set the sound timer
setSoundTimer:
	; Implement sound timer setting
	; Modify as needed for your platform
	pop

;===================;
; Optimized Blit    ;
;===================;

; Optimized blit routine for drawing sprites
; This routine avoids reinitializing the hardware for each row
; and focuses only on the affected area of the screen.

optimizedBlit:
	; r1 = color 1 (off)
	; r2 = color 2 (on)
	; r3 = x position
	; r4 = y position
	; r5 = width
	; r6 = height (and vertical counter)
	; r7 = horizontal counter
	; r8 = graphics byte
	; r9 = bit counter
	; DC = pointer to graphics

	; Set up initial screen position
	lr a, 4               ; Load Y position
	sl 1                  ; Multiply by 4
	sl 1
	sl 1
	as 3                  ; Add X position
	lr ql, a              ; Store in QL
	li $2f                ; Screen buffer base
	lr qu, a
	lr dc, q              ; Set DC to screen buffer position

	; Load sprite height into vertical counter
	lr a, 6
	lr 9, a

.nextRow:
	; Check if all rows are drawn
	ns 9
	bz .done

	; Load next graphics byte
	lm
	lr 8, a               ; Store graphics byte in r8

	; Draw the row
	lr a, 5               ; Load width into horizontal counter
	lr 7, a
.nextColumn:
	; Check if all columns are drawn
	ns 7
	bz .nextRowSetup

	; Shift graphics byte and determine color
	lr a, 8
	as 8
	lr 8, a
	lr a, 2               ; Default to color 1 (off)
	bc .drawPixel
	lr a, 1               ; Use color 2 (on)
.drawPixel:
	st                    ; Store pixel in screen buffer
	inc                   ; Move to next column
	jmp .nextColumn

.nextRowSetup:
	; Move to the next row in the screen buffer
	li 64                 ; Screen width
	as 3
	lr a, ql
	as 3
	lr ql, a
	jmp .nextRow

.done:
	pop                   ; Return from subroutine

font:
	; 0
	.byte	%11110000
	.byte	%10010000
	.byte	%10010000
	.byte	%10010000
	.byte	%11110000

	; 1
	.byte	%00100000
	.byte	%00100000
	.byte	%00100000
	.byte	%00100000
	.byte	%00100000

	; 2
	.byte	%11110000
	.byte	%00010000
	.byte	%11110000
	.byte	%10000000
	.byte	%11110000

	; 3
	.byte	%11110000
	.byte	%00010000
	.byte	%11110000
	.byte	%00010000
	.byte	%11110000

	; 4
	.byte	%10010000
	.byte	%10010000
	.byte	%11110000
	.byte	%00010000
	.byte	%00010000

	; 5
	.byte	%11110000
	.byte	%10000000
	.byte	%11110000
	.byte	%00010000
	.byte	%11110000

	; 6
	.byte	%11110000
	.byte	%10000000
	.byte	%11110000
	.byte	%10010000
	.byte	%11110000

	; 7
	.byte	%11110000
	.byte	%00010000
	.byte	%00100000
	.byte	%00100000
	.byte	%00100000

	; 8
	.byte	%11110000
	.byte	%10010000
	.byte	%11110000
	.byte	%10010000
	.byte	%11110000

	; 9
	.byte	%11110000
	.byte	%10010000
	.byte	%11110000
	.byte	%00010000
	.byte	%11110000

	; A
	.byte	%11110000
	.byte	%10010000
	.byte	%11110000
	.byte	%10010000
	.byte	%10010000

	; B
	.byte	%11100000
	.byte	%10010000
	.byte	%11100000
	.byte	%10010000
	.byte	%11100000

	; C
	.byte	%11110000
	.byte	%10000000
	.byte	%10000000
	.byte	%10000000
	.byte	%11110000

	; D
	.byte	%11100000
	.byte	%10010000
	.byte	%10010000
	.byte	%10010000
	.byte	%11100000

	; E
	.byte	%11110000
	.byte	%10000000
	.byte	%11110000
	.byte	%10000000
	.byte	%11110000

	; F
	.byte	%11110000
	.byte	%10000000
	.byte	%11110000
	.byte	%10000000
	.byte	%10000000


screenparams:
	.byte bkg
	.byte blue
	.byte 4
	.byte 4
	.byte 64
	.byte 32
	.word screenbuffer

;===========;
; Blit Code ;
;===========;

;--------------;
; Blit Graphic ;
;--------------;

; takes graphic parameters from ROM, stores them in r1-r6, 
; changes the DC and calls the blit function with the parameters
;
; modifies: r1-r6, Q, DC

blitGraphic:
	; load six bytes from the parameters into r0-r5
	lisu	0
	lisl	1
.blitGraphicGetParms:
	lm   
	lr	I, A						; store byte and increase ISAR
	br7	.blitGraphicGetParms				; not finished with the registers, loop

	; load the graphics address
	lm
	lr	Qu, A						; into Q
	lm
	lr	Ql, A
	lr	DC, Q						; load it into the DC

	; call the blit function
	jmp	blit

;---------------;
; Blit Function ;
;---------------;

; this function blits a graphic based on parameters set in r1-r6,
; and the graphic data pointed to by DC0, onto the screen
; originally from cart 26, modified and annotated
;
; modifies: r1-r9, DC

; register reference:
; -------------------
; r1 = color 1 (off)
; r2 = color 2 (on)
; r3 = x position
; r4 = y position
; r5 = width
; r6 = height (and vertical counter)
;
; r7 = horizontal counter
; r8 = graphics byte
; r9 = bit counter
;
; DC = pointer to graphics

blit:
	; fix the x coordinate
	lis	4
	as	3
	lr	3, A
	; fix the y coordinate
	lis	4
	as	4
	lr	4, A

	lis	1
	lr	9, A						; load #1 into r9 so it'll be reset when we start
	lr	A, 4						; load the y offset
	com							; invert it
.blitRow:
	outs	5						; load accumulator into port 5 (row)

	; check vertical counter
	ds	6						; decrease r6 (vertical counter)
	bnc	.blitExit					; if it rolls over exit

	; load the width into the horizontal counter
	lr	A, 5
	lr	7, A

	lr	A, 3						; load the x position
	com							; complement it
.blitColumn:
	outs	4						; use the accumulator as our initial column
	; check to see if this byte is finished
	ds	9						; decrease r9 (bit counter)
	bnz	.blitDrawBit					; if we aren't done with this byte, branch

.blitGetByte:
	; get the next graphics byte and set related registers
	lis	8
	lr	9, A						; load #8 into r9 (bit counter)
	lm
	lr	8, A						; load a graphics byte into r8

.blitDrawBit:
	; shift graphics byte
	lr	A, 8						; load r8 (graphics byte)
	as	8						; shift left one (with carry)
	lr	8, A						; save it

	; check color to use
	lr	A, 2						; load color 1
	bc	.blitSavePixel					; if this bit is on, draw the color
	lr	A, 1						; load color 2
.blitSavePixel:
	inc
	bc	.blitCheckColumn				; branch if the color is "clear"
	outs	1						; output A in p1 (color)

.blitTransferData:
	; transfer the pixel data
	li	$60
	outs	0
	li	$c0
	outs	0
	; and delay a little bit
.blitSavePixelDelay:
	ai	$60						; add 96
	bnz	.blitSavePixelDelay				; loop if not 0 (small delay)

.blitCheckColumn:
	ds	7						; decrease r7 (horizontal counter)
	bz	.blitCheckRow					; if it's 0, branch

	ins	4						; get p4 (column)
	ai	$ff						; add 1 (complemented)
	br	.blitColumn					; branch

.blitCheckRow:
	ins	5						; get p5 (row)
	ai	$ff						; add 1 (complemented)
	br	.blitRow					; branch

.blitExit:
	; return from the subroutine
	pop


; The CHIP-8 program will be copied from ROM to Schach RAM, of which
; we have $700 or 1792 available bytes (the final $FF or 256 bytes are
; reserved for the screen buffer). We assert both the size of the
; Channel F ROM and the CHIP-8 ROM like so:

gameROM:
	incbin "test_opcode.ch8"

cartridgeEnd:
	org gameROM + $6ff,0
	.byte $00