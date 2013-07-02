bl_info = {
    "name": "Texture Atlas",
    "author": "Andreas Esau, Paul Geraskin",
    "version": (0, 15),
    "blender": (2, 6, 5),
    "location": "Properties > Render",
    "description": "A simple Texture Atlas for baking of many objects. It creates additional UV",
    "wiki_url": "http://code.google.com/p/blender-addons-by-mifth/",
    "tracker_url": "http://code.google.com/p/blender-addons-by-mifth/issues/list",
    "category": "UV"}

import bpy
from bpy.props import StringProperty, BoolProperty, EnumProperty, IntProperty, FloatProperty
import mathutils

class TextureAtlas(bpy.types.Panel):
    bl_label = "TextureAtlas - Lightbaker"
    bl_space_type = 'PROPERTIES'
    bl_region_type = 'WINDOW'
    bl_context = "render"
    COMPAT_ENGINES = {'BLENDER_RENDER'}
    
    def draw(self, context):
        col = self.layout.column()
        row = self.layout.row()
        split = self.layout.split()
        ob = context.object
        scene = context.scene
        row.template_list(scene, "ms_lightmap_groups", scene, "ms_lightmap_groups_index",prop_list="template_list_controls", rows=2)
        col = row.column(align=True)
        col.operator("scene.ms_add_lightmap_group", icon='ZOOMIN', text="")
        col.operator("scene.ms_del_lightmap_group", icon='ZOOMOUT', text="")
        
        row = self.layout.row(align=True)
        
        try:

            row.prop(context.scene.ms_lightmap_groups[context.scene.ms_lightmap_groups_index], 'resolution', text='Resolution',expand=True)
            row = self.layout.row()
            row.prop(context.scene.ms_lightmap_groups[context.scene.ms_lightmap_groups_index], 'unwrap_type', text='Lightmap',expand=True)
            row = self.layout.row()            
      
        except:
            pass    
        
        row = self.layout.row()
        row = self.layout.row()
        row.operator("scene.ms_add_selected_to_group", text="Add Selection To Current Group",icon="GROUP")
        row.operator("scene.ms_select_group", text="Select Current Group",icon="GROUP")
        row.operator("scene.ms_remove_selected", text="Remove Selected Group and UVs",icon="GROUP")        
        
        row = self.layout.row()
        row.operator("object.ms_auto",text="Auto Unwrap",icon="LAMP_SPOT")        
        row = self.layout.row()        
        row.operator("object.ms_run",text="Start Manual Unwrap/Bake",icon="LAMP_SPOT")
        row.operator("object.ms_run_remove",text="Finsh Manual Unwrap/Bake",icon="LAMP_SPOT")

        
        
class runAuto(bpy.types.Operator):
    bl_idname = "object.ms_auto"
    bl_label = "Auto Unwrapping"
    bl_description = "Auto Unwrapping"
    
    def execute(self, context):
        old_context = bpy.context.area.type

        try:
            group = bpy.context.scene.ms_lightmap_groups[bpy.context.scene.ms_lightmap_groups_index]
            bpy.context.area.type = 'VIEW_3D'
    
            if group.bake == True and len(bpy.data.groups[group.name].objects) > 0:

                 res = int(bpy.context.scene.ms_lightmap_groups[group.name].resolution)
                 bpy.ops.object.ms_create_lightmap(group_name=group.name, resolution=res)  
                 bpy.ops.object.ms_merge_objects(group_name=group.name, unwrap=True)
                 bpy.ops.object.ms_separate_objects(group_name=group.name) 
                 
            bpy.context.area.type = old_context

        except:
            self.report({'INFO'}, "Something went wrong!") 
            bpy.context.area.type = old_context  
        return{'FINISHED'}   
        
        
