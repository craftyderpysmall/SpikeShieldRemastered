extends Area2D

@export var player: Node2D
@export var camera: Camera2D
@export var hit_player: AudioStreamPlayer2D
@export var death_player: AudioStreamPlayer2D
@export var effect: PackedScene
@export var particle_container: Node2D
@export var godmode_hitbox: CollisionShape2D

@export var base_zoom: Vector2 = Vector2(1.0, 1.0)
@export var bump_intensity: float = 0.05
@export var bump_in_time: float = 0.02
@export var bump_out_time: float = 0.25

var pulse_tween: Tween

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Node2D) -> void:
	if area.name == "Shield": return
	if player.dead == true: return
	
	if player.godmode == true:
		godmode_hitbox.disabled = false
		hit(area)
	else:
		godmode_hitbox.disabled = true
		player.dead = true
		death_player.play()
		area.get_node("Outline").show()

func hit(area: Node2D) -> void:
	# Hit Particle Effect
	var particle = effect.instantiate()
	particle_container.add_child(particle)
	particle.position = area.global_position
	particle.rotation = area.global_rotation
	particle.emitting = true
	
	# Hit Camera Bump
	if pulse_tween and pulse_tween.is_running():
		pulse_tween.kill()
	pulse_tween = create_tween()
	var target_zoom = base_zoom + Vector2(bump_intensity, bump_intensity)
	pulse_tween.tween_property(camera, "zoom", target_zoom, bump_in_time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	pulse_tween.tween_property(camera, "zoom", base_zoom, bump_out_time)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	
	hit_player.play()
	area.queue_free()
