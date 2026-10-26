#!/usr/bin/env blender -b --python
"""Rebuild the playable Thornbound warrior from the supplied concept.

This is the editable character source: it imports the game's established
21-bone player rig and its five authored locomotion clips, replaces the
generic mesh with original rigged geometry, and writes both a .blend project
and an embedded-texture .glb. No screenshot is treated as mesh data.
"""

from __future__ import annotations

import argparse
import json
import math
import struct
import sys
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / "art/characters/thornbound/source/Thornbound_21Bone_Animation_Rig.glb"
DEFAULT_TEXTURES = ROOT / "art/characters/thornbound/textures/procedural"
DEFAULT_BLEND = ROOT / "art/characters/thornbound/Thornbound_ConceptWarrior.blend"
DEFAULT_GLB = ROOT / "game/assets/characters/thornbound/Retribution_Player_Thornbound_Warrior_MOBILE.glb"

REQUIRED_BONES = {
    "Root", "Hips", "Spine", "Chest", "Neck", "Head", "Halo", "Cape", "Sword",
    "LeftUpperArm", "LeftForearm", "LeftHand", "LeftThigh", "LeftShin", "LeftFoot",
    "RightUpperArm", "RightForearm", "RightHand", "RightThigh", "RightShin", "RightFoot",
}

MATERIALS = {
    "Leather": ("leather", 0.05, 0.80),
    "Steel": ("steel", 0.88, 0.34),
    "BlackIron": ("iron", 0.78, 0.56),
    "Bronze": ("bronze", 0.72, 0.54),
    "WornCloth": ("cloth", 0.0, 0.92),
    "Linen": ("linen", 0.0, 0.90),
    "Crimson": ("crimson", 0.0, 0.90),
    "Skin": ("skin", 0.0, 0.72),
    "Hair": ("hair", 0.02, 0.70),
}


def sanitize_source_glb(source: Path) -> Path:
    """Blender 4.2 requires scalar accessor bounds to be one-item arrays."""
    raw = source.read_bytes()
    if raw[:4] != b"glTF":
        raise RuntimeError(f"Not a binary glTF: {source}")
    offset = 12
    chunks: list[tuple[int, bytes]] = []
    while offset < len(raw):
        length, kind = struct.unpack_from("<II", raw, offset)
        offset += 8
        chunks.append((kind, raw[offset:offset + length]))
        offset += length
    json_kind = 0x4E4F534A
    json_chunk = next((data for kind, data in chunks if kind == json_kind), None)
    if json_chunk is None:
        raise RuntimeError("GLB JSON chunk is missing")
    document = json.loads(json_chunk.decode("utf-8").rstrip("\0 "))
    for accessor in document.get("accessors", []):
        if accessor.get("type") == "SCALAR":
            for key in ("min", "max"):
                if isinstance(accessor.get(key), (int, float)):
                    accessor[key] = [accessor[key]]
    encoded = json.dumps(document, separators=(",", ":")).encode("utf-8")
    encoded += b" " * ((-len(encoded)) % 4)
    chunks = [(kind, encoded if kind == json_kind else data) for kind, data in chunks]
    total_length = 12 + sum(8 + len(data) for _, data in chunks)
    result = bytearray(b"glTF" + struct.pack("<II", 2, total_length))
    for kind, data in chunks:
        result += struct.pack("<II", len(data), kind)
        result += data
    safe_path = Path(bpy.app.tempdir) / "Thornbound_ConceptWarrior_BlendImport.glb"
    safe_path.write_bytes(result)
    return safe_path


class MeshBucket:
    def __init__(self, material_name: str):
        self.material_name = material_name
        self.vertices: list[tuple[float, float, float]] = []
        self.faces: list[tuple[int, ...]] = []
        self.weight_runs: dict[str, list[tuple[int, int, float]]] = {}
        self.flat_faces: set[int] = set()

    def add(self, vertices, faces, bone: str, extra_bones: dict[str, float] | None = None, flat: bool = False) -> None:
        start = len(self.vertices)
        self.vertices.extend(tuple(float(c) for c in p) for p in vertices)
        for face in faces:
            if len(face) > 4:
                # glTF tangents are defined for triangles and quads. Cylinder
                # end caps are fan-triangulated here instead of exporting n-gons.
                local_faces = [(face[0], face[i], face[i + 1]) for i in range(1, len(face) - 1)]
            else:
                local_faces = [face]
            for local_face in local_faces:
                self.faces.append(tuple(start + int(i) for i in local_face))
                if flat:
                    self.flat_faces.add(len(self.faces) - 1)
        end = len(self.vertices)
        assignments = {bone: 1.0}
        if extra_bones:
            assignments = dict(extra_bones)
            total = sum(assignments.values())
            assignments = {name: value / total for name, value in assignments.items()}
        for name, weight in assignments.items():
            self.weight_runs.setdefault(name, []).append((start, end, weight))