class runStart(bpy.types.Operator):
    bl_idname = "object.ms_run"
    bl_label = "Make Manual Unwrapping Object"
    bl_description = "Makes Manual Unwrapping Object"
    
    def execute(self, context):
        old_context = bpy.context.area.type

        try:
            group = bpy.context.scene.ms_lightmap_groups[bpy.context.scene.ms_lightmap_groups_index]
            bpy.context.area.type = 'VIEW_3D'
    
            if group.bake == True and len(bpy.data.groups[group.name].objects) > 0:

                 res = int(bpy.context.scene.ms_lightmap_groups[group.name].resolution)
                 bpy.ops.object.ms_create_lightmap(group_name=group.name, resolution=res)  
                    
                 bpy.ops.object.ms_merge_objects(group_name=group.name, unwrap=False)

            bpy.context.area.type = old_context

        except:
             self.report({'INFO'}, "Something went wrong!") 
             bpy.context.area.type = old_context  
        return{'FINISHED'}
    

class runFinish(bpy.types.Operator):
    bl_idname = "object.ms_run_remove"
    bl_label = "Remove Manual Unwrapping Object"
    bl_description = "Removes Manual Unwrapping Object"
    
    def execute(self, context):
        old_context = bpy.context.area.type

        try:
            group = bpy.context.scene.ms_lightmap_groups[bpy.context.scene.ms_lightmap_groups_index]
            bpy.context.area.type = 'VIEW_3D'
    
            if group.bake == True and len(bpy.data.groups[group.name].objects) > 0:

                 bpy.ops.object.ms_separate_objects(group_name=group.name) 
                      
            bpy.context.area.type = old_context
            #bpy.ops.object.select_all(action='DESELECT')

        except:
             self.report({'INFO'}, "Something went wrong!") 
             bpy.context.area.type = old_context  
        return{'FINISHED'}
        
    
class uv_layers(bpy.types.PropertyGroup):
    name = bpy.props.StringProperty(default="")

   
class vertex_groups(bpy.types.PropertyGroup):
    name = bpy.props.StringProperty(default="") 
    
class groups(bpy.types.PropertyGroup):
    name = bpy.props.StringProperty(default="") 

class ms_lightmap_groups(bpy.types.PropertyGroup):
    
    #def update(self,context):
        #for object in bpy.data.groups[self.name].objects:
            #for material in object.data.materials:
                #material.texture_slots[self.name].use = self.bake
    
    name = bpy.props.StringProperty(default="")
    bake = bpy.props.BoolProperty(default=True)
    #bake = bpy.props.BoolProperty(default=True, update=update)

    unwrap_type = EnumProperty(name="unwrap_type",items=(('0','Smart_Unwrap', 'Smart_Unwrap'),('1','Lightmap', 'Lightmap'), ('2','No_Unwrap', 'No_Unwrap')))
    resolution = EnumProperty(name="resolution",items=(('256','256','256'),('512','512','512'),('1024','1024','1024'),('2048','2048','2048'),('4096','4096','4096')))
    template_list_controls = StringProperty(default="bake", options={"HIDDEN"})
    
    

class mergedObjects(bpy.types.PropertyGroup):
    name = bpy.props.StringProperty(default="")
    vertex_groups = bpy.props.CollectionProperty(type=vertex_groups)
    groups = bpy.props.CollectionProperty(type=groups)
    uv_layers = bpy.props.CollectionProperty(type=uv_layers)
    

class addSelectedToGroup(bpy.types.Operator):
    bl_idname = "scene.ms_add_selected_to_group" 
    bl_label = ""
    bl_description = "Adds selected Objects to current Group"
    
    
    def execute(self, context):
        try:
            group_name = bpy.context.scene.ms_lightmap_groups[bpy.context.scene.ms_lightmap_groups_index].name
        except:
            self.report({'INFO'}, "No Groups Exists!")
            
        for object in bpy.context.selected_objects:
            if object.type == 'MESH':
                try:
                    bpy.data.groups[group_name].objects.link(object)
                except:
                    pass
                    
        return {'FINISHED'}

