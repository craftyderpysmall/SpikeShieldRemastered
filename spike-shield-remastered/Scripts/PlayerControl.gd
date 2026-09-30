extends Node2D

@export var center: Node2D
@export var orbiter: Node2D
@export var radius: float = 24.0     # fixed orbit distance
@export var rotation_offset: float = PI/2  # radians, to match your sprite's default facing
@export var controller_deadzone: float = 0.2

var use_mouse: bool = true
var dead: bool = false
var restarting: bool = false
var godmode: bool = false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		use_mouse = true
	elif event is InputEventJoypadMotion and abs(event.axis_value) > controller_deadzone:
		use_mouse = false
		
	if restarting == true:
		dead = false
		restarting = false
	else:
		if Input.is_action_just_pressed("Restart"):
			if dead == true:
				dead = false
			else:
				dead = true
				restarting = true
	
	if Input.is_action_just_pressed("Godmode"):
		godmode = not godmode

func _process(_delta: float) -> void:
	if dead == true:
		return
	
	var dir: Vector2 = Vector2.ZERO

	if use_mouse:
		var to_mouse := get_global_mouse_position() - center.global_position
		if to_mouse.is_zero_approx():
			return
		dir = to_mouse.normalized()
	else:
		var stick: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down", controller_deadzone)
		if stick.is_zero_approx():
			return  # stick released: keep the last position
		dir = stick.normalized()

	orbiter.global_position = center.global_position + dir * radius
	orbiter.global_rotation = dir.angle() + rotation_offset