class CharacterBuilder:
    def __init__(self, armature, texture_dir: Path):
        self.armature = armature
        self.texture_dir = texture_dir
        self.buckets = {name: MeshBucket(name) for name in (*MATERIALS, "Ember")}
        self.bpy_materials = self._make_materials()
        self.front = Vector((0.0, -1.0, 0.0))

    def _make_materials(self):
        result = {}
        for name, (texture_key, metallic, roughness) in MATERIALS.items():
            material = bpy.data.materials.new("Thornbound_" + name)
            material.use_nodes = True
            nodes = material.node_tree.nodes
            links = material.node_tree.links
            principled = nodes.get("Principled BSDF")
            principled.inputs["Metallic"].default_value = metallic
            principled.inputs["Roughness"].default_value = roughness

            albedo = bpy.data.images.load(str(self.texture_dir / f"{texture_key}_albedo.jpg"), check_existing=True)
            normal = bpy.data.images.load(str(self.texture_dir / f"{texture_key}_normal.png"), check_existing=True)
            rough = bpy.data.images.load(str(self.texture_dir / f"{texture_key}_roughness.png"), check_existing=True)
            albedo.colorspace_settings.name = "sRGB"
            normal.colorspace_settings.name = "Non-Color"
            rough.colorspace_settings.name = "Non-Color"
            for image in (albedo, normal, rough):
                image.pack()

            base_tex = nodes.new("ShaderNodeTexImage")
            base_tex.name = name + "_Albedo"
            base_tex.image = albedo
            base_tex.interpolation = "Linear"
            links.new(base_tex.outputs["Color"], principled.inputs["Base Color"])
            rough_tex = nodes.new("ShaderNodeTexImage")
            rough_tex.name = name + "_Roughness"
            rough_tex.image = rough
            rough_tex.interpolation = "Linear"
            links.new(rough_tex.outputs["Color"], principled.inputs["Roughness"])
            normal_tex = nodes.new("ShaderNodeTexImage")
            normal_tex.name = name + "_Normal"
            normal_tex.image = normal
            normal_tex.interpolation = "Linear"
            normal_map = nodes.new("ShaderNodeNormalMap")
            normal_map.inputs["Strength"].default_value = 0.36
            links.new(normal_tex.outputs["Color"], normal_map.inputs["Color"])
            links.new(normal_map.outputs["Normal"], principled.inputs["Normal"])
            result[name] = material

        ember = bpy.data.materials.new("Thornbound_EmberInlay")
        ember.diffuse_color = (1.0, 0.20, 0.035, 1.0)
        ember.use_nodes = True
        shader = ember.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Base Color"].default_value = (0.24, 0.035, 0.01, 1.0)
        shader.inputs["Metallic"].default_value = 0.55
        shader.inputs["Roughness"].default_value = 0.42
        if "Emission Color" in shader.inputs:
            shader.inputs["Emission Color"].default_value = (1.0, 0.085, 0.012, 1.0)
            shader.inputs["Emission Strength"].default_value = 1.8
        elif "Emission" in shader.inputs:
            shader.inputs["Emission"].default_value = (1.0, 0.085, 0.012, 1.0)
        result["Ember"] = ember
        return result

    def add(self, material: str, vertices, faces, bone: str, extra_bones=None, flat=False):
        self.buckets[material].add(vertices, faces, bone, extra_bones, flat)

    def ellipsoid(self, material: str, center, scale, bone: str, segments=24, rings=16, extra_bones=None):
        center = Vector(center)
        vertices = []
        for lat_i in range(rings + 1):
            latitude = -math.pi / 2.0 + math.pi * lat_i / rings
            z = math.sin(latitude)
            ring = math.cos(latitude)
            for seg_i in range(segments):
                theta = math.tau * seg_i / segments
                x = math.sin(theta) * ring
                y = -math.cos(theta) * ring
                vertices.append(center + Vector((x * scale[0], y * scale[1], z * scale[2])))
        faces = []
        for row in range(rings):
            for col in range(segments):
                a = row * segments + col
                b = row * segments + (col + 1) % segments
                c = (row + 1) * segments + (col + 1) % segments
                d = (row + 1) * segments + col
                faces.append((a, b, c, d))
        self.add(material, vertices, faces, bone, extra_bones)

    def cylinder_between(self, material: str, start, end, radii, bone: str, segments=16, extra_bones=None):
        start, end = Vector(start), Vector(end)
        axis = (end - start).normalized()
        if axis.length_squared < 1e-6:
            return
        reference = Vector((0.0, 0.0, 1.0))
        if abs(axis.dot(reference)) > 0.94:
            reference = Vector((0.0, 1.0, 0.0))
        u = axis.cross(reference).normalized()
        v = axis.cross(u).normalized()
        r_start = radii[0] if isinstance(radii[0], (tuple, list)) else (radii[0], radii[0])
        r_end = radii[1] if isinstance(radii[1], (tuple, list)) else (radii[1], radii[1])
        vertices = []
        for point, radius in ((start, r_start), (end, r_end)):
            for index in range(segments):
                angle = math.tau * index / segments
                vertices.append(point + u * (math.cos(angle) * radius[0]) + v * (math.sin(angle) * radius[1]))
        faces = []
        for index in range(segments):
            nxt = (index + 1) % segments
            faces.append((index, nxt, segments + nxt, segments + index))
        faces.append(tuple(reversed(tuple(range(segments)))))
        faces.append(tuple(range(segments, 2 * segments)))
        self.add(material, vertices, faces, bone, extra_bones)

    def curve_tube(self, material: str, points, radius: float, bone: str, sides=8, radius_profile=None):
        points = [Vector(p) for p in points]
        if len(points) < 2:
            return
        vertices = []
        for index, point in enumerate(points):
            tangent = (points[min(index + 1, len(points) - 1)] - points[max(0, index - 1)]).normalized()
            reference = Vector((0.0, 0.0, 1.0))
            if abs(tangent.dot(reference)) > 0.92:
                reference = Vector((0.0, 1.0, 0.0))
            u = tangent.cross(reference).normalized()
            v = tangent.cross(u).normalized()
            r = radius if radius_profile is None else radius_profile[index]
            for side in range(sides):
                angle = math.tau * side / sides
                vertices.append(point + u * (math.cos(angle) * r) + v * (math.sin(angle) * r))
        faces = []
        for row in range(len(points) - 1):
            for side in range(sides):
                nxt = (side + 1) % sides
                a = row * sides + side
                b = row * sides + nxt
                c = (row + 1) * sides + nxt
                d = (row + 1) * sides + side
                faces.append((a, b, c, d))
        faces.append(tuple(reversed(tuple(range(sides)))))
        last = (len(points) - 1) * sides
        faces.append(tuple(range(last, last + sides)))
        self.add(material, vertices, faces, bone)

    def ribbon(self, material: str, points, width: float, thickness: float, bone: str):
        points = [Vector(p) for p in points]
        vertices = []
        for index, point in enumerate(points):
            tangent = (points[min(index + 1, len(points) - 1)] - points[max(0, index - 1)]).normalized()
            side = Vector((0.0, 0.0, 1.0)).cross(tangent)
            if side.length_squared < 1e-5:
                side = Vector((1.0, 0.0, 0.0))
            side.normalize()
            vertices.extend((point - side * width * 0.5, point + side * width * 0.5))
        midplane = list(vertices)
        vertices = [v + Vector((0.0, -thickness * 0.5, 0.0)) for v in midplane]
        front_end = len(vertices)
        vertices += [v + Vector((0.0, thickness * 0.5, 0.0)) for v in midplane]
        faces = []
        count = len(points)
        for row in range(count - 1):
            a = row * 2
            b = a + 1
            c = (row + 1) * 2 + 1
            d = (row + 1) * 2
            faces.extend(((a, b, c, d), (front_end + d, front_end + c, front_end + b, front_end + a)))
            faces.extend(((a, front_end + a, front_end + d, d), (b, c, front_end + c, front_end + b)))
        self.add(material, vertices, faces, bone)

    def plate(self, material: str, center, half_width, half_height, thickness, bone: str,
              basis_u=(1.0, 0.0, 0.0), basis_v=(0.0, 0.0, 1.0), bevel=0.025, curvature=0.018):
        center = Vector(center)
        u = Vector(basis_u).normalized()
        v = Vector(basis_v).normalized()
        normal = u.cross(v).normalized()
        radius = min(bevel, half_width * 0.42, half_height * 0.42)
        corners = [
            (half_width - radius, half_height - radius, 0.0, 90.0),
            (-half_width + radius, half_height - radius, 90.0, 180.0),
            (-half_width + radius, -half_height + radius, 180.0, 270.0),
            (half_width - radius, -half_height + radius, 270.0, 360.0),
        ]
        outline = []
        for cx, cy, a0, a1 in corners:
            for step in range(4):
                angle = math.radians(a0 + (a1 - a0) * step / 3.0)
                outline.append((cx + radius * math.cos(angle), cy + radius * math.sin(angle)))
        count = len(outline)
        vertices = []
        for x, y in outline:
            curved = curvature * max(0.0, 1.0 - (x / max(half_width, 1e-3)) ** 2)
            vertices.append(center + u * x + v * y + normal * (thickness * 0.5 + curved))
        vertices.append(center + normal * (thickness * 0.5 + curvature))
        front_center = count
        front_faces = [(front_center, i, (i + 1) % count) for i in range(count)]
        back_start = len(vertices)
        for x, y in outline:
            vertices.append(center + u * x + v * y - normal * thickness * 0.5)
        vertices.append(center - normal * thickness * 0.5)
        back_center = back_start + count
        faces = list(front_faces)
        faces.extend((back_center, back_start + (i + 1) % count, back_start + i) for i in range(count))
        faces.extend((i, (i + 1) % count, back_start + (i + 1) % count, back_start + i) for i in range(count))
        self.add(material, vertices, faces, bone)

    def build_mesh_objects(self):
        for material_name, bucket in self.buckets.items():
            if not bucket.vertices or not bucket.faces:
                continue
            mesh = bpy.data.meshes.new("Thornbound_%s_Geometry" % material_name)
            mesh.from_pydata(bucket.vertices, [], bucket.faces)
            mesh.update(calc_edges=True)
            obj = bpy.data.objects.new("Thornbound_%s" % material_name, mesh)
            bpy.context.collection.objects.link(obj)
            obj.data.materials.append(self.bpy_materials[material_name])
            for polygon in mesh.polygons:
                polygon.use_smooth = True
            for bone_name, runs in bucket.weight_runs.items():
                group = obj.vertex_groups.new(name=bone_name)
                for start, end, weight in runs:
                    group.add(list(range(start, end)), weight, "REPLACE")
            modifier = obj.modifiers.new("Thornbound player skin", "ARMATURE")
            modifier.object = self.armature
            modifier.use_vertex_groups = True
            obj.parent = self.armature
            obj.matrix_parent_inverse = self.armature.matrix_world.inverted()
            obj["asset_role"] = "rigged_player_character"
            obj["source_provenance"] = "Original procedural geometry based on user-provided colored concept art and Meshy screenshots."
            # Smart unwrap each material mesh into non-overlapping islands.
            bpy.ops.object.select_all(action="DESELECT")
            obj.select_set(True)
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.mode_set(mode="EDIT")
            bpy.ops.mesh.select_all(action="SELECT")
            bpy.ops.uv.smart_project(island_margin=0.012, area_weight=0.25, correct_aspect=True, scale_to_bounds=False)
            bpy.ops.object.mode_set(mode="OBJECT")
            bpy.ops.object.select_all(action="DESELECT")

            triangle_count = sum(max(0, len(poly.vertices) - 2) for poly in mesh.polygons)
            print("MESH_REPORT material=%s vertices=%d triangles=%d" % (material_name, len(mesh.vertices), triangle_count))


