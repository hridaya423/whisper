extends AnimatableBody2D

@export var move_distance: Vector2 = Vector2(200, 0)
@export var move_time: float = 2.0
@export var platform_size: Vector2 = Vector2(16, 16)
@export var activation_radius: float = 160.0

var tween: Tween
var _player: Node2D
var _is_active: bool = false
var _start_position: Vector2

func _ready():
	add_to_group("sonar_platforms")
	position = position.snapped(Vector2(16, 16))
	_start_position = position
	_player = _find_player()

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

	if global_position.distance_to(_player.global_position) <= activation_radius:
		_activate_platform()
		set_physics_process(false)

func _activate_platform():
	if _is_active:
		return
	_is_active = true
	position = _start_position
	tween = create_tween().set_loops()
	tween.tween_property(self, "position", _start_position + move_distance, move_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position", _start_position, move_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _find_player() -> Node2D:
	var current_scene = get_tree().current_scene
	if current_scene:
		return current_scene.find_child("Player", true, false) as Node2D
	return null
