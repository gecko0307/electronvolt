module engine.pause;

import std.conv;
import derelict.sdl.sdl;
import derelict.opengl.gl;
import dlib.image.io.png;
import engine.logic;
import engine.ui.text;
import engine.graphics.texture;
import engine.menu;

class PauseMenuObject: GameObject
{
    struct Entry
    {
        dstring text;
        string room;
        bool freeCurrentRoom;
        bool loadNextRoom;
        int x, y;
        int w, h;
    }

    Entry[] entries;
    Text txt;
    Texture background;

    this(GameLogicManager m)
    {
        super(m);

        txt = new Text(logic.fontMain);

        background = new Texture(loadPNG("data/ui/abstract.png"), false);

        addEntry(logic.dictionary["mExit"], "mainMenu", false, false);
        addEntry(logic.dictionary["mResumeGame"], "sandbox", false, false); //logic.previousRoom.name
    }

    void addEntry(dstring text, string roomName, bool free = true, bool load = true)
    {
        if (entries.length)
        {
            auto prev = &entries[$-1];
            entries ~= Entry(text, roomName, free, load,
                prev.x, prev.y + prev.h + 8, prev.w, prev.h);
        }
        else
        {
            entries ~= Entry(text, roomName, free, load, 16, 16, 200, 32);
        }
    }

    override void onDraw(double delta)
    {
        SDL_ShowCursor(1);

        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glLoadIdentity();

        // 2D mode
        glMatrixMode(GL_PROJECTION);
        glPushMatrix();
        glLoadIdentity();
        glOrtho(0, manager.window_width, 0, manager.window_height, -1, 1);
        glMatrixMode(GL_MODELVIEW);

        glLoadIdentity();

        glDisable(GL_LIGHTING);
        glDisable(GL_DEPTH_TEST);
        glDisable(GL_CULL_FACE);

        background.bind(delta);
        drawRectangle(0, 0, manager.window_width, manager.window_height);
        background.unbind();

        foreach(i, entry; entries)
        {
            if (mouseOverEntry(entry))
            {
                if (manager.lmb_pressed)
                    glColor4f(0.0f, 0.1f, 0.1f, 0.6f);
                else
                    glColor4f(1.0f, 1.0f, 1.0f, 0.6f);
            }
            else
            {
                glColor4f(1.0f, 0.5f, 0.0f, 0.9f);
            }
            drawRectangle(entry.x, entry.y, entry.w, entry.h);

            glColor4f(1.0f, 1.0f, 1.0f, 1.0f);

            float textx = entry.x + 16;
            float texty = entry.y + entry.h/2 - logic.mainFontHeight/2;
            txt.setPos(textx, texty);
            txt.render(entry.text);
        }

        glEnable(GL_CULL_FACE);
        glEnable(GL_DEPTH_TEST);
        glEnable(GL_LIGHTING);

        glMatrixMode(GL_PROJECTION);
        glPopMatrix();
        glMatrixMode(GL_MODELVIEW);
    }

    bool mouseOverEntry(Entry e)
    {
        return manager.mouseInRegionGlobal(e.x, e.y, e.w, e.h);
    }

    override void onKeyDown()
    {
        if (manager.event_key == SDLK_ESCAPE)
        {
            logic.goToRoom("level1", false, false);
        }
    }

    override void onMouseButtonUp()
    {
        if (manager.event_button == SDL_BUTTON_LEFT)
        {
            foreach(i, entry; entries)
            {
                if (mouseOverEntry(entry))
                {
                    if (entry.room == "mainMenu")
                    if (logic.previousRoom !is null)
                    {
                        logic.previousRoom.freeEvents();
                        logic.previousRoom.freeObjects();
                    }
                    logic.goToRoom(entry.room, entry.freeCurrentRoom, entry.loadNextRoom);
                    break;
                }
            }
        }
    }

    override void onFree()
    {
        background.free();
    }
}

class PauseMenuRoom: GameRoom
{
    this(string roomName, GameLogicManager m)
    {
        super(roomName, m);
    }

    override void onLoad()
    {
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);

        addObject(new PauseMenuObject(logic));
    }
}

