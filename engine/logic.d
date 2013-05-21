module engine.logic;

import std.stdio;
import engine.core.appmanager;
import engine.ui.font;
import engine.locale;

class GameLogicManager
{
    AppManager appManager;

    GameRoom currentRoom;
    GameRoom previousRoom;
    GameRoom[string] rooms;
    string nextRoom = "";
    bool freeCurrent;
    bool loadNext;

    Font fontMain;
    int mainFontHeight = 14;

    dstring[string] dictionary;

    //bool gameIsPaused = false;

    this(AppManager m)
    {
        appManager = m;
        rooms["_exit_"] = new ExitRoom(this);
        rooms["_current_room_"] = currentRoom;

        fontMain = new Font();
        fontMain.init("data/fonts/droid/DroidSans.ttf", mainFontHeight);

        dictionary["mNewGame"] = "New game";
        dictionary["mResumeGame"] = "Resume game";
        dictionary["mLoadGame"] = "Load game";
        dictionary["mOptions"] = "Options";
        dictionary["mExit"] = "Exit";
        readLocalization(dictionary, "data/locale/ru.txt");
    }

    void goToRoom(string roomName, bool free = true, bool load = true)
    {
        nextRoom = roomName;
        freeCurrent = free;
        loadNext = load;
    }

    void update()
    {
        if (nextRoom.length)
        {
            //writefln("Going to room %s...", nextRoom);

            if (currentRoom !is null)
            {
                currentRoom.freeEvents();
                if (freeCurrent)
                {
                    currentRoom.freeObjects();
                }
            }

            if (!(nextRoom in rooms))
                throw new Exception("No such room: " ~ nextRoom);

            previousRoom = currentRoom;
            currentRoom = rooms[nextRoom];
            nextRoom = "";
            rooms["_current_room_"] = currentRoom;

            if (loadNext)
            {
                currentRoom.load();
            }
            currentRoom.createEvents();

            //writefln("Room loaded");
        }

        if (currentRoom !is null)
            currentRoom.draw();
    }
}

class GameObject
{
    AppManager manager;
    GameLogicManager logic;
    int keyDownActionId;
    int keyUpActionId;
    int mouseButtonDownActionId;
    int mouseButtonUpActionId;

    this(GameLogicManager logi)
    {
        logic = logi;
        manager = logi.appManager;
        //createEvents();
    }

    void createEvents()
    {
        keyDownActionId = manager.bindActionToEvent(EventType.KeyDown, &onKeyDown);
        keyUpActionId = manager.bindActionToEvent(EventType.KeyUp, &onKeyUp);
        mouseButtonDownActionId = manager.bindActionToEvent(EventType.MouseButtonDown, &onMouseButtonDown);
        mouseButtonUpActionId = manager.bindActionToEvent(EventType.MouseButtonUp, &onMouseButtonUp);
    }

    void free()
    {
        onFree();
    }

    void freeEvents()
    {
        manager.unbindActionFromEvent(EventType.KeyDown, keyDownActionId);
        manager.unbindActionFromEvent(EventType.KeyUp, keyUpActionId);
        manager.unbindActionFromEvent(EventType.MouseButtonDown, mouseButtonDownActionId);
        manager.unbindActionFromEvent(EventType.MouseButtonUp, mouseButtonUpActionId);
    }

    void draw()
    {
        onDraw(manager.deltaTime);
    }

    // Override these:
    void onDraw(double delta) {}
    void onKeyDown() {}
    void onKeyUp() {}
    void onMouseButtonDown() {}
    void onMouseButtonUp() {}
    void onFree() {}
}

class GameRoom
{
    GameLogicManager logic;
    GameObject[] objects;

    this(GameLogicManager logi)
    {
        logic = logi;
    }

    void createEvents()
    {
        foreach(obj; objects)
            obj.createEvents();
    }

    void addObject(GameObject obj)
    {
        objects ~= obj;
    }

    void draw()
    {
        foreach(obj; objects)
            obj.draw();
    }

    void freeEvents()
    {
        foreach(obj; objects)
            if (obj !is null) 
                obj.freeEvents();
    }

    void freeObjects()
    {
        foreach(obj; objects)
            if (obj !is null) 
                obj.free();
        objects = [];
    }

    void load()
    {
        onLoad();
    }

    void onLoad() {}
}

class ExitRoom: GameRoom
{
    this(GameLogicManager logi)
    {
        super(logi);
    }

    override void onLoad()
    {
        logic.appManager.running = false;
    }
}

