bl_info = {
    "name": "DGL2 Export",
    "author": "Timur Gafarov",
    "version": (2, 0),
    "blender": (2, 6, 4),
    "location": "File > Export > DGL Scene (.dgl2)",
    "description": "Tools to create and export DGL scenes",
    "warning": "",
    "wiki_url": "",
    "tracker_url": "",
    "category": "Import-Export"}

import os
import struct
from math import pi, radians, sqrt
import mathutils
#from json import JSONEncoder

import bpy
from bpy.props import StringProperty
from bpy_extras.io_utils import ExportHelper

def enum(**enums):
    return type('Enum', (), enums)

ChunkType = enum(
    HEADER = 0, 
    END = 1,
    TRIMESH = 2,
    MATERIAL = 3,
    ENTITY = 4
)

def packChunk(chunkType, chunkId = -1, chunkName = '', chunkData = []):
    buf = struct.pack('<H', chunkType)
    buf = buf + struct.pack('<i', chunkId)
    buf = buf + struct.pack('<H', len(chunkName))
    buf = buf + struct.pack('<I', len(chunkData))
    buf = buf + bytearray(chunkName.encode('ascii'))
    buf = buf + bytearray(chunkData)
    return buf

def packVector4f(v):
    return struct.pack('<ffff', v[0], v[1], v[2], v[3])

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
    return (angle / 180.0) * pi

def radToDeg(angle):
    return (angle / pi) * 180.0

def writeMesh(f, obj, meshId, materials, maxMaterialId):
    rotX = mathutils.Matrix.Rotation(-pi/2, 4, 'X')

    bpy.context.scene.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.quads_convert_to_tris()
    bpy.context.scene.update()
    bpy.ops.object.mode_set(mode='OBJECT')

    mesh = obj.to_mesh(bpy.context.scene, True, 'PREVIEW')

    triBuffer = bytearray()

    for facei, face in enumerate(mesh.tessfaces):

        matIndex = -1

        if len(obj.data.materials) > 0:
            mat = obj.data.materials[face.material_index]
            if mat.name not in materials:
                materials[mat.name] = maxMaterialId
                matIndex = maxMaterialId
                maxMaterialId = maxMaterialId + 1
            else:
                matIndex = materials[mat.name]

        v0 = mesh.vertices[face.vertices[0]].co
        v1 = mesh.vertices[face.vertices[1]].co
        v2 = mesh.vertices[face.vertices[2]].co

        n0 = mesh.vertices[face.vertices[0]].normal
        n1 = mesh.vertices[face.vertices[1]].normal
        n2 = mesh.vertices[face.vertices[2]].normal

        uv1 = [[0.0, 0.0], [0.0, 0.0], [0.0, 0.0]]
        uv2 = [[0.0, 0.0], [0.0, 0.0], [0.0, 0.0]]
        uv = [uv1, uv2]

        uvtex = mesh.tessface_uv_textures #enumerate

        for uvmapi, uvmap in enumerate(uvtex):
            if uvmapi < 2:
                uv[uvmapi][0] = uvmap.data[facei].uv1
                uv[uvmapi][1] = uvmap.data[facei].uv2
                uv[uvmapi][2] = uvmap.data[facei].uv3

        if len(uvtex) == 1:
            uv[1][0] = uvtex[0].data[facei].uv1
            uv[1][1] = uvtex[0].data[facei].uv2
            uv[1][2] = uvtex[0].data[facei].uv3

        triBuffer = triBuffer + packTriangle(matIndex, 
            v0, v1, v2, 
            n0, n1, n2, 
            uv[0][0], uv[0][1], uv[0][2], 
            uv[1][0], uv[1][1], uv[1][2])

    f.write(packChunk(ChunkType.TRIMESH, meshId, obj.data.name, triBuffer))

    #bpy.context.scene.objects.active = obj
    #bpy.ops.object.mode_set(mode='EDIT')
    #bpy.ops.mesh.select_all(action='SELECT')
    #bpy.ops.mesh.tris_convert_to_quads()
    #bpy.context.scene.update()
    #bpy.ops.object.mode_set(mode='OBJECT')

    return maxMaterialId

def writeEntity(f, obj, entityId, meshes, materials):

    rotX = mathutils.Matrix.Rotation(-pi/2, 4, 'X')
    obj_matrix = obj.matrix_world.copy()
    mat = rotX * obj_matrix

    entityType = 0
    # TODO: material id
    materialId = -1

    meshName = obj.data.name
    meshId = -1
    if meshName in meshes:
        meshId = meshes[meshName]

    position = rotX * obj.location #mat.translation
    rot = mat.to_quaternion()
    rotation = (rot.x, rot.y, rot.z, rot.w)
    scaling = obj.scale #TODO: fix axes

    dml = {}

    if obj.type == 'LAMP':
        col = obj.data.color
        entityType = 1
        dml = {
            "color": vecToStr([col.r, col.g, col.b, 1.0])
        }
    else:
        dml = {
            "visible": str(int(not obj.hide_render))
        }

    dmlStr = encodeDML(dml)
    dmlASCII = dmlStr.encode('ascii')
    dmlSize = len(dmlASCII)

    data = bytearray()
    data = data + struct.pack('<I', entityType)
    data = data + struct.pack('<i', materialId)
    data = data + struct.pack('<i', meshId)
    data = data + packVector3f(position)
    data = data + packVector4f(rotation)
    data = data + packVector3f(scaling)
    data = data + struct.pack('<I', dmlSize)
    data = data + bytearray(dmlASCII)

    f.write(packChunk(ChunkType.ENTITY, entityId, obj.name, data))