class selectGroup(bpy.types.Operator):
    bl_idname = "scene.ms_select_group" 
    bl_label = ""
    bl_description = "Selected Objects of current Group"
    
    
    def execute(self, context):
        try:
            group_name = bpy.context.scene.ms_lightmap_groups[bpy.context.scene.ms_lightmap_groups_index].name
        except:
            self.report({'INFO'}, "No Groups Exists!")

        try:
            bpy.ops.object.select_all(action='DESELECT')
            for object in bpy.data.groups[group_name].objects:
                  object.select = True 
        except:
            pass
                    
        return {'FINISHED'}    
        
        
class removeFromGroup(bpy.types.Operator):
    bl_idname = "scene.ms_remove_selected" 
    bl_label = ""
    bl_description = "Remove Selected Group and UVs"
    
    ### removeUV method
    def removeUV(self, mesh, name):
             for uv in mesh.data.uv_textures:
                   if uv.name == name:
                        uv.active = True
                        bpy.ops.mesh.uv_texture_remove()
                        
        
        #remove all modifiers
        #for m in mesh.modifiers:
            #bpy.ops.object.modifier_remove(modifier=m.name)
            
    
    def execute(self, context):
        ### set 3dView context
        old_context = bpy.context.area.type        
        bpy.context.area.type = 'VIEW_3D'
        
        for group in bpy.context.scene.ms_lightmap_groups:        
            group_name = group.name

            for object in bpy.context.selected_objects:
                  bpy.context.scene.objects.active = object
        
                  if object.type == 'MESH' and bpy.data.groups[group_name] in object.users_group:

                         ### remove UV has crash
                         self.removeUV(object, group_name)

                         #### remove from group
                         bpy.data.groups[group_name].objects.unlink(object)
                         object.hide_render = False

                         
        bpy.context.area.type = old_context
        return {'FINISHED'}          
        
        
class addLightmapGroup(bpy.types.Operator):
    bl_idname = "scene.ms_add_lightmap_group" 
    bl_label = ""
    bl_description = "Adds a new Lightmap Group"
    
    name = StringProperty(name="Group Name",default='lightmap') 

    def execute(self, context):
        group = bpy.data.groups.new(self.name)
        
        item = bpy.context.scene.ms_lightmap_groups.add() 
        item.name = group.name
        item.resolution = '1024'
        bpy.context.scene.ms_lightmap_groups_index = len(bpy.context.scene.ms_lightmap_groups)-1
        
        if len(bpy.context.selected_objects) > 0:
             for object in bpy.context.selected_objects:
                 bpy.context.scene.objects.active = object
                 if bpy.context.active_object.type == 'MESH':
                     bpy.data.groups[group.name].objects.link(object)

        
        return {'FINISHED'}
    
    def invoke(self, context, event): 
        wm = context.window_manager 
        return wm.invoke_props_dialog(self) 
    
class delLightmapGroup(bpy.types.Operator):
    bl_idname = "scene.ms_del_lightmap_group" 
    bl_label = ""
    bl_description = "Deletes active Lightmap Group"
    

    def execute(self, context):
        idx = bpy.context.scene.ms_lightmap_groups_index
        group_name = bpy.context.scene.ms_lightmap_groups[idx].name
        
        for obj in bpy.data.groups[group_name].objects:
             obj.hide_render = False
        
        bpy.data.groups.remove(bpy.data.groups[bpy.context.scene.ms_lightmap_groups[idx].name])
        bpy.context.scene.ms_lightmap_groups.remove(bpy.context.scene.ms_lightmap_groups_index)
        bpy.context.scene.ms_lightmap_groups_index -= 1
        if bpy.context.scene.ms_lightmap_groups_index < 0:
              bpy.context.scene.ms_lightmap_groups_index = 0
        
        return {'FINISHED'}

        