def circle_points(center, radius_x, radius_y, start_angle, end_angle, count, z_offset=0.0):
    c = Vector(center)
    result = []
    for index in range(count):
        t = index / max(1, count - 1)
        angle = start_angle + (end_angle - start_angle) * t
        result.append((c.x + math.cos(angle) * radius_x, c.y + math.sin(angle) * radius_y, c.z + z_offset))
    return result


def add_chest_and_armor(builder: CharacterBuilder):
    # Tailored under-layer and shaped torso, kept readable between metal parts.
    builder.ellipsoid("Leather", (0.0, 0.012, 1.30), (0.275, 0.145, 0.285), "Spine", 30, 22,
                      {"Spine": 0.45, "Chest": 0.55})
    builder.ellipsoid("WornCloth", (0.0, 0.018, 1.02), (0.255, 0.16, 0.19), "Hips")
    builder.ellipsoid("BlackIron", (0.0, -0.105, 1.385), (0.235, 0.055, 0.19), "Chest")
    # Layered central breastplate; left and right halves have different shapes.
    builder.plate("Steel", (-0.085, -0.136, 1.425), 0.12, 0.145, 0.045, "Chest", bevel=0.036, curvature=0.026)
    builder.plate("BlackIron", (0.092, -0.137, 1.415), 0.105, 0.14, 0.038, "Chest", bevel=0.03, curvature=0.025)
    builder.plate("Steel", (-0.06, -0.167, 1.505), 0.145, 0.07, 0.035, "Chest", bevel=0.03, curvature=0.028)
    builder.plate("Bronze", (0.015, -0.182, 1.372), 0.042, 0.11, 0.022, "Chest", bevel=0.012, curvature=0.006)
    # Rivets and stamped plates reinforce close-range detail.
    for x in (-0.19, -0.105, 0.0, 0.105, 0.19):
        builder.ellipsoid("Bronze", (x, -0.177, 1.465), (0.012, 0.008, 0.012), "Chest", 10, 8)
    for row in range(3):
        z = 1.34 + row * 0.06
        for x in (-0.20, 0.20):
            builder.ellipsoid("Bronze", (x, -0.144, z), (0.011, 0.009, 0.011), "Chest", 10, 8)

    # Crossed leather harness straps and a short diagonal chain.
    builder.ribbon("Leather", [(-0.23, -0.095, 1.58), (-0.16, -0.16, 1.48), (-0.04, -0.178, 1.38), (0.11, -0.16, 1.28), (0.22, -0.09, 1.19)], 0.045, 0.018, "Chest")
    builder.ribbon("Crimson", [(0.24, -0.08, 1.57), (0.14, -0.157, 1.49), (0.0, -0.178, 1.41), (-0.13, -0.145, 1.29), (-0.22, -0.08, 1.20)], 0.032, 0.012, "Chest")
    builder.plate("Bronze", (-0.065, -0.198, 1.397), 0.035, 0.045, 0.014, "Chest", bevel=0.012)
    chain_points = []
    for index in range(30):
        t = index / 29.0
        chain_points.append((0.17 - 0.29 * t, -0.198 - 0.012 * math.sin(math.pi * t), 1.49 - 0.19 * t))
    builder.curve_tube("Bronze", chain_points, 0.005, "Chest", sides=6)

    # Asymmetric left pauldron: overlapping, curved steel lamellae.
    for row in range(4):
        z = 1.52 - row * 0.047
        width = 0.145 - row * 0.008
        center_x = -0.315 - row * 0.025
        builder.plate("Steel" if row % 2 == 0 else "BlackIron",
                      (center_x, -0.08 - row * 0.006, z), width, 0.048, 0.034,
                      "LeftUpperArm", basis_u=(0.97, 0.0, -0.24), bevel=0.024, curvature=0.028)
        for stud in (-1, 1):
            builder.ellipsoid("Bronze", (center_x + stud * width * 0.60, -0.111, z), (0.010, 0.008, 0.010), "LeftUpperArm", 10, 8)
    # Small right pauldron retains a leather shoulder silhouette.
    builder.ellipsoid("Leather", (0.33, 0.0, 1.49), (0.135, 0.12, 0.15), "RightUpperArm")
    builder.plate("BlackIron", (0.34, -0.094, 1.52), 0.12, 0.09, 0.035, "RightUpperArm", bevel=0.03)
    builder.plate("Bronze", (0.35, -0.12, 1.47), 0.10, 0.028, 0.019, "RightUpperArm", bevel=0.01)

    # Collar ribs and fine seam piping.
    for i in range(4):
        z = 1.32 + i * 0.055
        points = circle_points((0.0, 0.0, z), 0.257 - i * 0.008, 0.138 - i * 0.003, 0.0, math.tau, 56)
        builder.curve_tube("Leather" if i % 2 == 0 else "Bronze", points, 0.007 if i else 0.012, "Chest", sides=6)


