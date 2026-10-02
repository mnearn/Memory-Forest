extends Node

var current_memory: int = 0
var generation: int = 1
var deepest_room_reached: int = 0
var health_upgrades: int = 0
var attack_upgrades: int = 0
var movement_upgrades: int = 0
var attack_speed_upgrades: int = 0

func begin_run() -> void:
	deepest_room_reached = 0

func enter_room(room_number: int) -> void:
	deepest_room_reached = max(deepest_room_reached, room_number)

func player_died() -> int:
	var earned_memory = deepest_room_reached
	current_memory += earned_memory
	generation += 1
	deepest_room_reached = 0
	return earned_memory

func get_bonus_health() -> float:
	return health_upgrades * 20.0

func get_attack_multiplier() -> float:
	return pow(1.2, attack_upgrades)

func get_movement_speed_multiplier() -> float:
	return pow(1.1, movement_upgrades)

func get_attack_speed_multiplier() -> float:
	return pow(1.15, attack_speed_upgrades)

func get_generation() -> int:
	return generation

func get_current_memory() -> int:
	return current_memory

func get_upgrade_cost(upgrade: String) -> int:
	match upgrade:
		"health":
			return 2 + health_upgrades * 2
		"attack":
			return 3 + attack_upgrades * 2
		"movement":
			return 3 + movement_upgrades * 2
		"attack_speed":
			return 3 + attack_speed_upgrades * 2
		_:
			return -1

func purchase_upgrade(upgrade: String) -> bool:
	var cost = get_upgrade_cost(upgrade)
	if cost < 0 or current_memory < cost:
		return false

	current_memory -= cost
	match upgrade:
		"health":
			health_upgrades += 1
		"attack":
			attack_upgrades += 1
		"movement":
			movement_upgrades += 1
		"attack_speed":
			attack_speed_upgrades += 1
	return true
