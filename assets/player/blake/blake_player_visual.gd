extends Node3D

const SwordScene = preload("res://assets/weapons/medieval_sword/medieval_sword.glb")
const DownloadedActionPlayer = preload("res://Modular-Character-Controller-for-Godot-bce61c2ab0c317a32512daea65519e597cda72e7/addons/modular_character_controller/scripts/action_player.gd")
const VisualAction = preload("res://assets/player/blake/blake_visual_action.gd")

var animator: AnimationPlayer
var skeleton: Skeleton3D
var actions: Node
var attack_remaining := 0.0
var dead := false
var active_clip := ""
var sword_attachment: BoneAttachment3D
var attack_duration := 0.55
var sword: Node3D
var sword_tip := Vector3.ZERO
var slash_mesh := ImmediateMesh.new()
var slash: MeshInstance3D
var slash_samples: Array[Dictionary] = []

func _ready() -> void:
	var source := $Blake
	skeleton = source.find_child("Skeleton3D", true, false)
	animator = source.find_child("AnimationPlayer", true, false)
	# The source shares the first facial mesh's inverse binds across differently
	# exported meshes. Correct only instance resources, retaining UVs and weights.
	_correct_bind_spaces(source)
	var library := animator.get_animation_library("").duplicate(true)
	animator.remove_animation_library("")
	animator.add_animation_library("", library)
	for clip in ["armature|idle", "armature|walk", "armature|run"]:
		animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	animator.play("armature|idle")
	animator.seek(0.0, true)
	skeleton.force_update_all_bone_transforms()
	_attach_sword(source)
	_build_slash()
	actions = DownloadedActionPlayer.new()
	actions.name = "VisualActions"
	var action := VisualAction.new()
	action.name = "Animate"
	action.play_action.connect(action.immediate_exit_self)
	actions.add_child(action)
	add_child(actions)
	actions.set_request(self, &"animate", NodePath("Animate"))
	_request_clip("armature|idle")

func _correct_bind_spaces(source: Node3D) -> void:
	# Use transforms relative to the imported root, before its gameplay yaw.
	var to_skeleton := (source.global_transform.affine_inverse() * skeleton.global_transform).affine_inverse()
	for mesh: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		if mesh.name in ["Object_96", "Object_98"]:
			# These are the source character's gun and magazine, replaced by the sword.
			mesh.visible = false
			continue
		var fit := Transform3D.IDENTITY
		if mesh.name == "Object_90":
			fit.basis = Basis.IDENTITY.scaled(Vector3.ONE * 0.01)
		else:
			# Facial detail meshes retain their geometry/UVs and original bone weights.
			var targets := {
				"Object_86": AABB(Vector3(-0.034, 1.682, 0.071), Vector3(0.068, 0.022, 0.040)),
				"Object_88": AABB(Vector3(-0.032, 1.687, 0.062), Vector3(0.064, 0.019, 0.033)),
				"Object_92": AABB(Vector3(-0.056, 1.739, 0.043), Vector3(0.112, 0.034, 0.009)),
				"Object_94": AABB(Vector3(-0.019, 1.682, 0.036), Vector3(0.038, 0.010, 0.037))
			}
			var box := mesh.mesh.get_aabb()
			var target: AABB = targets[String(mesh.name)]
			fit.basis = Basis.IDENTITY.scaled(target.size / box.size)
			fit.origin = target.position - fit.basis * box.position
		var transform_vertices := to_skeleton * fit
		var original := mesh.mesh
		var corrected := ArrayMesh.new()
		for surface in range(original.get_surface_count()):
			var arrays := original.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var normal_basis := transform_vertices.basis.inverse().transposed()
			for i in range(vertices.size()):
				vertices[i] = transform_vertices * vertices[i]
				normals[i] = (normal_basis * normals[i]).normalized()
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_TANGENT] = null
			if mesh.name in ["Object_88", "Object_92"]:
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				for i in range(0, indices.size(), 3):
					var swap := indices[i + 1]
					indices[i + 1] = indices[i + 2]
					indices[i + 2] = swap
				arrays[Mesh.ARRAY_INDEX] = indices
			corrected.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			corrected.surface_set_material(surface, original.surface_get_material(surface))
		mesh.mesh = corrected
		for surface in range(corrected.get_surface_count()):
			var tool := SurfaceTool.new()
			tool.create_from(corrected, surface)
			tool.generate_tangents()
			var with_tangents := tool.commit()
			with_tangents.surface_set_material(0, corrected.surface_get_material(surface))
			# Every supplied character part currently has one surface.
			mesh.mesh = with_tangents
		var skin := mesh.skin.duplicate() as Skin
		for bind in range(skin.get_bind_count()):
			var bone := skeleton.find_bone(skin.get_bind_name(bind))
			if bone >= 0:
				skin.set_bind_pose(bind, skeleton.get_bone_global_rest(bone).affine_inverse())
		mesh.skin = skin
		mesh.custom_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))

