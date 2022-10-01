Electronvolt
============
Electronvolt (formerly known as Atrium) will be a sci-fi first-person puzzle written entirely in [D language](http://dlang.org). The game itself is under development. This repository contains a showcase that demonstrates planned visual style and basic gameplay mechanics. There are no puzzles/objectives yet.

[![Screenshot](https://gamedev.timurgafarov.ru/storage/eV_2.jpg)](https://gamedev.timurgafarov.ru/storage/eV_2.jpg)

Gameplay
--------
Electronvolt will provide high level of interactivity, featuring fully dynamic world with everything being controlled by the physics engine. You will be able to walk on any surface and push any object, use special devices to affect gravity and other physical behaviours of the environment.

Tech details
------------
The game features [Dagon](https://github.com/gecko0307/dagon) as a graphics engine. It also uses [Newton Dynamics](http://newtondynamics.com/) for physics and [SoLoud](https://github.com/jarikomppa/soloud) for playing sounds.

The old version based on DGL engine can be found [here](https://github.com/gecko0307/electronvolt/tree/atrium_dgl).

Building
--------
To build the demo, run `dub build --build=release-nobounds`.

The repository contains only the source code. To run Electronvolt, you'll need binary data which is available [here](https://drive.google.com/file/d/1hj390QgVPE82rwGyUdz9j-5hR5IbqVIe/view?usp=sharing). Download the archive `eV-data.zip`, unpack it and put the `data` folder alongside with the executable.
