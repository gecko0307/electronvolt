Electronvolt
============
Electronvolt (formerly known as Atrium) will be a sci-fi first-person puzzle written in [D language](http://dlang.org). The game itself is under development. This repository contains a tech demo that implements planned visual style and basic gameplay mechanics. There are no puzzles/objectives yet.

[![Screenshot](https://gamedev.timurgafarov.ru/storage/eV_2.jpg)](https://gamedev.timurgafarov.ru/storage/eV_2.jpg)

Gameplay
--------
Electronvolt will provide high level of interactivity, featuring fully dynamic world with everything being controlled by the physics engine. You will be able to walk on any surface and push any object, use special devices to affect gravity and other physical behaviours of the environment.

Tech details
------------
The game features [Dagon](https://github.com/gecko0307/dagon) as a graphics engine. It also uses [Newton Dynamics](http://newtondynamics.com/) for physics and [SoLoud](https://github.com/jarikomppa/soloud) for playing sounds.

Download
--------
Binary releases of the game are available for download on [GameJolt](https://gamejolt.com/games/electronvolt/46185).

Building
--------
To build the demo, run `dub build --build=release-nobounds`.

The repository contains only the source code. To run Electronvolt, you'll need binary data which is available [here](https://drive.google.com/file/d/1RbZPQ-sSfckf9nT6jGagbqBsn3YwCV4T/view?usp=drive_link). Download the archive `eV-0.0.7-assets.7z`, unpack it and put the contents alongside with the executable.

To lighten the updates of the asset archive, the game soundtrack (`assets/music` folder) is downloaded separately. It is available [here](https://drive.google.com/file/d/13rnpvkE5LarN8dg_jgjgP4-12Nk639RD/view?usp=sharing). Download the archive `eV-music.7z`, unpack it and put the contents alongside with the executable.

The Launcher
------------
Electronvolt features optional launcher written in Python that allows to configure graphics beforehand and will also provide GameJolt trophy system integration into the game.
