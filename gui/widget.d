module gui.widget;

import dlib;
import dgl;

class Widget: EventListener, Drawable
{
    Vector2f position;
    Vector2f scale;
    Widget parentWidget;
    
    this(EventManager emngr, Widget parentWidget)
    {
        super(emngr);
        this.parentWidget = parentWidget;
    }
    
    void onUpdate()
    {
        processEvents();
    }
    
    void onClick(int button)
    {
    }
    
    override void draw(double dt) {}
    override void free() { Delete(this); }
    
    Vector2f sourcePoint()
    {
        return position;
    }
    
    bool mouseInArea(Vector2f pos, Vector2f size)
    {
        return eventManager.mouseX > pos.x &&
               eventManager.windowHeight - eventManager.mouseY > pos.y &&
               eventManager.mouseX < pos.x + size.x &&
               eventManager.windowHeight - eventManager.mouseY < pos.y + size.y;
    }
    
    bool mouseOver()
    {
        if (parentWidget)
            return mouseInArea(parentWidget.sourcePoint() + position, scale);
        else
            return mouseInArea(position, scale);
    }
}