Free GPGMail
============

GPGMail (part of GPGTools now GPGSuite) has been an open source free product for
many years. Right up until the new version 3. In a surprise move the team at 
GPGTools changed the product to require a license key and online activation.
While they are perfectly in their rights to do so, it did catch a lot of people
off by surprise, especially as it came as just a regular update.

So while they are in their rights to charge and place DRM into their product, it
is still a GPL licensed product which requires the source code to be available.
This repository and project uses the open source source code with the DRM removed
so the product can be used without a license key or any online activation.

A particular motivation for this project is the fact that they offer no offline
activation mechanism which means it is not possible to use their product as is 
anymore on non-Internet connected machines (something that is a real issue for
some people, especially in the IT security world, something GPGTools should have
considered). 

Rather than building the entire GPGMail Suite and installer, this project just
concentrates on building the two GPGMail mailbundle versions. `Free-GPGMail_3.mailbundle`
and `Free-GPGMail_4.mailbundle`.

This repository contains the source tree for the modified versions of the mail bundles,
based on the original source packages from GPGTools. Along
with instructions on how to build them.

We also publish a copy of the original source packages and compiled binaries of the
updated mailbundles.

Note GPGSuite must be installed first and then the mailbundle binaries can be
replaced.


Build Instructions
------------------

Note: If you want to use pre-compiled mailbundles, download the latest [release](../../releases/).

This build uses Xcode. Command line build tools must be installed.

1. Go to the Source directory and run make:

        cd Source/
        make

  This should produce two mailbundles in the `Source/bundles/` directory:
  - `Free-GPGMail_3.mailbundle` 
  - `Free-GPGMail_4.mailbundle`


Installation
------------

1. Install GPGSuite suite as normal. Make sure you use the correct version.

2. Find the freshly installed `GPGMailLoader.mailbundle` and delete it.
   (Look into `/Library/Mail/Bundles/`,
   `/Library/Application Support/GPGTools/GPGMail` or the user-specific directory
   `~/Library/Mail/Bundles/`)

3. Build or download the modified mailbundle (version 3 or 4) and copy it
   to your user-specific Mail Bundle directory

        mkdir -p ~/Library/Mail/Bundles/
        cp -r Free-GPGMail_4.mailbundle ~/Library/Mail/Bundles/

4. On macOS 11.0 Big Sur and later, disable Gatekeeper

        sudo spctl --master-disable;

5. Restart Mail.app, go to `Preferences -> General -> Manage Plugins`.
   - Enable the Free GPGMail Plugin.
   
6. On macOS 11.0 Big Sur and later, re-enable Gatekeeper

        sudo spctl --master-enable.

7. Restart Mail.app. Some users also report, that a reboot is necessary.

