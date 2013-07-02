bl_info = {
    "name": "Atrium Content Creation Tools",
    "author": "Timur Gafarov (Gecko)",
    "version": (1, 1),
    "blender": (2, 6, 4),
    "location": "File > Export > Atrium Data File (.dat)",
    "description": "Tools to create and export Atrium content",
    "warning": "",
    "wiki_url": "",
    "tracker_url": "",
    "category": "Import-Export"}

import os
import struct
import mathutils
from math import pi, radians, sqrt
import bpy
from bpy.props import StringProperty
from bpy_extras.io_utils import ExportHelper

def enum(**enums):
    return type('Enum', (), enums)

ChunkType = enum(
    HEADER = 0, 
    END = 1,
    META = 2,
    TRIMESH = 3,
    ENTITY = 4,
    TRIGGER = 5,
    MATERIAL = 6,
    SPAWNPOS = 7,
    COLLECTIBLE = 8,
    ORB = 9
)

def packChunk(chunkType, chunkName = '', chunkData = []):
    buf = struct.pack('<H', chunkType)
    buf = buf + struct.pack('<H', len(chunkName))
    buf = buf + struct.pack('<I', len(chunkData))
    buf = buf + bytearray(chunkName.encode('ascii'))
    buf = buf + bytearray(chunkData)
    return buf

def packVector3f(v):
    return struct.pack('<fff', v[0], v[1], v[2])

def packVector2f(v):
    return struct.pack('<ff', v[0], v[1])

def packTriangle(
   matIndex, 
   va, vb, vc,
   na, nb, nc, 
   uv1a, uv1b, uv1c, 
   uv2a, uv2b, uv2c):
    buf = struct.pack('<i', matIndex)
    buf = buf + packVector3f(va) + packVector3f(vb) + packVector3f(vc)
    buf = buf + packVector3f(na) + packVector3f(nb) + packVector3f(nc)
    buf = buf + packVector2f(uv1a) + packVector2f(uv1b) + packVector2f(uv1c)
    buf = buf + packVector2f(uv2a) + packVector2f(uv2b) + packVector2f(uv2c)
    return buf

def degToRad(angle):
    return (angle / 180.0) * pi;

def radToDeg(angle):
    return (angle / pi) * 180.0;

def vectorRadToDeg(vec):
    return (radToDeg(vec[0]), radToDeg(vec[1]), radToDeg(vec[2]))

