; main program code
;
; Formatting:
; - Width: 132 Columns
; - Tab Size: 4, using tab
; - Comments: Column 57

; reset handler
Reset:
		lda FDS_CTRL_MIRROR								; get setting previously used by FDS BIOS
		and #$f7										; and set for vertical mirroring
		sta FDS_CTRL
		
		jsr InitMemory
		jsr InitNametables
		
		lda #$fd										; set VRAM buffer size to max value ($0302~$03ff)
		sta VRAM_BUFFER_SIZE
		
		lda #%00011110									; enable sprites/background and queue it for next NMI
		jsr UpdatePPUMask
		
		lda #%10000000									; enable NMIs & change background pattern map access
		sta PPU_CTRL
		sta PPU_CTRL_MIRROR
		
Main:
		jsr SetBGMode
		lda DisplayToggle
		beq :+
		
		jsr TimerLogic
		jsr RNGLogic
		
:
		inc NMIReady
		
:
		lda NMIReady									; the usual NMI wait loop
		bne :-

		inc FrameCount									; increment frame timer after NMI
		bne :+
		
		inc FrameCount+1
		
:
		jmp Main										; back to main loop

; "NMI" routine which is entered to bypass the BIOS check
Bypass:
		lda #$00										; disable NMIs since we don't need them anymore
		sta PPU_CTRL
		
		lda #<NonMaskableInterrupt						; put real NMI handler in NMI vector 3
		sta NMI_3
		lda #>NonMaskableInterrupt
		sta NMI_3+1
		
		lda #$35										; tell the FDS that the BIOS "did its job"
		sta RST_FLAG
		lda #$ac
		sta RST_TYPE
		
		jmp ($fffc)										; jump to reset FDS
		
; NMI handler
NonMaskableInterrupt:
		pha												; back up A
		lda NMIRunning									; exit if NMI is already in progress
		beq :+
		
		pla
		rti

:
		inc NMIRunning									; set flag for NMI in progress
		
		txa												; back up X/Y
		pha
		tya
		pha
		
		lda NMIReady									; check if ready to do NMI logic (i.e. not a lag frame)
		beq NotReady
		
		jsr SpriteDMA
		
		lda NeedDraw									; transfer Data to PPU if required
		beq :+
		
		jsr VRAMStructWrite
Struct:
	.word BGData										; this can be overwritten
		
		jsr SetScroll									; reset scroll after PPUADDR writes
		dec NeedDraw
		
:
		lda NeedPPUMask									; write PPUMASK if required
		beq :+
		
		lda PPU_MASK_MIRROR
		sta PPU_MASK
		dec NeedPPUMask

:
		dec NMIReady
		jsr ReadOrDownVerifyPads						; read controllers + expansion port (DMC safe, somehow...)

NotReady:
		jsr SetScroll									; remember to set scroll on lag frames
		
		pla												; restore X/Y/A
		tay
		pla
		tax
		pla
		
		dec NMIRunning									; clear flag for NMI in progres before exiting
		rti
		
; IRQ handler (unused for now)
InterruptRequest:
		rti

UpdatePPUMask:
		sta PPU_MASK_MIRROR
		lda #$01
		sta NeedPPUMask
		rts

MoveSpritesOffscreen:
		lda #$ff										; fill OAM buffer with $ff to move offscreen
		ldx #$02
		ldy #$02
		jmp MemFill

InitMemory:
		lda #$00
		tax
		
:
		sta $00,x										; clear $00~$f0
		inx
		cpx #$f1
		bne :-
		
		ldx #$02										; clear RAM from $0200 (prevent OAM decay on reset)
		ldy #$07										; up to and including $0700
		jmp MemFill

InitNametables:
		lda #$20										; top-left
		jsr InitNametable
		lda #$24										; top-right

InitNametable:
		ldx #$00										; clear nametable & attributes for high address held in A
		ldy #$00
		jmp VRAMFill

TimerLogic:												; convert frame timer to hex chars
		lda FrameCount+1
		jsr NumToChars
		stx Frames
		sty Frames+1
		lda FrameCount
		jsr NumToChars
		stx Frames+2
		sty Frames+3
		rts

; AX+ TinyRand8
; https://codebase64.org/doku.php?id=base:ax_tinyrand8
Rand8:
	RAND_=*+1
		lda #35
		asl
	RAND=*+1
		eor #53
		sta RAND_
		adc RAND
		sta RAND
		rts

SetSeed:
		lda FrameCount
		and #217
		clc
		adc #<21263
		sta RAND
		lda FrameCount
		and #255-217
		adc #>21263
		sta RAND_
		rts

