extends Node2D

@export var rod_length: float = 140.0
@export var bob_radius: float = 18.0
@export var swing_amplitude_degrees: float = 65.0
@export var swing_period: float = 2.5
@export var swing_center_offset_degrees: float = 0.0
@export var push_force: float = 720.0
@export var damage_cooldown: float = 0.8
@export var start_time_offset: float = 0.0
var _elapsed_time: float = 0.0
var _bob_position: Vector2 = Vector2.ZERO
var _previous_bob_position: Vector2 = Vector2.ZERO
var _bob_velocity: Vector2 = Vector2.ZERO
var _last_hit_time_by_body: Dictionary[int, float] = {}
var _previous_bob_velocity: Vector2 = Vector2.ZERO
var sonar_system: Node

const _MIN_DELTA: float = 0.0001
const SONAR_RANGE_PADDING: float = 18.0
const SONAR_CONE_PADDING: float = 8.0
const SONAR_WAVE_TOLERANCE: float = 28.0

@onready var _bob_area: Area2D = $BobArea
@onready var _bob_collision: CollisionShape2D = $BobArea/CollisionShape2D

func _ready():
	add_to_group("hazards")
	add_to_group("sonar_platforms")
	sonar_system = _find_sonar_system()
	visible = Engine.is_editor_hint()
	_elapsed_time = start_time_offset
	_previous_bob_position = _calculate_bob_position(_elapsed_time)
	_apply_bob_position(_previous_bob_position)
	_update_collision_shape()
	if _bob_area and is_instance_valid(_bob_area):
		_bob_area.body_exited.connect(_on_bob_area_body_exited)
		_bob_area.monitoring = true
		_bob_area.monitorable = true
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed_time += delta
	var new_position := _calculate_bob_position(_elapsed_time)
	_bob_velocity = (new_position - _previous_bob_position) / max(delta, _MIN_DELTA)
	if _previous_bob_velocity.length_squared() > 1.0 and _bob_velocity.length_squared() > 1.0:
		if _previous_bob_velocity.dot(_bob_velocity) < 0.0:
			_last_hit_time_by_body.clear()
	_previous_bob_velocity = _bob_velocity
	_previous_bob_position = new_position

	_apply_bob_position(new_position)
	queue_redraw()

	if not Engine.is_editor_hint() and _bob_area and is_instance_valid(_bob_area):
		var now_seconds := Time.get_ticks_msec() / 1000.0
		for body in _bob_area.get_overlapping_bodies():
			_apply_pendulum_effect(body, now_seconds)

func _calculate_bob_position(time_value: float) -> Vector2:
	if swing_period <= _MIN_DELTA:
		return Vector2.DOWN * rod_length

	var angular_frequency := TAU / swing_period
	var angle := deg_to_rad(swing_center_offset_degrees) + sin(time_value * angular_frequency) * deg_to_rad(swing_amplitude_degrees)
	return Vector2.DOWN.rotated(angle) * rod_length

func _apply_bob_position(local_position: Vector2) -> void:
	_bob_position = local_position
	if _bob_area and is_instance_valid(_bob_area):
		_bob_area.position = local_position

func _apply_pendulum_effect(body: Node, now_seconds: float) -> void:
	if body == null or not is_instance_valid(body):
		return

	var body_id: int = body.get_instance_id()
	var last_hit_time: float = -damage_cooldown
	if _last_hit_time_by_body.has(body_id):
		var stored_time: Variant = _last_hit_time_by_body[body_id]
		if stored_time is float:
			last_hit_time = stored_time
		elif stored_time != null:
			last_hit_time = float(stored_time)
	if now_seconds - last_hit_time < damage_cooldown:
		return

	_last_hit_time_by_body[body_id] = now_seconds

	var push_direction := _bob_velocity
	if push_direction.length_squared() < 0.0001:
		push_direction = (body.global_position - global_position).normalized()
	else:
		push_direction = push_direction.normalized()

	if body is CharacterBody2D:
		body.velocity = push_direction * push_force
	elif body.has_method("apply_central_impulse"):
		body.apply_central_impulse(push_direction * push_force)

	if body.has_method("take_damage"):
		body.take_damage()

func _on_bob_area_body_exited(body: Node) -> void:
	if body == null or not is_instance_valid(body):
		return
	_last_hit_time_by_body.erase(body.get_instance_id())

