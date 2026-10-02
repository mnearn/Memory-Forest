@tool
extends Node3D

# A visual-only composite. Neither source GLB is changed.
const DONOR := preload("res://assets/enemies/lion/lion.glb")
const BODY_COLOR := Color(0.34, 0.27, 0.20)
const GROUND_CORRECTIONS := [0,0.0013,0,0,0.0096,0.005,0,0,0.02,0.0264,0,0,0,0,0,0,0,0.0297,0,0,0,0.0351,0.0093,0,0,0,0,0.1594,0.0717,0,0,0.0302,0.0147,0.0326,0,0.1407,0.0104,0.0227,0.0371,0.0235,0.016,0,0,0,0,0,0,0,0,0,0,0.0294,0.0855,0.0106,0.0067,0,0,0,0,0,0,0,0,0,0,0.0168,0.0306,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0.0116,0,0,0,0,0,0,0,0.0003,0.016,0.0355,0.0511]
var animator: AnimationPlayer
var skeleton: Skeleton3D
var mane_attachment: BoneAttachment3D
var mane: MeshInstance3D

func _ready() -> void:
	var base := $AnimatedBody
	skeleton = base.find_children("*", "Skeleton3D", true, false)[0]
	var body_meshes := base.find_children("*", "MeshInstance3D", true, false)
	# The source includes three whole-body resolutions, not three body parts.
	# Show the highest-resolution body while keeping all source nodes/rig intact.
	for mesh_node in body_meshes:
		mesh_node.visible = mesh_node.name == "Object_8"
		var source := mesh_node.mesh.surface_get_material(0) as StandardMaterial3D
		var material := source.duplicate() as StandardMaterial3D
		material.resource_name = "Donor Brown Fur (Base UVs Preserved)"
		material.albedo_color = BODY_COLOR
		material.roughness = 0.90
		material.metallic_specular = 0.15
		mesh_node.material_override = material
	animator = base.find_child("AnimationPlayer", true, false) as AnimationPlayer
	# Use an instance-local looping copy. The original five-second clip is intact.
	var library := animator.get_animation_library("").duplicate(true) as AnimationLibrary
	animator.remove_animation_library("")
	animator.add_animation_library("", library)
	library.get_animation("Take 001").loop_mode = Animation.LOOP_LINEAR
	animator.play("Take 001")
	animator.seek(0.0, true)
	skeleton.force_update_all_bone_transforms()
	_build_mane()

func _process(_delta: float) -> void:
	if not is_instance_valid(animator):
		return
	# Measured foot penetration in Take 001; retain its intentional leap/rear-up.
	var sample := clampf(animator.current_animation_position / 0.05, 0.0, 100.0)
	var index := mini(int(sample), 99)
	$AnimatedBody.position.y = 0.06 + lerpf(GROUND_CORRECTIONS[index], GROUND_CORRECTIONS[index + 1], sample - index)

func _build_mane() -> void:
	var donor := DONOR.instantiate()
	var source_node := donor.find_children("*", "MeshInstance3D", true, false)[0]
	var source_mesh: Mesh = source_node.mesh
	var arrays := source_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	# This donor is missing normals. Generate them without reordering its UVs.
	for i in range(0, indices.size(), 3):
		var a := indices[i]
		var b := indices[i + 1]
		var c := indices[i + 2]
		var normal := (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a])
		normals[a] += normal
		normals[b] += normal
		normals[c] += normal
	for i in range(normals.size()):
		normals[i] = normals[i].normalized() if normals[i].length_squared() > 0.0000000001 else Vector3.UP
	var material := source_mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	material.resource_name = "Original Donor Mane and Teal Collar"
	material.albedo_color = Color(1.2, 1.2, 1.2)
	material.metallic_specular = 0.15
	var image := material.albedo_texture.get_image()
	if image.is_compressed():
		image.decompress()
	var selected := PackedInt32Array()
	for i in range(0, indices.size(), 3):
		var center := (vertices[indices[i]] + vertices[indices[i + 1]] + vertices[indices[i + 2]]) / 3.0
		if center.y < 0.08 or center.y > 1.01 or absf(center.x) > 0.67 or center.z < -0.55:
			continue
		# Exclude the donor's face, jaw, eyes, and muzzle: only the base has a face.
		if center.z > 0.31 and absf(center.x) < 0.31 and center.y > 0.20 and center.y < 0.84:
			continue
		var tex_uv := (uv[indices[i]] + uv[indices[i + 1]] + uv[indices[i + 2]]) / 3.0
		var color := image.get_pixel(posmod(int(tex_uv.x * image.get_width()), image.get_width()), posmod(int(tex_uv.y * image.get_height()), image.get_height()))
		var is_teal := color.g > color.r * 1.25 and color.b > color.r * 1.1
		if color.get_luminance() > 0.16 and not is_teal:
			continue
		selected.append(indices[i])
		selected.append(indices[i + 1])
		selected.append(indices[i + 2])
	var bone := skeleton.find_bone("Lion_Head_TopSHJnt_021")
	mane_attachment = BoneAttachment3D.new()
	mane_attachment.name = "DonorManeAttachment"
	mane_attachment.bone_name = skeleton.get_bone_name(bone)
	skeleton.add_child(mane_attachment)
	mane = MeshInstance3D.new()
	mane.name = "DonorManeOnly"
	# Map donor head/neck proportions to base skeleton units, then bind locally.
	var fit := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 65.0), Vector3(0, 44.7, 57.5))
	mane.transform = skeleton.get_bone_global_pose(bone).affine_inverse() * fit
	var mesh_arrays := []
	mesh_arrays.resize(Mesh.ARRAY_MAX)
	var compact_vertices := PackedVector3Array()
	var compact_normals := PackedVector3Array()
	var compact_uv := PackedVector2Array()
	var compact_indices := PackedInt32Array()
	var remap := {}
	for idx in selected:
		if not remap.has(idx):
			remap[idx] = compact_vertices.size()
			compact_vertices.append(vertices[idx])
			compact_normals.append(normals[idx])
			compact_uv.append(uv[idx])
		compact_indices.append(remap[idx])
	mesh_arrays[Mesh.ARRAY_VERTEX] = compact_vertices
	mesh_arrays[Mesh.ARRAY_NORMAL] = compact_normals
	mesh_arrays[Mesh.ARRAY_TEX_UV] = compact_uv
	mesh_arrays[Mesh.ARRAY_INDEX] = compact_indices
	var extracted := ArrayMesh.new()
	extracted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays)
	extracted.surface_set_material(0, material)
	mane.mesh = extracted
	mane_attachment.add_child(mane)
	# Bounds are computed from selected triangles rather than the discarded body.
	var bounds := AABB(vertices[selected[0]], Vector3.ZERO)
	for idx in selected:
		bounds = bounds.expand(vertices[idx])
	mane.custom_aabb = bounds
	donor.free()
