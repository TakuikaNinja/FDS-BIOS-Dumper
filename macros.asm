; macros

; for use with the FDS BIOS VRAM struct format
.macro big_endian addr16
	.hibytes addr16
	.lobytes addr16
.endmacro

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
