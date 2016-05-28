bl_info = {
    "name": "Level Design Tools",
    "author": "Timur Gafarov (Gecko)",
    "version": (1, 1),
    "blender": (2, 6, 4),
    "location": "Render",
    "description": "Tools for level design",
    "warning": "",
    "wiki_url": "",
    "tracker_url": "",
    "category": "Import-Export"}

import os
import bpy

class OpBakingModeOn(bpy.types.Operator):  
    bl_idname = "scene.baking_mode_on"  
    bl_label = "Light Baking Mode On"
    def execute(self, context):
        for obj in bpy.context.selected_objects:
            if obj.type == 'MESH':
                uvMaps = obj.data.uv_textures
                if len(uvMaps) > 1:
                    # assume second UV map as lightmap
                    obj.data.uv_textures.active = uvMaps[1]
            for matSlot in obj.material_slots:
                mat = matSlot.material
                mat.use_shadeless = False
                for texSlot in mat.texture_slots:
                    if not texSlot is None:
                        texSlot.use = False
        return {'FINISHED'}

class OpBakingModeOff(bpy.types.Operator):  
    bl_idname = "scene.baking_mode_off"  
    bl_label = "Light Baking Mode Off"
    def execute(self, context):  
        for obj in bpy.context.selected_objects:
            if obj.type == 'MESH':
                uvMaps = obj.data.uv_textures
                if len(uvMaps) > 1:
                    # assume first UV map as diffuse map
                    obj.data.uv_textures.active = uvMaps[0]
            for matSlot in obj.material_slots:
                mat = matSlot.material
                mat.use_shadeless = True
                for texSlot in mat.texture_slots:
                    if not texSlot is None:
                        texSlot.use = True
        return {'FINISHED'}

class LevelDesignToolsPanel(bpy.types.Panel):
    bl_label = "Level Design Tools"
    bl_space_type = "PROPERTIES"
    bl_region_type = "WINDOW"
    bl_context = "render"
    def draw(self, context):
        col = self.layout.column()
        row = self.layout.row()
        col = row.column(align=True)
        col.operator("scene.baking_mode_on", icon='MATERIAL', text="Baking On (Lightmapping mode)")
        col.operator("scene.baking_mode_off", icon='MATERIAL', text="Baking Off (Export mode)")

def register():
    bpy.utils.register_module(__name__)

def unregister():
    bpy.utils.unregister_class(AtriumPanel)
    bpy.utils.unregister_class(OpBakingModeOn)
    bpy.utils.unregister_class(OpBakingModeOff)
    bpy.utils.unregister_module(__name__)

if __name__ == "__main__":
    register()
