extends CharacterBody3D

signal defeated

var player: CharacterBody3D

var max_health := 40.0
var health := 40.0

var move_speed := 2.5
var damage := 10.0
var attack_range := 1.5
var attack_cooldown := 1.0

var can_attack := true
var is_dead := false


func _ready() -> void:
	add_to_group("enemies")
	_build_enemy_model()


func set_player(target: CharacterBody3D) -> void:
	player = target


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_instance_valid(player):
		return

	var offset := player.global_position - global_position
	var distance := offset.length()

	if distance > attack_range:
		var direction := offset.normalized()

		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed

	else:
		velocity.x = 0
		velocity.z = 0

		if can_attack:
			_attack()

	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0

	move_and_slide()


func _attack() -> void:
	can_attack = false

	if is_instance_valid(player):
		player.take_damage(damage)

	await get_tree().create_timer(attack_cooldown).timeout

	if not is_dead:
		can_attack = true


func take_damage(amount: float) -> void:
	if is_dead:
		return

	health -= amount

	if health <= 0:
		_die()


func _die() -> void:
	is_dead = true

	remove_from_group("enemies")

	defeated.emit()

	queue_free()


func _build_enemy_model() -> void:
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()

	shape.radius = 0.5
	shape.height = 1.4

	collision.shape = shape
	collision.position.y = 0.7

	add_child(collision)

	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()

	mesh.radius = 0.5
	mesh.height = 1.4

	body.mesh = mesh
	body.position.y = 0.7

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.38, 0.08, 0.08)

	body.material_override = material

	add_child(body)
