extends CharacterBody3D
const WorldEventSFX = preload("res://audio/world_event_sfx.gd")
const GORILLA_ROAR = preload("res://audio/enemies/gorilla/gorilla_roar.mp3")
var roar_sfx: AudioStreamPlayer3D

signal defeated

const GORILLA_MODEL = preload(
	"res://assets/enemies/gorilla/free_gorilla_visual.tscn"
)

var player: CharacterBody3D
var model: Node3D

# ============================================================
# GORILLA STATS
# ============================================================

var max_health: float = 120.0
var health: float = 120.0
var hit_flash_material: StandardMaterial3D
var hit_flash_remaining := 0.0
var hit_flash_started := false
var move_speed: float = 2.0
var health_bar: ProgressBar
var health_bar_container: SubViewport
var health_bar_sprite: Sprite3D
var melee_damage: float = 15.0
var slam_damage: float = 25.0

var melee_range: float = 2.4
var slam_range: float = 3.5

var attack_cooldown: float = 1.5
var slam_cooldown: float = 5.0

var can_attack: bool = true
var can_slam: bool = true
var is_attacking: bool = false
var is_dead: bool = false
var slam_warning: MeshInstance3D


func _ready() -> void:
	add_to_group("enemies")
	_build_gorilla()
	_build_health_bar()
	roar_sfx = WorldEventSFX.attach(self, GORILLA_ROAR, "GorillaRoarSFX", -15.0, "gorilla_roar_audio", 8.1)


func set_player(target: CharacterBody3D) -> void:
	player = target


# ============================================================
# MOVEMENT / AI
# ============================================================

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_instance_valid(player):
		return

	if is_attacking:
		velocity.x = 0.0
		velocity.z = 0.0
		_apply_gravity(delta)
		move_and_slide()
		return

	var offset := player.global_position - global_position
	var distance := offset.length()

	_face_player()

	# Chase but stop before overlapping the player.
	if distance > melee_range:
		var direction := offset.normalized()

		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed

		_fake_walk_motion()

	else:
		velocity.x = 0.0
		velocity.z = 0.0

		# Slam has priority when available.
		if can_slam and distance <= slam_range:
			_ground_slam()

		elif can_attack:
			_melee_attack()

	_apply_gravity(delta)
	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0


func _face_player() -> void:
	var target_position := player.global_position
	target_position.y = global_position.y

	if global_position.distance_to(target_position) > 0.1:
		look_at(target_position, Vector3.UP)


func _fake_walk_motion() -> void:
	if model == null:
		return

	var time := Time.get_ticks_msec() * 0.008

	model.position.y = 1.0 + sin(time) * 0.04

	model.rotation_degrees.z = sin(time * 0.5) * 2.0


# ============================================================
# BASIC ATTACK
# ============================================================

func _melee_attack() -> void:
	if is_attacking:
		return

	is_attacking = true
	can_attack = false

	if model != null:
		var tween := create_tween()

		# Pull back.
		tween.tween_property(
			model,
			"position:z",
			0.20,
			0.12
		)

		# Lunge forward.
		tween.tween_property(
			model,
			"position:z",
			0.6,
			0.10
		)

		# Return.
		tween.tween_property(
			model,
			"position:z",
			0.0,
			0.15
		)

	await get_tree().create_timer(0.22).timeout

	# The Gorilla could die during the attack wind-up.
	if is_dead or not is_inside_tree():
		return

	if is_instance_valid(player) and player.is_inside_tree():
		var distance: float = global_position.distance_to(
			player.global_position
		)

		if distance <= melee_range + 0.4:
			player.take_damage(melee_damage)

	await get_tree().create_timer(0.25).timeout

	if is_dead or not is_inside_tree():
		return

	is_attacking = false

	await get_tree().create_timer(
		attack_cooldown
	).timeout

	if is_dead or not is_inside_tree():
		return

	can_attack = true
# ============================================================
# GROUND SLAM
# ============================================================