def vecToStr(vec):
    return "[" + ", ".join(str(x) for x in vec) + "]",

def encodeDML(d):
    res = "{"
    for k, v in d.items():
        res += str(k) + "=" + "\"" + str(v[0]) + "\";"
    res += "}"
    return res

def writeMaterial(f, matName, matIndex):
    mat = bpy.data.materials[matName]

    diffuse = mat.diffuse_color
    specular = mat.specular_color
    shadeless = mat.use_shadeless

    dml = {
        "diffuseColor": vecToStr([diffuse.r, diffuse.g, diffuse.b, 1.0]),
        "specularColor": vecToStr([specular.r, specular.g, specular.b, 1.0]),
        "shadeless": str(int(shadeless))
    }

    # save texture slots

    # get number of active slots
    texSlotsNum = 0
    for texSloti, texSlot in enumerate(mat.texture_slots):
        if texSloti < 8:
            if not texSlot is None:
                if texSlot.texture.type == 'IMAGE':
                    if texSlot.texture.image:
                        texSlotsNum = texSlotsNum + 1

    dml["texturesNum"] = str(texSlotsNum)

    for texSloti, texSlot in enumerate(mat.texture_slots):
        # write maximum of 8 texture slots to maintain compatibility with legacy OpenGL
        if texSloti < 8:
            if not texSlot is None:
                tex = texSlot.texture
                if tex.type == 'IMAGE':
                    if tex.image:
                        imgFilename = os.path.basename(tex.image.filepath)
                        print(imgFilename)
                        print(texSlot.blend_type)
                        blend_type = 0
                        if texSlot.blend_type == 'MIX':
                            blend_type = 0
                        elif texSlot.blend_type == 'MULTIPLY':
                            blend_type = 1
                        else:
                            blend_type = 0

                        texIndex = "texture" + str(texSloti)
                        texStr = vecToStr([imgFilename, blend_type])
                        dml[texIndex] = texStr

    dmlStr = encodeDML(dml)
    print(dmlStr)

    dmlASCII = dmlStr.encode('ascii')
    dmlSize = len(dmlASCII)

    matData = bytearray()
    matData = matData + struct.pack('<I', dmlSize)
    matData = matData + bytearray(dmlASCII)

    f.write(packChunk(ChunkType.MATERIAL, matIndex, matName, matData))

def doExport(context, filepath = ""):
    print("Exporting objects as DGL file...")
    bpy.ops.object.mode_set(mode = 'OBJECT')

    materials = {}
    maxMatId = 0

    meshes = {}
    maxMeshId = 0

    entityId = 0

    matrix_rotX = mathutils.Matrix.Rotation(-pi/2, 4, 'X')

    f = open(filepath, 'wb')
    f.write(packChunk(ChunkType.HEADER, -1, context.scene.name))

    objects = bpy.data.objects

    # collect unique mesh ids
    for obj in objects:
        if obj.type == 'MESH':
            mesh = obj.data
            if not mesh.name in meshes:
                print("%s: %s" % (mesh.name, maxMeshId))
                meshes[mesh.name] = maxMeshId
                maxMatId = writeMesh(f, obj, maxMeshId, materials, maxMatId)
                maxMeshId = maxMeshId + 1

    for obj in objects:
        print("Processing object " + obj.name)
        writeEntity(f, obj, entityId, meshes, materials)
        entityId = entityId + 1

    for matName, matIndex in materials.items():
        print("Processing material " + matName)
        if matName in bpy.data.materials:
            writeMaterial(f, matName, matIndex)

    f.write(packChunk(ChunkType.END))
    f.close()
    return {'FINISHED'}

class ExportDGLFile(bpy.types.Operator, ExportHelper):
    bl_idname = "export_objects.dgl2"
    bl_label = "Export DGL2"
    filename_ext = ".dgl2"

    filter_glob = StringProperty(default="unknown.dgl2", options={'HIDDEN'})

    @classmethod
    def poll(cls, context):
        return True

    def execute(self, context):
        filepath = self.filepath
        filepath = bpy.path.ensure_ext(filepath, self.filename_ext)           
        return doExport(context, filepath)

    def invoke(self, context, event):
        wm = context.window_manager
        if True:
            wm.fileselect_add(self)
            return {'RUNNING_MODAL'}
        elif True:
            wm.invoke_search_popup(self)
            return {'RUNNING_MODAL'}
        elif False:
            return wm.invoke_props_popup(self, event)
        elif False:
            return self.execute(context)

def menu_func_export_dgl(self, context):
    self.layout.operator(ExportDGLFile.bl_idname, text = "DGL Scene (.dgl2)")

def register():
    bpy.utils.register_module(__name__)
    bpy.types.INFO_MT_file_export.append(menu_func_export_dgl)

def unregister():
    bpy.types.INFO_MT_file_export.remove(menu_func_export_dgl)
    bpy.utils.unregister_module(__name__)

if __name__ == "__main__":
    register()

