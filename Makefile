CC = xtensa-lx106-elf-gcc
CFLAGS = -Os -Iinclude -I. -Ilib/heatshrink \
		-std=c99 -Werror -Wpointer-arith -Wundef -Wall -Wl,-EL -fno-inline-functions \
		-nostdlib -mlongcalls -mtext-section-literals -D__ets__ -DICACHE_FLASH -Wno-address
LDLIBS = -nostdlib -Wl,--start-group -lhal -lmain -lupgrade -lnet80211 -lwpa -llwip -lpp -lphy -Wl,--end-group -lcirom -lgcc -static
LDFLAGS = -Teagle.app.v6.ld

ESPTOOL ?= esptool.py
ESPPORT ?= /dev/ttyUSB0


httpd-0x00000.bin: httpd
	esptool.py elf2image $^

httpd: user/auth.o \
	user/base64.o \
	user/cgi.o \
	user/cgiwifi.o \
	user/heatshrink_decoder.o \
	user/httpd.o \
	user/httpdespfs.o \
	user/io.o \
	user/stdout.o \
	user/user_main.o \
	user/espfs.o
	$(CC) $(LDFLAGS) $^ -o $@ $(LDLIBS)

flash: httpd-0x00000.bin
	esptool.py write_flash 0 httpd-0x00000.bin
	sleep 5
	esptool.py write_flash 0x40000 httpd-0x40000.bin

clean:
	rm -f httpd*
	rm -rf build
	find -name '*.o' -delete
	find -name '*.a' -delete

webpages.espfs: html/ html/wifi/ mkespfsimage/mkespfsimage
	cd html; find | ../mkespfsimage/mkespfsimage > ../webpages.espfs; cd ..

mkespfsimage/mkespfsimage: mkespfsimage/
	make -C mkespfsimage

htmlflash: webpages.espfs
	if [ $$(stat -c '%s' webpages.espfs) -gt $$(( 0x2E000 )) ]; then echo "webpages.espfs too big!"; false; fi
	$(ESPTOOL) --port $(ESPPORT) write_flash 0x12000 webpages.espfs

connect:
	picocom -b 115200 --omap crcrlf /dev/ttyUSB0