def add_belt_and_hanging_straps(builder: CharacterBuilder):
    belt_points = circle_points((0.0, 0.01, 1.035), 0.267, 0.155, 0.0, math.tau, 64)
    builder.curve_tube("Leather", belt_points, 0.034, "Hips", sides=10)
    trim_points = circle_points((0.0, 0.008, 1.072), 0.267, 0.155, 0.0, math.tau, 64)
    builder.curve_tube("Bronze", trim_points, 0.006, "Hips", sides=6)
    builder.plate("Bronze", (0.0, -0.168, 1.045), 0.075, 0.055, 0.035, "Hips", bevel=0.02, curvature=0.015)
    builder.plate("BlackIron", (0.0, -0.191, 1.045), 0.032, 0.023, 0.016, "Hips", bevel=0.009)
    for side in (-1, 1):
        x = 0.22 * side
        for z in (1.018, 1.072):
            builder.ellipsoid("Bronze", (x, -0.122, z), (0.012, 0.010, 0.012), "Hips", 10, 8)
    # Pouches with embossed lids and latch studs.
    for x, y, size in [(-0.19, -0.115, 0.075), (0.16, -0.13, 0.07), (0.265, -0.005, 0.055)]:
        builder.ellipsoid("Leather", (x, y, 0.982), (size, 0.055, 0.078), "Hips", 20, 14)
        builder.plate("BlackIron", (x, y - 0.05, 1.008), size * 0.80, 0.028, 0.015, "Hips", bevel=0.012)
        builder.ellipsoid("Bronze", (x, y - 0.063, 0.997), (0.010, 0.006, 0.010), "Hips", 10, 8)

    # Layered belt tabs, small hanging plates, and torn leather streamers.
    for index in range(9):
        angle = math.radians(200 + index * 17)
        x = 0.255 * math.cos(angle)
        y = 0.15 * math.sin(angle)
        z = 0.93 - (0.04 if index % 3 == 0 else 0.0)
        bone = "Hips" if abs(x) < 0.15 else ("LeftThigh" if x < 0 else "RightThigh")
        builder.plate("BlackIron" if index % 3 else "Steel", (x, y, z), 0.033, 0.092, 0.018, bone, bevel=0.014, curvature=0.006)
        builder.ellipsoid("Bronze", (x, y - 0.014, 0.89), (0.007, 0.006, 0.007), bone, 8, 6)
    for i, x in enumerate((-0.26, -0.16, -0.06, 0.04, 0.13, 0.23)):
        sway = 0.05 * math.sin(i * 1.5)
        bottom = 0.48 + 0.08 * (i % 3)
        bone = "Hips" if abs(x) < 0.12 else ("LeftThigh" if x < 0 else "RightThigh")
        builder.ribbon("Leather" if i % 2 else "Crimson",
                       [(x * 0.84, -0.18, 0.97), (x, -0.205, 0.78), (x + sway, -0.18, bottom)],
                       0.033, 0.010, bone)
        builder.plate("Bronze", (x, -0.205, 0.76), 0.022, 0.024, 0.012, bone, bevel=0.01)


