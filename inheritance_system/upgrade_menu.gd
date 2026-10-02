extends Control

# Descendant upgrade menu.
# Appears before the next generation enters Room 1.

@onready var memory_label: Label = $Panel/VBoxContainer/MemoryLabel
@onready var generation_label: Label = $Panel/VBoxContainer/GenerationLabel

@onready var attack_button: Button = $Panel/VBoxContainer/AttackButton
@onready var attack_speed_button: Button = $Panel/VBoxContainer/AttackSpeedButton
@onready var movement_speed_button: Button = $Panel/VBoxContainer/MovementSpeedButton
@onready var health_button: Button = $Panel/VBoxContainer/HealthButton


func _ready() -> void:
	update_menu()


func update_menu() -> void:
	memory_label.text = "Memory: %d" % InheritanceManager.get_current_memory()
	generation_label.text = "Generation: %d" % InheritanceManager.get_generation()

	update_button(
		attack_button,
		"Attack",
		"attack"
	)

	update_button(
		attack_speed_button,
		"Attack Speed",
		"attack_speed"
	)

	update_button(
		movement_speed_button,
		"Movement Speed",
		"movement_speed"
	)

	update_button(
		health_button,
		"Max Health",
		"health"
	)


func update_button(
	button: Button,
	display_name: String,
	upgrade_name: String
) -> void:

	var level := InheritanceManager.get_upgrade_level(upgrade_name)
	var cost := InheritanceManager.get_upgrade_cost(upgrade_name)

	button.text = "%s Lv.%d - %d Memory" % [
		display_name,
		level,
		cost
	]

	button.disabled = (
		InheritanceManager.get_current_memory() < cost
	)


func buy_upgrade(upgrade_name: String) -> void:
	var purchased := InheritanceManager.purchase_upgrade(upgrade_name)

	if purchased:
		update_menu()


func _on_attack_button_pressed() -> void:
	buy_upgrade("attack")


func _on_attack_speed_button_pressed() -> void:
	buy_upgrade("attack_speed")


func _on_movement_speed_button_pressed() -> void:
	buy_upgrade("movement_speed")


func _on_health_button_pressed() -> void:
	buy_upgrade("health")
