Libmacgpg
=========

Libmacgpg is an Objective-C framework which makes it easier to communicate with gnupg.
It's the base framework for all apps and services of [GPG Suite](https://gpgtools.org)

Updates
-------

The latest releases of Libmacgpg is part of GPG Suite and can be found on our [official website](https://gpgtools.org).

For the latest news and updates check our [Twitter](https://twitter.com/gpgtools).

If you have any questions how to use Libmacgpg in your own App, contact us on our [support page](https://gpgtools.tenderapp.com).


Build
-----

#### Clone the repository
```bash
git clone --recursive https://github.com/GPGTools/Libmacgpg.git
cd Libmacgpg
```

#### Build
```bash
make
```

#### Install
To install Libmacgpg copy build/Release/Libmacgpg.framework to ~/Library/Frameworks/Libmacgpg.framework

```bash
cp -R ./build/Release/Libmacgpg.framework ~/Library/Frameworks/Libmacgpg.framework
```

If you're using GPGMail, follow these steps to install the xpc service helper.

```bash
cp ./build/org.gpgtools.Libmacgpg.xpc.plist ~/Library/LaunchAgents/

mkdir -p ~/Library/Application\ Support/GPGTools
cp ~/build/Release/org.gpgtools.Libmacgpg.xpc ~/Library/Application\ Support/GPGTools

launchctl unload ~/Library/LaunchAgents/org.gpgtools.Libmacgpg.xpc.plist
launchctl load -w ~/Library/LaunchAgents/org.gpgtools.Libmacgpg.xpc.plist
```

Enjoy your custom Libmacgpg.


System Requirements
-------------------

* Mac OS X >= 10.6
* GnuPG v2.0.26
