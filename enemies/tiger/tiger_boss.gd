extends CharacterBody3D
const WorldEventSFX = preload("res://audio/world_event_sfx.gd")
const MEMORY_ROAR = preload("res://audio/enemies/lion/lion_growl.mp3")
var roar_sfx: AudioStreamPlayer3D
signal defeated
const CORRUPTION_MATERIAL := preload("res://enemies/tiger/memory_tiger.tres")
const MODEL_SCALE := 0.024
const MODEL_HEIGHT := 0.04
enum TigerState { CHASE, MELEE_WINDUP, MELEE, CHARGE_WINDUP, CHARGE, RECOVER, DEAD, ROAR_WINDUP, ROAR }
var animator: AnimationPlayer
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
var hit_materials: Array[ShaderMaterial] = []
var state := TigerState.CHASE
var state_time := 0.0
var attack_remaining := 0.0
var charge_remaining := 3.0
var recovery_duration := 0.5
var charge_travel := 0.0
var attack_direction := Vector3.FORWARD
var attack_hit := false
var is_dead := false
var flash_remaining := 0.0
var flash_started := false
var roar_remaining := 8.0
var roar_cooldown := 10.0
var roar_radius := 3.8
var roar_damage := 18.0
var roar_area: MeshInstance3D

func _ready() -> void:
	add_to_group("enemies")
	_build_model()
	_build_telegraph()
	_build_health_bar()
	roar_sfx = WorldEventSFX.attach(self, MEMORY_ROAR, "MemoryRoarSFX", -14.0, "memory_roar_audio", 6.4)

func set_player(target: CharacterBody3D) -> void:
	player = target

func _process(delta: float) -> void:
	if flash_started:
		flash_started = false
		return
	if flash_remaining > 0.0:
		flash_remaining -= delta
		if flash_remaining <= 0.0:
			for material in hit_materials:
				material.set_shader_parameter("hit_flash", 0.0)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	state_time += delta
	attack_remaining = maxf(0.0, attack_remaining - delta)
	charge_remaining = maxf(0.0, charge_remaining - delta)
	roar_remaining = maxf(0.0, roar_remaining - delta)
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
		TigerState.CHASE:
			if valid_target:
				rotation.y = rotate_toward(rotation.y, atan2(-offset.x, -offset.z), delta * 6.0)
				if roar_remaining <= 0.0 and distance <= 5.5:
					_begin_roar(offset)
				elif charge_remaining <= 0.0 and distance >= 3.0 and distance <= 12.0:
					_begin_attack(TigerState.CHARGE_WINDUP, offset)
				elif distance <= 2.8 and attack_remaining <= 0.0:
					_begin_attack(TigerState.MELEE_WINDUP, offset)
				elif distance > 2.3:
					var speed := minf(move_speed, (distance - 2.3) / delta)
					velocity.x = offset.normalized().x * speed
					velocity.z = offset.normalized().z * speed
		TigerState.MELEE_WINDUP:
			model.position.z = 0.18 * minf(state_time / 0.30, 1.0)
			if state_time >= 0.30:
				_change_state(TigerState.MELEE)
		TigerState.MELEE:
			model.position.z = -0.40 * sin(minf(state_time / 0.28, 1.0) * PI)
			animator.seek(2.5 + state_time * 2.8, true)
			if state_time >= 0.09 and state_time <= 0.20:
				_try_hit(damage, 2.8, valid_target)
			if state_time >= 0.28:
				attack_remaining = attack_cooldown
				_recover(0.50)
		TigerState.CHARGE_WINDUP:
			telegraph_material.emission_energy_multiplier = 1.0 + sin(state_time * 20.0) * 0.35
			animator.seek(3.75 + minf(state_time / 0.65, 1.0) * 0.75, true)
			model.position.z = 0.22 * minf(state_time / 0.65, 1.0)
			if state_time >= 0.65:
				charge_travel = 0.0
				_change_state(TigerState.CHARGE)
		TigerState.CHARGE:
			model.position.z = -0.25
			model.position.y = MODEL_HEIGHT + sin(minf(state_time / 0.70, 1.0) * PI) * 0.30
			animator.seek(4.5 + state_time * 2.0, true)
			velocity.x = attack_direction.x * charge_speed
			velocity.z = attack_direction.z * charge_speed
			var next_position := global_position + Vector3(velocity.x, 0, velocity.z) * delta
			# Keep missed pounces inside the open demo floor instead of falling off.
			if charge_travel >= charge_range or state_time >= charge_range / charge_speed or absf(next_position.x) > 13.0 or absf(next_position.z) > 11.0:
				velocity.x = 0.0
				velocity.z = 0.0
				_end_charge()
		TigerState.RECOVER:
			model.position.z = lerpf(model.position.z, 0.0, minf(delta * 12.0, 1.0))
			model.position.y = lerpf(model.position.y, MODEL_HEIGHT, minf(delta * 12.0, 1.0))
			if state_time >= recovery_duration:
				_change_state(TigerState.CHASE)
		TigerState.ROAR_WINDUP:
			animator.seek(7.25 + minf(state_time / 0.90, 1.0) * 0.75, true)
			roar_area.scale = Vector3.ONE * lerpf(0.25, 1.0, minf(state_time / 0.90, 1.0))
			if state_time >= 0.90:
				_change_state(TigerState.ROAR)
		TigerState.ROAR:
			animator.seek(8.75 + minf(state_time, 0.25), true)
			if not attack_hit:
				attack_hit = true
				if valid_target and distance <= roar_radius and absf(player.global_position.y - global_position.y) < 1.4:
					player.take_damage(roar_damage)
			if state_time >= 0.25:
				roar_remaining = roar_cooldown
				attack_remaining = maxf(attack_remaining, 0.8)
				_recover(0.85)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0
	var before := global_position
	move_and_slide()
	if state == TigerState.CHARGE:
		charge_travel += Vector2(global_position.x - before.x, global_position.z - before.z).length()
		_try_hit(charge_damage, 2.4, valid_target)
		if attack_hit or (state_time > 0.08 and is_on_wall()):
			_end_charge()

