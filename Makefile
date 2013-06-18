
#
# cyberchrist
#
# For debug build set: debug=true
#

#UNAME = $(shell sh -c 'uname -m')
#ifeq (${UNAME},x86_64)

INSTALL_PATH = usr/bin
CP = -cp src -cp ../om
FLAGS =

ifeq (${debug},true)
FLAGS = -debug
else
FLAGS = -dce full --no-traces
endif

HX = haxe $(CP) $(FLAGS) -main CyberChrist

all: bin

bin: src/*
	$(HX) -neko cyberchrist.n
	nekotools boot cyberchrist.n

install: bin
	#cp cyberchrist $(INSTALL_PATH)/cyberchrist
	cp ./cyberchrist $(INSTALL_PATH)

uninstall:
	rm -f $(INSTALL_PATH)/cyberchrist

clean:
	rm -f cyberchrist cyberchrist.n

PHONY: all bin install uninstall clean