def add_legs_and_boots(builder: CharacterBuilder):
    for side, x in (("Left", -0.20), ("Right", 0.20)):
        thigh, shin, foot = side + "Thigh", side + "Shin", side + "Foot"
        builder.ellipsoid("WornCloth", (x, 0.012, 0.68), (0.135, 0.132, 0.27), thigh, 28, 18)
        builder.ellipsoid("Leather", (x, 0.0, 0.48), (0.112, 0.102, 0.12), shin, 24, 16)
        builder.ellipsoid("Leather", (x, 0.015, 0.255), (0.086, 0.084, 0.18), shin, 24, 16)
        # Knee cup, leather backing, and rim.
        builder.ellipsoid("BlackIron", (x, -0.09, 0.49), (0.118, 0.058, 0.105), shin, 22, 14)
        builder.plate("Steel", (x, -0.137, 0.50), 0.103, 0.085, 0.032, shin, bevel=0.025, curvature=0.022)
        builder.plate("Bronze", (x, -0.161, 0.50), 0.026, 0.018, 0.012, shin, bevel=0.008)
        # Shin plates are segmented to keep shape when the knee bends.
        for row in range(3):
            z = 0.39 - row * 0.075
            builder.plate("Steel" if row != 1 else "BlackIron", (x, -0.088, z), 0.078, 0.041, 0.025, shin, bevel=0.02, curvature=0.019)
            for edge in (-1, 1):
                builder.ellipsoid("Bronze", (x + edge * 0.055, -0.114, z), (0.007, 0.006, 0.007), shin, 8, 6)
        # Wrapped cloth bands spiralling around both greaves.
        for band in range(8):
            z = 0.17 + band * 0.041
            points = []
            for step in range(13):
                t = step / 12.0
                angle = math.tau * t + band * 0.72
                points.append((x + 0.084 * math.cos(angle), 0.01 + 0.079 * math.sin(angle), z + 0.018 * t))
            builder.curve_tube("Linen" if band % 3 else "Leather", points, 0.0125, shin, sides=6)
        # Boot body, layered toe guard and heavy tread soles.
        builder.ellipsoid("Leather", (x, -0.055, 0.102), (0.112, 0.215, 0.078), foot, 24, 16)
        builder.ellipsoid("BlackIron", (x, -0.143, 0.113), (0.106, 0.105, 0.055), foot, 20, 12)
        builder.plate("Steel", (x, -0.207, 0.137), 0.076, 0.035, 0.020, foot, bevel=0.02)
        builder.cylinder_between("BlackIron", (x, 0.12, 0.04), (x, -0.24, 0.04), ((0.105, 0.052), (0.105, 0.052)), foot, 18)
        # Ankle wraps and buckles.
        for band in range(3):
            z = 0.16 + band * 0.047
            points = circle_points((x, 0.005, z), 0.09, 0.082, 0.0, math.tau, 28)
            builder.curve_tube("Leather" if band == 1 else "Linen", points, 0.013, shin, sides=6)
            builder.plate("Bronze", (x + 0.072, -0.024, z), 0.016, 0.019, 0.009, shin, bevel=0.007)
        # Raised sole grooves and toe seams add close-up geometry.
        for groove in range(3):
            y = -0.19 + groove * 0.085
            builder.ribbon("BlackIron", [(x - 0.07, y, 0.048), (x, y - 0.006, 0.043), (x + 0.07, y, 0.048)], 0.008, 0.004, foot)


def add_arms_and_hands(builder: CharacterBuilder):
    for side, sign in (("Left", -1.0), ("Right", 1.0)):
        upper, forearm, hand = side + "UpperArm", side + "Forearm", side + "Hand"
        shoulder = Vector((sign * 0.32, 0.005, 1.46))
        elbow = Vector((sign * 0.465, 0.015, 1.22))
        wrist = Vector((sign * 0.55, 0.035, 1.00))
        builder.ellipsoid("WornCloth", shoulder, (0.123, 0.12, 0.16), upper, 22, 16)
        builder.cylinder_between("Leather", shoulder, elbow, ((0.092, 0.09), (0.074, 0.072)), upper, 18)
        builder.cylinder_between("Leather", elbow, wrist, ((0.071, 0.068), (0.060, 0.060)), forearm, 18)
        builder.ellipsoid("Leather", (sign * 0.56, 0.03, 0.963), (0.079, 0.068, 0.088), hand, 18, 14)
        # Knuckle plates and individually modeled wrapped fingers.
        for finger in range(4):
            fx = sign * (0.515 + finger * 0.025)
            fz = 0.933 - abs(finger - 1.5) * 0.006
            builder.cylinder_between("Leather", (fx, -0.008, fz + 0.045), (fx, -0.014, fz - 0.028), (0.012, 0.008), hand, 8)
            builder.ellipsoid("BlackIron", (fx, -0.047, fz + 0.005), (0.014, 0.010, 0.016), hand, 10, 8)
        builder.cylinder_between("Leather", (sign * 0.50, 0.00, 0.963), (sign * 0.46, -0.04, 0.918), (0.015, 0.010), hand, 8)
        builder.ellipsoid("BlackIron", (sign * 0.50, -0.05, 0.93), (0.021, 0.012, 0.022), hand, 10, 8)
        # Forearm vambrace with raised central ridge and fastening rivets.
        center = (sign * 0.515, -0.055, 1.115)
        builder.plate("BlackIron", center, 0.085, 0.15, 0.036, forearm, basis_u=(0.91, 0.0, -0.40), bevel=0.025, curvature=0.020)
        builder.plate("Steel" if side == "Left" else "Bronze", (center[0], center[1] - 0.027, center[2]), 0.036, 0.105, 0.022, forearm, basis_u=(0.91, 0.0, -0.40), bevel=0.014, curvature=0.012)
        for band in range(4):
            z = 1.02 + band * 0.066
            points = circle_points((sign * (0.535 - band * 0.008), 0.018, z), 0.067, 0.066, 0.0, math.tau, 24)
            builder.curve_tube("Leather" if band % 2 else "Bronze", points, 0.010, forearm, sides=6)
        for z in (1.06, 1.17):
            builder.ellipsoid("Bronze", (sign * 0.548, -0.094, z), (0.009, 0.007, 0.009), forearm, 8, 6)


