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
		
		lda #$00										; clear RAM
		tax
@clrmem:
		sta $00,x
		cpx #4											; preserve BIOS stack variables at $0100~$0103
		bcc :+
		sta $100,x
:
		sta $200,x
		sta $300,x
		sta $400,x
		sta $500,x
		sta $600,x
		sta $700,x
		inx
		bne @clrmem
		jsr InitNametables
		
		lda #$fd										; set VRAM buffer size to max value ($0302~$03ff)
		sta VRAM_BUFFER_SIZE
		
		lda #%10000000									; enable NMIs & change background pattern map access
		sta PPU_CTRL
		sta PPU_CTRL_MIRROR
		
Main:
		jsr ProcessBGMode
		inc NMIReady
:
		lda NMIReady									; the usual NMI wait loop
		bne :-
		beq Main										; back to main loop

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
		
		lda NeedDraw									; transfer Data to PPU if required
		beq :+
		
		jsr WriteVRAMBuffer								; transfer data from VRAM buffer at $0302
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
		jsr ReadOrDownPads								; read controllers + expansion port

NotReady:
		jsr SetScroll									; remember to set scroll on lag frames
		
		pla												; restore X/Y/A
		tay
		pla
		tax
		pla
		
		dec NMIRunning									; clear flag for NMI in progress before exiting
		rti
		
; IRQ handler (unused for now)
InterruptRequest:
		rti

UpdatePPUMask:
		sta PPU_MASK_MIRROR
		lda #$01
		sta NeedPPUMask
		rts

InitNametables:
		lda #$20										; top-left
		jsr InitNametable
		lda #$24										; top-right

InitNametable:
		ldx #$00										; clear nametable & attributes for high address held in A
		ldy #$00
		jmp VRAMFill

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

EnableRendering:
		lda #%00001010									; enable background and queue it for next NMI
	.byte $2c											; [skip 2 bytes]
		
DisableRendering:
		lda #%00000000									; disable background and queue it for next NMI
		jmp UpdatePPUMask

WaitForNMI:
		inc NMIReady
:
		lda NMIReady
		bne :-
		rts

; Jump table for main logic
ProcessBGMode:
		lda BGMode
		jsr JumpEngine
	.addr BGInit
	.addr DumperPrep
	.addr DumpBIOS
	.addr DumpSuccess
	.addr DoNothing

; Initialise background to display the program name and FDS BIOS revision
BGInit:
		jsr CheckBIOS
		jsr DisableRendering
		jsr WaitForNMI
		jsr VRAMStructWrite
	.addr BGData
		inc BGMode
		jmp EnableRendering								; remember to enable rendering for the next NMI

; Show a prompt to insert a disk if nothing is in the drive
DumperPrep:
		rts

; Dump the BIOS to a disk file & show error messages if necessary
DumpBIOS:
		rts

; Display a success message
DumpSuccess:
		lda #$21
		ldx #$8A
		ldy #SuccessMsgLength
		jsr PrepareVRAMString
	.addr SuccessMsg
		sta StringStatus								; save status to check later
		inc BGMode										; next mode
		lda #$01										; queue VRAM transfer for next NMI
		sta NeedDraw
		rts

SuccessMsg:
	.byte "BIOS dumped!"
SuccessMsgLength=*-SuccessMsg

; Once the dump is done, stay in this state forever
DoNothing:
		rts

BGData:													; VRAM transfer structure
Palettes:
	.byte $3f, $00										; destination address (BIG endian)
	.byte %00000000 | PaletteSize						; d7=increment mode (+1), d6=transfer mode (copy), length

; Just write to all of the entries so PPUADDR safely leaves the palette RAM region
; (palette entries will never be changed anyway, so we might as well set them all)
PaletteData:
	.byte $0f, $00, $10, $20
	.byte $0f, $00, $10, $20
	.byte $0f, $00, $10, $20
	.byte $0f, $00, $10, $20
	.byte $0f, $00, $10, $20
	.byte $0f, $00, $10, $20
	.byte $0f, $00, $10, $20
	.byte $0f, $00, $10, $20 ; PPUADDR ends at $3F20 before the next write (avoids rare palette corruption)
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

