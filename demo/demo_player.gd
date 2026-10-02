extends CharacterBody3D

const PlayerVisualScene = preload("res://assets/player/blake/blake_player.tscn")
const WorldEventSFX = preload("res://audio/world_event_sfx.gd")
const SWORD_SWING = preload("res://audio/weapons/sword/sword_swing.mp3")
var sword_sfx: AudioStreamPlayer3D
var player_visual: Node3D

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
	sword_sfx = WorldEventSFX.attach(self, SWORD_SWING, "SwordSwingSFX", -12.0)

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
	player_visual.update_movement(velocity, _delta)

	if global_position.y < -4.0:
		_die()
		return

	if Input.is_key_pressed(KEY_SPACE) and can_attack:
		_attack()


func _attack() -> void:
	can_attack = false
	# Start the unchanged cooldown now; contact occurs during the visible swing.
	var cooldown_timer := get_tree().create_timer(attack_cooldown)
	_show_attack_swing()
	sword_sfx.play_event()
	await get_tree().create_timer(player_visual.get_attack_contact_delay(attack_cooldown)).timeout
	if is_dead:
		return

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue

		var distance := global_position.distance_to(enemy.global_position)

		if distance <= 2.5:
			enemy.take_damage(damage)

	await cooldown_timer.timeout

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
	player_visual.die()
	died.emit()


func _build_player_model() -> void:
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()

	shape.radius = 0.45
	shape.height = 1.8

	collision.shape = shape
	collision.position.y = 0.9

	add_child(collision)

	player_visual = PlayerVisualScene.instantiate()
	add_child(player_visual)


func _show_attack_swing() -> void:
	player_visual.attack(attack_cooldown)
