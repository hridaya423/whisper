extends StaticBody2D

@export var platform_size: Vector2 = Vector2(64, 16)
@export var spike_height: float = 14.0
@export var spike_count: int = 6
@export var damage_cooldown: float = 0.7
@export var knockback_strength: float = 140.0

var _spike_area: Area2D
var _last_damage_time_by_body: Dictionary[int, float] = {}

const _MIN_COOLDOWN: float = 0.05

@onready var _platform_collision: CollisionShape2D = $CollisionShape2D
@onready var _spike_collision: CollisionShape2D = $SpikeArea/CollisionShape2D

func _ready() -> void:
	add_to_group("hazards")
	add_to_group("sonar_platforms")
	visible = Engine.is_editor_hint()
	_configure_platform_collision()
	_configure_spike_area()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var now_seconds: float = Time.get_ticks_msec() / 1000.0
	if _spike_area and is_instance_valid(_spike_area):
		for body in _spike_area.get_overlapping_bodies():
			_apply_spike_effect(body, now_seconds)

func _configure_platform_collision() -> void:
	if not _platform_collision or not is_instance_valid(_platform_collision):
		return
	var rect_shape: RectangleShape2D
	if _platform_collision.shape and _platform_collision.shape is RectangleShape2D:
		rect_shape = _platform_collision.shape
	else:
		rect_shape = RectangleShape2D.new()
		_platform_collision.shape = rect_shape
	rect_shape.size = platform_size

func _configure_spike_area() -> void:
	_spike_area = $SpikeArea
	if not _spike_area or not is_instance_valid(_spike_area):
		return
	_spike_area.monitoring = true
	_spike_area.monitorable = true
	if _spike_collision and is_instance_valid(_spike_collision):
		var area_shape: RectangleShape2D
		if _spike_collision.shape and _spike_collision.shape is RectangleShape2D:
			area_shape = _spike_collision.shape
		else:
			area_shape = RectangleShape2D.new()
			_spike_collision.shape = area_shape
		area_shape.size = Vector2(platform_size.x, max(4.0, spike_height * 0.6))
		_spike_collision.position = Vector2(0, -platform_size.y * 0.5 - area_shape.size.y * 0.5)
	_spike_area.body_exited.connect(_on_spike_body_exited)

func _apply_spike_effect(body: Node, now_seconds: float) -> void:
	if body == null or not is_instance_valid(body):
		return
	var body_id: int = body.get_instance_id()
	var last_time: float = -max(_MIN_COOLDOWN, damage_cooldown)
	if _last_damage_time_by_body.has(body_id):
		var stored: Variant = _last_damage_time_by_body[body_id]
		if stored is float:
			last_time = stored
		elif stored != null:
			last_time = float(stored)
	if now_seconds - last_time < max(_MIN_COOLDOWN, damage_cooldown):
		return
	_last_damage_time_by_body[body_id] = now_seconds

	if knockback_strength > 0.0:
		if body is CharacterBody2D:
			var current_velocity: Vector2 = body.velocity
			if current_velocity.y < knockback_strength:
				body.velocity = Vector2(current_velocity.x, knockback_strength)
			else:
				body.velocity = current_velocity
		elif body.has_method("apply_central_impulse"):
			body.apply_central_impulse(Vector2(0, knockback_strength))

	if body.has_method("take_damage"):
		body.take_damage()

func _on_spike_body_exited(body: Node) -> void:
	if body == null or not is_instance_valid(body):
		return
	_last_damage_time_by_body.erase(body.get_instance_id())

func get_sonar_edges() -> Array:
	var edges: Array = []
	var half_size: Vector2 = platform_size * 0.5
	var top_y: float = -half_size.y
	var bottom_y: float = half_size.y
	var left_x: float = -half_size.x
	var right_x: float = half_size.x

	var corners: Array = [
		Vector2(left_x, top_y),
		Vector2(right_x, top_y),
		Vector2(right_x, bottom_y),
		Vector2(left_x, bottom_y)
	]

	for i in range(corners.size()):
		var start_local: Vector2 = corners[i]
		var end_local: Vector2 = corners[(i + 1) % corners.size()]
		edges.append({
			"start": to_global(start_local),
			"end": to_global(end_local)
		})

	var spike_spacing: float = platform_size.x / max(1, spike_count)
	for i in range(spike_count):
		var spike_left: float = left_x + spike_spacing * i
		var spike_right: float = left_x + spike_spacing * (i + 1)
		var spike_tip: Vector2 = Vector2((spike_left + spike_right) * 0.5, top_y - spike_height)
		var base_left: Vector2 = Vector2(spike_left, top_y)
		var base_right: Vector2 = Vector2(spike_right, top_y)
		edges.append({
			"start": to_global(base_left),
			"end": to_global(spike_tip)
		})
		edges.append({
			"start": to_global(spike_tip),
			"end": to_global(base_right)
		})

	return edges

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var half_size: Vector2 = platform_size * 0.5
	var top_left: Vector2 = Vector2(-half_size.x, -half_size.y)
	var top_right: Vector2 = Vector2(half_size.x, -half_size.y)
	var bottom_left: Vector2 = Vector2(-half_size.x, half_size.y)
	var bottom_right: Vector2 = Vector2(half_size.x, half_size.y)

	var platform_color: Color = Color(0.25, 0.3, 0.35, 0.8)
	draw_rect(Rect2(top_left, platform_size), platform_color)

	var spike_spacing: float = platform_size.x / max(1, spike_count)
	var spike_color: Color = Color(0.8, 0.75, 0.2, 0.85)
	for i in range(spike_count):
		var spike_left: float = top_left.x + spike_spacing * i
		var spike_right: float = top_left.x + spike_spacing * (i + 1)
		var spike_tip: Vector2 = Vector2((spike_left + spike_right) * 0.5, top_left.y - spike_height)
		var base_left: Vector2 = Vector2(spike_left, top_left.y)
		var base_right: Vector2 = Vector2(spike_right, top_left.y)
		draw_polygon([base_left, base_right, spike_tip], [spike_color, spike_color, spike_color])

	draw_line(top_left, top_right, Color(0.9, 0.9, 1.0, 0.8), 2.0)
	draw_line(top_right, bottom_right, Color(0.4, 0.4, 0.5, 0.6), 2.0)
	draw_line(bottom_right, bottom_left, Color(0.4, 0.4, 0.5, 0.6), 2.0)
	draw_line(bottom_left, top_left, Color(0.4, 0.4, 0.5, 0.6), 2.0)