RNGLogic:
		ldx RAND
		lda P1_PRESSED									; seed RNG with frame count if Start pressed
		and #BUTTON_START
		beq :+

		jsr SetSeed
		
:
		lda P1_PRESSED									; get RNG number if B pressed
		and #BUTTON_B
		beq :+
		
		jsr Rand8
		tax
		
:
		txa
		jsr NumToChars
		stx RNG
		sty RNG+1
		rts


NumToChars:												; converts A into hex chars and puts them in X/Y
		pha
		and #$0f
		tay
		lda NybbleToChar,y
		tay
		pla
		lsr
		lsr
		lsr
		lsr
		tax
		lda NybbleToChar,x
		tax
		rts

NybbleToChar:
	.byte "0123456789ABCDEF"

CheckBIOS:
		clc
		lda $fff9
		adc $fffc
		ldx #$00
		cmp #$17										; rev0: $00 + $17
		beq SaveRev
		
		inx
		cmp #$25										; rev1/twin: $01 + $24
		beq CheckTwin
		
		inx
		bne UnknownRev

CheckTwin:
		lda $f6b6										; load a byte from the logo screen data
		cmp #$28										; check for presence of trademark symbol (rev1)
		beq SaveRev
		
		inx
		cmp #$24										; check for presence of space (twin)
		beq SaveRev

UnknownRev:
		inx
		
SaveRev:
		lda BIOSRevs0,x
		sta RevNum
		lda BIOSRevs1,x
		sta RevNum+1
		lda BIOSRevs2,x
		sta RevNum+2
		rts

; these LUTs construct the BIOS revision string found on 2C33 markings
; "01 ", "01A", "02 " are official, "?? " is unknown/unofficial
BIOSRevs0:
	.byte "000?"
BIOSRevs1:
	.byte "112?"
BIOSRevs2:
	.byte " A  "

SetBGMode:
		ldx BGMode										; BG mode 0 = palette + initial text, draw immediately
		bne :+
		
		jsr CheckBIOS
		ldx #$00
		jsr DrawBG
		inc BGMode
		rts
		
:
		lda P1_PRESSED									; otherwise toggle BG modes 1/2 via Select press
		and #BUTTON_SELECT
		beq DrawBG										; skip toggle if not pressed
		
		lda DisplayToggle								; toggle BG mode and transfer to X
		eor #$01
		sta DisplayToggle
		tax
		inx

DrawBG:
		lda StructAddrsLo,x								; index into LUT and set Struct address in NMI handler
		sta Struct
		lda StructAddrsHi,x
		sta Struct+1
		
		lda #$01										; queue the VRAM transfer
		sta NeedDraw
		stx BGMode
		rts

StructAddrsLo:
	.lobytes BGData, BlankData, NumData
	
StructAddrsHi:
	.hibytes BGData, BlankData, NumData

BGData:													; VRAM transfer structure
Palettes:
	.byte $3f, $00										; destination address (BIG endian)
	.byte %00000000 | PaletteSize						; d7=increment mode (+1), d6=transfer mode (copy), length
	
PaletteData:
	.byte $0f, $00, $10, $20
PaletteSize=*-PaletteData

TextData:
	.byte $20, $89										; destination address (BIG endian)
	.byte %00000000 | Text1Length						; d7=increment mode (+1), d6=transfer mode (copy), length
	
Chars1:
	.byte "FDS-BIOS-Dumper"
Text1Length=*-Chars1

	.byte $20, $aa										; destination address (BIG endian)
	.byte %00000000 | Text2Length						; d7=increment mode (+1), d6=transfer mode (copy), length
	
Chars2:
	.byte "BIOS Rev. "
RevNum:
	.byte "?? "
Text2Length=*-Chars2
	.byte $ff											; terminator

BlankData:
	.byte $20, $e9										; destination address (BIG endian)
	.byte %01000000 | FramesLength						; d7=increment mode (+1), d6=transfer mode (fill), length
	.byte " "
	.byte $21, $09										; destination address (BIG endian)
	.byte %01000000 | RNGLength							; d7=increment mode (+1), d6=transfer mode (fill), length
	.byte " "
	.byte $ff											; terminator

NumData:
	.byte $20, $e9										; destination address (BIG endian)
	.byte %00000000 | FramesLength						; d7=increment mode (+1), d6=transfer mode (copy), length
FramesChars:
	.byte "Frames = "
Frames:
	.byte "0000"
FramesLength=*-FramesChars

	.byte $21, $09										; destination address (BIG endian)
	.byte %00000000 | RNGLength							; d7=increment mode (+1), d6=transfer mode (copy), length
RNGChars:
	.byte "Random =  "
RNG:
	.byte "00"
RNGLength=*-RNGChars
	.byte $ff											; terminator

