Free GPGMail
============

*GPG Mail* (part of *GPGTools* now *GPG Suite*) has been a free product for
many years. Right up until version 3. In a surprise move the team at
GPGTools changed the product to require a license key and online activation.
While they are perfectly in their rights to do so, it did catch a lot of people
off by surprise, especially as it came as just a regular update.

So while they are in their rights to charge and place DRM into their product, it
is still a GPL licensed product which requires the source code to be available.

This repository and project uses the open source code with the DRM code
replaced so the product can be used without a license key, support plan or
online activation.

Rather than building the entire GPG Suite and installer, this project just
concentrates on building the GPG Mail mailbundles. Depending on supported macOS
versions, there are different versions of GPG Mail available:

- `Free-GPGMail_3.mailbundle`
- `Free-GPGMail_4.mailbundle`
- `Free-GPGMail_5.mailbundle`

Refer to the GPG Suite documentation for a list of supported macOS versions.

This repository contains the source tree for the modified versions of the mail
bundles, based on the original source packages from GPG Suite. Along with
instructions on how to build them.

We also publish a copy of the original source packages and compiled binaries of the
updated mailbundles.

Note GPG Suite must be installed first and then the mailbundle binaries can be
replaced.


Build Instructions
------------------

Note: If you want to use pre-compiled mailbundles, download the latest [release](../../releases/).

This build uses Xcode. Command line build tools must be installed.

1. Go to the Source directory and run make for the desired Free-GPGMail version:

        cd Source/
        make GPGMail_$n

   where valid values for `$n` are `3`, `4`, or `5`. This will create a
   `Free-GPGMail_$n.mailbundle` in `bundles/`. If you want to build bundles for
   all versions, just call `make`.


Installation
------------

1. Install GPG Suite suite as normal. Make sure you use the correct version.

2. Find the freshly installed `GPGMailLoader.mailbundle` and delete it.
   (Look into `/Library/Mail/Bundles/`,
   `/Library/Application Support/GPGTools/GPGMail` or the user-specific directory
   `~/Library/Mail/Bundles/`)

3. Build or download the modified mailbundle and copy it
   to your user-specific Mail Bundle directory

        mkdir -p ~/Library/Mail/Bundles/
        cp -r Free-GPGMail_5.mailbundle ~/Library/Mail/Bundles/

4. Restart Mail.app, go to `Preferences -> General -> Manage Plugins`.
   - Enable the Free GPGMail Plugin.
   
5. Restart Mail.app. Some users also report that a reboot is necessary.


Bug Reports and User Support
----------------------------

This project is run by volunteers in the free and open source spirit. Contributions
are welcome. Problems with building or installing Free-GPGMail should be posted
in the Github issue tracker. If you need help with the program itself, consider
buying the commercial product at GPGTools and make them work for their money.
