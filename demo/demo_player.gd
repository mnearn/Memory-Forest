extends CharacterBody3D

signal died
signal health_changed(current_health: float, max_health: float)

var base_health: float = 100.0
var base_damage: float = 20.0
var base_speed: float = 6.0
var base_attack_cooldown: float = 0.65

var max_health: float
var health: float
var damage: float
var move_speed: float
var attack_cooldown: float

var can_attack := true
var is_dead := false


func _ready() -> void:
	_apply_inherited_stats()
	_build_player_model()

	health = max_health
	health_changed.emit(health, max_health)


func _apply_inherited_stats() -> void:
	max_health = base_health + InheritanceManager.get_bonus_health()

	damage = (
		base_damage
		* InheritanceManager.get_attack_multiplier()
	)

	move_speed = (
		base_speed
		* InheritanceManager.get_movement_speed_multiplier()
	)

	attack_cooldown = (
		base_attack_cooldown
		/ InheritanceManager.get_attack_speed_multiplier()
	)


func _physics_process(_delta: float) -> void:
	if is_dead:
		return

	var input := Vector2.ZERO

	if Input.is_key_pressed(KEY_A):
		input.x -= 1.0

	if Input.is_key_pressed(KEY_D):
		input.x += 1.0

	if Input.is_key_pressed(KEY_W):
		input.y -= 1.0

	if Input.is_key_pressed(KEY_S):
		input.y += 1.0

	input = input.normalized()

	velocity.x = input.x * move_speed
	velocity.z = input.y * move_speed

	if not is_on_floor():
		velocity.y -= 20.0 * _delta
	else:
		velocity.y = 0.0

	move_and_slide()

	if Input.is_key_pressed(KEY_SPACE) and can_attack:
		_attack()


func _attack() -> void:
	can_attack = false

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue

		var distance := global_position.distance_to(enemy.global_position)

		if distance <= 2.5:
			enemy.take_damage(damage)

	await get_tree().create_timer(attack_cooldown).timeout

	if not is_dead:
		can_attack = true


func take_damage(amount: float) -> void:
	if is_dead:
		return

	health -= amount
	health = max(health, 0.0)

	health_changed.emit(health, max_health)

	if health <= 0:
		_die()


func _die() -> void:
	if is_dead:
		return

	is_dead = true
	velocity = Vector3.ZERO
	died.emit()


func _build_player_model() -> void:
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()

	shape.radius = 0.45
	shape.height = 1.8

	collision.shape = shape
	collision.position.y = 0.9

	add_child(collision)

	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()

	mesh.radius = 0.45
	mesh.height = 1.8

	body.mesh = mesh
	body.position.y = 0.9

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.72, 0.46, 0.20)

	body.material_override = material

	add_child(body)

	var marker := MeshInstance3D.new()
	var marker_mesh := BoxMesh.new()

	marker_mesh.size = Vector3(0.7, 0.25, 0.5)
	marker.mesh = marker_mesh
	marker.position = Vector3(0, 1.35, -0.38)

	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = Color(0.9, 0.22, 0.08)

	marker.material_override = marker_material

	add_child(marker)