func _begin_attack(next: TigerState, direction: Vector3) -> void:
	attack_direction = direction.normalized()
	rotation.y = atan2(-direction.x, -direction.z)
	attack_hit = false
	_change_state(next)
	telegraph.visible = true
	telegraph.scale = Vector3(1.35, 0.08, 1.35) if next == TigerState.CHARGE_WINDUP else Vector3(1, 0.08, 1)
	telegraph_material.albedo_color = Color(0.396, 0.839, 0.765, 0.65) if next == TigerState.CHARGE_WINDUP else Color(0.8, 0.14, 0.10, 0.55)
	telegraph_material.emission = telegraph_material.albedo_color
	telegraph.get_node("ChargeDirection").visible = next == TigerState.CHARGE_WINDUP

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
	roar_area.hide()
	_change_state(TigerState.RECOVER)

func _change_state(next: TigerState) -> void:
	state = next
	state_time = 0.0
	if next == TigerState.ROAR:
		roar_area.material_override.albedo_color = Color("8ff5df", 0.38)
	if is_instance_valid(animator):
		if next == TigerState.CHASE or next == TigerState.RECOVER:
			animator.play("Idle")
		else:
			animator.pause()
	for material in hit_materials:
		var energy := 0.35
		if next == TigerState.CHARGE_WINDUP or next == TigerState.CHARGE:
			energy = 2.5
		elif next == TigerState.ROAR_WINDUP or next == TigerState.ROAR:
			energy = 4.0
		material.set_shader_parameter("memory_energy", energy)

