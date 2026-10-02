extends SceneTree

func _initialize() -> void:
	call_deferred("_run_probe")

func _run_probe() -> void:
	var main_scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	await physics_frame

	var player = main_scene.player
	var start_position: Vector3 = player.global_position
	var move_press := InputEventKey.new()
	move_press.physical_keycode = KEY_W
	move_press.keycode = KEY_W
	move_press.pressed = true
	Input.parse_input_event(move_press)
	for _frame in range(20):
		await physics_frame
	var move_release := move_press.duplicate() as InputEventKey
	move_release.pressed = false
	Input.parse_input_event(move_release)
	var moved_distance := start_position.distance_to(player.global_position)
	print("INPUT_PROBE movement: start=", start_position, " end=", player.global_position, " distance=", moved_distance)

	var target = main_scene.enemies[0]
	player.facing = Vector3.FORWARD
	target.global_position = player.global_position + Vector3(0.0, 0.0, -1.5)
	target.velocity = Vector3.ZERO
	target.move_speed = 0.0
	var health_before: float = target.health
	var attack_press := InputEventKey.new()
	attack_press.physical_keycode = KEY_SPACE
	attack_press.keycode = KEY_SPACE
	attack_press.pressed = true
	Input.parse_input_event(attack_press)
	await process_frame
	var health_after: float = target.health
	print("INPUT_PROBE light attack: before=", health_before, " after=", health_after)

	if moved_distance <= 0.1 or health_after >= health_before:
		push_error("Input probe failed: movement or attack did not respond to simulated key input.")
		quit(1)
	else:
		print("INPUT_PROBE PASS")
		quit(0)
