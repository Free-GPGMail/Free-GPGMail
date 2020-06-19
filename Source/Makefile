all:
	cd Libmacgpg && \
		make && \
		cp -r build/Release/Libmacgpg.framework ../GPGMail_3/Frameworks/ && \
		cp -r build/Release/Libmacgpg.framework ../GPGMail_4/Frameworks/
	cd GPGMail_3 && \
		make && \
		cp -r build/Release/GPGMail.mailbundle ../GPGMail_3.mailbundle
	cd GPGMail_4 && \
		make && \
        cp -r build/Release/GPGMail.mailbundle ../GPGMail_4.mailbundle


clean:
	rm -rf *mailbundle
	rm -rf GPGMail*/build
