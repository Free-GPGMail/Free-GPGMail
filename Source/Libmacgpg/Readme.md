Libmacgpg
=========

Libmacgpg is an Objective-C framework which makes it easier to communicate with gnupg.
It's the base framework for Free-GPGMail and more


Build
-----

#### Clone the repository
```bash
git clone --recursive https://github.com/Free-GPGMail/Free-GPGMail/
cd Source/Libmacgpg
```

#### Build
```bash
make
```

#### Install

(this might be outdated)

To install Libmacgpg copy build/Release/Libmacgpg.framework to ~/Library/Frameworks/Libmacgpg.framework

```bash
cp -R ./build/Release/Libmacgpg.framework ~/Library/Frameworks/Libmacgpg.framework
```

If you're using Free-GPGMail, follow these steps to install the xpc service helper.

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
