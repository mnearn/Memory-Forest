extends Node3D

var memory_label: Label
var generation_label: Label
var message_label: Label
var cards_box: VBoxContainer
var strength_label: Label
var begin_button: Button

const TEAL := Color(0.25, 0.95, 0.70)
const TEAL_DIM := Color(0.10, 0.48, 0.34)
const BONE := Color(0.91, 0.90, 0.82)
const INK := Color(0.008, 0.018, 0.014, 0.94)
const STONE := Color(0.035, 0.050, 0.041, 0.97)

func _ready() -> void:
	_build_environment()
	_build_ui()
	_refresh_ui()

func _style(bg: Color, border: Color, radius: int = 8, width: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	return s

func _label(text_value: String, size: int = 16, color: Color = BONE) -> Label:
	var l := Label.new()
	l.text = text_value
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.003, 0.012, 0.008)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.08, 0.18, 0.12)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)

	# Dark forest floor beneath the real shrine model.
	var floor := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 8.0; fm.bottom_radius = 8.5; fm.height = 0.35
	floor.mesh = fm; floor.position = Vector3(0, -1.12, -2.2)
	var fmat := StandardMaterial3D.new(); fmat.albedo_color = Color(0.025, 0.045, 0.028)
	floor.material_override = fmat; add_child(floor)

	# Official Memory Shrine model supplied by the user.
	var shrine_scene := load("res://assets/shrine/memory_shrine.glb") as PackedScene
	if shrine_scene:
		var shrine := shrine_scene.instantiate()
		shrine.name = "MemoryShrineModel"
		shrine.position = Vector3(0, 0.0, -2.4)
		shrine.scale = Vector3(3.5, 3.5, 3.5)
		shrine.rotation_degrees.y = 180.0
		_restore_shrine_normals(shrine)
		add_child(shrine)

	# Teal memory glow around the physical shrine.
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 1.3, -1.0)
	glow.light_color = Color(0.16, 1.0, 0.66)
	glow.omni_range = 9.0
	glow.light_energy = 5.0
	add_child(glow)

	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-48, -28, 0)
	rim.light_color = Color(0.55, 0.68, 0.58)
	rim.light_energy = 0.9
	rim.shadow_enabled = true
	add_child(rim)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 2.8, 8.6)
	camera.rotation_degrees = Vector3(-8, 0, 0)
	camera.fov = 56
	add_child(camera)

func _restore_shrine_normals(node: Node) -> void:
	# The supplied GLB has no vertex normals. Keep its geometry, UVs and materials.
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		var source_mesh := instance.mesh
		if source_mesh is ArrayMesh:
			var repaired_mesh := ArrayMesh.new()
			var repaired := false
			for surface in range(source_mesh.get_surface_count()):
				var arrays := source_mesh.surface_get_arrays(surface)
				var normals = arrays[Mesh.ARRAY_NORMAL]
				if (normals == null or normals.is_empty()) and source_mesh.surface_get_primitive_type(surface) == Mesh.PRIMITIVE_TRIANGLES:
					var surface_tool := SurfaceTool.new()
					surface_tool.create_from(source_mesh, surface)
					surface_tool.generate_normals()
					arrays[Mesh.ARRAY_NORMAL] = surface_tool.commit_to_arrays()[Mesh.ARRAY_NORMAL]
					repaired = true
				repaired_mesh.add_surface_from_arrays(source_mesh.surface_get_primitive_type(surface), arrays)
				repaired_mesh.surface_set_material(surface, source_mesh.surface_get_material(surface))
				repaired_mesh.surface_set_name(surface, source_mesh.surface_get_name(surface))
			if repaired:
				instance.mesh = repaired_mesh
	for child in node.get_children():
		_restore_shrine_normals(child)

