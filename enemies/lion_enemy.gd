extends CharacterBody3D
signal defeated
const LION_MODEL := preload("res://assets/enemies/lion/lion.glb")
const MODEL_SCALE := 1.65
const MODEL_HEIGHT := 1.67
enum LionState { CHASE, MELEE_WINDUP, MELEE, CHARGE_WINDUP, CHARGE, RECOVER, DEAD }
static var corrected_meshes: Dictionary = {}
var max_health := 300.0
var health := 300.0
var move_speed := 3.5
var damage := 20.0
var charge_damage := 25.0
var attack_cooldown := 1.5
var charge_cooldown := 6.0
var charge_speed := 10.0
var charge_range := 7.0
var player: CharacterBody3D
var model: Node3D
var health_bar: ProgressBar
var boss_panel: PanelContainer
var telegraph: MeshInstance3D
var telegraph_material: StandardMaterial3D
var hit_materials: Array[BaseMaterial3D] = []
var state := LionState.CHASE
var state_time := 0.0
var attack_remaining := 0.0
var charge_remaining := 3.0
var recovery_duration := 0.5
var charge_travel := 0.0
var attack_direction := Vector3.FORWARD
var attack_hit := false
var is_dead := false
var flash_remaining := 0.0

func _ready() -> void:
	add_to_group("enemies")
	_build_model()
	_build_telegraph()
	_build_health_bar()

func set_player(target: CharacterBody3D) -> void:
	player = target

func _physics_process(delta: float) -> void:
	if flash_remaining > 0.0:
		flash_remaining -= delta
		if flash_remaining <= 0.0:
			for material in hit_materials:
				material.emission_enabled = false
	if is_dead:
		return
	state_time += delta
	attack_remaining = maxf(0.0, attack_remaining - delta)
	charge_remaining = maxf(0.0, charge_remaining - delta)
	velocity.x = 0.0
	velocity.z = 0.0
	var valid_target: bool = is_instance_valid(player) and not player.get("is_dead")
	var offset := Vector3.ZERO
	var distance := INF
	if valid_target:
		offset = player.global_position - global_position
		offset.y = 0.0
		distance = offset.length()
	match state:
		LionState.CHASE:
			if valid_target:
				rotation.y = rotate_toward(rotation.y, atan2(-offset.x, -offset.z), delta * 6.0)
				if charge_remaining <= 0.0 and distance >= 3.0 and distance <= 12.0:
					_begin_attack(LionState.CHARGE_WINDUP, offset)
				elif distance <= 2.8 and attack_remaining <= 0.0:
					_begin_attack(LionState.MELEE_WINDUP, offset)
				elif distance > 2.3:
					var speed := minf(move_speed, (distance - 2.3) / delta)
					velocity.x = offset.normalized().x * speed
					velocity.z = offset.normalized().z * speed
		LionState.MELEE_WINDUP:
			model.position.z = 0.18 * minf(state_time / 0.30, 1.0)
			if state_time >= 0.30:
				_change_state(LionState.MELEE)
		LionState.MELEE:
			model.position.z = -0.40 * sin(minf(state_time / 0.28, 1.0) * PI)
			if state_time >= 0.09 and state_time <= 0.20:
				_try_hit(damage, 2.8, valid_target)
			if state_time >= 0.28:
				attack_remaining = attack_cooldown
				_recover(0.50)
		LionState.CHARGE_WINDUP:
			telegraph_material.emission_energy_multiplier = 1.0 + sin(state_time * 20.0) * 0.35
			model.position.z = 0.22 * minf(state_time / 0.65, 1.0)
			if state_time >= 0.65:
				charge_travel = 0.0
				_change_state(LionState.CHARGE)
		LionState.CHARGE:
			model.position.z = -0.25
			velocity.x = attack_direction.x * charge_speed
			velocity.z = attack_direction.z * charge_speed
			if charge_travel >= charge_range or state_time >= charge_range / charge_speed:
				velocity.x = 0.0
				velocity.z = 0.0
				_end_charge()
		LionState.RECOVER:
			model.position.z = lerpf(model.position.z, 0.0, minf(delta * 12.0, 1.0))
			if state_time >= recovery_duration:
				_change_state(LionState.CHASE)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0
	var before := global_position
	move_and_slide()
	if state == LionState.CHARGE:
		charge_travel += Vector2(global_position.x - before.x, global_position.z - before.z).length()
		_try_hit(charge_damage, 2.0, valid_target)
		if attack_hit or (state_time > 0.08 and is_on_wall()):
			_end_charge()

func _begin_attack(next: LionState, direction: Vector3) -> void:
	attack_direction = direction.normalized()
	rotation.y = atan2(-direction.x, -direction.z)
	attack_hit = false
	_change_state(next)
	telegraph.visible = true
	telegraph.scale = Vector3(1.35, 0.08, 1.35) if next == LionState.CHARGE_WINDUP else Vector3(1, 0.08, 1)
	telegraph_material.albedo_color = Color(1.0, 0.55, 0.08, 0.65) if next == LionState.CHARGE_WINDUP else Color(1.0, 0.12, 0.04, 0.55)
	telegraph_material.emission = telegraph_material.albedo_color
	telegraph.get_node("ChargeDirection").visible = next == LionState.CHARGE_WINDUP

