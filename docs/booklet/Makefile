# JLP + FujiNet booklet (Typst 0.15+). The fonts are the INTV programmer's
# guide's, in fujinet-manuals; point FONTS at that directory.
TYPST ?= typst
FONTS ?= $(HOME)/Workspace/fujinet-manuals/intv/fujinet-programmers-guide/fonts
OUT    = jlp-fujinet.pdf

all: $(OUT)

$(OUT): jlp-fujinet.typ style.typ $(wildcard ../img/*.svg)
	$(TYPST) compile --root .. --font-path $(FONTS) jlp-fujinet.typ $(OUT)

preview: $(OUT)
	mkdir -p preview
	pdftoppm -png -r 110 $(OUT) preview/page

clean:
	rm -rf $(OUT) preview

.PHONY: all preview clean
