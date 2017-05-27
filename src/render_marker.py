# by p2or on Blender StackExchange
# https://blender.stackexchange.com/questions/23121
import bpy
import os

# get the scene
scn = bpy.context.scene

# get the output path
output_path = scn.render.filepath

# iterate through markers and render
for k, m in scn.timeline_markers.items():  
    frame = m.frame
    marker_name = m.name
    scn.frame_set(frame)
    scn.render.filepath = os.path.join(output_path, marker_name + ".jpg")
    bpy.ops.render.render( write_still=True )

bpy.context.scene.render.filepath = output_path