func _ground_slam() -> void:
	if is_attacking:
		return

	is_attacking = true
	can_slam = false
	can_attack = false
	_show_slam_warning()
	roar_sfx.play_event()

	# ---------------- WARNING ----------------
	# Gorilla rises up before attacking.
	# This gives the player time to escape.

	if model != null:
		var windup := create_tween()

		windup.tween_property(
			model,
			"position:y",
			0.55,
			0.45
		)

		windup.parallel().tween_property(
			model,
			"scale",
			Vector3(3.15, 3.15, 3.15),
			0.45
		)

	await get_tree().create_timer(0.55).timeout

	# ---------------- SLAM ----------------

	if model != null:
		var slam := create_tween()

		slam.tween_property(
			model,
			"position:y",
			-0.15,
			0.10
		)

		slam.parallel().tween_property(
			model,
			"scale",
			Vector3(3.0, 2.8, 3.0),
			0.10
		)

	await get_tree().create_timer(0.10).timeout

	# Damage happens when the Gorilla hits the ground.
		# Damage happens when the Gorilla hits the ground.
	if is_dead or not is_inside_tree():
		return
		
	_remove_slam_warning()
	_create_slam_shockwave()

	if is_instance_valid(player) and player.is_inside_tree():
		var distance: float = global_position.distance_to(
			player.global_position
		)

		if distance <= slam_range:
			player.take_damage(slam_damage)
	# Return to normal.
	if model != null:
		var recover := create_tween()

		recover.tween_property(
			model,
			"position:y",
			1.0,
			0.20
		)

		recover.parallel().tween_property(
			model,
			"scale",
			Vector3(3.0, 3.0, 3.0),
			0.20
		)

	await get_tree().create_timer(0.35).timeout

	is_attacking = false

	await get_tree().create_timer(
		attack_cooldown
	).timeout

	if not is_dead:
		can_attack = true

	await get_tree().create_timer(
		slam_cooldown - attack_cooldown
	).timeout

	if not is_dead:
		can_slam = true


# ============================================================
# DAMAGE
# ============================================================
func _show_slam_warning() -> void:
	if is_dead or not is_inside_tree():
		return

	slam_warning = MeshInstance3D.new()

	var warning_mesh := CylinderMesh.new()
	warning_mesh.top_radius = slam_range
	warning_mesh.bottom_radius = slam_range
	warning_mesh.height = 0.03

	slam_warning.mesh = warning_mesh
	slam_warning.position = Vector3(0, 0.04, 0)

	var warning_material := StandardMaterial3D.new()
	warning_material.albedo_color = Color(0.85, 0.12, 0.04, 0.30)
	warning_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	warning_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	slam_warning.material_override = warning_material
	add_child(slam_warning)

	slam_warning.scale = Vector3(0.15, 1.0, 0.15)

	var tween := create_tween()
	tween.tween_property(
		slam_warning,
		"scale",
		Vector3(1.0, 1.0, 1.0),
		0.55
	)


func _remove_slam_warning() -> void:
	if is_instance_valid(slam_warning):
		slam_warning.queue_free()

	slam_warning = null


func _create_slam_shockwave() -> void:
	if is_dead or not is_inside_tree():
		return

	var shockwave := MeshInstance3D.new()

	var shockwave_mesh := CylinderMesh.new()
	shockwave_mesh.top_radius = 1.0
	shockwave_mesh.bottom_radius = 1.0
	shockwave_mesh.height = 0.05

	shockwave.mesh = shockwave_mesh
	shockwave.position = Vector3(0, 0.06, 0)

	var shockwave_material := StandardMaterial3D.new()
	shockwave_material.albedo_color = Color(1.0, 0.45, 0.08, 0.65)
	shockwave_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shockwave_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shockwave_material.emission_enabled = true
	shockwave_material.emission = Color(1.0, 0.25, 0.03)
	shockwave_material.emission_energy_multiplier = 2.0

	shockwave.material_override = shockwave_material
	add_child(shockwave)

	shockwave.scale = Vector3(0.15, 1.0, 0.15)

	var tween := create_tween()

	tween.tween_property(
		shockwave,
		"scale",
		Vector3(slam_range, 1.0, slam_range),
		0.30
	)

	tween.parallel().tween_property(
		shockwave_material,
		"albedo_color:a",
		0.0,
		0.30
	)

	await tween.finished

	if is_instance_valid(shockwave):
		shockwave.queue_free()