class createLightmap(bpy.types.Operator):
    bl_idname = "object.ms_create_lightmap" 
    bl_label = "TextureAtlas - Generate Lightmap"
    bl_description = "Generates a Lightmap"
    
    group_name = StringProperty(default='')
    resolution = IntProperty(default=1024)
    
    def execute(self, context):  
        
      ### create lightmap uv layout
      
      
      for object in bpy.data.groups[self.group_name].objects:  
          bpy.ops.object.select_all(action='DESELECT')
          object.select = True
          bpy.context.scene.objects.active = object
          bpy.ops.object.mode_set(mode = 'EDIT')
          
        
          if bpy.context.object.data.uv_textures.active == None:
              bpy.ops.mesh.uv_texture_add()
              bpy.context.object.data.uv_textures.active.name = self.group_name
          else:    
              if self.group_name not in bpy.context.object.data.uv_textures:
                  bpy.ops.mesh.uv_texture_add()
                  bpy.context.object.data.uv_textures.active.name = self.group_name
                  bpy.context.object.data.uv_textures[self.group_name].active = True
                  bpy.context.object.data.uv_textures[self.group_name].active_render = True
              else:
                  bpy.context.object.data.uv_textures[self.group_name].active = True
                  bpy.context.object.data.uv_textures[self.group_name].active_render = True
        
          bpy.ops.mesh.select_all(action='SELECT')
        
          ### set Image  
          bpy.ops.object.mode_set(mode = 'EDIT')
          bpy.ops.mesh.select_all(action='SELECT')
          if self.group_name not in bpy.data.images:
              bpy.ops.image.new(name=self.group_name,width=self.resolution,height=self.resolution)
              bpy.ops.object.mode_set(mode = 'EDIT')
              bpy.data.screens['UV Editing'].areas[1].spaces[0].image = bpy.data.images[self.group_name]
          else:
              bpy.ops.object.mode_set(mode = 'EDIT')
              bpy.data.screens['UV Editing'].areas[1].spaces[0].image = bpy.data.images[self.group_name]
              bpy.data.images[self.group_name].generated_type = 'COLOR_GRID'
              bpy.data.images[self.group_name].generated_width = self.resolution
              bpy.data.images[self.group_name].generated_height = self.resolution
            
            
          bpy.ops.object.mode_set(mode = 'OBJECT')
      return{'FINISHED'}        
        
        