func _begin_roar(direction: Vector3) -> void:
	if direction.length_squared() > 0.001:
		rotation.y = atan2(-direction.x, -direction.z)
	attack_hit = false
	_change_state(TigerState.ROAR_WINDUP)
	roar_sfx.play_event()
	telegraph.visible = true
	telegraph.scale = Vector3(roar_radius / 2.2, 0.08, roar_radius / 2.2)
	telegraph.get_node("ChargeDirection").hide()
	telegraph_material.albedo_color = Color(0.396, 0.839, 0.765, 0.70)
	telegraph_material.emission = telegraph_material.albedo_color
	roar_area.material_override.albedo_color = Color("65d6c3", 0.20)
	roar_area.scale = Vector3.ONE * 0.25
	roar_area.show()

func take_damage(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	health_bar.value = health
	flash_remaining = 0.12
	flash_started = true
	for material in hit_materials:
		material.set_shader_parameter("hit_flash", 1.0)
	if health <= 0.0:
		_die()

func _die() -> void:
	is_dead = true
	_change_state(TigerState.DEAD)
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	telegraph.hide()
	roar_area.hide()
	boss_panel.hide()
	remove_from_group("enemies")
	var tween := create_tween()
	tween.tween_property(model, "rotation:z", -PI / 2.0, 0.55)
	tween.parallel().tween_property(model, "position:y", 0.7, 0.55)
	tween.tween_callback(func():
		defeated.emit()
		queue_free())

func _build_model() -> void:
	model = $TigerModel
	for mesh_node in model.find_children("*", "MeshInstance3D", true, false):
		var material := CORRUPTION_MATERIAL.duplicate() as ShaderMaterial
		mesh_node.material_override = material
		hit_materials.append(material)
	animator = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var library := animator.get_animation_library("").duplicate(true) as AnimationLibrary
	animator.remove_animation_library("")
	animator.add_animation_library("", library)
	library.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
	animator.play("Idle")
	var collision := CollisionShape3D.new()
	collision.name = "TigerCollision"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.72
	shape.height = 3.2
	collision.shape = shape
	collision.rotation_degrees.x = 90.0
	collision.position.y = 0.72
	add_child(collision)

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
	roar_area = MeshInstance3D.new()
	roar_area.name = "MemoryRoarRadius"
	var disk := CylinderMesh.new()
	disk.top_radius = roar_radius
	disk.bottom_radius = roar_radius
	disk.height = 0.02
	roar_area.mesh = disk
	roar_area.position.y = 0.08
	var area_material := StandardMaterial3D.new()
	area_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	area_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	area_material.albedo_color = Color("65d6c3", 0.20)
	roar_area.material_override = area_material
	roar_area.visible = false
	add_child(roar_area)

func _build_health_bar() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "MemoryTigerBossHUD"
	canvas.layer = 3
	add_child(canvas)
	boss_panel = PanelContainer.new()
	boss_panel.name = "MemoryTigerBossPanel"
	boss_panel.anchor_left = 0.5
	boss_panel.anchor_right = 0.5
	boss_panel.anchor_top = 0.0
	boss_panel.anchor_bottom = 0.0
	boss_panel.offset_left = -310
	boss_panel.offset_right = 310
	boss_panel.offset_top = 110
	boss_panel.offset_bottom = 206
	var background := StyleBoxFlat.new()
	background.bg_color = Color("101714", 0.92)
	background.border_color = Color("65d6c3")
	background.set_border_width_all(1)
	background.set_corner_radius_all(6)
	background.content_margin_left = 16
	background.content_margin_right = 16
	background.content_margin_top = 8
	background.content_margin_bottom = 8
	boss_panel.add_theme_stylebox_override("panel", background)
	canvas.add_child(boss_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	boss_panel.add_child(box)
	var title := Label.new()
	title.text = "MEMORY TIGER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("e5e8e4"))
	box.add_child(title)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(560, 18)
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("7b252b")
	fill.set_corner_radius_all(2)
	var empty := StyleBoxFlat.new()
	empty.bg_color = Color("17251e")
	empty.set_corner_radius_all(2)
	health_bar.add_theme_stylebox_override("fill", fill)
	health_bar.add_theme_stylebox_override("background", empty)
	box.add_child(health_bar)
	var caption := Label.new()
	caption.text = "BOSS"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", Color("a6b5ad"))
	box.add_child(caption)

