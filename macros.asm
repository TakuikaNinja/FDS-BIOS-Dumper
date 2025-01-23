; macros

; place bytes + define a string label with length variable
.macro define_string label, str
	.proc label
		.byte str
	.endproc
	.ident(.concat(.string(label), "Length")) = .sizeof(label)
.endmacro

; call PrepareVRAMString with *constant* PPU address, source CPU address, and length values
.macro vram_string ppu16, addr16, length
	.assert length > 0, error, "invalid string size"
	.assert length <= BUFFER_SIZE, warning, "string size exceeds buffer"
	lda #>(ppu16)
	ldx #<(ppu16)
	ldy #(length)
	jsr PrepareVRAMString
	.addr addr16
.endmacro

; for use with the FDS BIOS VRAM struct format
.macro encode_length inc32, fill, len 
	.assert len > 0 && len <= 64, error, "cannot encode length"
	.byte (inc32 << 7) | (fill << 6) | (len & 63)
.endmacro

.macro encode_string inc32, fill, arg 
	.assert .strlen(arg) > 0 && .strlen(arg) <= 64, error, "cannot encode string"
	.byte (inc32 << 7) | (fill << 6) | (.strlen(arg) & 63), arg
.endmacro

.macro encode_call addr16
	.byte $4c
	.addr addr16
.endmacro

.macro encode_return
	.byte $60
.endmacro

.macro encode_terminator
	.byte $ff
.endmacro
