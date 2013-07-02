module main;

import derelict.sdl.sdl;
import derelict.opengl.gl;
import engine.core.application;
import engine.logic;
import engine.menu;
import engine.pause;
//import engine.level;
import engine.sandbox;

class AtriumApp: Application
{
    GameLogicManager logic;

    this(uint w, uint h, string caption)
    {
        super(w, h, caption);

        logic = new GameLogicManager(manager);

        logic.rooms["mainMenu"] = new MainMenuRoom("mainMenu", logic);
        logic.rooms["pauseMenu"] = new PauseMenuRoom("pauseMenu", logic);
        logic.rooms["pauseMenu"].load();
        //logic.rooms["level1"] = new LevelRoom("level1", "data/levels/area0/area0.dat", logic);
        logic.rooms["sandbox"] = new SandboxRoom("sandbox", logic);

        logic.goToRoom("mainMenu");
    }

    override void onUpdate()
    {
        logic.update();
    }
}

void main()
{
    AtriumApp app = new AtriumApp(800, 600, "Atrium");
    app.run();
}

