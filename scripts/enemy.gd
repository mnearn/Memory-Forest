extends CharacterBody3D

var main: Node3D
var kind: String = "brute"
var move_speed: float = 2.5
var attack_range: float = 2.2
var attack_damage: float = 10.0
var max_health: float = 50.0
var health: float = max_health
var attack_cooldown: float = 0.0
var difficulty_level: int = 1
var is_dead: bool = false

func init(_main: Node3D, _kind: String, _difficulty_level: int) -> void:
	main = _main
	kind = _kind
	difficulty_level = _difficulty_level

	match kind:
		"brute":
			move_speed = 2.2 + difficulty_level * 0.12
			attack_range = 2.6
			attack_damage = 10.0 + difficulty_level * 2.5
			max_health = 55.0 + difficulty_level * 12.5
		"skirmisher":
			move_speed = 3.5 + difficulty_level * 0.18
			attack_range = 1.9
			attack_damage = 8.0 + difficulty_level * 2.0
			max_health = 35.0 + difficulty_level * 8.0
		"ranger":
			move_speed = 2.0 + difficulty_level * 0.11
			attack_range = 10.0
			attack_damage = 12.0 + difficulty_level * 2.0
			max_health = 40.0 + difficulty_level * 10.0

	health = max_health
	attack_cooldown = 1.0
	_setup_visuals()

func _setup_visuals() -> void:
	var collision = CollisionShape3D.new()
	var capsule_shape = CapsuleShape3D.new()
	capsule_shape.radius = 0.45
	capsule_shape.height = 1.8
	collision.shape = capsule_shape
	collision.position.y = 0.9
	add_child(collision)

	var body_mesh = CapsuleMesh.new()
	body_mesh.radius = 0.5
	body_mesh.height = 1.8
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = body_mesh
	mesh_instance.position.y = 0.9
	add_child(mesh_instance)

	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	match kind:
		"brute":
			material.albedo_color = Color(0.78, 0.3, 0.25)
		"skirmisher":
			material.albedo_color = Color(0.67, 0.78, 0.24)
		"ranger":
			material.albedo_color = Color(0.35, 0.55, 0.93)
	mesh_instance.material_override = material

func _physics_process(delta: float) -> void:
	if is_dead or main == null or not is_instance_valid(main.player):
		return

	if attack_cooldown > 0.0:
		attack_cooldown -= delta

	var player = main.player
	var to_player = player.global_position - global_position
	var distance = to_player.length()
	var direction = to_player.normalized() if distance > 0.001 else Vector3.ZERO

	if distance > 0.1:
		if kind == "skirmisher":
			var strafe = Vector3(direction.z, 0.0, -direction.x).normalized()
			var dodge_bias = 0.35 if (int(global_position.x + global_position.z) % 2 == 0) else -0.35
			var desired_move = direction + strafe * dodge_bias
			desired_move = desired_move.normalized()
			velocity.x = desired_move.x * move_speed
			velocity.z = desired_move.z * move_speed
		else:
			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed

		if kind == "ranger" and distance <= 11.0:
			velocity *= 0.4
			if attack_cooldown <= 0.0:
				_fire_projectile(player)
		elif distance <= attack_range and attack_cooldown <= 0.0:
			_attack_player(player)

		if kind == "brute" and distance < 5.0:
			velocity *= 1.15

		move_and_slide()
		rotation.y = atan2(direction.x, direction.z)
	else:
		velocity = Vector3.ZERO

func _attack_player(player: Node3D) -> void:
	attack_cooldown = 1.1 if kind == "brute" else 0.7
	if player.has_method("take_damage"):
		player.take_damage(attack_damage, global_position)

func _fire_projectile(player: Node3D) -> void:
	attack_cooldown = 1.5
	var projectile = preload("res://scripts/projectile.gd").new()
	var direction = (player.global_position - global_position).normalized()
	projectile.init(main, "enemy", direction, attack_damage * 0.8)
	projectile.global_position = global_position + Vector3(0.0, 1.2, 0.0)
	main.add_child(projectile)

func take_damage(amount: float, source_position: Vector3) -> void:
	if is_dead:
		return

	health -= amount
	if health <= 0.0:
		health = 0.0
		_die()

func _die() -> void:
	is_dead = true
	velocity = Vector3.ZERO
	if main != null and main.has_method("_register_enemy_defeat"):
		main._register_enemy_defeat(self)
	queue_free()
