extends Area2D
class_name PressurePlate

signal activated(plate)
signal deactivated(plate)

@export_group("Plate Properties")
@export var plate_size: Vector2 = Vector2(32, 8)
@export var sequence_number: int = 1
@export var stays_pressed: bool = false
@export var activation_delay: float = 0.0
@export var deactivation_delay: float = 0.1

@export_group("Activation Conditions")
@export var player_only: bool = true
@export var requires_weight: bool = false
@export var minimum_weight: float = 1.0

@export_group("Actions")
@export var target_node_path: NodePath
@export var action_on_press: String = "open"
@export var action_on_release: String = "" 
@export var release_delay: float = 2.5

const MIN_DELAY: float = 0.01

var _release_timer: float = 0.0
var _pending_release: bool = false

var _is_pressed: bool = false
var _bodies_on_plate: Array[Node] = []
var _collision_shape: CollisionShape2D
var _activation_timer: float = 0.0
var _deactivation_timer: float = 0.0
var _press_animation: float = 0.0

func _ready() -> void:
	add_to_group("pressure_plates")
	add_to_group("sonar_platforms")

	position = position.snapped(Vector2(16, 16))

	monitoring = true
	monitorable = true
	collision_layer = 0
	collision_mask = 1

	_configure_collision()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _configure_collision() -> void:
	_collision_shape = CollisionShape2D.new()
	_collision_shape.name = "CollisionShape2D"
	add_child(_collision_shape)

	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = plate_size
	_collision_shape.shape = rect

func _process(delta: float) -> void:
	_update_timers(delta)

	if _is_pressed:
		_press_animation = min(_press_animation + delta * 3.0, 1.0)
		_pending_release = false
		_release_timer = 0.0
	else:
		_press_animation = max(_press_animation - delta * 5.0, 0.0)

	if _pending_release:
		_release_timer += delta
		if _release_timer >= release_delay:
			_trigger_release_action()
			_pending_release = false
			_release_timer = 0.0

func _update_timers(delta: float) -> void:
	var has_valid_bodies: bool = _count_valid_bodies() > 0

	if has_valid_bodies:
		_deactivation_timer = 0.0
		if not _is_pressed:
			_activation_timer += delta
			if _activation_timer >= max(activation_delay, 0.0):
				_press()
	else:
		_activation_timer = 0.0
		if _is_pressed and not stays_pressed:
			_deactivation_timer += delta
			if _deactivation_timer >= max(deactivation_delay, MIN_DELAY):
				_release()

func _count_valid_bodies() -> int:
	var count: int = 0
	for body in _bodies_on_plate:
		if body == null or not is_instance_valid(body):
			continue
		if _is_valid_activator(body):
			count += 1
	return count

func _is_valid_activator(body: Node) -> bool:
	if player_only:
		return body.is_in_group("player")

	if requires_weight:
		if body.has_method("get_weight"):
			return body.get_weight() >= minimum_weight
		return true

	return true

func _press() -> void:
	if _is_pressed:
		return

	_is_pressed = true
	activated.emit(self)
	_trigger_action()

func _release() -> void:
	if not _is_pressed:
		return

	_is_pressed = false
	deactivated.emit(self)

	if not action_on_release.is_empty():
		_pending_release = true
		_release_timer = 0.0

func _trigger_action() -> void:
	if target_node_path.is_empty():
		return

	var target: Node = get_node_or_null(target_node_path)
	if not target:
		push_warning("PressurePlate: Target node not found at path: " + str(target_node_path))
		return

	if target.has_method(action_on_press):
		target.call(action_on_press)
	else:
		push_warning("PressurePlate: Target node does not have method: " + action_on_press)

func _trigger_release_action() -> void:
	if target_node_path.is_empty() or action_on_release.is_empty():
		return

	var target: Node = get_node_or_null(target_node_path)
	if not target:
		return

	if target.has_method(action_on_release):
		target.call(action_on_release)
	else:
		push_warning("PressurePlate: Target node does not have method: " + action_on_release)

func _on_body_entered(body: Node) -> void:
	if body not in _bodies_on_plate:
		_bodies_on_plate.append(body)

func _on_body_exited(body: Node) -> void:
	_bodies_on_plate.erase(body)

func is_pressed() -> bool:
	return _is_pressed

func get_sequence_number() -> int:
	return sequence_number

func reset() -> void:
	_is_pressed = false
	_activation_timer = 0.0
	_deactivation_timer = 0.0
	_bodies_on_plate.clear()
	_press_animation = 0.0

func get_sonar_edges() -> Array:
	var edges: Array = []
	var half_size: Vector2 = plate_size * 0.5

	var corners: Array[Vector2] = [
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y)
	]

	for i in range(corners.size()):
		var start: Vector2 = to_global(corners[i])
		var end: Vector2 = to_global(corners[(i + 1) % corners.size()])
		edges.append({"start": start, "end": end})

	if _press_animation > 0.01:
		var inner_scale: float = 0.3 + (_press_animation * 0.4)
		var inner_half: Vector2 = half_size * inner_scale

		var inner_corners: Array[Vector2] = [
			Vector2(-inner_half.x, -inner_half.y),
			Vector2(inner_half.x, -inner_half.y),
			Vector2(inner_half.x, inner_half.y),
			Vector2(-inner_half.x, inner_half.y)
		]

		for i in range(inner_corners.size()):
			var start: Vector2 = to_global(inner_corners[i])
			var end: Vector2 = to_global(inner_corners[(i + 1) % inner_corners.size()])
			edges.append({"start": start, "end": end})

		var cross_size: float = inner_half.length() * 0.7
		edges.append({
			"start": to_global(Vector2(-cross_size, -cross_size) * 0.5),
			"end": to_global(Vector2(cross_size, cross_size) * 0.5)
		})
		edges.append({
			"start": to_global(Vector2(cross_size, -cross_size) * 0.5),
			"end": to_global(Vector2(-cross_size, cross_size) * 0.5)
		})

	return edges
