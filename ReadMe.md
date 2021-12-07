Free-GPGMail
============

This is a liberated version of a similarly named plugin for Apple Mail.

While the seller of the commercial product has the right to charge for a
support plan and place DRM into their product, it is still a GPL licensed
product which requires the source code to be available.

This repository and project uses the open source code with the DRM code
replaced so the product can be used without a license key, support plan or
online activation.

Rather than building the entire suite and installer, this project just
concentrates on building the "mailbundle", the plugin for Apple Mail.

We also publish a copy of the original source packages and execise our right,
granted by the open source license, to redistribute the compiled suite
without a fee. We neither endorse nor promote our releases with the names
of the intermediate copyright holders.

Depending on supported macOS versions, there are different versions of
the plugin available:

| Mailbundle                  | supported macOS versions          |
| --------------------------- | --------------------------------- |
| `Free-GPGMail_3.mailbundle` | Mojave & High Sierra              |
| `Free-GPGMail_4.mailbundle` | Catalina, Mojave & High Sierra    |
| `Free-GPGMail_5.mailbundle` | Big Sur, Catalina & Mojave        |
| `Free-GPGMail_6.mailbundle` | Monterey                          |


Note that GnuPG and Libmacgpg must be installed first and then the mailbundle
binaries can be activated. You can compile them from source or install the
bundled versions from the compiled suite.

Build Instructions
------------------

Note: If you want to use pre-compiled, signed, and notarized mailbundles, you
can download a mailbundle from the [release page](../../releases/).

This build uses Xcode. Command line build tools must be installed.

1. Go to the Source directory and run make for the desired Free-GPGMail version:

        cd Source/
        make GPGMail_$n

   where valid values for `$n` are `3` to `6`. This will create a
   `Free-GPGMail_$n.mailbundle` in `bundles/`. If you want to build bundles for
   all versions, just call `make`.

2. On Big Sur or later, you may need to codesign the mailbundle with your personal
   developer key, or add a Gatekeeper rule after installation (see below).

Installation
------------

1. Download and install the GPG Suite .dmg file from the commercial seller or from the
   [Free-GPGMail releases page](../../releases/).
   - If you are asked by the installed whether you want to
     "enable GPG Mail now", say **Not Now** and check
     **I am not interested in GPG Mail. Don't ask me again.**

2. Build or download a Free-GPGMail mailbundle compatible with your
   macOS version.

3. Create a folder `~/Library/Mail/Bundles/` and drag
   `Free-GPGMail_<version>.mailbundle` into that folder.
   (`~/Library` may be hidden in Finder, but you can enable the
   visibility in "Show View Options" while you are in **Home**)

4. On macOS 11 Big Sur or later, if you built your own mailbundle from
   source and did not codesign it, add a Gatekeeper rule:

        sudo spctl --add ~/Library/Mail/Bundles/Free-GPGMail_*.mailbundle

   This is not necessary for downloaded mailbundles.

5. Restart Mail.app, go to `Preferences -> General -> Manage Plugins...`.
   - Make sure that `GPGMailLoader_*.mailbundle`, if present, is disabled.     
   - Enable the `Free-GPGMail_<version>.mailbundle`.
   - **Apply and Restart Mail**.

6. In Mail.app, check `Preferences -> Free-GPGMail`. If it says that you are in
   **Trial Mode** or **Decryption Only Mode**, hit **Activate**.


Bug Reports and User Support
----------------------------

This project is run by volunteers in the free and open source spirit. Contributions
are welcome. Problems with building or installing Free-GPGMail should be posted
in the Github issue tracker. If you need help with the program itself, consider
buying the commercial product and make them work for their money.
