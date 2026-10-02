extends CharacterBody3D

signal defeated

const JAGUAR_MODEL := preload("res://assets/enemies/jaguar/jaguar.glb")
const MODEL_SCALE := 2.0
# The animated head-to-tail direction is (-0.5, 0, 0.866), not Godot's -Z.
const MODEL_YAW := -150.0

enum JaguarState { IDLE, CHASE, WINDUP, LUNGE, RECOVER, DEAD }

var max_health := 80.0
var health := 80.0
var damage := 16.0
var move_speed := 4.2
var attack_cooldown := 2.0
var detection_range := 18.0
var attack_distance := 2.7
var stopping_distance := 1.9
var hit_distance := 2.05
var lunge_speed := 8.0

var player: CharacterBody3D
var model: Node3D
var animator: AnimationPlayer
var health_bar: ProgressBar
var state := JaguarState.IDLE
var is_dead := false
var state_time := 0.0
var cooldown_remaining := 0.0
var attack_direction := Vector3.FORWARD
var attack_hit := false
var hit_flash_remaining := 0.0
var hit_flash_started := false
var hit_materials: Array[BaseMaterial3D] = []

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("jaguars")
	_build_model()
	_build_health_bar()

func set_player(target: CharacterBody3D) -> void:
	player = target

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	state_time += delta
	velocity.x = 0.0
	velocity.z = 0.0
	var target_valid: bool = is_instance_valid(player) and not player.get("is_dead")
	var offset := Vector3.ZERO
	var distance := INF
	if target_valid:
		offset = player.global_position - global_position
		offset.y = 0.0
		distance = offset.length()

	match state:
		JaguarState.IDLE, JaguarState.CHASE:
			if target_valid and distance <= detection_range:
				state = JaguarState.CHASE
				_face(offset, delta)
				if distance <= attack_distance and cooldown_remaining <= 0.0:
					attack_direction = offset.normalized()
					attack_hit = false
					_set_state(JaguarState.WINDUP)
				elif distance > stopping_distance:
					var direction := offset.normalized()
					# Spread the pack without pushing Jaguars into their target.
					for other in get_tree().get_nodes_in_group("jaguars"):
						if other == self or not is_instance_valid(other):
							continue
						var away: Vector3 = global_position - other.global_position
						away.y = 0.0
						if away.length() < 1.5 and away.length() > 0.01:
							direction += away.normalized() * 0.4
					var speed := minf(move_speed, (distance - stopping_distance) / delta)
					velocity.x = direction.normalized().x * speed
					velocity.z = direction.normalized().z * speed
				else:
					state = JaguarState.IDLE
			else:
				state = JaguarState.IDLE
		JaguarState.WINDUP:
			# Telegraph the pounce; no damage is possible during windup.
			model.position.y = 0.04 - 0.10 * minf(state_time / 0.30, 1.0)
			if state_time >= 0.30:
				_set_state(JaguarState.LUNGE)
		JaguarState.LUNGE:
			velocity.x = attack_direction.x * lunge_speed
			velocity.z = attack_direction.z * lunge_speed
			model.position.y = 0.04 + sin(minf(state_time / 0.24, 1.0) * PI) * 0.30
			if state_time >= 0.24:
				velocity.x = 0.0
				velocity.z = 0.0
				cooldown_remaining = attack_cooldown
				_set_state(JaguarState.RECOVER)
		JaguarState.RECOVER:
			model.position.y = lerpf(model.position.y, 0.04, minf(delta * 15.0, 1.0))
			if state_time >= 0.55:
				_set_state(JaguarState.CHASE)

	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	# Check the post-movement contact only while the lunge is active.
	if state == JaguarState.LUNGE and target_valid and not attack_hit:
		var contact := player.global_position - global_position
		var vertical_distance := absf(contact.y)
		contact.y = 0.0
		if vertical_distance < 1.2 and contact.length() <= hit_distance and attack_direction.dot(contact.normalized()) > 0.4:
			attack_hit = true
			player.take_damage(damage)
			velocity.x = 0.0
			velocity.z = 0.0
			cooldown_remaining = attack_cooldown
			_set_state(JaguarState.RECOVER)

