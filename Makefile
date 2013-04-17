
#
# cyberchrist
#

INSTALL_PATH =
CP = -cp src -cp ../om
FLAGS = -dce full --no-traces

ifeq ($(wildcard $INSTALL_PATH),)
INSTALL_PATH = /usr/bin/cyberchrist
endif

all: build

build: src/*
	haxe -neko cyberchrist.n $(CP) $(FLAGS) -main CyberChrist

install: build
	#TODO
	nekotools boot cyberchrist.n
	#cp cyberchrist $(INSTALL_PATH)

uninstall:
	#TODO
	#rm -f $(INSTALL_PATH)

clean:
	rm -f cyberchrist cyberchrist.n

PHONY: all build install uninstall clean