func _build_ui() -> void:
	var canvas := CanvasLayer.new(); add_child(canvas)

	# Subtle vignette-like overlay keeps text readable while leaving the shrine visible.
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.015, 0.01, 0.16)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(shade)

	# Header.
	var header := PanelContainer.new()
	header.position = Vector2(330, 18); header.custom_minimum_size = Vector2(620, 104)
	header.add_theme_stylebox_override("panel", _style(Color(0.008,0.022,0.017,0.93), TEAL_DIM, 10, 2))
	canvas.add_child(header)
	var hb := VBoxContainer.new(); hb.alignment = BoxContainer.ALIGNMENT_CENTER; header.add_child(hb)
	var title := _label("MEMORY SHRINE", 31, BONE); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; hb.add_child(title)
	generation_label = _label("", 16, Color(0.75,0.80,0.74)); generation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; hb.add_child(generation_label)
	memory_label = _label("", 23, TEAL); memory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; hb.add_child(memory_label)

	# Left: inheritance cards. The center of the screen stays open so the 3D shrine is visible.
	var left := PanelContainer.new()
	left.position = Vector2(28, 142); left.custom_minimum_size = Vector2(455, 540)
	left.add_theme_stylebox_override("panel", _style(INK, Color(0.07,0.28,0.20,0.95), 12, 2)); canvas.add_child(left)
	var lm := MarginContainer.new(); lm.add_theme_constant_override("margin_left",16); lm.add_theme_constant_override("margin_right",16); lm.add_theme_constant_override("margin_top",16); lm.add_theme_constant_override("margin_bottom",16); left.add_child(lm)
	var main := VBoxContainer.new(); main.add_theme_constant_override("separation",9); lm.add_child(main)
	var section := _label("INHERIT THE FALLEN", 20, TEAL); section.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; main.add_child(section)
	var desc := _label("Spend Memory to strengthen every descendant who follows.", 13, Color(0.72,0.76,0.70)); desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; main.add_child(desc)
	cards_box = VBoxContainer.new(); cards_box.add_theme_constant_override("separation",7); main.add_child(cards_box)
	message_label = _label("", 13, TEAL); message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; main.add_child(message_label)

	# Right: current inherited strength + run button.
	var right := PanelContainer.new()
	right.position = Vector2(925, 184); right.custom_minimum_size = Vector2(325, 390)
	right.add_theme_stylebox_override("panel", _style(INK, Color(0.07,0.28,0.20,0.95), 12, 2)); canvas.add_child(right)
	var rm := MarginContainer.new(); rm.add_theme_constant_override("margin_left",18); rm.add_theme_constant_override("margin_right",18); rm.add_theme_constant_override("margin_top",18); rm.add_theme_constant_override("margin_bottom",18); right.add_child(rm)
	var rv := VBoxContainer.new(); rv.add_theme_constant_override("separation",14); rm.add_child(rv)
	var st := _label("YOUR INHERITED STRENGTH", 18, TEAL); st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; rv.add_child(st)
	var line := HSeparator.new(); rv.add_child(line)
	strength_label = _label("", 16, BONE); strength_label.add_theme_constant_override("line_spacing", 8); rv.add_child(strength_label)
	var lore := _label("The forest remembers every life that came before.", 13, Color(0.64,0.70,0.64)); lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; rv.add_child(lore)
	begin_button = Button.new(); begin_button.custom_minimum_size = Vector2(0,58); begin_button.add_theme_font_size_override("font_size",16); begin_button.add_theme_color_override("font_color", BONE); begin_button.add_theme_stylebox_override("normal", _style(Color(0.045,0.16,0.115,0.98), TEAL_DIM,8,2)); begin_button.add_theme_stylebox_override("hover", _style(Color(0.06,0.25,0.17,0.98), TEAL,8,2)); begin_button.pressed.connect(_start_demo_run); rv.add_child(begin_button)

func _upgrade_values(name: String, level: int) -> Array[String]:
	match name:
		"attack": return ["%d%%" % (100 + level*5), "%d%%" % (105 + level*5), "+5%"]
		"attack_speed": return ["%d%%" % (100 + level*5), "%d%%" % (105 + level*5), "+5%"]
		"movement_speed": return ["%d%%" % (100 + level*4), "%d%%" % (104 + level*4), "+4%"]
		"health": return [str(100 + level*10), str(110 + level*10), "+10 HP"]
	return ["?","?","?"]

func _add_card(display: String, key: String) -> void:
	var level := InheritanceManager.get_upgrade_level(key)
	var cost := InheritanceManager.get_upgrade_cost(key)
	var vals := _upgrade_values(key, level)
	var can_buy := InheritanceManager.get_current_memory() >= cost
	var card := PanelContainer.new(); card.custom_minimum_size = Vector2(0,82)
	card.add_theme_stylebox_override("panel", _style(STONE, Color(0.08,0.30,0.22,0.9),7,1)); cards_box.add_child(card)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation",8); card.add_child(row)
	var info := _label("%s   LV %d → %d\n%s → %s   %s" % [display,level,level+1,vals[0],vals[1],vals[2]], 14, BONE)
	info.custom_minimum_size = Vector2(270,0); info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; row.add_child(info)
	var button := Button.new(); button.text = "INHERIT\n%d MEMORY" % cost; button.custom_minimum_size = Vector2(140,66); button.disabled = not can_buy
	button.add_theme_font_size_override("font_size",13)
	button.add_theme_stylebox_override("normal", _style(Color(0.035,0.13,0.095), TEAL_DIM,6,1)); button.add_theme_stylebox_override("hover", _style(Color(0.055,0.23,0.16), TEAL,6,2))
	button.pressed.connect(func(): _buy_upgrade(key, display, vals[0], vals[1])); row.add_child(button)

func _refresh_ui() -> void:
	var generation := InheritanceManager.get_generation()
	generation_label.text = "GENERATION %d" % generation
	memory_label.text = "MEMORY  ◆  %d" % InheritanceManager.get_current_memory()
	begin_button.text = "BEGIN GENERATION %d" % generation
	for child in cards_box.get_children(): child.queue_free()
	_add_card("ATTACK", "attack")
	_add_card("MAX HEALTH", "health")
	_add_card("ATTACK SPEED", "attack_speed")
	_add_card("MOVEMENT SPEED", "movement_speed")
	var hp := 100 + InheritanceManager.get_upgrade_level("health") * 10
	var atk := 100 + InheritanceManager.get_upgrade_level("attack") * 5
	var aspd := 100 + InheritanceManager.get_upgrade_level("attack_speed") * 5
	var move := 100 + InheritanceManager.get_upgrade_level("movement_speed") * 4
	strength_label.text = "HEALTH\n   %d HP\n\nATTACK\n   %d%%\n\nATTACK SPEED\n   %d%%\n\nMOVEMENT\n   %d%%" % [hp, atk, aspd, move]

func _buy_upgrade(key: String, display: String, before: String, after: String) -> void:
	if InheritanceManager.purchase_upgrade(key):
		message_label.text = "MEMORY INHERITED\n%s   %s → %s" % [display,before,after]
	else:
		message_label.text = "NOT ENOUGH MEMORY"
	_refresh_ui()

func _start_demo_run() -> void:
	get_tree().change_scene_to_file("res://demo/demo_run.tscn")