class mergeObjects(bpy.types.Operator):
    bl_idname = "object.ms_merge_objects" 
    bl_label = "TextureAtlas - MergeObjects"
    bl_description = "Merges Objects and stores Origins"
    
    group_name = StringProperty(default='')
    unwrap = BoolProperty(default=False)
    
    def execute(self, context):
      
        #objToDelete = None
        bpy.ops.object.select_all(action='DESELECT')
        for obj in bpy.context.scene.objects:
             if obj.name == self.group_name + "_mergedObject":
                  obj.select = True
                  bpy.context.scene.objects.active = obj
                  bpy.ops.object.delete(use_global=False)        


  
        
        me = bpy.data.meshes.new(self.group_name + '_mergedObject')
        ob_merge = bpy.data.objects.new(self.group_name + '_mergedObject', me)
        ob_merge.location = bpy.context.scene.cursor_location   # position object at 3d-cursor
        bpy.context.scene.objects.link(ob_merge)                # Link object to scene
        me.update()
        ob_merge.select = False      
      
        active_object = bpy.data.groups[self.group_name].objects[0]
        bpy.ops.object.select_all(action='DESELECT')
        
        OBJECTLIST = []
        for object in bpy.data.groups[self.group_name].objects:
            OBJECTLIST.append(object)   
            object.select = True   
        bpy.context.scene.objects.active = active_object      

        
        ### Make Object Single User
        #bpy.ops.object.make_single_user(type='SELECTED_OBJECTS', object=True, obdata=True, material=False, texture=False, animation=False)

        for object in OBJECTLIST:
            
            bpy.ops.object.select_all(action='DESELECT')
            object.select = True
            
            ### activate lightmap uv if existant
            for uv in object.data.uv_textures:
                if uv.name == self.group_name:
                    uv.active = True
                    bpy.context.scene.objects.active = object

                    
            ### generate temp Duplicate Objects with copied modifier,properties and logic bricks
            bpy.ops.object.select_all(action='DESELECT')
            object.select = True
            bpy.context.scene.objects.active = object
            bpy.ops.object.duplicate(linked=False, mode='TRANSLATION')
            active_object = bpy.context.scene.objects.active
            active_object.select = True

            ### hide render of original mesh
            object.hide_render = True
            object.hide = True
            object.select = False

            ### delete vertex groups of the object
            for group in active_object.vertex_groups:
                id = bpy.context.active_object.vertex_groups[group.name]
                bpy.context.active_object.vertex_groups.remove(id)               
                
            ### remove unused UV
            bpy.ops.object.mode_set(mode = 'EDIT')
            for uv in active_object.data.uv_textures:
                if uv.name != self.group_name:
                    uv.active = True
                    bpy.ops.mesh.uv_texture_remove()
            bpy.ops.object.mode_set(mode = 'OBJECT')
            
            ### create vertex groups for each selected object
            bpy.context.scene.objects.active = bpy.data.objects[active_object.name]
            bpy.ops.object.mode_set(mode = 'EDIT')
            bpy.ops.mesh.select_all(action='SELECT')
            bpy.ops.object.vertex_group_add()
            bpy.ops.object.vertex_group_assign()
            id = len(bpy.context.object.vertex_groups)-1
            bpy.context.active_object.vertex_groups[id].name = object.name
            bpy.ops.mesh.select_all(action='DESELECT')
            bpy.ops.object.mode_set(mode = 'OBJECT')
            
            
            ### save object name and object location in merged object
            item = ob_merge.ms_merged_objects.add()
            item.name = object.name
            #item.scale = mathutils.Vector(object.scale)
            #item.rotation = mathutils.Vector(object.rotation_euler)
            

            ### merge objects together
            bpy.ops.object.select_all(action='DESELECT')
            active_object.select = True
            ob_merge.select = True
            bpy.context.scene.objects.active = ob_merge
            bpy.ops.object.join()

        ### make Unwrap    
        bpy.ops.object.select_all(action='DESELECT')        
        ob_merge.select = True
        bpy.context.scene.objects.active = ob_merge
        bpy.ops.object.mode_set(mode = 'EDIT')        
        bpy.ops.mesh.select_all(action='SELECT')
        
        if self.unwrap == True and bpy.context.scene.ms_lightmap_groups[self.group_name].unwrap_type == '0':
               bpy.ops.uv.smart_project(angle_limit=72.0, island_margin=0.2, user_area_weight=0.0)
        elif self.unwrap == True and bpy.context.scene.ms_lightmap_groups[self.group_name].unwrap_type == '1':
               bpy.ops.uv.lightmap_pack(PREF_CONTEXT='ALL_FACES', PREF_PACK_IN_ONE=True, PREF_NEW_UVLAYER=False, PREF_APPLY_IMAGE=False, PREF_IMG_PX_SIZE=1024, PREF_BOX_DIV=48, PREF_MARGIN_DIV=0.2)        
        bpy.ops.object.mode_set(mode = 'OBJECT')    
        
        ### remove all materials
        for material in ob_merge.material_slots:
             bpy.ops.object.material_slot_remove()  
             
        return{'FINISHED'}

        
