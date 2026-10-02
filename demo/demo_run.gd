extends Node3D

const PlayerScript = preload("res://demo/demo_player.gd")
const JungleEnvironmentScene = preload("res://assets/environment/jungle_preview/jungle_environment_instance.tscn")
const EnemyScript = preload("res://demo/demo_enemy.gd")
const GorillaScript = preload("res://enemies/gorilla/gorilla_enemy.gd")
const TigerBossScene = preload("res://enemies/tiger/tiger_boss.tscn")
const JaguarScript = preload("res://enemies/jaguar/jaguar_enemy.gd")
const SnakeScript = preload("res://enemies/anaconda/snake_enemy.gd")

var player: CharacterBody3D

var current_room := 1
var enemies_remaining := 0
var run_finished := false

var health_label: Label
var room_label: Label
var generation_label: Label
var memory_label: Label
var message_label: Label
var health_bar: ProgressBar
var sacrifice_overlay: PanelContainer
var sacrifice_reward_label: Label
var message_panel: PanelContainer
var completion_panel: PanelContainer
var completion_info: Label

const HUD_INK := Color("101714", 0.88)
const HUD_BORDER := Color("315c52")
const HUD_TEXT := Color("e5e8e4")
const HUD_TEAL := Color("65d6c3")
const HUD_HEALTH := Color("7b252b")


func _ready() -> void:
	_build_world()
	_build_hud()
	_spawn_player()
	start_room(1)


func _build_world() -> void:
	# Retain the accepted flat gameplay floor; imported scenery is visual only.
	var floor := StaticBody3D.new()
	floor.name = "JungleFloor"
	add_child(floor)
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(30, 0.5, 26)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.25
	floor.add_child(floor_collision)

	add_child(JungleEnvironmentScene.instantiate())

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	light.light_energy = 1.05
	light.shadow_enabled = true
	light.light_color = Color(0.85, 0.92, 0.78)
	add_child(light)

	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.065, 0.09, 0.075)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.65, 0.8, 0.72)
	world.environment.ambient_light_energy = 0.45
	add_child(world)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 11, 16)
	camera.rotation_degrees = Vector3(-36, 0, 0)
	add_child(camera)

# Original prototype helpers retained, but no longer called by _build_world().
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
	# _ready emits before the signal connection; initialize the presentation too.
	_on_health_changed(player.health, player.max_health)


func start_room(room_number: int) -> void:
	current_room = room_number
	InheritanceManager.enter_room(current_room)
	_refresh_status()

	room_label.text = "ROOM %d / 5" % current_room
	message_label.text = "Clear the enemies."

	_spawn_room_enemies()


func _room_progress() -> String:
	var result := ""
	for i in range(1, 6):
		result += "● " if i < current_room else ("◉ " if i == current_room else "○ ")
	return result


func _spawn_room_enemies() -> void:
	if current_room == 5:
		enemies_remaining = 1
		var tiger := TigerBossScene.instantiate()
		tiger.position = Vector3(0, 0.1, -7)
		add_child(tiger)
		tiger.set_player(player)
		tiger.defeated.connect(_on_enemy_defeated)
		message_label.text = "MEMORY TIGER — The forest remembers every descendant."
		return

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

	if current_room == 2:
		enemies_remaining = 3
		for i in range(3):
			var snake := CharacterBody3D.new()
			snake.name = "Snake%d" % (i + 1)
			snake.set_script(SnakeScript)
			var angle := float(i) / 3.0 * TAU
			snake.position = Vector3(cos(angle) * 5.0, 0.1, sin(angle) * 5.0 - 2.0)
			add_child(snake)
			snake.set_player(player)
			snake.defeated.connect(_on_enemy_defeated)
		message_label.text = "Snakes guard the ruins. Dodge their bite."
		return

	if current_room == 3:
		enemies_remaining = 2
		for i in range(2):
			var jaguar := CharacterBody3D.new()
			jaguar.name = "Jaguar%d" % (i + 1)
			jaguar.set_script(JaguarScript)
			var angle := float(i) / 2.0 * TAU
			jaguar.position = Vector3(cos(angle) * 5.0, 0.1, sin(angle) * 5.0 - 2.0)
			add_child(jaguar)
			jaguar.set_player(player)
			jaguar.defeated.connect(_on_enemy_defeated)
		message_label.text = "Jaguars stalk the ruins. Watch for their pounce."
		return

	if current_room == 4:
		enemies_remaining = 4
		var encounter := [
			{"name": "Room4Gorilla", "script": GorillaScript, "position": Vector3(0, 0.1, -9)},
			{"name": "Room4SnakeLeft", "script": SnakeScript, "position": Vector3(-4, 0.1, 0)},
			{"name": "Room4SnakeRight", "script": SnakeScript, "position": Vector3(4, 0.1, -4)},
			{"name": "Room4Jaguar", "script": JaguarScript, "position": Vector3(7, 0.1, -9)}
		]
		for entry in encounter:
			var enemy := CharacterBody3D.new()
			enemy.name = entry["name"]
			enemy.set_script(entry["script"])
			enemy.position = entry["position"]
			# This rear guard engages later; its combat stats remain unchanged.
			if entry["script"] == JaguarScript:
				enemy.detection_range = 9.0
			add_child(enemy)
			enemy.set_player(player)
			enemy.defeated.connect(_on_enemy_defeated)
		message_label.text = "The forest's predators gather. Watch the rear guard."
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
		completion_info.text = "GENERATION  %d     ·     MEMORY  %d" % [InheritanceManager.get_generation(), InheritanceManager.get_current_memory()]
		completion_panel.show()
		message_panel.hide()
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
	_refresh_status()

	message_label.text = (
		"Generation fallen in Room %d.\n"
		+ "The next descendant inherits %d Memory."
	) % [reached_room, inherited]

	await get_tree().create_timer(2.0).timeout

	get_tree().change_scene_to_file(
		"res://inheritance_system/upgrade_shrine.tscn"
	)


