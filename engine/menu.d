module engine.menu;

import std.conv;
import derelict.sdl.sdl;
import derelict.opengl.gl;
import dlib.image.io.png;
import engine.logic;
import engine.ui.text;
import engine.graphics.texture;

void drawRectangle(float x, float y, float width, float height)
{
    glBegin(GL_QUADS);
    glTexCoord2f(0, 1); glVertex2f(x, y); 
    glTexCoord2f(0, 0); glVertex2f(x, y+height);
    glTexCoord2f(1, 0); glVertex2f(x+width, y+height);
    glTexCoord2f(1, 1); glVertex2f(x+width, y);
    glEnd();
}

class MainMenuObject: GameObject
{
    struct Entry
    {
        dstring text;
        string room;
        bool freeCurrentRoom;
        bool loadNextRoom;
        int x;
        int y;
        int w;
        int h;
    }

    Entry[] entries;
    uint resumeEntryIndex;
    Text txt;
    Texture background;

    this(GameLogicManager m)
    {
        super(m);

        txt = new Text(logic.fontMain);

        background = new Texture(loadPNG("data/ui/space.png"), false);

        addEntry(logic.dictionary["mExit"], "_exit_");
        addEntry(logic.dictionary["mOptions"], "_current_room_", false, false);
        addEntry(logic.dictionary["mLoadGame"], "_current_room_", false, false);
        addEntry(logic.dictionary["mNewGame"], "level1", false, true);
    }

    uint addEntry(dstring text, string roomName, bool free = true, bool load = true)
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
        return entries.length-1;
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

        foreach(i, ref entry; entries)
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
                    glColor4f(1.0f, 0.5f, 0.0f, 0.6f);
                }

            glDisable(GL_TEXTURE_2D);
            drawRectangle(entry.x, entry.y, entry.w, entry.h);

            glColor4f(1.0f, 1.0f, 1.0f, 1.0f);

            float textx = entry.x + 16;
            float texty = entry.y + entry.h/2 - logic.mainFontHeight/2;
            txt.setPos(textx, texty);
            txt.render(entry.text);
        }
        
        //drawRectangle(200, 200, 50, 50);

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
            manager.running = false;
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

class MainMenuRoom: GameRoom
{
    this(GameLogicManager m)
    {
        super(m);
    }

    override void onLoad()
    {
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);

        addObject(new MainMenuObject(logic));
    }
}
