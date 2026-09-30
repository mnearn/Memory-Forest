extends Node3D

const PlayerScript = preload("res://demo/demo_player.gd")
const EnemyScript = preload("res://demo/demo_enemy.gd")
const GorillaScript = preload("res://enemies/gorilla/gorilla_enemy.gd")

var player: CharacterBody3D

var current_room := 1
var enemies_remaining := 0
var run_finished := false

var health_label: Label
var room_label: Label
var generation_label: Label
var memory_label: Label
var message_label: Label


func _ready() -> void:
	_build_world()
	_build_hud()
	_spawn_player()
	start_room(1)


func _build_world() -> void:
	# =========================================================
	# ROOM 1 - JUNGLE RUINS
	# =========================================================

	# ---------------- FLOOR ----------------
	var floor := StaticBody3D.new()
	floor.name = "JungleFloor"
	add_child(floor)

	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()

	floor_shape.size = Vector3(30, 0.5, 26)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.25
	floor.add_child(floor_collision)

	var floor_mesh := MeshInstance3D.new()
	var mesh := BoxMesh.new()

	mesh.size = Vector3(30, 0.5, 26)
	floor_mesh.mesh = mesh
	floor_mesh.position.y = -0.25

	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.07, 0.16, 0.06)

	floor_mesh.material_override = ground_material
	floor.add_child(floor_mesh)


	# ---------------- CENTRAL PATH ----------------
	var path := MeshInstance3D.new()
	var path_mesh := BoxMesh.new()

	path_mesh.size = Vector3(6, 0.04, 24)
	path.mesh = path_mesh
	path.position = Vector3(0, 0.03, 0)

	var path_material := StandardMaterial3D.new()
	path_material.albedo_color = Color(0.20, 0.17, 0.10)

	path.material_override = path_material
	add_child(path)


	# ---------------- JUNGLE TREES ----------------
	var tree_positions: Array[Vector3] = [
		Vector3(-12, 0, -10),
		Vector3(-9, 0, -8),
		Vector3(-12, 0, -4),
		Vector3(-10, 0, 1),
		Vector3(-12, 0, 7),
		Vector3(-9, 0, 10),

		Vector3(12, 0, -10),
		Vector3(9, 0, -8),
		Vector3(12, 0, -4),
		Vector3(10, 0, 1),
		Vector3(12, 0, 7),
		Vector3(9, 0, 10)
	]

	for tree_position in tree_positions:
		_create_tree(tree_position)


	# ---------------- RUIN PILLARS ----------------
	_create_ruin_pillar(Vector3(-5, 0, -5))
	_create_ruin_pillar(Vector3(5, 0, -5))

	_create_ruin_pillar(Vector3(-5, 0, 5))
	_create_ruin_pillar(Vector3(5, 0, 5))


	# ---------------- BROKEN STONES ----------------
	_create_ruin_stone(
		Vector3(-6.5, 0.35, 1),
		Vector3(2.5, 0.7, 1.3),
		12.0
	)

	_create_ruin_stone(
		Vector3(7, 0.25, -2),
		Vector3(1.8, 0.5, 1.5),
		-18.0
	)

	_create_ruin_stone(
		Vector3(-7, 0.2, 8),
		Vector3(1.5, 0.4, 2.0),
		25.0
	)


	# ---------------- LIGHTING ----------------
	var light := DirectionalLight3D.new()

	light.rotation_degrees = Vector3(-55, -30, 0)
	light.light_energy = 1.05
	light.shadow_enabled = true

	light.light_color = Color(0.85, 0.92, 0.78)

	add_child(light)


	# ---------------- CAMERA ----------------
	var camera := Camera3D.new()

	camera.position = Vector3(0, 11, 16)
	camera.rotation_degrees = Vector3(-36, 0, 0)

	add_child(camera)

func _create_tree(pos: Vector3) -> void:
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()

	trunk_mesh.top_radius = 0.3
	trunk_mesh.bottom_radius = 0.45
	trunk_mesh.height = 4

	trunk.mesh = trunk_mesh
	trunk.position = pos + Vector3(0, 2, 0)

	var trunk_material := StandardMaterial3D.new()
	trunk_material.albedo_color = Color(0.20, 0.10, 0.04)
	trunk.material_override = trunk_material
	add_child(trunk)

	var leaves := MeshInstance3D.new()
	var leaves_mesh := SphereMesh.new()

	leaves_mesh.radius = 1.5
	leaves_mesh.height = 3

	leaves.mesh = leaves_mesh
	leaves.position = pos + Vector3(0, 4.3, 0)

	var leaf_material := StandardMaterial3D.new()
	leaf_material.albedo_color = Color(0.06, 0.30, 0.08)
	leaves.material_override = leaf_material
	add_child(leaves)
