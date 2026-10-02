extends AudioStreamPlayer3D
## Small positional one-shot player; shared gates affect audio only.

var shared_gate := ""
var minimum_gap := 0.0
var gap_remaining := 0.0
var event_count := 0

static func attach(actor: Node3D, sound: AudioStream, node_name: String, level_db: float, gate: String = "", gap: float = 0.0) -> AudioStreamPlayer3D:
	var voice = load("res://audio/world_event_sfx.gd").new()
	voice.name = node_name
	voice.stream = sound
	voice.volume_db = level_db
	voice.position.y = 1.0
	voice.unit_size = 8.0
	voice.max_distance = 35.0
	voice.max_polyphony = 1
	voice.shared_gate = gate
	voice.minimum_gap = gap
	actor.add_child(voice)
	if not gate.is_empty():
		voice.add_to_group(gate)
	return voice

func _process(delta: float) -> void:
	gap_remaining = maxf(0.0, gap_remaining - delta)

func play_event() -> void:
	if gap_remaining > 0.0:
		return
	if not shared_gate.is_empty():
		for voice in get_tree().get_nodes_in_group(shared_gate):
			if voice.playing or voice.gap_remaining > 0.0:
				return
	play()
	event_count += 1
	gap_remaining = minimum_gap