func _update_collision_shape() -> void:
	if not _bob_collision or not is_instance_valid(_bob_collision):
		return
	var circle_shape: CircleShape2D
	if _bob_collision.shape and _bob_collision.shape is CircleShape2D:
		circle_shape = _bob_collision.shape
	else:
		circle_shape = CircleShape2D.new()
		_bob_collision.shape = circle_shape
	circle_shape.radius = bob_radius

func get_sonar_edges() -> Array:
	var edges: Array = []
	var pivot_global := global_position
	var bob_global := to_global(_bob_position)
	edges.append({"start": pivot_global, "end": bob_global})

	var segments := 12
	for i in range(segments):
		var angle_a := TAU * float(i) / segments
		var angle_b := TAU * float(i + 1) / segments
		var point_a_local := _bob_position + Vector2(cos(angle_a), sin(angle_a)) * bob_radius
		var point_b_local := _bob_position + Vector2(cos(angle_b), sin(angle_b)) * bob_radius
		edges.append({
			"start": to_global(point_a_local),
			"end": to_global(point_b_local)
		})
	return edges

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAW:
		_draw_pendulum()

func _draw_pendulum() -> void:
	if not Engine.is_editor_hint():
		return
	var arm_color := Color(0.7, 0.7, 0.8, 1.0)
	var bob_color_outer := Color(0.45, 0.45, 0.55, 1.0)
	var bob_color_inner := Color(0.9, 0.85, 0.55, 0.9)

	draw_line(Vector2.ZERO, _bob_position, arm_color, 3.0)
	draw_circle(_bob_position, bob_radius, bob_color_outer)
	draw_circle(_bob_position, bob_radius * 0.55, bob_color_inner)

func _find_sonar_system() -> Node:
	var root := get_tree().root
	if not root:
		return null
	return root.find_child("SonarSystem", true, false)

func _is_sonar_wave_revealing() -> bool:
	if not sonar_system or not is_instance_valid(sonar_system):
		return false

	var is_glowing_variant: Variant = sonar_system.get("is_glowing")
	var is_glowing: bool = false
	if is_glowing_variant is bool:
		is_glowing = is_glowing_variant
	elif is_glowing_variant != null:
		is_glowing = bool(is_glowing_variant)
	if not is_glowing:
		return false

	var sonar_position_variant: Variant = sonar_system.get("sonar_position")
	var sonar_direction_variant: Variant = sonar_system.get("sonar_direction")
	var sonar_range_variant: Variant = sonar_system.get("sonar_range")
	var sonar_cone_angle_variant: Variant = sonar_system.get("sonar_cone_angle")
	var wave_rings_variant: Variant = sonar_system.get("wave_rings")

	if not (sonar_position_variant is Vector2 and sonar_direction_variant is Vector2 and (sonar_range_variant is float or sonar_range_variant is int) and (sonar_cone_angle_variant is float or sonar_cone_angle_variant is int)):
		return false

	var sonar_position: Vector2 = sonar_position_variant as Vector2
	var sonar_direction: Vector2 = sonar_direction_variant as Vector2
	var sonar_range: float = float(sonar_range_variant)
	var sonar_cone_angle: float = float(sonar_cone_angle_variant)

	var wave_rings: Array = []
	if wave_rings_variant is Array:
		wave_rings = wave_rings_variant as Array
	else:
		return false

	var distance_to_sonar: float = global_position.distance_to(sonar_position)
	if distance_to_sonar > sonar_range + SONAR_RANGE_PADDING:
		return false

	if sonar_direction != Vector2.ZERO:
		var direction_to_pendulum: Vector2 = (global_position - sonar_position).normalized()
		var angle_to_pendulum: float = abs(rad_to_deg(sonar_direction.angle_to(direction_to_pendulum)))
		if angle_to_pendulum > (sonar_cone_angle * 0.5) + SONAR_CONE_PADDING:
			return false

	for ring_variant in wave_rings:
		if not (ring_variant is Dictionary):
			continue
		var ring: Dictionary = ring_variant as Dictionary
		if not ring.has("active"):
			continue
		var active_value: Variant = ring["active"]
		if not bool(active_value):
			continue
		var ring_radius: float = 0.0
		if ring.has("radius"):
			var radius_value: Variant = ring["radius"]
			if radius_value is float:
				ring_radius = radius_value
			elif radius_value is int:
				ring_radius = float(radius_value)
			elif radius_value != null:
				ring_radius = float(radius_value)
		if abs(distance_to_sonar - ring_radius) <= SONAR_WAVE_TOLERANCE:
			return true

	return false