func _face(direction: Vector3, delta: float) -> void:
	if direction.length_squared() > 0.0001:
		rotation.y = rotate_toward(rotation.y, atan2(-direction.x, -direction.z), 8.0 * delta)

func _set_state(next: JaguarState) -> void:
	state = next
	state_time = 0.0
	if next == JaguarState.WINDUP:
		# Lock the heading before the pounce instead of homing through the player.
		rotation.y = atan2(-attack_direction.x, -attack_direction.z)

func take_damage(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	health_bar.value = health
	hit_flash_remaining = 0.12
	hit_flash_started = true
	for material in hit_materials:
		material.emission_enabled = true
		material.emission = Color(0.75, 1.0, 0.94)
		material.emission_energy_multiplier = 1.2
	if health <= 0.0:
		_die()
	else:
		# A hit interrupts the windup/lunge and gives a short recovery window.
		cooldown_remaining = maxf(cooldown_remaining, 0.65)
		_set_state(JaguarState.RECOVER)
		model.position.y = 0.11

func _process(delta: float) -> void:
	_update_flash(delta)

func _update_flash(delta: float) -> void:
	if hit_flash_started:
		hit_flash_started = false
		return
	if hit_flash_remaining <= 0.0:
		return
	hit_flash_remaining -= delta
	if hit_flash_remaining <= 0.0:
		for material in hit_materials:
			var original: Dictionary = material.get_meta("hit_emission_original")
			material.emission_enabled = original.enabled
			material.emission = original.color
			material.emission_energy_multiplier = original.energy

func _die() -> void:
	is_dead = true
	_set_state(JaguarState.DEAD)
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	remove_from_group("enemies")
	remove_from_group("jaguars")
	animator.pause()
	# The source has no death clip; use a short fall, then remove the body.
	var tween := create_tween()
	tween.tween_property(model, "rotation:z", -PI / 2.0, 0.30)
	tween.parallel().tween_property(model, "position:y", 0.18, 0.30)
	tween.tween_callback(queue_free)
	defeated.emit()

func _build_model() -> void:
	model = JAGUAR_MODEL.instantiate()
	model.name = "JaguarModel"
	model.scale = Vector3.ONE * MODEL_SCALE
	model.rotation_degrees.y = MODEL_YAW
	# Posed vertices sampled at 0, 3, 7, 10 and 14 seconds put paws near y=0.
	model.position = Vector3(0.0, 0.04, 0.0)
	add_child(model)
	for mesh_node in model.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh_node.mesh.get_surface_count()):
			var source := mesh_node.mesh.surface_get_material(surface) as BaseMaterial3D
			if source:
				# Per-enemy copies keep original textures and avoid flashing the pack.
				var material := source.duplicate() as BaseMaterial3D
				mesh_node.set_surface_override_material(surface, material)
				material.set_meta("hit_emission_original", {"enabled":material.emission_enabled, "color":material.emission, "energy":material.emission_energy_multiplier})
				hit_materials.append(material)
	animator = model.find_children("*", "AnimationPlayer", true, false)[0]
	var animation_name := animator.get_animation_list()[0]
	# Loop an instance-local copy of the supplied standing/stretching clip.
	var library := animator.get_animation_library("").duplicate(true) as AnimationLibrary
	animator.remove_animation_library("")
	animator.add_animation_library("", library)
	library.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
	animator.play(animation_name)
	animator.seek(randf() * library.get_animation(animation_name).length, true)

	var collision := CollisionShape3D.new()
	collision.name = "JaguarCollision"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.72
	shape.height = 2.4
	collision.shape = shape
	collision.rotation_degrees.x = 90.0
	collision.position = Vector3(0, 0.72, 0)
	add_child(collision)

func _build_health_bar() -> void:
	var viewport := SubViewport.new()
	viewport.name = "HealthBarViewport"
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
	sprite.name = "JaguarHealthBar"
	sprite.texture = viewport.get_texture()
	sprite.position = Vector3(0, 2.05, 0)
	sprite.pixel_size = 0.007
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	add_child(sprite)
