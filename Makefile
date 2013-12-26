
##
## Cyberchrist
##

DEBUG = false
INSTALL_PATH = /usr/bin/
LIBS = -lib libom
CP = -cp src
ifeq (${DEBUG},true)
	FLAGS = -debug
else
	FLAGS = -dce full --no-traces
endif
HX = haxe $(LIBS) $(CP) $(FLAGS) -main CyberChrist

all: build

cyberchrist.n: src/* src/cyberchrist/*
	$(HX) -neko cyberchrist.n

build: cyberchrist.n
	nekotools boot cyberchrist.n

install: cyberchrist
	cp ./cyberchrist $(INSTALL_PATH)

uninstall:
	rm -f $(INSTALL_PATH)/cyberchrist

clean:
	rm -f cyberchrist cyberchrist.n

PHONY: all build install uninstall clean
