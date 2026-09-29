extends Node2D

@export var orbiter: Node2D          # the object that circles the center
@export var radius: float = 24.0     # fixed orbit distance
@export var rotation_offset: float = PI/2  # radians, to match your sprite's default facing

func _process(_delta: float) -> void:
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.is_zero_approx():
		return  # mouse is exactly on the center, direction is undefined

	var dir := to_mouse.normalized()
	orbiter.global_position = global_position + dir * radius
	orbiter.global_rotation = dir.angle() + rotation_offset
