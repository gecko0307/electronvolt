module gui.window;

import dlib;
import dgl;
import gui.widget;
import gui.button;

class MinimizeButton: Button
{
    bool minimized = false;

    this(EventManager emngr, Window parentWindow)
    {
        super(emngr, parentWindow);
    }
    
    override void onClick(int button)
    {
        minimized = !minimized;
        auto win = cast(Window)parentWidget;
        if (win)
            win.minimized = !win.minimized;
    }
    
    override void free()
    {
        Delete(this);
    }
    
    override void draw(double dt)
    {
        super.draw(dt);
        glPushMatrix();
        glTranslatef(position.x + scale.x * 0.25, -(position.y + scale.y * 0.5f - scale.y * 0.05f), 0);
        glScalef(scale.x * 0.5, scale.y * 0.1f, 1);
        glColor4f(0, 0, 0, 1);
        glBegin(GL_QUADS);
        glVertex2f(0,  0);
        glVertex2f(0, -1);
        glVertex2f(1, -1);
        glVertex2f(1,  0);
        glEnd();
        glPopMatrix();
        
        if (!minimized)
            return;
            
        glPushMatrix();
        glTranslatef(position.x + scale.x * 0.5 - scale.x * 0.05f, -(position.y + scale.y * 0.25f), 0);
        glScalef(scale.x * 0.1, scale.y * 0.5f, 1);
        glColor4f(0, 0, 0, 1);
        glBegin(GL_QUADS);
        glVertex2f(0,  0);
        glVertex2f(0, -1);
        glVertex2f(1, -1);
        glVertex2f(1,  0);
        glEnd();
        glPopMatrix();
    }
}

class MaximizeButton: Button
{
    this(EventManager emngr, Window parentWindow)
    {
        super(emngr, parentWindow);
    }
    
    override void onClick(int button)
    {
        auto win = cast(Window)parentWidget;
        if (win)
            win.toggleMaximize();
    }
    
    override void free()
    {
        Delete(this);
    }
    
    override void draw(double dt)
    {
        super.draw(dt);
        glPushMatrix();
        glTranslatef(position.x + scale.x * 0.25, -(position.y + scale.y * 0.25f), 0);
        glScalef(scale.x * 0.5, scale.y * 0.5f, 1);
        glColor4f(0, 0, 0, 1);
        glPolygonMode(GL_FRONT, GL_LINE);
        glLineWidth(scale.x * 0.1f);
        glBegin(GL_QUADS);
        glVertex2f(0,  0);
        glVertex2f(0, -1);
        glVertex2f(1, -1);
        glVertex2f(1,  0);
        glEnd();
        glLineWidth(1);
        glPolygonMode(GL_FRONT, GL_FILL);
        glPopMatrix();
    }
}

class Window: Widget
{
    uint depth = 0;
    Vector2f minScale;
    float titlebarHeight;
    float resizerSize;
    Color4f backgroundColor;
    Color4f borderColor;
    Color4f titlebarColor;
    Color4f titlebarColorB;
    float borderWidth;
    
    bool minimized = false;
    bool maximized = false;
    Vector2f oldScale;
    
    DynamicArray!Widget widgets;
    MinimizeButton minButton;
    MaximizeButton maxButton;
    
    this(EventManager emngr, uint depth, Vector2f pos, Vector2f size)
    {
        super(emngr, null);
        this.depth = depth;
        position = pos;
        scale = size;
        titlebarHeight = 32;
        resizerSize = 20.0f;
        minScale = Vector2f(100, resizerSize * 2);
        backgroundColor = Color4f(0.4, 0.4, 0.4, 1);
        borderColor = Color4f(0.2, 0.2, 0.2, 1);
        titlebarColor = Color4f(0.3, 0.3, 0.3, 1);
        titlebarColorB = Color4f(0.25, 0.25, 0.25, 1);
        borderWidth = 2.0f;
        
        minButton = New!MinimizeButton(emngr, this);
        minButton.position.x = scale.x - 12 - minButton.scale.x - minButton.scale.x;
        minButton.position.y = -titlebarHeight + 6;
        
        maxButton = New!MaximizeButton(emngr, this);
        maxButton.position.x = scale.x - 6 - minButton.scale.x;
        maxButton.position.y = -titlebarHeight + 6;
    }
    
    ~this()
    {
        foreach(w; widgets.data)
            w.free();
        widgets.free();
        minButton.free();
        maxButton.free();
    }
    
    void toggleMaximize()
    {
        if (minimized)
            return;
            
        if (maximized)
        {
            scale = oldScale;
            maximized = false;
        }
        else
        {
            oldScale = scale;
            position = Vector2f(0, 0);
            scale = Vector2f(eventManager.windowWidth, eventManager.windowHeight - titlebarHeight);
            maximized = true;
        }
    }
    