def add_head_hair_and_scarf(builder: CharacterBuilder):
    # Hood mass sits behind the head; the face remains open and readable.
    builder.ellipsoid("WornCloth", (0.0, 0.115, 1.69), (0.232, 0.17, 0.24), "Neck", 30, 20)
    builder.ellipsoid("BlackIron", (0.0, 0.018, 1.635), (0.16, 0.135, 0.14), "Neck", 24, 16)
    builder.cylinder_between("Skin", (0.0, 0.005, 1.58), (0.0, 0.005, 1.73), (0.09, 0.085), "Neck", 18)

    # Layered scarf folds around the throat.
    for index in range(4):
        z = 1.625 + index * 0.043
        rx = 0.16 + (index % 2) * 0.018
        ry = 0.128 + (index % 2) * 0.018
        points = circle_points((0.0, -0.012 + index * 0.012, z), rx, ry, 0.0, math.tau, 48)
        builder.curve_tube("Linen" if index in (0, 2) else "Crimson", points, 0.036, "Neck", sides=10)
    # Folded scarf tails and an off-center wine-red wrap.
    builder.ribbon("Linen", [(-0.18, -0.02, 1.65), (-0.14, -0.16, 1.55), (-0.05, -0.20, 1.42), (0.03, -0.21, 1.31)], 0.105, 0.024, "Chest")
    builder.ribbon("Crimson", [(0.16, -0.03, 1.66), (0.11, -0.155, 1.55), (0.04, -0.19, 1.46), (-0.06, -0.182, 1.35)], 0.075, 0.020, "Chest")
    builder.ribbon("Linen", [(0.19, 0.08, 1.66), (0.25, 0.09, 1.54), (0.28, 0.13, 1.41), (0.31, 0.19, 1.33)], 0.082, 0.022, "Chest")

    # Sculpted head, jaw, ears, nose, eyelids and visible eyes.
    builder.ellipsoid("Skin", (0.0, -0.012, 1.775), (0.128, 0.122, 0.166), "Head", 36, 26)
    builder.ellipsoid("Skin", (0.0, -0.072, 1.701), (0.092, 0.073, 0.075), "Head", 24, 16)
    for sign in (-1, 1):
        builder.ellipsoid("Skin", (sign * 0.124, -0.004, 1.775), (0.032, 0.052, 0.058), "Head", 16, 12)
        builder.ellipsoid("BlackIron", (sign * 0.047, -0.118, 1.805), (0.034, 0.020, 0.019), "Head", 20, 12)
        builder.ellipsoid("Linen", (sign * 0.047, -0.133, 1.805), (0.023, 0.012, 0.011), "Head", 16, 10)
        builder.ellipsoid("Bronze", (sign * 0.047, -0.143, 1.805), (0.0085, 0.006, 0.009), "Head", 12, 8)
        builder.ellipsoid("BlackIron", (sign * 0.047, -0.148, 1.805), (0.0045, 0.004, 0.006), "Head", 10, 8)
        # Brows sit proud of the eyes; one is scarred and slightly lower.
        builder.curve_tube("Hair", [(sign * 0.014, -0.137, 1.833), (sign * 0.045, -0.145, 1.839), (sign * 0.079, -0.124, 1.827)], 0.012, "Head", sides=7)
        builder.curve_tube("Skin", [(sign * 0.11, -0.02, 1.78), (sign * 0.15, -0.026, 1.76), (sign * 0.11, -0.04, 1.735)], 0.003, "Head", sides=5)
    builder.ellipsoid("Skin", (0.0, -0.145, 1.773), (0.026, 0.045, 0.041), "Head", 18, 12)
    builder.ellipsoid("Skin", (0.0, -0.176, 1.755), (0.028, 0.025, 0.026), "Head", 16, 10)
    builder.ellipsoid("BlackIron", (0.0, -0.152, 1.702), (0.044, 0.013, 0.009), "Head", 16, 10)
    builder.ellipsoid("Crimson", (0.0, -0.163, 1.699), (0.034, 0.008, 0.005), "Head", 14, 8)
    # Cheek planes, a small healed scar, and chin creases.
    for sign in (-1, 1):
        builder.ellipsoid("Skin", (sign * 0.075, -0.104, 1.752), (0.048, 0.034, 0.034), "Head", 18, 12)
    builder.curve_tube("BlackIron", [(-0.06, -0.150, 1.85), (-0.045, -0.160, 1.82), (-0.032, -0.166, 1.79), (-0.016, -0.159, 1.765)], 0.0028, "Head", sides=5)

    # Tousled sculpted locks over the crown and down the temples.
    builder.ellipsoid("Hair", (0.0, 0.012, 1.914), (0.154, 0.135, 0.088), "Head", 32, 18)
    for index in range(42):
        t = index / 42.0
        angle = math.tau * t
        sx = 0.13 * math.sin(angle)
        sy = 0.02 - 0.12 * math.cos(angle)
        sz = 1.92 + 0.025 * math.sin(index * 1.83)
        direction = math.sin(index * 2.17)
        ex = max(-0.16, min(0.16, sx * 0.58 + 0.045 * direction))
        ey = -0.12 + 0.055 * math.cos(index * 1.31)
        ez = 1.75 + 0.13 * (0.5 + 0.5 * math.sin(index * 1.7))
        path = [
            (sx, sy, sz),
            (sx * 0.80 + ex * 0.20, sy - 0.035, sz + 0.035),
            (sx * 0.42 + ex * 0.58, ey - 0.012, (sz + ez) * 0.5 + 0.025),
            (ex, ey, ez),
        ]
        radius = 0.008 + 0.006 * (0.5 + 0.5 * math.sin(index * 2.6))
        builder.curve_tube("Hair", path, radius, "Head", sides=7, radius_profile=[radius, radius * 0.92, radius * 0.58, radius * 0.08])
    for sign in (-1, 1):
        for row in range(4):
            x = sign * (0.115 + row * 0.009)
            builder.curve_tube("Hair", [(x, -0.04, 1.91), (x * 1.10, -0.11, 1.84), (x * 0.92, -0.132, 1.77 - row * 0.012)], 0.009, "Head", sides=7,
                               radius_profile=[0.012, 0.009, 0.001])


