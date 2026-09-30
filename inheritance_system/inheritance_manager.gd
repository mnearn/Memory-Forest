extends Node
const SAVE_PATH := "user://inheritance_save.json"
# ============================================================
# MEMORY FOREST - INHERITANCE MANAGER
# ============================================================
# Handles persistent Memory, room progression, generations,
# and inherited player upgrades.
#
# Enemy systems can READ progression values from this manager,
# but enemy transformation logic belongs to another system.
# ============================================================


# ---------------- MEMORY ----------------

# Memory the player currently has available to spend.
var current_memory: int = 0

# All Memory earned by the bloodline.
# Spending Memory DOES NOT lower this value.
var total_memory_earned: int = 0


# ---------------- RUN PROGRESSION ----------------

const MAX_ROOMS: int = 5

# Current room reached during this run.
var current_room: int = 1

# Highest room reached during this run.
var furthest_room: int = 1

# Number of characters/generations played.
var generation: int = 1


# Memory earned based on the furthest room reached.
# These numbers are intentionally easy to rebalance.
var room_memory_rewards := {
	1: 0,
	2: 10,
	3: 25,
	4: 50,
	5: 100
}


# ---------------- UPGRADES ----------------

var attack_level: int = 0
var attack_speed_level: int = 0
var movement_speed_level: int = 0
var health_level: int = 0


# Upgrade costs by level:
# Level 0 -> 1 costs 10
# Level 1 -> 2 costs 20
# etc.
const BASE_UPGRADE_COST: int = 10
func _ready() -> void:
	load_inheritance()

# ---------------- ROOM TRACKING ----------------

func enter_room(room_number: int) -> void:
	if room_number < 1 or room_number > MAX_ROOMS:
		push_warning("Invalid room number: " + str(room_number))
		return

	current_room = room_number

	if room_number > furthest_room:
		furthest_room = room_number


# ---------------- DEATH / INHERITANCE ----------------

func player_died() -> int:
	var memory_gained: int = get_memory_reward()

	current_memory += memory_gained
	total_memory_earned += memory_gained

	generation += 1

	reset_run()
save_inheritance()

	return memory_gained


func get_memory_reward() -> int:
	return room_memory_rewards.get(furthest_room, 0)


func reset_run() -> void:
	current_room = 1
	furthest_room = 1


# ---------------- MEMORY ACCESS ----------------

func get_current_memory() -> int:
	return current_memory


func get_total_memory_earned() -> int:
	# Other systems, such as enemy progression,
	# can safely read this value.
	return total_memory_earned


func get_generation() -> int:
	return generation


# ---------------- UPGRADE COSTS ----------------

func get_upgrade_cost(upgrade_name: String) -> int:
	var level := get_upgrade_level(upgrade_name)

	if level < 0:
		return -1

	return BASE_UPGRADE_COST * (level + 1)


func get_upgrade_level(upgrade_name: String) -> int:
	match upgrade_name:
		"attack":
			return attack_level

		"attack_speed":
			return attack_speed_level

		"movement_speed":
			return movement_speed_level

		"health":
			return health_level

		_:
			push_warning("Unknown upgrade: " + upgrade_name)
			return -1


# ---------------- BUYING UPGRADES ----------------

func purchase_upgrade(upgrade_name: String) -> bool:
	var cost := get_upgrade_cost(upgrade_name)

	if cost < 0:
		return false

	if current_memory < cost:
		return false

	current_memory -= cost

	match upgrade_name:
		"attack":
			attack_level += 1

		"attack_speed":
			attack_speed_level += 1

		"movement_speed":
			movement_speed_level += 1

		"health":
			health_level += 1

		_:
			return false

	return true


# ---------------- PLAYER STAT BONUSES ----------------

func get_attack_multiplier() -> float:
	# +5% damage per level
	return 1.0 + (attack_level * 0.05)


func get_attack_speed_multiplier() -> float:
	# +5% attack speed per level
	return 1.0 + (attack_speed_level * 0.05)


func get_movement_speed_multiplier() -> float:
	# +4% movement speed per level
	return 1.0 + (movement_speed_level * 0.04)


func get_bonus_health() -> int:
	# +10 maximum health per level
	return health_level * 10


# ============================================================
# SAVE / LOAD
# ============================================================

func save_inheritance() -> void:
	var save_data := {
		"current_memory": current_memory,
		"total_memory_earned": total_memory_earned,
		"generation": generation,

		"attack_level": attack_level,
		"attack_speed_level": attack_speed_level,
		"movement_speed_level": movement_speed_level,
		"health_level": health_level
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file == null:
		push_warning("Could not save inheritance data.")
		return

	file.store_string(JSON.stringify(save_data))


func load_inheritance() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)

	if file == null:
		push_warning("Could not load inheritance data.")
		return

	var json := JSON.new()
	var error := json.parse(file.get_as_text())

	if error != OK:
		push_warning("Inheritance save file could not be read.")
		return

	var data = json.data

	if typeof(data) != TYPE_DICTIONARY:
		return

	current_memory = int(data.get("current_memory", 0))
	total_memory_earned = int(data.get("total_memory_earned", 0))
	generation = int(data.get("generation", 1))

	attack_level = int(data.get("attack_level", 0))
	attack_speed_level = int(data.get("attack_speed_level", 0))
	movement_speed_level = int(data.get("movement_speed_level", 0))
	health_level = int(data.get("health_level", 0))


func reset_inheritance_save() -> void:
	current_memory = 0
	total_memory_earned = 0
	generation = 1

	attack_level = 0
	attack_speed_level = 0
	movement_speed_level = 0
	health_level = 0

	reset_run()
	save_inheritance()
