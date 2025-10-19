extends AnimatableBody2D

@export var move_distance: Vector2 = Vector2(200, 0)
@export var move_time: float = 2.0
@export var platform_size: Vector2 = Vector2(16, 16)
@export var activation_radius: float = 160.0
@export var end_pause_time: float = 1.0

var tween: Tween
var _player: Node2D
var _is_active: bool = false
var _start_position: Vector2
var _activation_radius_squared: float = 0.0

func _ready():
	add_to_group("sonar_platforms")
	position = position.snapped(Vector2(16, 16))
	_start_position = position
	_player = _find_player()
	var clamped_radius: float = max(activation_radius, 0.0)
	_activation_radius_squared = clamped_radius * clamped_radius

	if $Sprite2D:
		$Sprite2D.visible = false

	if $CollisionShape2D and $CollisionShape2D.shape is RectangleShape2D:
		$CollisionShape2D.shape.size = platform_size

	if activation_radius <= 0.0:
		_activate_platform()
	else:
		set_physics_process(true)

func _physics_process(_delta):
	if _is_active:
		set_physics_process(false)
		return

	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
	if _player == null or not is_instance_valid(_player):
		return

	if activation_radius <= 0.0 or global_position.distance_squared_to(_player.global_position) <= _activation_radius_squared:
		_activate_platform()
		set_physics_process(false)

func _activate_platform():
	if _is_active:
		return
	_is_active = true
	position = _start_position
	var pause_duration: float = max(end_pause_time, 0.0)
	tween = create_tween().set_loops()
	if pause_duration > 0.0:
		tween.tween_interval(pause_duration)
	tween.tween_property(self, "position", _start_position + move_distance, move_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if pause_duration > 0.0:
		tween.tween_interval(pause_duration)
	tween.tween_property(self, "position", _start_position, move_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _find_player() -> Node2D:
	var current_scene = get_tree().current_scene
	if current_scene:
		return current_scene.find_child("Player", true, false) as Node2D
	return null
