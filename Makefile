#
# Credits: romgrk
#

CC=gcc
OS=$(shell uname | tr A-Z a-z)
ifeq ($(findstring mingw,$(OS)), mingw)
    OS='windows'
endif
ARCH=`uname -m`

all:
	$(CC) -Ofast -c -Wall -static -fpic -o ./lua/popfix/fzy-native-src/match.o ./lua/popfix/fzy-native-src/match.c
	$(CC) -shared -o ./lua/popfix/libfzy-$(OS)-$(ARCH).so ./lua/popfix/fzy-native-src/match.o
