; RAM

; zeropage
.segment "ZEROPAGE"
	temp: .res 16 ; temp memory, also used by FDS BIOS
	NMIRunning: .res 1
	NMIReady: .res 1
	NeedDraw: .res 1
	NeedPPUMask: .res 1
	FrameCount: .res 2
	BGMode: .res 1
	DisplayToggle: .res 1

; BIOS zeropage variables
.segment "BIOSZP"

; controller states
	ExpTransitions: .res 4 ; up->down transitions for Pad1, Pad2, Exp1, Exp2 (used by ReadDownExpPads)
	Buttons: .res 4 ; Usage depends on polling routine

; FDS BIOS register mirrors
	FDS_EXT_MIRROR: .res 1
	FDS_CTRL_MIRROR: .res 1
	JOY1_MIRROR: .res 1
	PPU_Y_SCROLL_MIRROR: .res 1
	PPU_X_SCROLL_MIRROR: .res 1
	PPU_MASK_MIRROR: .res 1
	PPU_CTRL_MIRROR: .res 1

; stack
; FDS BIOS vector flags
.segment "STACK"
	NMI_FLAG: .res 1 ; (bits 6 & 7)
	IRQ_FLAG: .res 1 ; (bits 6 & 7)
	RST_FLAG: .res 1 ; $35 = skip BIOS
	RST_TYPE: .res 1 ; $ac = first boot, $53 = soft-reset

; OAM buffer
.segment "OAM"
	oam: .res 256

; FDS BIOS VRAM buffer
.segment "RAM"
	VRAM_BUFFER_SIZE: .res 1 ; default = $7d, max = $fd
	VRAM_BUFFER_END: .res 1 ; holds end index of the buffer
	VRAM_BUFFER: .res $fd ; actual buffer

; rest of memory