func _try_hit(amount: float, reach: float, valid_target: bool) -> void:
	if not valid_target or attack_hit:
		return
	var contact := player.global_position - global_position
	var vertical := absf(contact.y)
	contact.y = 0.0
	if vertical < 1.4 and contact.length() <= reach and attack_direction.dot(contact.normalized()) > 0.4:
		attack_hit = true
		player.take_damage(amount)

func _end_charge() -> void:
	charge_remaining = charge_cooldown
	attack_remaining = maxf(attack_remaining, 1.0)
	_recover(0.85)

func _recover(duration: float) -> void:
	recovery_duration = duration
	telegraph.visible = false
	_change_state(LionState.RECOVER)

func _change_state(next: LionState) -> void:
	state = next
	state_time = 0.0

func take_damage(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	health_bar.value = health
	flash_remaining = 0.20
	for material in hit_materials:
		material.emission_enabled = true
		material.emission = Color(1.0, 0.15, 0.05)
		material.emission_energy_multiplier = 0.8
	if health <= 0.0:
		_die()

func _die() -> void:
	is_dead = true
	_change_state(LionState.DEAD)
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	telegraph.hide()
	boss_panel.hide()
	remove_from_group("enemies")
	var tween := create_tween()
	tween.tween_property(model, "rotation:z", -PI / 2.0, 0.55)
	tween.parallel().tween_property(model, "position:y", 0.7, 0.55)
	tween.tween_callback(func():
		defeated.emit()
		queue_free())

func _build_model() -> void:
	model = LION_MODEL.instantiate()
	model.name = "LionModel"
	model.scale = Vector3.ONE * MODEL_SCALE
	model.rotation_degrees.y = 180.0
	model.position.y = MODEL_HEIGHT
	add_child(model)
	for mesh_node in model.find_children("*", "MeshInstance3D", true, false):
		mesh_node.mesh = _with_normals(mesh_node.mesh)
		for surface in range(mesh_node.mesh.get_surface_count()):
			var original := mesh_node.mesh.surface_get_material(surface) as BaseMaterial3D
			if original:
				var material := original.duplicate() as BaseMaterial3D
				mesh_node.set_surface_override_material(surface, material)
				hit_materials.append(material)
	var collision := CollisionShape3D.new()
	collision.name = "LionCollision"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.8
	shape.height = 3.1
	collision.shape = shape
	collision.position.y = 1.55
	add_child(collision)

func _with_normals(original: Mesh) -> Mesh:
	if corrected_meshes.has(original):
		return corrected_meshes[original]
	var fixed := ArrayMesh.new()
	for surface in range(original.get_surface_count()):
		var arrays := original.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if arrays[Mesh.ARRAY_NORMAL] == null or arrays[Mesh.ARRAY_NORMAL].is_empty():
			# Preserve original vertices, UVs, indices, and material; only add normals.
			var normals := PackedVector3Array()
			normals.resize(vertices.size())
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for i in range(vertices.size()):
					indices.append(i)
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
			arrays[Mesh.ARRAY_NORMAL] = normals
		fixed.add_surface_from_arrays(original.surface_get_primitive_type(surface), arrays)
		fixed.surface_set_material(surface, original.surface_get_material(surface))
	corrected_meshes[original] = fixed
	return fixed

func _build_telegraph() -> void:
	telegraph = MeshInstance3D.new()
	telegraph.name = "AttackTelegraph"
	var ring := TorusMesh.new()
	ring.inner_radius = 2.1
	ring.outer_radius = 2.3
	telegraph.mesh = ring
	telegraph.position.y = 0.09
	telegraph.scale.y = 0.08
	telegraph_material = StandardMaterial3D.new()
	telegraph_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	telegraph_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	telegraph_material.emission_enabled = true
	telegraph.material_override = telegraph_material
	telegraph.visible = false
	add_child(telegraph)
	var marker := MeshInstance3D.new()
	marker.name = "ChargeDirection"
	var strip := BoxMesh.new()
	strip.size = Vector3(0.3, 0.02, 5.0)
	marker.mesh = strip
	marker.position = Vector3(0, 0.1, -3.7)
	marker.material_override = telegraph_material
	telegraph.add_child(marker)

func _build_health_bar() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "LionBossHUD"
	canvas.layer = 3
	add_child(canvas)
	boss_panel = PanelContainer.new()
	boss_panel.name = "LionBossPanel"
	boss_panel.anchor_left = 0.5
	boss_panel.anchor_right = 0.5
	boss_panel.anchor_top = 1.0
	boss_panel.anchor_bottom = 1.0
	boss_panel.offset_left = -300
	boss_panel.offset_right = 300
	boss_panel.offset_top = -150
	boss_panel.offset_bottom = -75
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.025, 0.035, 0.025, 0.95)
	background.border_color = Color(0.70, 0.48, 0.14)
	background.set_border_width_all(2)
	background.content_margin_left = 16
	background.content_margin_right = 16
	background.content_margin_top = 8
	background.content_margin_bottom = 8
	boss_panel.add_theme_stylebox_override("panel", background)
	canvas.add_child(boss_panel)
	var box := VBoxContainer.new()
	boss_panel.add_child(box)
	var title := Label.new()
	title.text = "LION — MEMORY FOREST GUARDIAN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(560, 24)
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.055, 0.035)
	var empty := StyleBoxFlat.new()
	empty.bg_color = Color(0.16, 0.025, 0.015)
	health_bar.add_theme_stylebox_override("fill", fill)
	health_bar.add_theme_stylebox_override("background", empty)
	box.add_child(health_bar)