def doExport(context, filepath=""):
    print("Exporting selected objects as Atrium Data File...")
    bpy.ops.object.mode_set(mode = 'OBJECT')

    materials = {'Material':-1}
    maxMatIndex = -1

    objects = bpy.data.objects #context.selected_objects
    if not objects:
        raise Exception("scene is empty")

    matrix_rotX = mathutils.Matrix.Rotation(-pi/2, 4, 'X')

    f = open(filepath, 'wb')
    f.write(packChunk(ChunkType.HEADER, context.scene.name))

    for obj in objects:
        print("Processing object " + obj.name)
        obj_matrix = obj.matrix_world.copy()

        if (obj.type == 'EMPTY' and obj['AType'] == 'spawnpos'):
            spawnposData = bytearray()

            mat = matrix_rotX * obj_matrix;

            position = mat.translation
            spawnposData = spawnposData + packVector3f(position)

            rotation = vectorRadToDeg(obj_matrix.to_quaternion().to_euler())
            rotation = (rotation[0], rotation[2], rotation[1])
            spawnposData = spawnposData + packVector3f(rotation)

            f.write(packChunk(ChunkType.SPAWNPOS, obj.name, spawnposData))

        if (obj.type == 'EMPTY' and obj['AType'] == 'collectible'):
            collectibleData = bytearray()

            collectibleType = 0
            if 'ACollectibleType' in obj:
                collectibleType = obj['ACollectibleType']
            collectibleData = collectibleData + struct.pack('<H', collectibleType)

            mat = matrix_rotX * obj_matrix;
            position = mat.translation
            collectibleData = collectibleData + packVector3f(position)

            f.write(packChunk(ChunkType.COLLECTIBLE, "", collectibleData))

        if (obj.type == 'EMPTY' and obj['AType'] == 'orb'):
            orbData = bytearray()

            orbType = 0
            if 'AOrbType' in obj:
                orbType = obj['AOrbType']
            orbData = orbData + struct.pack('<H', orbType)

            mat = matrix_rotX * obj_matrix;
            position = mat.translation
            orbData = orbData + packVector3f(position)

            f.write(packChunk(ChunkType.ORB, "", orbData))

        elif ((obj.type == 'MESH') and (len(obj.data.vertices.values()) > 0)):

            bpy.context.scene.objects.active = obj
            bpy.ops.object.mode_set(mode='EDIT')
            bpy.ops.mesh.select_all(action='SELECT')
            bpy.ops.mesh.quads_convert_to_tris()
            bpy.context.scene.update()
            bpy.ops.object.mode_set(mode='OBJECT')

            mesh = obj.to_mesh(bpy.context.scene, True, 'PREVIEW')

            vertex_matrix = matrix_rotX * obj_matrix
            obj_rotation = obj_matrix.to_quaternion()

            triBuffer = bytearray()

            for facei, face in enumerate(mesh.tessfaces): #(obj.data.polygons):

                mat = obj.data.materials[face.material_index]
                matIndex = -1
                if mat.name not in materials:
                    maxMatIndex = maxMatIndex + 1
                    materials[mat.name] = maxMatIndex
                    matIndex = maxMatIndex
                else:
                    matIndex = materials[mat.name]        

                v0 = vertex_matrix * mesh.vertices[face.vertices[0]].co
                v1 = vertex_matrix * mesh.vertices[face.vertices[1]].co
                v2 = vertex_matrix * mesh.vertices[face.vertices[2]].co

                n0 = obj_rotation * (matrix_rotX * mesh.vertices[face.vertices[0]].normal)
                n1 = obj_rotation * (matrix_rotX * mesh.vertices[face.vertices[1]].normal)
                n2 = obj_rotation * (matrix_rotX * mesh.vertices[face.vertices[2]].normal)

                uv1 = [[0.0, 0.0], [0.0, 0.0], [0.0, 0.0]]
                uv2 = [[0.0, 0.0], [0.0, 0.0], [0.0, 0.0]]
                uv = [uv1, uv2]

                for uvmapi, uvmap in enumerate(mesh.tessface_uv_textures):
                    if uvmapi < 2:
                        uv[uvmapi][0] = uvmap.data[facei].uv1
                        uv[uvmapi][1] = uvmap.data[facei].uv2
                        uv[uvmapi][2] = uvmap.data[facei].uv3

                triBuffer = triBuffer + packTriangle(matIndex, 
                    v0, v1, v2, 
                    n0, n1, n2, 
                    uv[0][0], uv[0][1], uv[0][2], 
                    uv[1][0], uv[1][1], uv[1][2])

            f.write(packChunk(ChunkType.TRIMESH, obj.name, triBuffer))

            bpy.context.scene.objects.active = obj
            bpy.ops.object.mode_set(mode='EDIT')
            bpy.ops.mesh.select_all(action='SELECT')
            bpy.ops.mesh.tris_convert_to_quads()
            bpy.context.scene.update()
            bpy.ops.object.mode_set(mode='OBJECT')

        # TODO: add support for other object types (aabb, empty, lamp, etc.)

    for matName, matIndex in materials.items():
        print("Processing material " + matName)

        if not matName in bpy.data.materials:
            continue

        mat = bpy.data.materials[matName]

        matData = bytearray()

        matData = matData + struct.pack('<i', matIndex)
        matData = matData + struct.pack('<I', mat.use_shadeless)
        matData = matData + packVector3f(mat.diffuse_color)
        matData = matData + packVector3f(mat.specular_color)
        matData = matData + struct.pack('<i', mat.specular_hardness)

        # save metadata

        danger = 0.0
        walkSound = ''

        if 'ADanger' in mat:
            danger = mat['ADanger']
        if 'AWalkSound' in mat:
            walkSound = mat['AWalkSound']

        matData = matData + struct.pack('<f', danger)
        matData = matData + struct.pack('<H', len(walkSound))
        matData = matData + bytearray(walkSound.encode('ascii')) 

        # save texture slots

        # get number of active slots
        texSlotsNum = 0
        for texSloti, texSlot in enumerate(mat.texture_slots):
            if texSloti < 8:
                if not texSlot is None:
                    if texSlot.texture.type == 'IMAGE':
                        texSlotsNum = texSlotsNum + 1

        matData = matData + struct.pack('<I', texSlotsNum)

        for texSloti, texSlot in enumerate(mat.texture_slots):
            # write maximum of 8 texture slots to maintain compatibility with legacy OpenGL
            if texSloti < 8:
                if not texSlot is None:
                    tex = texSlot.texture
                    if tex.type == 'IMAGE':
                        imgFilename = os.path.basename(tex.image.filepath)
                        print(imgFilename)
                        matData = matData + struct.pack('<H', len(imgFilename))
                        matData = matData + bytearray(imgFilename.encode('ascii'))
                    print(texSlot.blend_type)

                    # TODO: add support for other blend types
                    if texSlot.blend_type == 'MULTIPLY':
                        matData = matData + struct.pack('<H', 1)
                    else:
                        matData = matData + struct.pack('<H', 0)

        f.write(packChunk(ChunkType.MATERIAL, matName, matData))

    f.write(packChunk(ChunkType.END))
    f.close()
    return {'FINISHED'}

