; main program code
;
; Formatting:
; - Width: 132 Columns
; - Tab Size: 4, using tab
; - Comments: Column 57

; reset handler
Reset:
;		lda FDS_CTRL_MIRROR								; get setting previously used by FDS BIOS
;		and #$f7										; and set for vertical mirroring
;		sta FDS_CTRL
		
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
		jsr InitFileHeader
		jsr InitNametables
		
		lda #$fd										; set VRAM buffer size to max value ($0302~$03ff)
		sta VRAM_BUFFER_SIZE

		lda #%10000000									; enable NMIs & change background pattern map access
		sta PPU_CTRL
		sta PPU_CTRL_MIRROR
		
Main:
		jsr ProcessBGMode
		jsr WaitForNMI
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
		bit NMIRunning									; exit if NMI is already in progress
		bmi InterruptRequest
		
		sec
		ror NMIRunning									; set flag for NMI in progress
		
		pha												; back up A/X/Y
		txa
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
		
		asl NMIRunning									; clear flag for NMI in progress before exiting
		
; IRQ handler (unused for now)
InterruptRequest:
		rti

EnableRendering:
		lda #%00001010									; enable background and queue it for next NMI
	.byte $2c											; [skip 2 bytes]
		
DisableRendering:
		lda #%00000000									; disable background and queue it for next NMI

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

; uses CRC32 calculation routine from https://www.nesdev.org/wiki/Calculate_CRC32
CheckBIOS:
		lda #$00										; init pointer
		sta BIOSPtr
		tay
		lda #$e0
		sta BIOSPtr+1
		
@crc32init:
		ldx #3
		lda #$ff
@c3il:
		sta testcrc+0,x
		dex
		bpl @c3il
		
@CalcCRC32:
		lda (BIOSPtr),y
@crc32:
		ldx #8
		eor testcrc+0
		sta testcrc+0
@c32l:
		lsr testcrc+3
		ror testcrc+2
		ror testcrc+1
		ror testcrc+0
		bcc @dc32
		lda #$ed
		eor testcrc+3
		sta testcrc+3
		lda #$b8
		eor testcrc+2
		sta testcrc+2
		lda #$83
		eor testcrc+1
		sta testcrc+1
		lda #$20
		eor testcrc+0
		sta testcrc+0
@dc32:
		dex
		bne @c32l

		inc BIOSPtr
		bne :+
		inc BIOSPtr+1
:
		bne @CalcCRC32									; will fall through once BIOSPtr == $0000

@crc32end:
		ldx #3
@c3el:
		lda #$ff
		eor testcrc+0,x
		sta testcrc+0,x
		dex
		bpl @c3el

		lda testcrc+3
		jsr NumToChars
		stx CRC32+0
		sty CRC32+1
		lda testcrc+2
		jsr NumToChars
		stx CRC32+2
		sty CRC32+3
		lda testcrc+1
		jsr NumToChars
		stx CRC32+4
		sty CRC32+5
		lda testcrc+0
		jsr NumToChars
		stx CRC32+6
		sty CRC32+7
		rts

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
	.addr DumpPrep
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

; Print a message before dumping the BIOS
DumpPrep:
		lda #$21
		ldx #$8A
		ldy #PrepMsgLength
		jsr PrepareVRAMString
	.addr PrepMsg
		sta StringStatus								; save status to check later
		inc BGMode										; next mode
		lda #$01										; queue VRAM transfer for next NMI
		sta NeedDraw
		rts

PrepMsg:
	.byte "Dumping..."
PrepMsgLength=*-PrepMsg

; Dump the BIOS to 1KiB disk files & show error messages if necessary
DumpBIOS:
		jsr VINTWait									; wait a frame and disable NMIs just to be safe
		lda FileNum										; this should resume after the last valid file
		jsr WriteFile
	.addr DiskID
	.addr FileHeader
		bne PrintError
		
		lda FileNum
		cmp #$0B										; check if dump all done
		beq FinishDump									; end loop
		
		inc FileNum										; update file number
		ldx #$08
		inc FileHeader,x								; update file name
		ldx #$0C
		lda FileHeader,x								; get size
		ldx #$0A
		adc FileHeader,x
		sta FileHeader,x								; update start addr
		ldx #$0F
		sta FileHeader,x								; update start addr
		bne DumpBIOS									; [unconditional branch]
		
FinishDump:
		inc BGMode										; go to next mode on successful write
		
EnableNMI:
		lda PPU_CTRL_MIRROR								; enable NMI
		ora #%10000000
		bit PPU_STATUS									; in case this was called with the vblank flag set
		sta PPU_CTRL_MIRROR								; write to mirror first for thread safety
		sta PPU_CTRL
		rts

; Print the error message and wait for an inserted disk before retrying
PrintError:
		jsr NumToChars
		stx ErrorNum
		sty ErrorNum+1
		lda #$21
		ldx #$95
		ldy #ErrorMsgLength
		jsr PrepareVRAMString
	.addr ErrorMsg
		sta StringStatus								; save status to check later
		lda #$01										; queue VRAM transfer for next NMI
		sta NeedDraw
		jsr EnableNMI									; but enable NMI first
		jsr WaitForNMI
		
SideError:
		lda FDS_DRIVE_STATUS
		and #$01
		beq SideError									; wait until disk is ejected

Insert:
		lda FDS_DRIVE_STATUS
		and #$01
		bne Insert										; wait until disk is inserted
		
		lda #$21										; clear error message
		ldx #$95
		ldy #BlankMsgLength
		jsr PrepareVRAMString
	.addr BlankMsg
		sta StringStatus								; save status to check later
		lda #$01										; queue VRAM transfer for next NMI
		sta NeedDraw
		jsr WaitForNMI
		jmp DumpBIOS									; then retry the file write

InitFileHeader:
		ldx #$10
@loop:
		lda FileHeaderR,x
		sta FileHeader,x
		dex
		bpl @loop
		lda #$04
		sta FileNum
		rts


BlankMsg:
	.byte "       "
BlankMsgLength=*-BlankMsg

ErrorMsg:
	.byte "Err. "
ErrorNum:
	.byte "00"
ErrorMsgLength=*-ErrorMsg

DiskID:
	.byte $00 ; manufacturer
	.byte "DUM" ; yes, I know...
	.byte $20 ; normal disk
	.byte $00 ; game version
	.byte $00 ; side
	.byte $00 ; disk
	.byte $00 ; disk type
	.byte $00 ; unknown

FileHeaderR:
	.byte $FF
	.byte "DISKSYS0"
	.word __FILE4_DAT_RUN__
	.word __FILE4_DAT_SIZE__
	.byte 0 ; PRG
	.word __FILE4_DAT_RUN__
	.byte $00

; Display a success message
DumpSuccess:
		lda #$21
		ldx #$95
		ldy #SuccessMsgLength
		jsr PrepareVRAMString
	.addr SuccessMsg
		sta StringStatus								; save status to check later
		inc BGMode										; next mode
		lda #$01										; queue VRAM transfer for next NMI
		sta NeedDraw
		rts

SuccessMsg:
	.byte "OK!"
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

	.byte $20, $a9										; destination address (BIG endian)
	.byte %00000000 | Text2Length						; d7=increment mode (+1), d6=transfer mode (copy), length
	
Chars2:
	.byte "CRC32: "
CRC32:
	.byte "FFFFFFFF"
Text2Length=*-Chars2
	.byte $ff											; terminator

