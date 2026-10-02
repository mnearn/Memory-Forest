extends CharacterBody3D

var main: Node3D
var camera: Camera3D
var max_health: float = 100.0
var health: float = max_health
var move_speed: float = 8.0
var acceleration: float = 32.0
var deceleration: float = 40.0
var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var dash_speed: float = 18.0
var dash_duration: float = 0.22
var dash_cooldown: float = 0.75
var light_damage: float = 15.0
var heavy_damage: float = 28.0
var attack_time_left: float = 0.0
var heavy_time_left: float = 0.0
var dash_time_left: float = 0.0
var dash_cooldown_left: float = 0.0
var facing: Vector3 = Vector3.FORWARD
var dash_direction: Vector3 = Vector3.FORWARD
var dead: bool = false

func _ready() -> void:
	max_health += InheritanceManager.get_bonus_health()
	move_speed *= InheritanceManager.get_movement_speed_multiplier()
	light_damage *= InheritanceManager.get_attack_multiplier()
	heavy_damage *= InheritanceManager.get_attack_multiplier()
	health = max_health

	var collision = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.8
	collision.shape = capsule
	add_child(collision)
	_setup_visuals()

func _setup_visuals() -> void:
	var body_mesh = CapsuleMesh.new()
	body_mesh.radius = 0.5
	body_mesh.height = 1.8
	var body = MeshInstance3D.new()
	body.mesh = body_mesh
	body.name = "Body"
	add_child(body)

	var weapon_mesh = BoxMesh.new()
	weapon_mesh.size = Vector3(0.25, 0.25, 1.25)
	var weapon = MeshInstance3D.new()
	weapon.mesh = weapon_mesh
	weapon.position = Vector3(0.8, 0.2, -0.4)
	weapon.rotation_degrees.x = 90.0
	add_child(weapon)

	var body_material = StandardMaterial3D.new()
	body_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	body_material.albedo_color = Color(0.15, 0.55, 1.0)
	body_material.emission_enabled = true
	body_material.emission = Color(0.05, 0.18, 0.5)
	body.material_override = body_material

func _physics_process(delta: float) -> void:
	if dead:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	if dash_time_left > 0.0:
		dash_time_left -= delta
		velocity.x = dash_direction.x * dash_speed
		velocity.z = dash_direction.z * dash_speed
		move_and_slide()
		return

	if dash_cooldown_left > 0.0:
		dash_cooldown_left -= delta
	if attack_time_left > 0.0:
		attack_time_left -= delta
	if heavy_time_left > 0.0:
		heavy_time_left -= delta

	var move_vector = _get_move_vector()
	if move_vector.length() > 0.01:
		move_vector = move_vector.normalized()
		facing = move_vector
		rotation.y = atan2(-move_vector.x, -move_vector.z)
		velocity.x = move_toward(velocity.x, move_vector.x * move_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, move_vector.z * move_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)

	move_and_slide()

func _get_move_vector() -> Vector3:
	var move_input = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A):
		move_input.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		move_input.x += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		move_input.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		move_input.y += 1.0

	if camera == null:
		return Vector3(move_input.x, 0.0, move_input.y)

	var forward = -camera.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		forward = Vector3.FORWARD
	forward = forward.normalized()

	var right = camera.global_basis.x
	right.y = 0.0
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	right = right.normalized()

	var direction = forward * -move_input.y + right * move_input.x
	return direction.normalized() if direction.length_squared() > 0.01 else Vector3.ZERO

func _input(event: InputEvent) -> void:
	if dead or not (event is InputEventKey):
		return
	if not event.pressed or event.echo:
		return

	var key_event := event as InputEventKey
	if key_event.keycode == KEY_SPACE or key_event.physical_keycode == KEY_SPACE:
		_light_attack()
	elif key_event.keycode == KEY_E or key_event.physical_keycode == KEY_E:
		_heavy_attack()
	elif key_event.keycode == KEY_SHIFT or key_event.physical_keycode == KEY_SHIFT:
		var move_vector = _get_move_vector()
		_dash(move_vector if move_vector.length() > 0.01 else facing)

func _dash(direction: Vector3) -> void:
	if dash_cooldown_left > 0.0:
		return
	dash_cooldown_left = dash_cooldown
	dash_time_left = dash_duration
	dash_direction = Vector3(direction.x, 0.0, direction.z).normalized()
	if dash_direction.length_squared() < 0.01:
		dash_direction = facing
	velocity.x = dash_direction.x * dash_speed
	velocity.z = dash_direction.z * dash_speed

func _light_attack() -> void:
	if attack_time_left > 0.0 or main == null:
		return
	attack_time_left = 0.35 / InheritanceManager.get_attack_speed_multiplier()
	if main.enemies.is_empty():
		return
	for enemy in main.enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.is_dead:
			continue
		var to_enemy = enemy.global_position - global_position
		to_enemy.y = 0.0
		var distance = to_enemy.length()
		if distance <= 2.8 and to_enemy.normalized().dot(facing) >= 0.0:
			enemy.take_damage(light_damage, global_position)

func _heavy_attack() -> void:
	if heavy_time_left > 0.0 or main == null:
		return
	heavy_time_left = 0.7 / InheritanceManager.get_attack_speed_multiplier()
	for enemy in main.enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.is_dead:
			continue
		var to_enemy = enemy.global_position - global_position
		to_enemy.y = 0.0
		var distance = to_enemy.length()
		if distance <= 4.3 and to_enemy.normalized().dot(facing) >= -0.25:
			enemy.take_damage(heavy_damage, global_position)

func take_damage(amount: float, source_position: Vector3) -> void:
	if dead:
		return

	health -= amount
	if health <= 0.0:
		health = 0.0
		dead = true
		if main != null and main.has_method("_on_player_defeated"):
			main._on_player_defeated()

func _process(delta: float) -> void:
	if dead:
		return
	if health < max_health and main != null and main.has_method("_register_enemy_defeat"):
		pass
