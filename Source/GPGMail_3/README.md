GPGMail
=======

Free-GPGMail is a plugin for OS X's Mail.app, which let's you  
send and receive secure, OpenPGP encrypted and signed messages.

Updates
-------

The latest releases of Free-GPGMail can be found on [GitHub](https://github.com/Free-GPGMail/Free-GPGMail).

Prerequisite
------------

In order to use Free-GPGMail you need to have GnuPG and Libmacgpg installed.
You can either build your own version, use one from [homebrew](http://brew.sh) or
find a packaged (non-fee redistributed) version at [Free-GPGMail](https://github.com/Free-GPGMail/Free-GPGMail).

Build
-----

1. Build Libmacgpg
2. Copy `Libmacgpg/build/Release/Libmacgpg.framework` to Frameworks/
3. `make`

Install
-------
1. Copy `build/Release/GPGMail.mailbundle` to `~/Library/Mail/Bundles/`
2. Activate the mailbundle in `Preferences -> General -> Manage Plugins...`



System Requirements
-------------------

* macOS 10.13 - 10.14
* Libmacgpg
* GnuPG


License
-------

This source code folders contains a BSD-3-Clause LICENSE.txt as well as BSD-3-Clause headers in most
relevant source files, which [were introduced](https://www.sente.ch/software/GPGMail/English.lproj/GPGMail.html#License)
by the original author Stéphane Corthésy. gpgtools.org/legal claims that GPG Mail is licensed under GPLv3,
and the source metadata in Resources/Info.plist lists unversioned GPL in NSHumanReadableCopyright.

We play it safe and release Free GPGMail under the most restrictive license of those mentioned above: GPLv3.