def add_cloak_and_halo(builder: CharacterBuilder):
    # Full 3D cape shell with hand-torn hem, folds, and a separate crimson inner panel.
    def cape_surface(material, x_scale, y_offset, z_bottom, panel_phase, bone="Cape"):
        columns, rows = 18, 22
        vertices = []
        for row in range(rows):
            t = row / (rows - 1)
            for col in range(columns):
                u = col / (columns - 1)
                x = (u - 0.5) * (0.44 + 0.80 * t) * x_scale
                fold = 0.038 * math.sin(u * math.tau * 4.0 + panel_phase) * t
                fold += 0.018 * math.sin(u * math.tau * 9.0 - panel_phase) * t
                y = y_offset + 0.19 * t + fold
                hem_wave = 0.055 * math.sin(u * math.tau * 7.0 + panel_phase) + 0.028 * math.sin(u * math.tau * 13.0)
                tear = 0.0
                if t > 0.91:
                    notch = max(0.0, math.sin(u * math.tau * 8.0 + panel_phase))
                    tear = (t - 0.91) / 0.09 * 0.12 * notch
                z = 1.50 - (1.50 - z_bottom) * t + hem_wave * t * t + tear
                vertices.append((x, y, z))
        faces = []
        for row in range(rows - 1):
            for col in range(columns - 1):
                a = row * columns + col
                b = a + 1
                c = b + columns
                d = a + columns
                faces.append((a, b, c, d))
        # Double-sided cloth geometry avoids losing the cape in either camera orbit.
        base = len(vertices)
        vertices += [(x, y - 0.018, z) for x, y, z in vertices]
        faces += [tuple(base + i for i in reversed(face)) for face in faces]
        builder.add(material, vertices, faces, bone)

    cape_surface("Linen", 1.0, 0.16, 0.045, 0.4)
    cape_surface("Crimson", 0.82, 0.115, 0.09, 1.7)
    # Torn tapered cloth ribbons hang from the lower edge and wave as a single
    # low-cost Cape bone rather than a mobile cloth simulation.
    for index in range(11):
        x = -0.49 + index * 0.098
        length = 0.18 + 0.20 * (0.5 + 0.5 * math.sin(index * 2.15))
        builder.ribbon("Linen" if index % 3 else "Crimson",
                       [(x, 0.36, 0.32), (x + 0.045 * math.sin(index), 0.40, 0.20), (x + 0.025 * math.cos(index), 0.39, max(0.015, 0.32 - length))],
                       0.042, 0.009, "Cape")
    # Hood seam and cape attachment clasp.
    for sign in (-1, 1):
        builder.plate("Bronze", (sign * 0.23, 0.13, 1.49), 0.028, 0.035, 0.016, "Chest", bevel=0.012)
    builder.ellipsoid("Bronze", (0.0, -0.135, 1.585), (0.035, 0.022, 0.035), "Chest", 16, 12)
    builder.ellipsoid("Ember", (0.0, -0.157, 1.585), (0.012, 0.008, 0.012), "Chest", 12, 8)

    # Broken halo arcs; forged thorn barbs and four glowing cracked inlays.
    halo_center = Vector((0.0, 0.16, 1.99))
    arc_ranges = [(-0.02, 2.06), (2.42, 4.30), (4.70, 6.18)]
    for arc_index, (start, end) in enumerate(arc_ranges):
        points = []
        for step in range(44):
            angle = start + (end - start) * step / 43.0
            points.append((halo_center.x + 0.285 * math.sin(angle), halo_center.y, halo_center.z + 0.285 * math.cos(angle)))
        builder.curve_tube("Bronze", points, 0.012, "Halo", sides=8)
        inner = [(x, y - 0.014, z) for x, y, z in points]
        builder.curve_tube("BlackIron", inner, 0.006, "Halo", sides=6)
    for index in range(18):
        angle = math.tau * index / 18.0 + 0.12
        x = halo_center.x + 0.285 * math.sin(angle)
        z = halo_center.z + 0.285 * math.cos(angle)
        dx = math.sin(angle)
        dz = math.cos(angle)
        length = 0.055 + 0.035 * (0.5 + 0.5 * math.sin(index * 1.87))
        tip = (x + dx * length, halo_center.y - 0.005, z + dz * length)
        builder.cylinder_between("Steel", (x, halo_center.y, z), tip, (0.013, 0.001), "Halo", 8)
        if index in (1, 5, 10, 14):
            builder.ellipsoid("Ember", (x, halo_center.y - 0.025, z), (0.018, 0.008, 0.018), "Halo", 12, 8)
    # A few floating-looking tips are physically joined to the ring at their bases.
    for sign in (-1, 1):
        builder.cylinder_between("Bronze", (sign * 0.16, 0.14, 2.20), (sign * 0.22, 0.14, 2.31), (0.015, 0.0), "Halo", 8)


def add_sword(builder: CharacterBuilder):
    # The sword is weighted to the existing Sword bone under RightHand.
    grip = Vector((0.55, 0.0, 0.98))
    pommel = grip + Vector((0.015, 0.0, 0.18))
    builder.cylinder_between("Leather", grip, pommel, (0.034, 0.028), "Sword", 14)
    for index in range(6):
        t = index / 5.0
        p = grip.lerp(pommel, t)
        builder.curve_tube("Bronze", [(p.x - 0.03, p.y - 0.015, p.z - 0.025), (p.x + 0.03, p.y - 0.015, p.z + 0.025)], 0.0035, "Sword", sides=5)
    builder.ellipsoid("Bronze", pommel, (0.052, 0.046, 0.045), "Sword", 18, 12)
    builder.ellipsoid("Ember", (pommel.x, pommel.y - 0.045, pommel.z), (0.018, 0.009, 0.018), "Sword", 12, 8)
    guard_center = grip + Vector((0.0, -0.005, 0.015))
    guard_path = [
        (guard_center.x - 0.22, guard_center.y, guard_center.z - 0.018),
        (guard_center.x - 0.16, guard_center.y - 0.025, guard_center.z + 0.018),
        (guard_center.x - 0.08, guard_center.y - 0.038, guard_center.z + 0.035),
        (guard_center.x, guard_center.y - 0.045, guard_center.z + 0.020),
        (guard_center.x + 0.08, guard_center.y - 0.038, guard_center.z + 0.035),
        (guard_center.x + 0.16, guard_center.y - 0.025, guard_center.z + 0.018),
        (guard_center.x + 0.22, guard_center.y, guard_center.z - 0.018),
    ]
    builder.curve_tube("BlackIron", guard_path, 0.022, "Sword", sides=8)
    builder.curve_tube("Bronze", [(x, y - 0.020, z) for x, y, z in guard_path], 0.008, "Sword", sides=6)
    for sign in (-1, 1):
        builder.cylinder_between("Steel", (guard_center.x + sign * 0.17, guard_center.y, guard_center.z + 0.02),
                                 (guard_center.x + sign * 0.28, guard_center.y, guard_center.z + 0.11), (0.022, 0.0), "Sword", 8)

    # Broad double-edged blade with a raised central ridge and a chipped tip.
    start = Vector((0.55, -0.01, 0.99))
    tip = Vector((0.74, -0.025, 0.10))
    axis = tip - start
    side = Vector((1.0, 0.0, 0.0))
    profile = [(0.03, 0.020), (0.07, 0.030), (0.12, 0.037), (0.135, 0.035), (0.112, 0.028), (0.072, 0.020), (0.0, 0.0)]
    vertices = []
    for index, (half_width, half_thickness) in enumerate(profile):
        t = index / (len(profile) - 1)
        center = start.lerp(tip, t)
        vertices.extend((center - side * half_width + Vector((0.0, -half_thickness, 0.0)),
                         center + side * half_width + Vector((0.0, -half_thickness, 0.0)),
                         center - side * half_width + Vector((0.0, half_thickness, 0.0)),
                         center + side * half_width + Vector((0.0, half_thickness, 0.0))))
    faces = []
    for row in range(len(profile) - 1):
        a = row * 4
        b = a + 4
        faces.extend(((a, a + 1, b + 1, b), (a + 2, b + 2, b + 3, a + 3),
                      (a, b, b + 2, a + 2), (a + 1, a + 3, b + 3, b + 1)))
    faces.append((0, 2, 3, 1))
    last = (len(profile) - 1) * 4
    faces.append((last, last + 1, last + 3, last + 2))
    builder.add("Steel", vertices, faces, "Sword", flat=True)
    # Dark fuller rails and a thin ember fracture running toward the chipped tip.
    for sign in (-1, 1):
        rail = []
        for index in range(1, len(profile) - 1):
            t = index / (len(profile) - 1)
            center = start.lerp(tip, t)
            rail.append((center.x + sign * profile[index][0] * 0.76, center.y - profile[index][1] - 0.004, center.z))
        builder.curve_tube("BlackIron", rail, 0.0045, "Sword", sides=5)
    crack = []
    for index in range(21):
        t = 0.10 + 0.73 * index / 20.0
        center = start.lerp(tip, t)
        crack.append((center.x + 0.007 * math.sin(index * 1.7), center.y - 0.039 + 0.003 * math.sin(index * 2.4), center.z))
    builder.curve_tube("Ember", crack, 0.004, "Sword", sides=5)
    for sign in (-1, 1):
        builder.cylinder_between("Steel", (guard_center.x + sign * 0.22, guard_center.y, guard_center.z),
                                 (guard_center.x + sign * 0.34, guard_center.y, guard_center.z - 0.015), (0.021, 0.0), "Sword", 8)


