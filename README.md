Electronvolt
============
Electronvolt (formerly known as Atrium) is a sci-fi first-person puzzle written entirely in [D language](http://dlang.org). The game is not finished yet, currently there is only a tech demo.

Gameplay
--------
Electronvolt will provide high level of interactivity, featuring fully dynamic world with everything being controlled by the physics engine. You will be able to walk on any surface and push any object, use special devices to affect gravity and other physical behaviours of the environment.

Tech details
------------
The game features [its own graphics engine](https://github.com/gecko0307/dagon). It also uses [Newton Dynamics](http://newtondynamics.com/) for physics.

The old version based on DGL engine can be found [here](https://github.com/gecko0307/electronvolt/tree/atrium_dgl).

Building
--------
To build the game, run `dub build --build=release-nobounds`.

The repository contains only the source code. To run Electronvolt, you'll need binary data which is available on [Releases page](https://github.com/gecko0307/electronvolt/releases). Download the archive `electronvolt-data.7z`, unpack it and put the `data` folder alongside with the executable.
