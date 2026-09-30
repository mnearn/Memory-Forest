extends Node3D

var info_label: Label
var memory_label: Label
var generation_label: Label
var message_label: Label


func _ready() -> void:
	_build_environment()
	_build_ui()
	_refresh_ui()


# ============================================================
# 3D SHRINE
# ============================================================

func _build_environment() -> void:
	# Dark jungle-like background.
	var world := WorldEnvironment.new()
	var environment := Environment.new()

	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.025, 0.07, 0.045)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.25, 0.35, 0.25)
	environment.ambient_light_energy = 0.8

	world.environment = environment
	add_child(world)

	# Ground.
	var floor := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(18, 0.4, 12)
	floor.mesh = floor_mesh
	floor.position = Vector3(0, -0.2, 0)

	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.10, 0.18, 0.09)
	floor.material_override = floor_material

	add_child(floor)

	# Central inheritance shrine.
	var shrine := MeshInstance3D.new()
	var shrine_mesh := CylinderMesh.new()
	shrine_mesh.top_radius = 2.0
	shrine_mesh.bottom_radius = 2.4
	shrine_mesh.height = 0.8
	shrine.mesh = shrine_mesh
	shrine.position = Vector3(0, 0.4, -1)

	var shrine_material := StandardMaterial3D.new()
	shrine_material.albedo_color = Color(0.20, 0.16, 0.10)
	shrine.material_override = shrine_material

	add_child(shrine)

	# Glowing Memory pillar.
	var memory_pillar := MeshInstance3D.new()
	var pillar_mesh := CylinderMesh.new()
	pillar_mesh.top_radius = 0.45
	pillar_mesh.bottom_radius = 0.65
	pillar_mesh.height = 3.0
	memory_pillar.mesh = pillar_mesh
	memory_pillar.position = Vector3(0, 1.9, -1)

	var memory_material := StandardMaterial3D.new()
	memory_material.albedo_color = Color(0.15, 0.65, 0.50)
	memory_material.emission_enabled = true
	memory_material.emission = Color(0.10, 0.75, 0.55)
	memory_material.emission_energy_multiplier = 2.0
	memory_pillar.material_override = memory_material

	add_child(memory_pillar)

	# Four simple stone markers around the shrine.
	_create_pedestal(Vector3(-3.5, 0.5, -1), Color(0.65, 0.18, 0.12))
	_create_pedestal(Vector3(-1.3, 0.5, 2.0), Color(0.75, 0.55, 0.12))
	_create_pedestal(Vector3(1.3, 0.5, 2.0), Color(0.15, 0.45, 0.75))
	_create_pedestal(Vector3(3.5, 0.5, -1), Color(0.25, 0.65, 0.25))

	# Light.
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.light_energy = 1.2
	light.shadow_enabled = true
	add_child(light)

	# Camera.
	var camera := Camera3D.new()
	camera.position = Vector3(0, 7, 10)
	camera.rotation_degrees = Vector3(-25, 0, 0)
	add_child(camera)


func _create_pedestal(pos: Vector3, color: Color) -> void:
	var pedestal := MeshInstance3D.new()
	var mesh := BoxMesh.new()

	mesh.size = Vector3(1.4, 1.0, 1.4)
	pedestal.mesh = mesh
	pedestal.position = pos

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	pedestal.material_override = material

	add_child(pedestal)


# ============================================================
# USER INTERFACE
# ============================================================

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.position = Vector2(30, 30)
	panel.size = Vector2(430, 620)
	canvas.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var title := Label.new()
	title.text = "THE INHERITANCE SHRINE"
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)

	info_label = Label.new()
	info_label.text = "A descendant carries the memories\nof those who came before."
	box.add_child(info_label)

	generation_label = Label.new()
	generation_label.add_theme_font_size_override("font_size", 20)
	box.add_child(generation_label)

	memory_label = Label.new()
	memory_label.add_theme_font_size_override("font_size", 24)
	box.add_child(memory_label)

	box.add_child(HSeparator.new())

	_add_upgrade_button(box, "Attack", "attack")
	_add_upgrade_button(box, "Attack Speed", "attack_speed")
	_add_upgrade_button(box, "Movement Speed", "movement_speed")
	_add_upgrade_button(box, "Max Health", "health")

	box.add_child(HSeparator.new())

	# Temporary demo button.
	var run_button := Button.new()
	run_button.text = "ENTER THE FOREST"
	run_button.custom_minimum_size = Vector2(0, 55)
	run_button.pressed.connect(_start_demo_run)
	box.add_child(run_button)

	# This lets us prove inheritance before combat is finished.
	var test_death_button := Button.new()
	test_death_button.text = "DEMO: DIE IN ROOM 3"
	test_death_button.custom_minimum_size = Vector2(0, 45)
	test_death_button.pressed.connect(_demo_room_three_death)
	box.add_child(test_death_button)

	message_label = Label.new()
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.text = "Choose how this descendant inherits the past."
	box.add_child(message_label)


func _add_upgrade_button(
	parent: VBoxContainer,
	display_name: String,
	upgrade_name: String
) -> void:

	var button := Button.new()

	var level := InheritanceManager.get_upgrade_level(upgrade_name)
	var cost := InheritanceManager.get_upgrade_cost(upgrade_name)

	button.text = "%s  Lv.%d  |  %d Memory" % [
		display_name,
		level,
		cost
	]

	button.custom_minimum_size = Vector2(0, 48)

	button.pressed.connect(
		func():
			_buy_upgrade(upgrade_name)
	)

	parent.add_child(button)


# ============================================================
# INHERITANCE
# ============================================================

func _buy_upgrade(upgrade_name: String) -> void:
	var success := InheritanceManager.purchase_upgrade(upgrade_name)

	if success:
		message_label.text = "The descendant inherited %s." % upgrade_name
	else:
		message_label.text = "Not enough Memory."

	# Rebuild so costs/levels immediately update.
	get_tree().reload_current_scene()


func _demo_room_three_death() -> void:
	InheritanceManager.enter_room(3)

	var memory_received := InheritanceManager.player_died()

	message_label.text = (
		"The previous descendant fell in Room 3.\n"
		+ "Memory inherited: "
		+ str(memory_received)
	)

	_refresh_ui()


func _start_demo_run() -> void:
	message_label.text = (
		"Descendant %d enters the forest.\n"
		+ "Playable rooms are the next build step."
	) % InheritanceManager.get_generation()


func _refresh_ui() -> void:
	if memory_label == null:
		return

	memory_label.text = "Memory: %d" % InheritanceManager.get_current_memory()

	generation_label.text = "Generation: %d" % InheritanceManager.get_generation()
