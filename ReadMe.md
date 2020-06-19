GPGMail - No Activation
=======================

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
concentrates on building the two GPGMail mailbundle versions. `GPGMail_3.mailbundle`
and `GPGMail_4.mailbundle`.

This repository contains the source tree for the modified versions of the mail bundles,
based on the original source packages from GPGTools. Along
with instructions on how to build them.

We also publish a copy of the original source packages and compiled binaries of the
updated mailbundles, ~along with a .DMG for easy installation.~

Note GPGSuite must be installed first and then
the mailbundle binaries replaced using the .DMG.


Build Instructions
------------------

This build uses Xcode. Command line build tools must be installed.

1. Go to the Source directory and run:

    make

  This should produce two mailbundles: `GPGMail_3.mailbundle` and `GPGMail_4.mailbundle`


Installation
------------

1. Install GPGSuite suite as normal. Make sure you use the correct version.

2. Copy the modified mailbundle(s) to your user-specific Mail Bundle directory

    mkdir -p ~/Library/Mail/Bundles/
    cp -r GPGMail_?.mailbundle ~/Library/Mail/Bundles/

3. Restart Mail.app, go to `Preferences -> General -> Manage Plugins`.
   You should see the plugin, enable it and click Apply
   
4. Restart Mail.app

Hopefully it's working for you now.
