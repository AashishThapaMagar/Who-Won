"""Prepares a Meshy image-to-3D character for the game, in Blender.

    blender -b --python tools/prep_meshy_body.py -- <in.glb> <out.glb> [--faces 40000] [--tex 2048] [--info]

Meshy's Ultra models are hundreds of thousands of triangles with 4K
textures: far too heavy for two fighters on a phone. This decimates the mesh
to about --faces triangles (keeping its UVs), scales every texture down to
--tex pixels, stands the model on the floor at the origin facing +Z (glTF
forward, which Meshy's rigging expects) and writes a GLB. --info only
prints the model's size, triangle count and textures.
"""
import os
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[0], (argv[1] if len(argv) > 1 and not argv[1].startswith("--") else "")
faces = int(argv[argv.index("--faces") + 1]) if "--faces" in argv else 40000
tex = int(argv[argv.index("--tex") + 1]) if "--tex" in argv else 2048

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def bounds():
    xs, ys, zs = [], [], []
    for obj in meshes:
        for corner in obj.bound_box:
            world = obj.matrix_world @ __import__("mathutils").Vector(corner)
            xs.append(world.x)
            ys.append(world.y)
            zs.append(world.z)
    return (min(xs), max(xs)), (min(ys), max(ys)), (min(zs), max(zs))


total = sum(tris(o) for o in meshes)
(x0, x1), (y0, y1), (z0, z1) = bounds()
print("INFO meshes=%d tris=%d size x=%.2f y=%.2f z=%.2f (blender z up)" % (len(meshes), total, x1 - x0, y1 - y0, z1 - z0))
for image in bpy.data.images:
    print("INFO texture", image.name, image.size[0], image.size[1])
if "--info" in argv or not dst:
    sys.exit(0)

for obj in meshes:
    bpy.context.view_layer.objects.active = obj
    ratio = min(1.0, faces * (tris(obj) / max(total, 1)) / max(tris(obj), 1))
    if ratio < 1.0:
        mod = obj.modifiers.new("decimate", "DECIMATE")
        mod.ratio = ratio
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
for image in bpy.data.images:
    if image.size[0] > tex or image.size[1] > tex:
        scale = tex / max(image.size[0], image.size[1])
        image.scale(int(image.size[0] * scale), int(image.size[1] * scale))
        image.pack()
# Feet on the floor, centred on the origin.
(x0, x1), (y0, y1), (z0, z1) = bounds()
for obj in meshes:
    obj.location.x -= (x0 + x1) / 2.0
    obj.location.y -= (y0 + y1) / 2.0
    obj.location.z -= z0
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
print("INFO after tris=%d" % sum(tris(o) for o in meshes))
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_image_format="JPEG", export_jpeg_quality=88)
print("WROTE", dst, os.path.getsize(dst))