func _attach_sword(source: Node3D) -> void:
	sword_attachment = BoneAttachment3D.new()
	sword_attachment.name = "SwordHandAttachment"
	sword_attachment.bone_name = "hand_R_028"
	skeleton.add_child(sword_attachment)
	sword = SwordScene.instantiate() as Node3D
	sword.name = "MedievalSword"
	sword_attachment.add_child(sword)
	# Fit the sword's existing diagonal geometry around the grip, not its center.
	var desired_basis := Basis(Vector3.FORWARD, deg_to_rad(40.0)).scaled(Vector3.ONE * 0.60)
	var grip := Vector3(-0.34, 0.48, 0.0)
	var hand := source.global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("hand_R_028"))
	var fit := Transform3D(desired_basis, hand.origin - desired_basis * grip)
	sword.transform = hand.affine_inverse() * fit
	# Locate the blade tip in the supplied geometry, retaining the existing grip.
	var farthest := 0.0
	for mesh: MeshInstance3D in sword.find_children("*", "MeshInstance3D", true, false):
		var to_sword := sword.global_transform.affine_inverse() * mesh.global_transform
		for surface in mesh.mesh.get_surface_count():
			for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var point: Vector3 = to_sword * vertex
				if point.distance_squared_to(grip) > farthest:
					farthest = point.distance_squared_to(grip)
					sword_tip = point

func _build_slash() -> void:
	slash = MeshInstance3D.new()
	slash.name = "SwordArc"
	slash.mesh = slash_mesh
	slash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color("65d6c3", 0.28)
	slash.material_override = material
	add_child(slash)

func _process(_delta: float) -> void:
	var grip := sword_attachment.global_position
	var tip := sword.global_transform * sword_tip
	slash_samples.append({"inner":to_local(grip.lerp(tip, 0.55)), "outer":to_local(tip)})
	if slash_samples.size() > 2:
		slash_samples.pop_front()
	slash_mesh.clear_surfaces()
	# One-frame blade ribbon only in the striking portion (~0.16 seconds).
	var clip_time := animator.current_animation_position
	if dead or active_clip != "armature|hand_attack" or clip_time < 0.20 or clip_time > 0.55 or slash_samples.size() < 2:
		return
	slash_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, slash_samples.size()):
		var a := slash_samples[i - 1]
		var b := slash_samples[i]
		for vertex in [a.inner, a.outer, b.outer, a.inner, b.outer, b.inner]:
			slash_mesh.surface_add_vertex(vertex)
	slash_mesh.surface_end()

func update_movement(velocity: Vector3, delta: float) -> void:
	if dead:
		return
	if attack_remaining > 0.0:
		attack_remaining = maxf(attack_duration - animator.current_animation_position / maxf(animator.speed_scale, 0.001), 0.0)
		if not animator.is_playing():
			attack_remaining = 0.0
	var moving := Vector2(velocity.x, velocity.z).length() > 0.1
	if attack_remaining > 0.0:
		return
	if moving:
		rotation.y = rotate_toward(rotation.y, atan2(-velocity.x, -velocity.z), delta * 12.0)
		_request_clip("armature|run", clampf(Vector2(velocity.x, velocity.z).length() / 6.0, 0.8, 1.8))
	else:
		_request_clip("armature|idle")

func attack(cooldown: float) -> void:
	if dead:
		return
	attack_remaining = minf(cooldown, 0.55)
	attack_duration = attack_remaining
	slash_samples.clear()
	_request_clip("armature|hand_attack", 1.2 / attack_remaining)
	# Restart even if a fast consecutive attack requests the same clip.
	animator.seek(0.0, true)

func get_attack_contact_delay(cooldown: float) -> float:
	return minf(cooldown, 0.55) * 0.30

func die() -> void:
	dead = true
	_request_clip("armature|dead")

func _request_clip(clip: String, speed: float = 1.0) -> void:
	if active_clip == clip:
		animator.speed_scale = speed
		return
	actions.play(self, &"animate", {"clip": clip, "speed": speed})

func play_clip(clip: String, speed: float = 1.0) -> void:
	active_clip = clip
	animator.speed_scale = speed
	animator.play(clip, 0.08)
