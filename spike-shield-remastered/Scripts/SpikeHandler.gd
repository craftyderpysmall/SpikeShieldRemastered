extends Node2D

@export var audio_player: AudioStreamPlayer2D
@export var ball: Node2D
@export var spawn_points_path: NodePath
@export var level_path: String = "res://Levels/deadlocked.json"
@export var object_scene: PackedScene
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

func _ready():
	_load_spawn_points()
	load_level(level_path)
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
	
	print()


func _start_audio() -> void:
	audio_player.play()
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
	song_time_seconds += delta
	var song_time_beats = song_time_seconds * (bpm / 60.0)

	while next_event_index < events.size() \
			and events[next_event_index]["beat_time"] <= song_time_beats:

		var event = events[next_event_index]
		for dir_name in event["dirs"]:
			spawn_object(str(dir_name))

		next_event_index += 1

	_update_objects(delta)


func _update_objects(delta: float) -> void:
	var center: Vector2 = ball.global_position

	for obj in active_objects:
		var dir_to_center = (center - obj.position).normalized()
		obj.position += dir_to_center * speed * delta
		# check_shield_collision(obj)

# ---- Spawning helper ----
func spawn_object(dir_name: String) -> void:
	if not spawn_data.has(dir_name):
		push_warning("Unknown direction in level data: " + dir_name)
		return

	var data = spawn_data[dir_name]
	var center: Vector2 = ball.global_position

	var obj = object_scene.instantiate()
	obj.global_position = data["pos"]
	obj.rotation = (center - data["pos"]).angle() + rotation_offset

	add_child(obj)
	active_objects.append(obj)
