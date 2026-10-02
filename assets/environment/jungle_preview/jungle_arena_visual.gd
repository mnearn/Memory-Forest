extends Node3D

# Presentation only. The existing JungleFloor remains the sole arena collision.
var fitted_meshes := 0
var material_cache: Dictionary = {}

func _ready() -> void:
	for body: CollisionObject3D in $JungleAsset.find_children("*", "CollisionObject3D", true, false):
		body.collision_layer = 0
		body.collision_mask = 0
	for mesh: MeshInstance3D in $JungleAsset.find_children("*", "MeshInstance3D", true, false):
		_tint_materials(mesh)
		if "Ground_2" in String(mesh.name):
			_flatten_ground(mesh)
		elif "Water2" in String(mesh.name):
			var bounds := _bounds(mesh)
			mesh.global_position += Vector3(26.0 - bounds.get_center().x, -0.07 - bounds.position.y, 0.0)
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			_fit_decoration(mesh)

func _bounds(mesh: MeshInstance3D) -> AABB:
	return mesh.global_transform * mesh.mesh.get_aabb()

func _tint_materials(mesh: MeshInstance3D) -> void:
	for surface in range(mesh.mesh.get_surface_count()):
		var original := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
		if original == null:
			continue
		var key := original.get_instance_id()
		if not material_cache.has(key):
			var material := original.duplicate() as StandardMaterial3D
			var tint := Color(0.65, 0.70, 0.63)
			if original.resource_name == "Plant_Mat":
				tint = Color(0.48, 0.60, 0.46)
			elif original.resource_name == "Ground_Mat":
				tint = Color(0.58, 0.64, 0.53)
			elif original.resource_name == "Water_Mat":
				tint = Color(0.45, 0.72, 0.65)
			material.albedo_color *= tint
			material_cache[key] = material
		mesh.set_surface_override_material(surface, material_cache[key])

func _flatten_ground(mesh: MeshInstance3D) -> void:
	# Derive a flat visual from the asset's triangles and UVs, without editing GLB.
	var original := mesh.mesh
	var flattened := ArrayMesh.new()
	var inverse := mesh.global_transform.affine_inverse()
	var top_height := _bounds(mesh).end.y
	for surface in range(original.get_surface_count()):
		var arrays := original.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var source_vertices := vertices.duplicate()
		for i in range(vertices.size()):
			var point := mesh.global_transform * vertices[i]
			# Widen only the visual terrain to cover all four gameplay-floor corners.
			point.x *= 1.5
			point.z *= 1.5
			# Retain a tiny depth separation between overlapping terrain layers.
			# The entire visual stays just below the authoritative flat collision.
			point.y = -0.015 - (top_height - point.y) * 0.002
			vertices[i] = inverse * point
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_TANGENT] = null
		# Imported custom streams are not used by the StandardMaterial3D ground.
		# Their import-format flags cannot be carried into a newly built ArrayMesh.
		for channel in range(Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM3 + 1):
			arrays[channel] = null
		var source_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var indices := PackedInt32Array()
		for i in range(0, source_indices.size(), 3):
			var a := source_indices[i]
			var b := source_indices[i + 1]
			var c := source_indices[i + 2]
			var source_cross := (mesh.global_transform.basis * (source_vertices[b] - source_vertices[a])).cross(mesh.global_transform.basis * (source_vertices[c] - source_vertices[a]))
			# Discard cliff/underside faces instead of layering them over the terrain.
			if source_cross.normalized().y >= -0.15:
				continue
			var cross := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
			if cross.length_squared() < 0.00001:
				continue
			indices.append_array(PackedInt32Array([a, b, c]))
		arrays[Mesh.ARRAY_INDEX] = indices
		flattened.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var tool := SurfaceTool.new()
		tool.create_from(flattened, surface)
		tool.generate_normals()
		tool.generate_tangents()
		mesh.mesh = tool.commit()
		mesh.mesh.surface_set_material(0, original.surface_get_material(surface))
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _fit_decoration(mesh: MeshInstance3D) -> void:
	var bounds := _bounds(mesh)
	var center := bounds.get_center()
	var target := center
	# Rear scenery is behind every spawn; side scenery clears the entire floor.
	if center.z < -7.0:
		target.z = minf(center.z, -14.0 - bounds.size.z * 0.5)
	else:
		var side := -1.0 if center.x < 0.0 else 1.0
		target.x = side * (15.8 + bounds.size.x * 0.5 + absf(center.x) * 0.12)
		target.z = clampf(center.z, -8.0, 6.0)
	mesh.global_position += Vector3(target.x - center.x, -0.025 - bounds.position.y, target.z - center.z)
	fitted_meshes += 1
	# Transparent grass and flower cards do not need expensive real-time shadows.
	if "Plant_Mat" in String(mesh.name) or "Vine" in String(mesh.name):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