def make_model(armature, texture_dir: Path):
    builder = CharacterBuilder(armature, texture_dir)
    add_chest_and_armor(builder)
    add_belt_and_hanging_straps(builder)
    add_legs_and_boots(builder)
    add_arms_and_hands(builder)
    add_head_hair_and_scarf(builder)
    add_cloak_and_halo(builder)
    add_sword(builder)
    builder.build_mesh_objects()
    return builder


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--textures", type=Path, default=DEFAULT_TEXTURES)
    parser.add_argument("--blend", type=Path, default=DEFAULT_BLEND)
    parser.add_argument("--glb", type=Path, default=DEFAULT_GLB)
    parser.add_argument("--no-render", action="store_true")
    return parser.parse_args(argv)


def main():
    args = parse_args()
    for path in (args.source, args.textures / "skin_albedo.jpg", args.blend.parent, args.glb.parent):
        if not path.exists() and path not in (args.blend.parent, args.glb.parent):
            raise FileNotFoundError(path)
    args.blend.parent.mkdir(parents=True, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    safe_source = sanitize_source_glb(args.source)
    bpy.ops.import_scene.gltf(filepath=str(safe_source))
    armatures = [obj for obj in bpy.data.objects if obj.type == "ARMATURE"]
    if len(armatures) != 1:
        raise RuntimeError(f"Expected one source rig, found {len(armatures)}")
    armature = armatures[0]
    armature.name = "PlayerHumanoidRig"
    armature.data.name = "Thornbound_21Bone_Rig"
    bone_names = {bone.name for bone in armature.data.bones}
    missing = REQUIRED_BONES - bone_names
    if missing:
        raise RuntimeError("Source player rig is missing required bones: " + ", ".join(sorted(missing)))
    if len(armature.data.bones) != 21:
        raise RuntimeError(f"Expected the established 21-bone player skeleton; found {len(armature.data.bones)}")
    action_names = {track.name for track in armature.animation_data.nla_tracks} if armature.animation_data else set()
    expected_clips = {"Idle", "Walk", "Sprint", "Jump", "Sword_Slash"}
    if not expected_clips.issubset(action_names):
        raise RuntimeError(f"Source rig clips missing: {sorted(expected_clips - action_names)}")
    print("SOURCE_RIG bones=21 clips=" + ",".join(sorted(action_names)))

    for obj in list(bpy.data.objects):
        if obj != armature:
            bpy.data.objects.remove(obj, do_unlink=True)
    for material in list(bpy.data.materials):
        if material.users == 0:
            bpy.data.materials.remove(material)
    for image in list(bpy.data.images):
        if image.users == 0:
            bpy.data.images.remove(image)

    armature.data.pose_position = "POSE"
    make_model(armature, args.textures)
    armature["asset_provenance"] = "Original procedural character. User-provided concept art and Meshy screenshots used as visual references only; no source mesh was supplied."
    armature["source_rig"] = "Thornbound 21-bone rig from the existing Bijatyka player GLB"
    armature["mobile_render_budget"] = "One skinned mesh per PBR material; manual cape motion; no cloth simulation."
    armature["primary_weapon_bone"] = "Sword"
    armature["halo_bone"] = "Halo"
    armature["triangle_count_estimate"] = sum(sum(max(0, len(poly.vertices) - 2) for poly in obj.data.polygons) for obj in bpy.data.objects if obj.type == "MESH")

    # Keep the original Blender actions/NLA strips untouched for Idle, Walk,
    # Sprint, Jump, and Sword_Slash. Godot authors the responsive hit-synced
    # left/right punches and kicks and the additional short action clips.
    bpy.context.scene.frame_start = 0
    bpy.context.scene.frame_end = 49
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.object.select_all(action="DESELECT")
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.wm.save_as_mainfile(filepath=str(args.blend), compress=True)

    bpy.ops.export_scene.gltf(
        filepath=str(args.glb),
        export_format="GLB",
        export_animations=True,
        export_nla_strips=True,
        export_force_sampling=True,
        export_skins=True,
        export_morph=False,
        export_materials="EXPORT",
        export_image_format="AUTO",
        export_cameras=False,
        export_lights=False,
        export_apply=True,
        export_texcoords=True,
        export_normals=True,
        export_tangents=True,
        export_yup=True,
    )
    print("EXPORT_REPORT blend=%s glb=%s bytes=%d triangles=%s" % (
        args.blend, args.glb, args.glb.stat().st_size, armature.get("triangle_count_estimate")
    ))


if __name__ == "__main__":
    main()
