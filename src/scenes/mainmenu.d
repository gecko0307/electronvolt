/*
Copyright (c) 2024-2025 Timur Gafarov

Boost Software License - Version 1.0 - August 17th, 2003
Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/
module scenes.mainmenu;

import std.stdio;
import dagon;
import dagon.ext.imgui;
import audio;

class MainMenuScene: Scene
{
    Game game;
    Camera camera;
    TextureAsset aBg;
    Entity bg;

    this(Game game)
    {
        super(game);
        this.game = game;
    }

    override void beforeLoad()
    {
        aBg = addTextureAsset("assets/ui/bg_planet.jpg");
    }
    
    override void onLoad(Time t, float progress)
    {
    }
    
    override void afterLoad()
    {
        camera = addCamera();
        
        auto hudShader = New!HUDShader(assetManager);
        
        bg = addEntityHUD();
        bg.drawable = New!ShapeQuad(assetManager);
        resizeBg(eventManager.windowWidth, eventManager.windowHeight);
        auto bgMaterial = addMaterial();
        bgMaterial.shader = hudShader;
        bgMaterial.baseColorTexture = aBg.texture;
        bgMaterial.depthWrite = false;
        bgMaterial.useCulling = false;
        bg.material = bgMaterial;
        
        onReset();
    }
    
    override void onReset()
    {
        game.hudRenderer.passHUD.clear = true;
        game.renderer.activeCamera = camera;
        
        playMusic("assets/music/dust.mp3");
    }
    
    override void onUpdate(Time t)
    {
    }
    
    override void onResize(int width, int height)
    {
        if (bg) resizeBg(width, height);
    }
    
    void resizeBg(int width, int height)
    {
        float aspectRatio = cast(float)width / cast(float)height;
        float imageAspectRatio = 16.0f / 9.0f;
        if (aspectRatio > imageAspectRatio)
            bg.scaling = Vector3f(width, width / imageAspectRatio, 1.0f);
        else
            bg.scaling = Vector3f(height * imageAspectRatio, height, 1.0f);
        
        // Centering
        bg.position = Vector3f(cast(float)width * 0.5 - bg.scaling.x * 0.5, cast(float)height * 0.5 - bg.scaling.y * 0.5, 0.0f);
    }
    
    override void onKeyDown(int key) { }
    override void onKeyUp(int key) { }
    override void onMouseButtonDown(int button) { }
    override void onMouseButtonUp(int button) { }
}
