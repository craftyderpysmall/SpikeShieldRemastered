extends Node2D

@export var level: Node2D
@export var music_player: AudioStreamPlayer2D
@export var player: Node2D
@export var ball: Node2D
@export var spawn_points_path: NodePath
@export var spike_scene: PackedScene
@export var hit_radius: float = 24.0  # distance from center where beat should land
@export var rotation_offset: float = -(PI/2)  # radians, to match your sprite's default facing


const DIRECTION_NAMES = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

# populated in _ready: { "N": {"pos": Vector2, "angle": float}, "NE": {...}, ... }
var spawn_data: Dictionary = {}

var bpm: float
var speed: float
var events: Array = []
var next_event_index: int = 0
var song_time_seconds: float = 0.0
var active_objects: Array = []
var audio_delay: float = 0.0
var audio_started: bool = false
var was_dead: bool = false # To check if recently restarted in _process
var last_song_time_beats: float = 0.0 # For pulses

func _ready():
	_load_spawn_points()
	load_level(level.level_path)
	music_player.stream = load(level.song_path)
	_setup_audio_offset()

# ---- Read spawn point positions + rotations from the scene tree ----
func _load_spawn_points() -> void:
	var spawn_container = get_node(spawn_points_path)

	for dir_name in DIRECTION_NAMES:
		var marker: Node2D = spawn_container.get_node(dir_name)
		spawn_data[dir_name] = {
			"pos": marker.global_position,
			"angle": marker.global_rotation_degrees,
		}

# ---- Compute travel_time and delay audio start ----
func _setup_audio_offset() -> void:
	var center: Vector2 = ball.global_position

	# use distance from any one spawn point as reference
	# (assumes spawn points are equidistant from center — see note above)
	var reference_pos: Vector2 = spawn_data[DIRECTION_NAMES[0]]["pos"]
	var travel_distance = reference_pos.distance_to(center) - hit_radius

	audio_delay = travel_distance / speed

	var timer = get_tree().create_timer(audio_delay)
	timer.timeout.connect(_start_audio)


func _start_audio() -> void:
	music_player.play()
	audio_started = true
	
# ---- Convert [beat, interval] -> beats since start ----
func step_to_beats(step: Array) -> float:
	var beat: int = step[0]
	var interval: int = step[1]
	return float(beat - 1) + float(interval - 1) / 8.0

# ---- Load and parse level JSON ----
func load_level(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()

	var data = JSON.parse_string(json_text)

	bpm = data.get("bpm", 120.0)
	speed = data.get("speed", 120.0)
	events = data.get("events", [])

	for event in events:
		event["beat_time"] = step_to_beats(event["step"])

	events.sort_custom(func(a, b): return a["beat_time"] < b["beat_time"])

	next_event_index = 0
	song_time_seconds = 0.0

# ---- Main loop ----
func _process(delta: float) -> void:
	if player.dead == true:
		dead()
		was_dead = true
		return
	elif player.dead == false and was_dead == true:
		restart()
		was_dead = false
		return
	
	song_time_seconds += delta
	var song_time_beats = song_time_seconds * (bpm / 60.0)
	
	# Pulse towers on beat
	if floor(song_time_beats) > floor(last_song_time_beats):
		for tower in get_node(spawn_points_path).get_children():
			pulse(tower)

	last_song_time_beats = song_time_beats

	while next_event_index < events.size() \
			and events[next_event_index]["beat_time"] <= song_time_beats:

		var event = events[next_event_index]
		for dir_name in event["dirs"]:
			spawn_object(str(dir_name))

		next_event_index += 1

	_update_objects(delta)


func _update_objects(delta: float) -> void:
	var center: Vector2 = ball.global_position
	var objects_to_delete: Array = []

	if player.dead == true:
		return

	for obj in active_objects:
		if is_instance_valid(obj):
			var dir_to_center = (center - obj.position).normalized()
			obj.position += dir_to_center * speed * delta
		else: # Deleted
			objects_to_delete.append(obj)
		
	for obj in objects_to_delete:
		active_objects.erase(obj)

# ---- Spawning helper ----
func spawn_object(dir_name: String) -> void:
	if not spawn_data.has(dir_name):
		push_warning("Unknown direction in level data: " + dir_name)
		return

	var data = spawn_data[dir_name]
	var center: Vector2 = ball.global_position

	var obj = spike_scene.instantiate()
	obj.name = dir_name + "SPIKE"
	obj.global_position = data["pos"]
	obj.rotation = (center - data["pos"]).angle() + rotation_offset

	add_child(obj)
	active_objects.append(obj)
	
func pulse(target: CanvasItem) -> void:
	if not is_instance_valid(target):
		return
	
	var tween = create_tween().bind_node(target)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	tween.tween_property(target, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(target, "scale", Vector2(1.0, 1.0), 0.1)
	
	tween.finished.connect(pulse)
	
func dead() -> void:
	music_player.stop()
	audio_started = false
	audio_delay = 0.0
	next_event_index = 0
	song_time_seconds = 0.0
	next_event_index = 0
	active_objects.clear()

func restart() -> void:
	for child in get_children():
		child.queue_free()
	_setup_audio_offset()
