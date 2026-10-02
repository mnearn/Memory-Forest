extends CharacterBody3D
const WorldEventSFX = preload("res://audio/world_event_sfx.gd")
const SNAKE_HISS = preload("res://audio/enemies/anaconda/anaconda_hiss.mp3")
var hiss_sfx: AudioStreamPlayer3D

signal defeated

const SNAKE_MODEL := preload("res://assets/enemies/anaconda/snake_attack_animations_multiple.glb")
enum SnakeState { CHASE, TELEGRAPH, BITE, RECOVER, DEAD }

var max_health := 60.0
var health := 60.0
var damage := 12.0
var move_speed := 3.6
var attack_cooldown := 1.8
var player: CharacterBody3D
var model: Node3D
var animator: AnimationPlayer
var skeleton: Skeleton3D
var health_bar: ProgressBar
var hit_materials: Array[BaseMaterial3D] = []
var state := SnakeState.CHASE
var is_dead := false
var state_time := 0.0
var cooldown_remaining := 0.0
var flash_remaining := 0.0
var flash_started := false
var slither_time := 34.0
var attack_direction := Vector3.FORWARD
var attack_hit := false
var animation_time := 34.0

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("snakes")
	_build_model()
	_build_health_bar()
	hiss_sfx = WorldEventSFX.attach(self, SNAKE_HISS, "SnakeHissSFX", -18.0, "snake_hiss_audio", 3.2)

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
				var original: Dictionary = material.get_meta("hit_emission_original")
				material.emission_enabled = original.enabled
				material.emission = original.color
				material.emission_energy_multiplier = original.energy

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	state_time += delta
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
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
		SnakeState.CHASE:
			slither_time = 34.0 + fmod(slither_time - 34.0 + delta, 3.0)
			animation_time = slither_time
			if valid_target and distance < 18.0:
				rotation.y = rotate_toward(rotation.y, atan2(-offset.x, -offset.z), delta * 8.0)
				if distance <= 2.0 and cooldown_remaining <= 0.0:
					attack_direction = offset.normalized()
					rotation.y = atan2(-offset.x, -offset.z)
					attack_hit = false
					_change_state(SnakeState.TELEGRAPH)
				elif distance > 1.8:
					var direction := offset.normalized()
					for other in get_tree().get_nodes_in_group("snakes"):
						if other == self or not is_instance_valid(other):
							continue
						var away: Vector3 = global_position - other.global_position
						away.y = 0.0
						if away.length() > 0.01 and away.length() < 1.5:
							direction += away.normalized() * 0.5
					var speed := minf(move_speed, (distance - 1.8) / delta)
					velocity.x = direction.normalized().x * speed
					velocity.z = direction.normalized().z * speed
		SnakeState.TELEGRAPH:
			animation_time = 8.0 + minf(state_time, 0.20) * 2.0
			if state_time >= 0.20:
				_change_state(SnakeState.BITE)
		SnakeState.BITE:
			animation_time = 8.4 + minf(state_time, 0.45) * 2.0
			# Brief locked-direction lunge. Stop advancing once close enough.
			if valid_target and distance > 1.5 and state_time < 0.25:
				var speed := minf(2.4, (distance - 1.5) / delta)
				velocity.x = attack_direction.x * speed
				velocity.z = attack_direction.z * speed
			if state_time >= 0.45:
				cooldown_remaining = attack_cooldown
				_change_state(SnakeState.RECOVER)
		SnakeState.RECOVER:
			animation_time = 9.3 + minf(state_time, 0.40) * 2.0
			if state_time >= 0.40:
				_change_state(SnakeState.CHASE)
	animator.seek(animation_time, true)
	skeleton.force_update_all_bone_transforms()
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	# Only the advancing/closing jaw portion can hurt the player, once per bite.
	if state == SnakeState.BITE and animation_time >= 8.6 and animation_time <= 9.2 and valid_target and not attack_hit:
		var head := skeleton.to_global(skeleton.get_bone_global_pose(9).origin)
		var target_point := player.global_position
		target_point.y += clampf(head.y - target_point.y, 0.2, 1.6)
		var to_player := player.global_position - global_position
		to_player.y = 0.0
		if head.distance_to(target_point) < 0.95 and attack_direction.dot(to_player.normalized()) > 0.5:
			attack_hit = true
			player.take_damage(damage)

func _change_state(next: SnakeState) -> void:
	state = next
	state_time = 0.0
	if next == SnakeState.TELEGRAPH:
		hiss_sfx.play_event()

func take_damage(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	health_bar.value = health
	flash_remaining = 0.12
	flash_started = true
	for material in hit_materials:
		material.emission_enabled = true
		material.emission = Color(0.75, 1.0, 0.94)
		material.emission_energy_multiplier = 1.2
	if health <= 0.0:
		is_dead = true
		_change_state(SnakeState.DEAD)
		collision_layer = 0
		collision_mask = 0
		remove_from_group("enemies")
		remove_from_group("snakes")
		var tween := create_tween()
		tween.tween_property(model, "rotation:z", 0.35, 0.25)
		tween.parallel().tween_property(model, "scale", model.scale * 0.75, 0.35)
		tween.tween_callback(queue_free)
		defeated.emit()
	else:
		# Interrupt attacks without needing an invented skeletal hit clip.
		cooldown_remaining = maxf(cooldown_remaining, 0.65)
		_change_state(SnakeState.RECOVER)

func _build_model() -> void:
	model = Node3D.new()
	model.name = "SnakeVisual"
	model.scale = Vector3.ONE * 0.03
	model.rotation_degrees.y = 90.0
	model.position.y = 0.04
	add_child(model)
	var source := SNAKE_MODEL.instantiate()
	# Fit the animated brown variant; the source contains two separate snakes.
	source.position = Vector3(-20.0, 0.0, -21.23)
	model.add_child(source)
	var meshes := source.find_children("*", "MeshInstance3D", true, false)
	meshes[0].visible = false
	# Keep both source rigs and animation tracks intact, displaying one snake.
	skeleton = meshes[1].get_parent() as Skeleton3D
	for mesh_node in meshes:
		for surface in range(mesh_node.mesh.get_surface_count()):
			var original := mesh_node.mesh.surface_get_material(surface) as BaseMaterial3D
			if original:
				var material := original.duplicate() as BaseMaterial3D
				mesh_node.set_surface_override_material(surface, material)
				material.set_meta("hit_emission_original", {"enabled":material.emission_enabled, "color":material.emission, "energy":material.emission_energy_multiplier})
				hit_materials.append(material)
	animator = source.find_child("AnimationPlayer", true, false) as AnimationPlayer
	animator.play("Animation")
	animator.seek(34.0, true)
	animator.pause()
	var collision := CollisionShape3D.new()
	collision.name = "SnakeCollision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.40
	capsule.height = 2.6
	collision.shape = capsule
	collision.rotation_degrees.x = 90.0
	collision.position = Vector3(0, 0.4, 0.1)
	add_child(collision)

func _build_health_bar() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(200, 36)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	health_bar = ProgressBar.new()
	health_bar.position = Vector2(4, 12)
	health_bar.size = Vector2(192, 18)
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color("101714")
	background.border_color = Color("315c52")
	background.set_border_width_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("7b252b")
	health_bar.add_theme_stylebox_override("background", background)
	health_bar.add_theme_stylebox_override("fill", fill)
	viewport.add_child(health_bar)
	var sprite := Sprite3D.new()
	sprite.name = "SnakeHealthBar"
	sprite.texture = viewport.get_texture()
	sprite.position = Vector3(0, 1.85, 0)
	sprite.pixel_size = 0.007
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	add_child(sprite)