func take_damage(amount: float) -> void:
	if is_dead:
		return

	health -= amount

	if is_instance_valid(health_bar):
		health_bar.value = health

	_fake_hit_reaction()
	_flash_hit()

	if health <= 0.0:
		_die()


func _fake_hit_reaction() -> void:
	if model == null:
		return
func _flash_hit() -> void:
	if model == null:
		return

	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	hit_flash_remaining = 0.12
	hit_flash_started = true

	for mesh in meshes:
		if mesh is MeshInstance3D:
			if not mesh.has_meta("hit_overlay_original"):
				mesh.set_meta("hit_overlay_original", {"material":mesh.material_overlay})

			var flash_material := StandardMaterial3D.new()
			flash_material.albedo_color = Color(0.75, 1.0, 0.94)
			flash_material.emission_enabled = true
			flash_material.emission = Color(0.65, 1.0, 0.90)
			flash_material.emission_energy_multiplier = 1.0

			mesh.material_overlay = flash_material


	var tween := create_tween()

	tween.tween_property(
		model,
		"scale",
		Vector3(3.15, 2.85, 3.15),
		0.06
	)

	tween.tween_property(
		model,
		"scale",
		Vector3(3.0, 3.0, 3.0),
		0.10
	)


# ============================================================
# DEATH
# ============================================================

func _process(delta: float) -> void:
	if hit_flash_started:
		hit_flash_started = false
		return
	if hit_flash_remaining <= 0.0:
		return
	hit_flash_remaining -= delta
	if hit_flash_remaining <= 0.0 and is_instance_valid(model):
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			if mesh.has_meta("hit_overlay_original"):
				mesh.material_overlay = mesh.get_meta("hit_overlay_original").material
				mesh.remove_meta("hit_overlay_original")

func _die() -> void:
	if is_dead:
		return

	is_dead = true
	is_attacking = true

	remove_from_group("enemies")

	velocity = Vector3.ZERO

	if model != null:
		var tween := create_tween()

		tween.tween_property(
			model,
			"rotation_degrees:x",
			90.0,
			0.65
		)

		tween.parallel().tween_property(
			model,
			"position:y",
			0.6,
			0.65
		)

		await tween.finished

	defeated.emit()
	queue_free()


# ============================================================
# MODEL / COLLISION
# ============================================================

func _build_gorilla() -> void:
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()

	shape.radius = 1.2
	shape.height = 3.2

	collision.shape = shape
	collision.position.y = 1.6

	add_child(collision)

	model = GORILLA_MODEL.instantiate()
	add_child(model)

	model.position = Vector3(0, 1.0, 0)

	model.scale = Vector3(
		3.0,
		3.0,
		3.0
	)

	model.rotation_degrees = Vector3(
		0,
		180,
		0
	)
func _build_health_bar() -> void:
	health_bar_container = SubViewport.new()
	health_bar_container.size = Vector2i(220, 28)
	health_bar_container.transparent_bg = true
	health_bar_container.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(health_bar_container)

	health_bar = ProgressBar.new()
	health_bar.min_value = 0
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color("101714")
	background.border_color = Color("315c52")
	background.set_border_width_all(2)
	background.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("7b252b")
	fill.set_corner_radius_all(3)
	health_bar.add_theme_stylebox_override("background", background)
	health_bar.add_theme_stylebox_override("fill", fill)
	health_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	health_bar_container.add_child(health_bar)

	health_bar_sprite = Sprite3D.new()
	health_bar_sprite.texture = health_bar_container.get_texture()
	health_bar_sprite.position = Vector3(0, 3.7, 0)
	health_bar_sprite.pixel_size = 0.008
	health_bar_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_bar_sprite.no_depth_test = true
	add_child(health_bar_sprite)
