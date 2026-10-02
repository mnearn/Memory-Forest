extends Node3D

var player: Node3D
var camera: Camera3D
var enemies: Array[Node3D] = []
var current_room: int = 1
var run_finished: bool = false
var hud: VBoxContainer
var health_label: Label
var room_label: Label
var generation_label: Label
var memory_label: Label
var message_label: Label

func _ready() -> void:
	randomize()
	InheritanceManager.begin_run()
	_build_world()
	_spawn_player()
	_create_hud()
	start_room(1)

func _build_world() -> void:
	var world = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.025, 0.08, 0.035)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.35, 0.45, 0.30)
	environment.ambient_light_energy = 0.9
	world.environment = environment
	add_child(world)

	var floor = StaticBody3D.new()
	floor.name = "Ground"
	add_child(floor)

	var floor_collision = CollisionShape3D.new()
	var floor_shape = BoxShape3D.new()
	floor_shape.size = Vector3(24.0, 0.5, 20.0)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.25
	floor.add_child(floor_collision)

	var floor_mesh = MeshInstance3D.new()
	var floor_box = BoxMesh.new()
	floor_box.size = Vector3(24.0, 0.5, 20.0)
	floor_mesh.mesh = floor_box
	floor_mesh.position.y = -0.25
	var floor_material = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.10, 0.20, 0.08)
	floor_mesh.material_override = floor_material
	floor.add_child(floor_mesh)

	for x in [-9.0, -6.0, 6.0, 9.0]:
		_create_tree(Vector3(x, 0.0, -6.0))
		_create_tree(Vector3(x, 0.0, 6.0))

	var sunlight = DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sunlight.light_energy = 1.4
	sunlight.shadow_enabled = true
	add_child(sunlight)

func _create_tree(position: Vector3) -> void:
	var trunk = MeshInstance3D.new()
	var trunk_mesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.3
	trunk_mesh.bottom_radius = 0.45
	trunk_mesh.height = 4.0
	trunk.mesh = trunk_mesh
	trunk.position = position + Vector3(0.0, 2.0, 0.0)
	var trunk_material = StandardMaterial3D.new()
	trunk_material.albedo_color = Color(0.20, 0.10, 0.04)
	trunk.material_override = trunk_material
	add_child(trunk)

	var leaves = MeshInstance3D.new()
	var leaves_mesh = SphereMesh.new()
	leaves_mesh.radius = 1.5
	leaves_mesh.height = 3.0
	leaves.mesh = leaves_mesh
	leaves.position = position + Vector3(0.0, 4.3, 0.0)
	var leaf_material = StandardMaterial3D.new()
	leaf_material.albedo_color = Color(0.06, 0.30, 0.08)
	leaves.material_override = leaf_material
	add_child(leaves)

func _spawn_player() -> void:
	var PlayerScript = preload("res://scripts/player.gd")
	player = PlayerScript.new()
	player.name = "Player"
	player.position = Vector3(0.0, 0.9, 5.0)
	player.main = self
	add_child(player)

	camera = Camera3D.new()
	camera.name = "PlayerCamera"
	camera.current = true
	camera.fov = 68.0
	camera.near = 0.1
	add_child(camera)
	camera.global_position = player.global_position + Vector3(0.0, 5.0, 9.0)
	camera.look_at(player.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)
	player.camera = camera

func _create_hud() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)

	hud = VBoxContainer.new()
	hud.position = Vector2(25.0, 25.0)
	hud.add_theme_constant_override("separation", 7)
	canvas.add_child(hud)

	health_label = Label.new()
	hud.add_child(health_label)

	room_label = Label.new()
	hud.add_child(room_label)

	generation_label = Label.new()
	hud.add_child(generation_label)

	memory_label = Label.new()
	hud.add_child(memory_label)

	message_label = Label.new()
	message_label.text = "Enter the forest."
	hud.add_child(message_label)

	var controls = Label.new()
	controls.text = "WASD: Move    SHIFT: Dash    SPACE: Light Attack    E: Heavy Attack"
	hud.add_child(controls)

func _process(delta: float) -> void:
	if is_instance_valid(camera) and is_instance_valid(player):
		var target = player.global_position + Vector3(0.0, 5.0, 9.0)
		var follow_weight = 1.0 - exp(-8.0 * delta)
		camera.global_position = camera.global_position.lerp(target, follow_weight)
		camera.look_at(player.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)

	if is_instance_valid(player):
		health_label.text = "Health: %d / %d" % [int(player.health), int(player.max_health)]
		room_label.text = "Room: %d / 5" % current_room
		generation_label.text = "Generation: %d" % InheritanceManager.get_generation()
		memory_label.text = "Memory: %d" % InheritanceManager.get_current_memory()

func start_room(room_number: int) -> void:
	current_room = room_number
	InheritanceManager.enter_room(current_room)
	room_label.text = "Room: %d / 5" % current_room
	message_label.text = "Clear the enemies."
	_spawn_room_enemies()

func _spawn_room_enemies() -> void:
	var amount = min(current_room + 1, 5)
	for i in range(amount):
		var enemy = preload("res://scripts/enemy.gd").new()
		enemy.init(self, _pick_enemy_kind(), current_room)
		enemy.name = "Room%d_Enemy%d" % [current_room, i + 1]
		var angle = float(i) / float(amount) * TAU
		enemy.position = Vector3(cos(angle) * 5.0, 0.0, sin(angle) * 5.0 - 2.0)
		add_child(enemy)
		enemies.append(enemy)

func _pick_enemy_kind() -> String:
	var roll = randi() % 100
	if current_room <= 1:
		return "brute" if roll < 55 else "skirmisher"
	if current_room <= 3:
		return "brute" if roll < 40 else "skirmisher" if roll < 75 else "ranger"
	return "brute" if roll < 30 else "skirmisher" if roll < 65 else "ranger"

func _register_enemy_defeat(enemy: Node3D) -> void:
	if enemy in enemies:
		enemies.erase(enemy)
	if enemies.is_empty() and not run_finished:
		_room_cleared()

func _room_cleared() -> void:
	if current_room >= 5:
		run_finished = true
		message_label.text = "The forest has been conquered."
		return

	player.health = min(player.max_health, player.health + 15.0)
	player.global_position = Vector3(0.0, 0.9, 5.0)
	player.velocity = Vector3.ZERO
	start_room(current_room + 1)

func _on_player_defeated() -> void:
	if run_finished:
		return
	run_finished = true

	var reached_room = current_room
	var earned_memory = InheritanceManager.player_died()
	message_label.text = (
		"Generation fallen in Room %d.\n"
		+ "The next descendant inherits %d Memory."
	) % [reached_room, earned_memory]

	await get_tree().create_timer(2.0).timeout
	if is_inside_tree():
		get_tree().change_scene_to_file("res://inheritance_system/upgrade_shrine.tscn")
