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
concentrates on building the GPGMail mailbundle. There are currently only two
components in the suite that have the DRM. `GPGMail_13.mailbundle` and
`GPGMail_14.mailbundle`.

This repository contains a copy of the original downloads from gpgtools.org as
as well as a source tree for the modified versions of the mail bundles. Along
with instructions on how to build them.

Finally this also contains compiled binaries of the updated mailbundles, along
with a .DMG for easy installation. Note GPGSuite must be installed first and then
The mailbundle binaries replaced using the .DMG.

LICENSE
=======

GPGMailNoActivation
Copyright (C) 2018-2019

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
