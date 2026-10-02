extends Control

var memory_label: Label
var generation_label: Label
var upgrade_status: Label
var upgrade_buttons: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(460.0, 0.0)
	center.add_child(panel)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)

	var title = Label.new()
	title.text = "MEMORY SHRINE"
	title.add_theme_font_size_override("font_size", 28)
	layout.add_child(title)

	generation_label = Label.new()
	layout.add_child(generation_label)

	memory_label = Label.new()
	layout.add_child(memory_label)

	upgrade_status = Label.new()
	upgrade_status.text = "Spend Memory to strengthen the next descendant."
	layout.add_child(upgrade_status)

	_add_upgrade_button(layout, "health", "Health +20")
	_add_upgrade_button(layout, "attack", "Attack damage +20%")
	_add_upgrade_button(layout, "movement", "Movement speed +10%")
	_add_upgrade_button(layout, "attack_speed", "Attack speed +15%")

	var continue_button = Button.new()
	continue_button.text = "ENTER THE FOREST"
	continue_button.pressed.connect(_start_next_generation)
	layout.add_child(continue_button)

	_refresh()

func _add_upgrade_button(layout: VBoxContainer, upgrade: String, description: String) -> void:
	var button = Button.new()
	button.pressed.connect(_purchase_upgrade.bind(upgrade))
	layout.add_child(button)
	upgrade_buttons[upgrade] = {
		"button": button,
		"description": description
	}

func _refresh() -> void:
	generation_label.text = "Generation: %d" % InheritanceManager.get_generation()
	memory_label.text = "Memory: %d" % InheritanceManager.get_current_memory()

	for upgrade in upgrade_buttons:
		var entry = upgrade_buttons[upgrade]
		var button: Button = entry["button"]
		var cost = InheritanceManager.get_upgrade_cost(upgrade)
		button.text = "%s - %d Memory" % [entry["description"], cost]
		button.disabled = InheritanceManager.get_current_memory() < cost

func _purchase_upgrade(upgrade: String) -> void:
	if InheritanceManager.purchase_upgrade(upgrade):
		upgrade_status.text = "Upgrade purchased for the next descendant."
	else:
		upgrade_status.text = "Not enough Memory for that upgrade."
	_refresh()

func _start_next_generation() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