class separateObjects(bpy.types.Operator):
    bl_idname = "object.ms_separate_objects" 
    bl_label = "TextureAtlas - Separate Objects"
    bl_description = "Separates Objects and restores Origin"
    
    group_name = StringProperty(default='')

    def execute(self, context):
        for obj in bpy.context.scene.objects:
             if obj.name == self.group_name + "_mergedObject":
  
                bpy.ops.object.mode_set(mode = 'OBJECT')
                bpy.ops.object.select_all(action='DESELECT')
                ob_merged = obj
                ob_merged.select = True
                groupSeparate = bpy.data.groups.new(ob_merged.name)
                bpy.data.groups[groupSeparate.name].objects.link(ob_merged)
                ob_merged.select = False

                OBJECTLIST = []
                for object in ob_merged.ms_merged_objects:
                      OBJECTLIST.append(object.name)
                      ### select vertex groups and separate group from merged object
                      bpy.ops.object.select_all(action='DESELECT')
                      ob_merged.select = True
                      bpy.context.scene.objects.active = ob_merged
                      #bpy.context.scene.objects[object.name]
                      #bpy.context.scene.objects.active
                      bpy.ops.object.mode_set(mode = 'EDIT')
                      bpy.ops.mesh.select_all(action='DESELECT')
                      bpy.context.active_object.vertex_groups.active_index = bpy.context.active_object.vertex_groups[object.name].index            
                      bpy.ops.object.vertex_group_select()
                      bpy.ops.mesh.separate(type='SELECTED')
                      bpy.ops.object.mode_set(mode = 'OBJECT')
                      #bpy.context.scene.objects.active.select = False
            
                      ### copy UVs
                      ob_separeted = None
                      for obj in groupSeparate.objects:
                           if obj != ob_merged:
                               ob_separeted = obj
                               
                      ob_merged.select = False
                      #ob_separeted = bpy.context.selected_objects[0]
                      ob_original = bpy.context.scene.objects[object.name]
                      ob_original.hide = False
                      ob_original.select = True
                      bpy.context.scene.objects.active = ob_separeted
                      bpy.ops.object.join_uvs()

                      ### unhide render of original mesh
                      ob_original.hide_render = False                      
                      
                      ### delete separeted object
                      bpy.ops.object.select_all(action='DESELECT')
                      ob_separeted.select = True
                      bpy.ops.object.delete(use_global=False)
        
                ### delete duplicated object
                bpy.ops.object.select_all(action='DESELECT')
                ob_merged.select = True
                bpy.ops.object.delete(use_global=False)
        
            
        return{'FINISHED'}



def register():
    bpy.utils.register_class(TextureAtlas)
    
    bpy.utils.register_class(addLightmapGroup)
    bpy.utils.register_class(delLightmapGroup)
    bpy.utils.register_class(addSelectedToGroup)
    bpy.utils.register_class(selectGroup)
    bpy.utils.register_class(removeFromGroup)
    
    bpy.utils.register_class(runAuto)
    bpy.utils.register_class(runStart)
    bpy.utils.register_class(runFinish)
    bpy.utils.register_class(mergeObjects)
    bpy.utils.register_class(separateObjects)
    bpy.utils.register_class(createLightmap)

    bpy.utils.register_class(uv_layers)
    bpy.utils.register_class(vertex_groups)
    bpy.utils.register_class(groups)
    
    bpy.utils.register_class(mergedObjects)
    bpy.types.Object.ms_merged_objects = bpy.props.CollectionProperty(type=mergedObjects)
    
    bpy.utils.register_class(ms_lightmap_groups)
    bpy.types.Scene.ms_lightmap_groups = bpy.props.CollectionProperty(type=ms_lightmap_groups)
    bpy.types.Scene.ms_lightmap_groups_index = bpy.props.IntProperty()
    


def unregister():
    bpy.utils.unregister_class(TextureAtlas)
    
    bpy.utils.unregister_class(addLightmapGroup)
    bpy.utils.unregister_class(delLightmapGroup)
    bpy.utils.unregister_class(addSelectedToGroup)
    bpy.utils.unregister_class(selectGroup)
    bpy.utils.unregister_class(removeFromGroup)
    
    bpy.utils.unregister_class(runAuto)
    bpy.utils.unregister_class(runStart)
    bpy.utils.unregister_class(runFinish)
    bpy.utils.unregister_class(mergeObjects)
    bpy.utils.unregister_class(separateObjects)
    bpy.utils.unregister_class(createLightmap)
    
    bpy.utils.unregister_class(uv_layers)
    bpy.utils.unregister_class(vertex_groups)
    bpy.utils.unregister_class(groups)
    
    bpy.utils.unregister_class(mergedObjects)
    
    bpy.utils.unregister_class(ms_lightmap_groups)
    
    
if __name__ == "__main__":
    register()