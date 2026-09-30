extends Node2D

@export var level_id: int

var level_path: String
var song_path: String

var level_dictionary: Dictionary[int, Array] = {
	1: ["NUMBER", "res://Levels/number.json", "res://Music/NUMBER.mp3"],
	2: ["Deadlocked", "res://Levels/deadlocked.json", "res://Music/Deadlocked.mp3"],
}

# _enter_tree is called between _init and children's _ready
func _enter_tree() -> void:
	print(level_id)
	level_path = level_dictionary[level_id][1]
	song_path = level_dictionary[level_id][2]
