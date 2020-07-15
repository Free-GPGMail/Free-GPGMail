GPGMAILS = GPGMail_3 GPGMail_4

.PHONY: all
all: $(GPGMAILS)

.PHONY: Libmacgpg
Libmacgpg:
	$(MAKE) -C Libmacgpg

.PHONY: $(GPGMAILS)	
$(GPGMAILS): Libmacgpg
	cp -r Libmacgpg/build/Release/Libmacgpg.framework $@/Frameworks
	$(MAKE) -C $@
	mkdir -p bundles/Free-$@.mailbundle
	cp -r $@/build/Release/GPGMail.mailbundle bundles/Free-$@.mailbundle/Free-$@.mailbundle

clean:
	rm -rf *.mailbundle
	$(MAKE) -C Libmacgpg clean
	$(MAKE) -C GPGMail_3 clean
	$(MAKE) -C GPGMail_4 clean
