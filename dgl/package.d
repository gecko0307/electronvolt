module dgl;

public
{
    import derelict.opengl.gl;
    import derelict.opengl.glu;
    import derelict.opengl.glext;
    import derelict.sdl.sdl;

    import dgl.core.application;
    import dgl.core.compat;
    import dgl.core.event;
    import dgl.core.interfaces;
    import dgl.core.layer;
    import dgl.core.room;

    import dgl.graphics.arbshader;
    import dgl.graphics.axes;
    import dgl.graphics.billboard;
    import dgl.graphics.camera;
    import dgl.graphics.entity;
    import dgl.graphics.glslshader;
    import dgl.graphics.light;
    import dgl.graphics.lightmanager;
    import dgl.graphics.material;
    import dgl.graphics.mesh;
    import dgl.graphics.object3d;
    import dgl.graphics.scene;
    import dgl.graphics.shader;
    import dgl.graphics.shadow;
    import dgl.graphics.shapes;
    import dgl.graphics.sprite;
    import dgl.graphics.tbcamera;
    import dgl.graphics.texture;
    import dgl.graphics.ubershader;

    import dgl.ui.font;
    import dgl.ui.ftfont;
    import dgl.ui.textline;
    import dgl.ui.textlineinput;

    import dgl.asset.dgl2;
    import dgl.asset.resman;
    import dgl.asset.serialization;

    import dgl.vfs.vfs;
    import dgl.dml.dml;

    import dgl.templates.freeview;
}
