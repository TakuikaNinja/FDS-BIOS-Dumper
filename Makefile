GAME=bios-dumper
ASSEMBLER=ca65
LINKER=ld65

OBJ_FILES=$(GAME).o

all: $(GAME).fds

$(GAME).fds: $(OBJ_FILES)  $(GAME).cfg
	$(LINKER) -o $(GAME).fds -C $(GAME).cfg $(OBJ_FILES) -m $(GAME).map.txt -Ln $(GAME).labels.txt --dbgfile $(GAME).dbg

.PHONY: clean

clean:
	rm -f *.o *.fds *.dbg *.nl *.map.txt *.labels.txt

$(GAME).o: *.asm Jroatch-chr-sheet.chr

%.o:%.asm
	$(ASSEMBLER) $< -g -o $@
