Free-GPGMail
============

This is a liberated version of *GPG Mail*&reg;, an Apple Mail plugin sold
with a support plan as part of the *GPG Suite*&reg; by *GPGTools*.

While the seller of the commercial product has the right to charge for a
support plan and place DRM into their product, it is still BSD and GPL
licensed software which requires the source code to be available.

This repository and project uses the open source code with the DRM code
replaced so the product can be used without a license key, support plan or
online activation.

Rather than building the entire suite and installer, this project just
concentrates on building the "mailbundle", the plugin for Apple Mail.

We also publish a copy of the original source packages and exercise our right,
granted by the open source license, to redistribute the compiled suite
without any business involved. This does not constitute any endorsement
or promotion of our releases by the intermediate copyright holders.

Depending on supported macOS versions, there are different versions of
the plugin available:

| Mailbundle      | 10.13       | 10.14  | 10.15    | 11      | 12       |
| --------------  | ----------- | ------ | -------- | --------| -------- |
|                 | High Sierra | Mojave | Catalina | Big Sur | Monterey |
| Free-GPGMail 3  | x           | x      |          |         |          |
| Free-GPGMail 4  | x           | x      | x        |         |          |
| Free-GPGMail 5* |             | u      | u        | s       |          |
| Free-GPGMail 6  |             |        |          |         | x        |

(*) While Big Sur requires Free-GPGMail 5 to be codesigned, Mojave and Catalina
do not like the code signature of the provided mailbundles. Thus, we publish
an unsigned and a signed version of the Free-GPGMail 5 mailbundle.

Note that GnuPG and Libmacgpg must be installed first and then the mailbundle
binaries can be activated. You can compile them from source or install them
from the GPG Suite.

Build Instructions
------------------

Note: If you want to use pre-compiled, signed, and notarized mailbundles, you
can download a mailbundle from the [release page](../../releases/).

This build uses Xcode&reg;. Command line build tools must be installed.

1. Go to the Source directory and run make for the desired Free-GPGMail version:

        cd Source/
        make GPGMail_$n

   where valid values for `$n` are `3` to `6`. This will create a
   `Free-GPGMail_$n.mailbundle` in `bundles/`. If you want to build bundles for
   all versions, just call `make`.

2. On Big Sur or later, if you want to use the mailbundle on a different machine
   than where it has been built, you may need to codesign the mailbundle with
   a developer key, or add a Gatekeeper rule after installation (see below):

        sudo spctl --add ~/Library/Mail/Bundles/Free-GPGMail_*.mailbundle


Installation
------------

1. Download and install Free-GPGMail:
    - Using [Homebrew](https://brew.sh):
      ```bash
      brew install --cask free-gpgmail
      ```

      If you receive an error mkdir: `/Users/YOUR_USERNAME/Library/Mail/Bundles: Operation not permitted`,
      open the Security & Privacy system preference panel, and grant "Full Disk
      Access" to terminal. Retry the installation.

    - or manually:
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

2. Restart Mail.app, go to `Preferences -> General -> Manage Plugins...`.
    
    If the "Manage Plugins" button is not present in the lower left corner,
    open a terminal and run:
    ```bash
    sudo defaults write “/Library/Preferences/com.apple.mail” EnableBundles 1
    defaults write com.apple.mail EnableBundles -bool true
    ```
    
    Then restart Mail.app again.

   - Make sure that `GPGMailLoader_*.mailbundle`, if present, is disabled.     
   - Enable the `Free-GPGMail_<version>.mailbundle`.
   - **Apply and Restart Mail**.

3. In Mail.app, check `Preferences -> Free-GPGMail`. If it says that you are in
   **Trial Mode** or **Decryption Only Mode**, hit **Activate**. It will perform
   a dummy activation routine.


Bug Reports and User Support
----------------------------

This project is run by volunteers in the free and open source spirit. Contributions
are welcome. Problems with building or installing Free-GPGMail should be posted
in the GitHub issue tracker. If you need help with the program itself, consider
buying the commercial product and make them work for their money.

Trademarks
----------

*Apple*&reg; and *Xcode*&reg; are trademarks of Apple Inc.

*GPG Mail*&reg;, *GPG Suite*&reg; and *GPGTools*&reg; are trademarks of GPGTools GmbH.

Neither use of these terms within this Readme or within Free-GPGMail
constitutes endorsement of Free-GPGMail by the respective holders.
Free-GPGMail is a non-commercial software without any business involved.
