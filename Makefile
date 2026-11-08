# JLP + FujiNet coexistence test for the Intellivision.
#
#   make            ROM (.bin + .cfg for the cart, .rom for jzIntv) + checks
#   make nofuji     same ROM without [vars] fujinet = 1 (the mailbox gate test)
#   make dist       dist/jlpfn.bin + .cfg, ready for an SD card or TNFS host
#   make test       headless jzIntv test matrix (see tools/run-tests.sh)
#   make clean
#
# URL is the file the N: tests download. It must serve data/pattern.bin.

INTYBASIC ?= intybasic
AS1600    ?= as1600
PYTHON    ?= python3
LIBDIR    ?= lib/
URL       ?= https://raw.githubusercontent.com/FujiNetWIFI/fujinet-intv-jlp-test/main/data/pattern.bin

SOURCES = $(wildcard src/*.bas)
OUT     = build/jlpfn

.DELETE_ON_ERROR:
.PHONY: all nofuji check dist test clean FORCE

all: $(OUT).bin check

build data:
	mkdir -p $@

data/pattern.bin build/pattern.bas: tools/mkpattern.py | build data
	$(PYTHON) tools/mkpattern.py data/pattern.bin build/pattern.bas

# Rebuilt whenever URL changes.
build/url.txt: FORCE | build
	@echo '$(URL)' | cmp -s - $@ || echo '$(URL)' > $@

build/url.bas: build/url.txt tools/mkurl.py
	$(PYTHON) tools/mkurl.py '$(URL)' $@

$(OUT).asm: $(SOURCES) build/pattern.bas build/url.bas $(LIBDIR)intybasic_prologue.asm $(LIBDIR)intybasic_epilogue.asm
	$(INTYBASIC) --jlp --title "JLP+FujiNet Test" src/main.bas $@ $(LIBDIR)

# as1600 with no extension on -o writes .bin, .cfg and .rom together.
$(OUT).bin: $(OUT).asm
	$(AS1600) -o $(OUT) -l $(OUT).lst -s $(OUT).sym $<

check: $(OUT).bin
	$(PYTHON) tools/check_map.py $(OUT).cfg $(OUT).sym
	$(PYTHON) tools/lint_accel.py $(OUT).asm

nofuji: $(OUT)-nofuji.bin

# Test helper: boots /jlpfn-test/jlpfn.bin from FujiNet host slot 1.
build/pushboot.rom: tools/pushboot.bas | build
	$(INTYBASIC) tools/pushboot.bas build/pushboot.asm $(LIBDIR)
	$(AS1600) -o $@ build/pushboot.asm

$(OUT)-nofuji.asm: $(OUT).asm
	grep -v 'CFGVAR "fujinet"' $< > $@

$(OUT)-nofuji.bin: $(OUT)-nofuji.asm
	$(AS1600) -o $(OUT)-nofuji -s $(OUT)-nofuji.sym $<
	$(PYTHON) tools/check_map.py --nofuji $(OUT)-nofuji.cfg $(OUT)-nofuji.sym

dist: all
	mkdir -p dist
	cp $(OUT).bin dist/jlpfn.bin
	cp $(OUT).cfg dist/jlpfn.cfg

test: all nofuji build/pushboot.rom
	tools/run-tests.sh

clean:
	rm -rf build dist