    override void onClick(int button)
    {
        foreach(w; widgets.data)
        {
            if (w.mouseOver)
                w.onClick(button);
        }
        
        if (minButton.mouseOver)
            minButton.onClick(button);
            
        if (maxButton.mouseOver)
            maxButton.onClick(button);
    }
    
    override Vector2f sourcePoint()
    {
        return position + Vector2f(0, titlebarHeight);
    }
    
    void addWidget(Widget w)
    {
        widgets.append(w);
    }
    
    Vector2f resizerPosition()
    {
        return sourcePoint() + scale - resizerSize;
    }
    
    Vector2f lowerRightCorner()
    {
        return sourcePoint() + scale;
    }
    
    override bool mouseOver()
    {
        if (minimized)
            return mouseOverTitlebar();
        else
            return mouseInArea(position, Vector2f(0.0f, titlebarHeight) + scale);
    }
    
    bool mouseOverResizer()
    {
        return !minimized && mouseInArea(resizerPosition(), Vector2f(resizerSize, resizerSize));
    }
    
    bool mouseOverTitlebar()
    {               
        return mouseInArea(position, Vector2f(scale.x, titlebarHeight));
    }
    
    override void onResize(int width, int height)
    {
        if (maximized)
        {
            scale = Vector2f(eventManager.windowWidth, eventManager.windowHeight - titlebarHeight);
        }
    }
    
    override void onUpdate()
    {
        processEvents();
        foreach(w; widgets.data)
            w.onUpdate();
        minButton.onUpdate();
        maxButton.onUpdate();
    }

    override void draw(double dt)
    {
        minButton.position.x = scale.x - (6-borderWidth) - 6 - minButton.scale.x - minButton.scale.x;
        minButton.position.y = -titlebarHeight + 6;
        
        maxButton.position.x = scale.x - (6-borderWidth) - minButton.scale.x;
        maxButton.position.y = -titlebarHeight + 6;
        
        glPushMatrix();
        glTranslatef(position.x, eventManager.windowHeight - position.y, 0);
        
        // Draw border
        glPushMatrix();
        glTranslatef(-borderWidth, borderWidth, 0);
        if (minimized)
            glScalef(scale.x + borderWidth * 2 , titlebarHeight + borderWidth * 2, 1);
        else
            glScalef(scale.x + borderWidth * 2, scale.y + titlebarHeight + borderWidth * 2, 1);
        glColor4fv(borderColor.arrayof.ptr);
        //glPolygonMode(GL_FRONT, GL_LINE);
        glBegin(GL_QUADS);
        glVertex2f(0, 0);
        glVertex2f(0, -1);
        glVertex2f(1, -1);
        glVertex2f(1, 0);
        glEnd();
        //glPolygonMode(GL_FRONT, GL_FILL);
        glPopMatrix();
        
        if (!minimized)
        {
            // Draw window background
            glPushMatrix();
            //glTranslatef(position.x, eventManager.windowHeight - position.y, 0);
            glScalef(scale.x, scale.y + titlebarHeight, 1);
            glColor4fv(backgroundColor.arrayof.ptr);
            glBegin(GL_QUADS);
            glVertex2f(0, 0);
            glVertex2f(0, -1);
            glVertex2f(1, -1);
            glVertex2f(1, 0);
            glEnd();
            glPopMatrix();
            
            glPushMatrix();
            glTranslatef(0, -titlebarHeight, 0);
            foreach(w; widgets.data)
                w.draw(dt);
            glPopMatrix();
            
            // Draw resizer triangle
            if (!maximized)
            {
            glPushMatrix();
            glTranslatef(scale.x, -(titlebarHeight + scale.y), 0);
            glColor4fv(borderColor.arrayof.ptr);
            glBegin(GL_LINES);
            glVertex2f(0, resizerSize);
            glVertex2f(-resizerSize, 0);
            glEnd();
            glBegin(GL_LINES);
            glVertex2f(0, resizerSize * 0.75);
            glVertex2f(-resizerSize * 0.75, 0);
            glEnd();
            glScalef(resizerSize * 0.5, resizerSize * 0.5, 1);
            glBegin(GL_TRIANGLES);
            glVertex2f(0, 1);
            glVertex2f(-1, 0);
            glVertex2f(0, 0);
            glEnd();
            glPopMatrix();
            }
        }
        
        // Draw titlebar
        glPushMatrix();
        //glTranslatef(position.x, eventManager.windowHeight - position.y, 0);
        glScalef(scale.x, titlebarHeight, 1);
        //glColor4fv(titlebarColor.arrayof.ptr);
        glBegin(GL_QUADS);
        glColor4fv(titlebarColor.arrayof.ptr);  glVertex2f(0,  0);
        glColor4fv(titlebarColorB.arrayof.ptr); glVertex2f(0, -1);
        glColor4fv(titlebarColorB.arrayof.ptr); glVertex2f(1, -1);
        glColor4fv(titlebarColor.arrayof.ptr);  glVertex2f(1,  0);
        glEnd();
        glPopMatrix();
        
        // Draw titlebar buttons
        glPushMatrix();
        glTranslatef(0, -titlebarHeight, 0);
        glScalef(1, 1, 1);
        minButton.draw(dt);
        maxButton.draw(dt);
        glPopMatrix();
        
        glPopMatrix();
    }
    
