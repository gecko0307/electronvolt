Atrium
======
The goal of this project is to create a full-fledged 3D platform game, 
entirely in D language (http://dlang.org).

Atrium uses OpenGL for rendering, thus (theoretically) supporting all 
platforms that provide OpenGL API. Currently Atrium is well-tested on
Windows (Windows XP and above, 32-bit) and Linux (x86, Ubuntu 8.10).

The project is written in D2 using Phobos, and requires up-to-date 
D compiler (DMD or LDC).

We currently don't provide any build scripts or makefiles, since
Atrium uses its own in-house building toolchain based on Cook
(http://code.google.com/p/cook-build-automation-tool). 
Sorry for the inconvenience.