func _create_ruin_pillar(pos: Vector3) -> void:
	var pillar := MeshInstance3D.new()
	var pillar_mesh := BoxMesh.new()

	pillar_mesh.size = Vector3(1.2, 3.5, 1.2)

	pillar.mesh = pillar_mesh
	pillar.position = pos + Vector3(0, 1.75, 0)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.24, 0.18)

	pillar.material_override = material

	add_child(pillar)


func _create_ruin_stone(
	pos: Vector3,
	size: Vector3,
	rotation_y: float
) -> void:

	var stone := MeshInstance3D.new()
	var stone_mesh := BoxMesh.new()

	stone_mesh.size = size

	stone.mesh = stone_mesh
	stone.position = pos
	stone.rotation_degrees.y = rotation_y

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.17, 0.19, 0.14)

	stone.material_override = material

	add_child(stone)


func _spawn_player() -> void:
	player = CharacterBody3D.new()
	player.set_script(PlayerScript)
	player.position = Vector3(0, 0.1, 5)
	add_child(player)

	player.died.connect(_on_player_died)
	player.health_changed.connect(_on_health_changed)


func start_room(room_number: int) -> void:
	current_room = room_number
	InheritanceManager.enter_room(current_room)

	room_label.text = "Room: %d / 5" % current_room
	message_label.text = "Clear the enemies."

	_spawn_room_enemies()


func _spawn_room_enemies() -> void:
	# Room 1 is our Gorilla test room.
	if current_room == 1:
		enemies_remaining = 1

		var gorilla := CharacterBody3D.new()
		gorilla.set_script(GorillaScript)
		gorilla.position = Vector3(0, 0.1, -3)

		add_child(gorilla)

		gorilla.set_player(player)
		gorilla.defeated.connect(_on_enemy_defeated)

		return

	# Other rooms still use the original demo enemies.
	var amount: int = min(current_room + 1, 5)
	enemies_remaining = amount

	for i in range(amount):
		var enemy := CharacterBody3D.new()
		enemy.set_script(EnemyScript)

		var angle := float(i) / float(amount) * TAU

		enemy.position = Vector3(
			cos(angle) * 5.0,
			0.1,
			sin(angle) * 5.0 - 2.0
		)

		add_child(enemy)
		enemy.set_player(player)
		enemy.defeated.connect(_on_enemy_defeated)
func _on_enemy_defeated() -> void:
	enemies_remaining -= 1

	if enemies_remaining <= 0:
		_room_cleared()


func _room_cleared() -> void:
	if current_room >= 5:
		message_label.text = "The forest has been conquered."
		run_finished = true
		return

	current_room += 1

	player.position = Vector3(0, 0.1, 5)
	start_room(current_room)


func _on_player_died() -> void:
	if run_finished:
		return

	run_finished = true

	var reached_room := current_room
	var inherited := InheritanceManager.player_died()

	message_label.text = (
		"Generation fallen in Room %d.\n"
		+ "The next descendant inherits %d Memory."
	) % [reached_room, inherited]

	await get_tree().create_timer(2.0).timeout

	get_tree().change_scene_to_file(
		"res://inheritance_system/upgrade_shrine.tscn"
	)


func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var box := VBoxContainer.new()
	box.position = Vector2(25, 25)
	box.add_theme_constant_override("separation", 7)
	canvas.add_child(box)

	var title := Label.new()
	title.text = "MEMORY FOREST"
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)

	health_label = Label.new()
	box.add_child(health_label)

	room_label = Label.new()
	box.add_child(room_label)

	generation_label = Label.new()
	generation_label.text = (
		"Generation: %d"
		% InheritanceManager.get_generation()
	)
	box.add_child(generation_label)

	memory_label = Label.new()
	memory_label.text = (
		"Memory: %d"
		% InheritanceManager.get_current_memory()
	)
	box.add_child(memory_label)

	message_label = Label.new()
	message_label.text = "Enter the forest."
	box.add_child(message_label)

	var controls := Label.new()
	controls.text = "WASD: Move    SPACE: Attack"
	box.add_child(controls)

	# Temporary testing button.
	var death_button := Button.new()
	death_button.text = "DEMO: END RUN"

	death_button.pressed.connect(
		func():
			if is_instance_valid(player):
				player.take_damage(9999)
	)

	box.add_child(death_button)


func _on_health_changed(
	current_health: float,
	maximum_health: float
) -> void:
	health_label.text = (
		"Health: %d / %d"
		% [int(current_health), int(maximum_health)]
	)