    override void free()
    {
        Delete(this);
    }
}

class WindowManager: EventListener, Drawable
{
    DynamicArray!Window windows;
    uint maxWindowDepth = 0;
    
    this(EventManager emgr)
    {
        super(emgr);
    }
    
    Window addWindow(Vector2f pos, Vector2f size)
    {
        Window w = New!Window(eventManager, maxWindowDepth, pos, size);
        windows.append(w);
        maxWindowDepth++;
        return w;
    }
    
    ~this()
    {
        foreach(w; windows.data)
            w.free();
        windows.free();
    }
    
    override void free()
    {
        Delete(this);
    }
    
    Window pickedWindow;
    bool drag = false;
    int borderIndex;
    Vector2f posDiff;
    Vector2f initialResizePosDiff;
    
    Vector2f mousePosition()
    {
        return Vector2f(eventManager.mouseX, eventManager.windowHeight - eventManager.mouseY);
    }
    
    override void onMouseButtonDown(int button)
    {
        if (button == SDL_BUTTON_LEFT ||
            button == SDL_BUTTON_RIGHT ||
            button == SDL_BUTTON_MIDDLE)
        {
            pickWindow();
        }
        
        if (pickedWindow)
        {
            pickedWindow.onClick(button);
       
            pickedWindow.depth = maxWindowDepth++;
            sortWindowsByDepth();
            
            if (button == SDL_BUTTON_LEFT)
            {
                if (pickedWindow.mouseOverResizer && !pickedWindow.maximized)
                    drag = false;
                else if (pickedWindow.mouseOverTitlebar && !pickedWindow.maximized)
                    drag = true;
                else
                    pickedWindow = null;
            }
        }
    }
    
    override void onMouseButtonUp(int button)
    {
        if (button == SDL_BUTTON_LEFT)
        {
            pickedWindow = null;
        }
    }
    
    void onUpdate()
    {
        processEvents();
        foreach(w; windows.data)
            w.onUpdate();
    }
    
    override void draw(double dt)
    {
        if (pickedWindow)
        {
            if (eventManager.mouseButtonPressed[SDL_BUTTON_LEFT])
            {
                if (drag)
                    pickedWindow.position = mousePosition() + posDiff;
                else
                {
                    Vector2f newScale = 
                        mousePosition() + initialResizePosDiff - 
                        pickedWindow.position - Vector2f(0, pickedWindow.titlebarHeight);
                    if (newScale.x >= pickedWindow.minScale.x)
                        pickedWindow.scale.x = newScale.x;
                    if (newScale.y >= pickedWindow.minScale.y)
                        pickedWindow.scale.y = newScale.y;
                }
            }
        }

        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        glOrtho(0, eventManager.windowWidth, 0, eventManager.windowHeight, 0, 1);
        glMatrixMode(GL_MODELVIEW);
        
        glLoadIdentity();
        foreach(w; windows.data)
        {
            glDisable(GL_DEPTH_TEST);
            w.draw(dt);
        }
    }
    
    void pickWindow()
    {
        foreach_reverse(w; windows.data)
        {
            if (w.mouseOver)
            {
                pickedWindow = w;
                posDiff = pickedWindow.position - mousePosition();
                initialResizePosDiff = pickedWindow.lowerRightCorner() - mousePosition();
                break;
            }
        }
    }
    
    void sortWindowsByDepth()
    {
        size_t j = 0;
        Window tmp;

        auto wdata = windows.data;

        foreach(i, v; wdata)
        {
            j = i;
            size_t k = i;

            while (k < wdata.length)
            {
                float b1 = wdata[j].depth;
                float b2 = wdata[k].depth;
                if (b2 < b1)
                    j = k;
                k++;
            }

            tmp = wdata[i];
            wdata[i] = wdata[j];
            wdata[j] = tmp;
        }
    }
}