class AtriumAddObject(bpy.types.Operator):
    bl_idname = ("scene.atrium_add_object")
    bl_label = ("Atrium Object :: add object")
    
    name = bpy.props.StringProperty()
    
    value = bpy.props.EnumProperty(attr="values", name="values", default='collectible',
        items=[
            ('spawnpos', 'Spawn Position', 'Spawn Position'),
            ('collectible', 'Collectible', 'Collectible'),
            ('orb', 'Orb', 'Orb')
        ])
    
    def execute(self, context):
        # TODO: use active scene
        bpy.ops.object.add(type='EMPTY', location=bpy.data.scenes[0].cursor_location)
        for curr in bpy.data.objects:
            if curr.type == 'EMPTY' and curr.select:
                curr['AType'] = self.value
                if self.value == 'collectible':
                    curr.empty_draw_type = 'SPHERE'
                    curr.empty_draw_size = 0.5
                    curr['ACollectibleType'] = 0
                elif self.value == 'spawnpos':
                    curr.empty_draw_type = 'ARROWS'
                    curr.empty_draw_size = 1.0
                elif self.value == 'orb':
                    curr.empty_draw_type = 'SPHERE'
                    curr.empty_draw_size = 0.5
                    curr['AOrbType'] = 0
                    curr['AOrbMass'] = 1.0
        return {'FINISHED'}

class AtriumExportDataFile(bpy.types.Operator, ExportHelper):
    bl_idname = "export_objects.dat"
    bl_label = "Export Data File"
    filename_ext = ".dat"

    filter_glob = StringProperty(default="unknown.dat", options={'HIDDEN'})

    @classmethod
    def poll(cls, context):
        return True #len(context.selected_objects) > 0 #context.active_object.type in {'MESH'}

    def execute(self, context):
        filepath = self.filepath
        filepath = bpy.path.ensure_ext(filepath, self.filename_ext)           
        return doExport(context, filepath)

    def invoke(self, context, event):
        wm = context.window_manager
        if True:
            # File selector
            wm.fileselect_add(self) # will run self.execute()
            return {'RUNNING_MODAL'}
        elif True:
            # search the enum
            wm.invoke_search_popup(self)
            return {'RUNNING_MODAL'}
        elif False:
            # Redo popup
            return wm.invoke_props_popup(self, event)
        elif False:
            return self.execute(context)

def menu_func_add_atrium_object(self, context):
    self.layout.operator_menu_enum(AtriumAddObject.bl_idname, property="value", text="Atrium", icon='LOGIC')
    
def menu_func_export_atrium_map(self, context):
    self.layout.operator(AtriumExportDataFile.bl_idname, text = "Atrium Data File (.dat)")

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

class AtriumPanel(bpy.types.Panel):
    bl_label = "Atrium Tools"
    bl_space_type = "PROPERTIES"
    bl_region_type = "WINDOW"
    bl_context = "render"
    def draw(self, context):
        col = self.layout.column()
        row = self.layout.row()
        col = row.column(align=True)
        col.operator("scene.baking_mode_on", icon='MATERIAL', text="Baking On (Lightmapping mode)")
        col.operator("scene.baking_mode_off", icon='MATERIAL', text="Baking Off (DAT Export mode)")

def register():
    bpy.utils.register_module(__name__)
    bpy.types.INFO_MT_add.append(menu_func_add_atrium_object)
    bpy.types.INFO_MT_file_export.append(menu_func_export_atrium_map)

def unregister():
    bpy.utils.unregister_class(AtriumPanel)
    bpy.utils.unregister_class(OpBakingModeOn)
    bpy.utils.unregister_class(OpBakingModeOff)
    bpy.types.INFO_MT_add.remove(menu_func_add_atrium_object)
    bpy.types.INFO_MT_file_export.remove(menu_func_export_atrium_map)
    bpy.utils.unregister_module(__name__)

if __name__ == "__main__":
    register()