func _panel_style(bg: Color, border: Color, radius: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style


func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "GameplayHUD"
	add_child(canvas)
	var hud := Control.new()
	hud.name = "HUDLayout"
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", HUD_TEXT)
	hud.theme = theme
	canvas.add_child(hud)

	var player_panel := PanelContainer.new()
	player_panel.name = "PlayerStatus"
	player_panel.position = Vector2(24, 20)
	player_panel.custom_minimum_size = Vector2(280, 152)
	player_panel.add_theme_stylebox_override("panel", _panel_style(HUD_INK, HUD_BORDER, 7))
	hud.add_child(player_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	player_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)
	generation_label = Label.new()
	generation_label.text = "GENERATION %d" % InheritanceManager.get_generation()
	generation_label.add_theme_font_size_override("font_size", 19)
	box.add_child(generation_label)
	health_bar = ProgressBar.new()
	health_bar.name = "PlayerHealth"
	health_bar.custom_minimum_size = Vector2(244, 18)
	health_bar.show_percentage = false
	health_bar.add_theme_stylebox_override("background", _panel_style(Color("17251e"), Color("263d32"), 3))
	health_bar.add_theme_stylebox_override("fill", _panel_style(HUD_HEALTH, HUD_HEALTH, 3))
	box.add_child(health_bar)
	health_label = Label.new()
	health_label.add_theme_font_size_override("font_size", 14)
	box.add_child(health_label)
	memory_label = Label.new()
	memory_label.text = "MEMORY  %d" % InheritanceManager.get_current_memory()
	memory_label.add_theme_color_override("font_color", HUD_TEAL)
	memory_label.add_theme_font_size_override("font_size", 19)
	box.add_child(memory_label)

	var progress_panel := PanelContainer.new()
	progress_panel.name = "RoomStatus"
	progress_panel.anchor_left = 0.5
	progress_panel.anchor_right = 0.5
	progress_panel.offset_left = -150
	progress_panel.offset_right = 150
	progress_panel.offset_top = 20
	progress_panel.offset_bottom = 96
	progress_panel.add_theme_stylebox_override("panel", _panel_style(HUD_INK, HUD_BORDER, 7))
	hud.add_child(progress_panel)
	var progress_box := VBoxContainer.new()
	progress_box.alignment = BoxContainer.ALIGNMENT_CENTER
	progress_panel.add_child(progress_box)
	var title := Label.new()
	title.text = "MEMORY FOREST"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("a6b5ad"))
	progress_box.add_child(title)
	room_label = Label.new()
	room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_label.add_theme_font_size_override("font_size", 23)
	progress_box.add_child(room_label)

	var controls_panel := PanelContainer.new()
	controls_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	controls_panel.name = "Controls"
	controls_panel.offset_left = -240
	controls_panel.offset_right = -24
	controls_panel.offset_top = -92
	controls_panel.offset_bottom = -24
	var controls_style := _panel_style(Color("101714", 0.78), HUD_BORDER, 6)
	controls_style.content_margin_left = 14
	controls_style.content_margin_top = 10
	controls_style.content_margin_bottom = 10
	controls_panel.add_theme_stylebox_override("panel", controls_style)
	hud.add_child(controls_panel)
	var controls := Label.new()
	controls.text = "SPACE — ATTACK\nQ — SACRIFICE"
	controls.add_theme_font_size_override("font_size", 14)
	controls.add_theme_color_override("font_color", Color("a6b5ad"))
	controls_panel.add_child(controls)

	message_panel = PanelContainer.new()
	message_panel.name = "EncounterMessage"
	message_panel.anchor_left = 0.5
	message_panel.anchor_right = 0.5
	message_panel.anchor_top = 1.0
	message_panel.anchor_bottom = 1.0
	message_panel.offset_left = -310
	message_panel.offset_right = 310
	message_panel.offset_top = -76
	message_panel.offset_bottom = -24
	var message_style := _panel_style(Color("101714", 0.80), HUD_BORDER, 6)
	message_style.content_margin_left = 14
	message_style.content_margin_right = 14
	message_panel.add_theme_stylebox_override("panel", message_style)
	message_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(message_panel)
	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 15)
	message_label.text = "Enter the forest."
	message_panel.add_child(message_label)

	var sacrifice_button := Button.new()
	sacrifice_button.name = "SacrificeDescendant"
	sacrifice_button.text = "SACRIFICE DESCENDANT"
	sacrifice_button.position = Vector2(24, 182)
	sacrifice_button.custom_minimum_size = Vector2(280, 40)
	_style_sacrifice_button(sacrifice_button)
	sacrifice_button.pressed.connect(_show_sacrifice_confirmation)
	hud.add_child(sacrifice_button)

	_build_sacrifice_overlay(hud)
	_build_completion_panel(hud)

func _refresh_status() -> void:
	generation_label.text = "GENERATION  %d" % InheritanceManager.get_generation()
	memory_label.text = "MEMORY  %d" % InheritanceManager.get_current_memory()

func _style_sacrifice_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color("f0e5e5"))
	button.add_theme_color_override("font_hover_color", Color("f0e5e5"))
	button.add_theme_stylebox_override("normal", _panel_style(Color("54262a", 0.94), Color("76363c"), 5))
	button.add_theme_stylebox_override("hover", _panel_style(Color("76363c"), Color("a65860"), 5))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("3e1c20"), Color("a65860"), 5))
	button.add_theme_stylebox_override("focus", _panel_style(Color(0,0,0,0), HUD_TEAL, 5))

func _build_completion_panel(hud: Control) -> void:
	completion_panel = PanelContainer.new()
	completion_panel.name = "DemoCompletion"
	completion_panel.set_anchors_preset(Control.PRESET_CENTER)
	completion_panel.offset_left = -330
	completion_panel.offset_right = 330
	completion_panel.offset_top = -120
	completion_panel.offset_bottom = 120
	var style := _panel_style(Color("101714", 0.96), HUD_TEAL, 9)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	completion_panel.add_theme_stylebox_override("panel", style)
	hud.add_child(completion_panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	completion_panel.add_child(box)
	var title := Label.new()
	title.text = "MEMORY FOREST COMPLETE"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", HUD_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "The forest remembers your bloodline."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	box.add_child(subtitle)
	completion_info = Label.new()
	completion_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	completion_info.add_theme_color_override("font_color", HUD_TEAL)
	completion_info.add_theme_font_size_override("font_size", 18)
	box.add_child(completion_info)
	completion_panel.hide()


func _build_sacrifice_overlay(canvas: Control) -> void:
	sacrifice_overlay = PanelContainer.new()
	sacrifice_overlay.position = Vector2(390, 220)
	sacrifice_overlay.custom_minimum_size = Vector2(500, 280)
	sacrifice_overlay.add_theme_stylebox_override("panel", _panel_style(Color("101714", 0.97), HUD_BORDER, 9))
	sacrifice_overlay.visible = false
	canvas.add_child(sacrifice_overlay)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	sacrifice_overlay.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	var title := Label.new()
	title.text = "SACRIFICE THIS DESCENDANT?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)
	var desc := Label.new()
	desc.text = "End this descendant's journey and pass their accumulated Memory to the next generation."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(desc)
	sacrifice_reward_label = Label.new()
	sacrifice_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sacrifice_reward_label.add_theme_color_override("font_color", HUD_TEAL)
	box.add_child(sacrifice_reward_label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	box.add_child(buttons)
	var confirm := Button.new()
	confirm.text = "SACRIFICE"
	_style_sacrifice_button(confirm)
	confirm.custom_minimum_size = Vector2(140, 38)
	confirm.pressed.connect(_confirm_sacrifice)
	buttons.add_child(confirm)
	var cancel := Button.new()
	cancel.text = "KEEP FIGHTING"
	cancel.custom_minimum_size = Vector2(140, 38)
	cancel.add_theme_stylebox_override("normal", _panel_style(Color("17251e"), HUD_BORDER, 5))
	cancel.add_theme_stylebox_override("hover", _panel_style(Color("263d32"), HUD_TEAL, 5))
	cancel.add_theme_color_override("font_color", HUD_TEXT)
	cancel.pressed.connect(func(): sacrifice_overlay.visible = false)
	buttons.add_child(cancel)


func _show_sacrifice_confirmation() -> void:
	if run_finished:
		return
	sacrifice_reward_label.text = "Memory inherited: +%d" % InheritanceManager.get_memory_reward()
	sacrifice_overlay.visible = true


func _confirm_sacrifice() -> void:
	if run_finished:
		return
	run_finished = true
	sacrifice_overlay.visible = false
	var generation := InheritanceManager.get_generation()
	var inherited := InheritanceManager.player_died()
	_refresh_status()
	message_label.text = "THE SACRIFICE IS REMEMBERED — Generation %d surrendered. +%d Memory" % [generation, inherited]
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://inheritance_system/upgrade_shrine.tscn")


func _on_health_changed(
	current_health: float,
	maximum_health: float
) -> void:
	health_label.text = "HEALTH  %d / %d" % [int(current_health), int(maximum_health)]
	if health_bar != null:
		health_bar.max_value = maximum_health
		health_bar.value = current_health


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q:
		_show_sacrifice_confirmation()
