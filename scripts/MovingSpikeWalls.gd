extends StaticBody2D

@export var platform_size: Vector2 = Vector2(64, 16)
@export var spike_height: float = 14.0
@export_range(1, 16, 1, "or_greater") var spike_count: int = 6
@export var extend_distance: float = 24.0
@export var toggle_interval: float = 1.5
@export var move_time: float = 0.25
@export var damage_cooldown: float = 0.7
@export var knockback_strength: float = 220.0

const _MIN_INTERVAL: float = 0.05
const _MIN_MOVE_TIME: float = 0.05
const _MIN_COOLDOWN: float = 0.05

@onready var _base_collision: CollisionShape2D = $CollisionShape2D
@onready var _spike_visual: Node2D = $SpikeBody
@onready var _damage_area: Area2D = $SpikeBody/DamageArea
@onready var _damage_shape: CollisionShape2D = $SpikeBody/DamageArea/CollisionShape2D
@onready var _spike_sprite: Sprite2D = $SpikeBody.get_node_or_null("Sprite2D")

var _retracted_sprite_y: float = 0.0
var _extended_sprite_y: float = 0.0
var _extend_progress: float = 0.0
var _tween: Tween
var _state_timer: float = 0.0
var _last_damage_time_by_body: Dictionary = {}
var _knockback_cycle_by_body: Dictionary = {}
var _current_cycle_id: int = 0

func _ready() -> void:
	add_to_group("hazards")
	add_to_group("sonar_platforms")

	if not _spike_visual:
		push_warning("SpikeBody node is missing; MovingSpikeWalls will be disabled.")
		set_process(false)
		set_physics_process(false)
		return

	set_process(true)
	set_physics_process(true)

	_configure_base_collision()
	_configure_damage_area()
	_configure_visual()
	_set_extended(false, true)

func _process(delta: float) -> void:
	var effective_interval: float = max(toggle_interval, _MIN_INTERVAL)
	if effective_interval <= _MIN_INTERVAL:
		return

	_state_timer += delta
	if _state_timer >= effective_interval:
		_state_timer -= effective_interval
		_set_extended(_extend_progress < 0.5, false)

func _physics_process(_delta: float) -> void:
	if _extend_progress < 0.95 or not _damage_area or not is_instance_valid(_damage_area):
		return
	var now_seconds: float = Time.get_ticks_msec() / 1000.0
	for body in _damage_area.get_overlapping_bodies():
		_apply_spike_effect(body, now_seconds)

func _set_extended(should_extend: bool, immediate: bool) -> void:
	var target_progress: float = 1.0 if should_extend else 0.0

	if _tween and _tween.is_valid():
		_tween.kill()

	if should_extend:
		_current_cycle_id += 1
		_knockback_cycle_by_body.clear()

	if immediate or move_time <= _MIN_MOVE_TIME:
		_extend_progress = target_progress
		_apply_visual_progress()
	else:
		var tween_duration: float = max(move_time, _MIN_MOVE_TIME)
		_tween = create_tween()
		_tween.tween_method(_set_extend_progress, _extend_progress, target_progress, tween_duration)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)

	if not should_extend:
		_last_damage_time_by_body.clear()
		_knockback_cycle_by_body.clear()

func _set_extend_progress(value: float) -> void:
	_extend_progress = clamp(value, 0.0, 1.0)
	_apply_visual_progress()

func _apply_visual_progress() -> void:
	var current_y: float = lerp(_retracted_sprite_y, _extended_sprite_y, _extend_progress)
	if _spike_sprite and is_instance_valid(_spike_sprite):
		_spike_sprite.position.y = current_y
	if _damage_area and is_instance_valid(_damage_area):
		_damage_area.position.y = current_y
		var should_monitor: bool = _extend_progress >= 0.95
		if _damage_area.monitoring != should_monitor:
			_damage_area.monitoring = should_monitor

func _configure_base_collision() -> void:
	if not _base_collision or not is_instance_valid(_base_collision):
		return

	var rect_shape: RectangleShape2D
	if _base_collision.shape and _base_collision.shape is RectangleShape2D:
		rect_shape = _base_collision.shape
	else:
		rect_shape = RectangleShape2D.new()
		_base_collision.shape = rect_shape
	rect_shape.size = platform_size

func _configure_damage_area() -> void:
	if not _damage_area or not is_instance_valid(_damage_area):
		return

	_damage_area.monitoring = false
	_damage_area.monitorable = true

	if _damage_area and is_instance_valid(_damage_area):
		_damage_area.position = Vector2.ZERO

	if _damage_shape and is_instance_valid(_damage_shape):
		var area_shape: RectangleShape2D
		if _damage_shape.shape and _damage_shape.shape is RectangleShape2D:
			area_shape = _damage_shape.shape
		else:
			area_shape = RectangleShape2D.new()
			_damage_shape.shape = area_shape
		area_shape.size = Vector2(platform_size.x, max(4.0, spike_height + abs(extend_distance)))
		var half_height: float = area_shape.size.y * 0.5
		_damage_shape.position = Vector2(0.0, -half_height)

	var callable: Callable = Callable(self, "_on_damage_area_body_exited")
	if not _damage_area.body_exited.is_connected(callable):
		_damage_area.body_exited.connect(callable)

func _configure_visual() -> void:
	var top_of_platform: float = -platform_size.y * 0.5
	if _spike_visual and is_instance_valid(_spike_visual):
		_spike_visual.position = Vector2(0.0, top_of_platform)

	var sprite_height: float = spike_height
	if _spike_sprite and is_instance_valid(_spike_sprite):
		_spike_sprite.centered = true
		if _spike_sprite.region_enabled and _spike_sprite.region_rect.size.y > 0.0:
			sprite_height = _spike_sprite.region_rect.size.y
		elif _spike_sprite.texture:
			sprite_height = _spike_sprite.texture.get_height()

	_retracted_sprite_y = -sprite_height * 0.5
	_extended_sprite_y = _retracted_sprite_y - abs(extend_distance)
	_extend_progress = 0.0
	_apply_visual_progress()

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
		var last_cycle: int = -1
		if _knockback_cycle_by_body.has(body_id):
			var stored_cycle: Variant = _knockback_cycle_by_body[body_id]
			if stored_cycle is int:
				last_cycle = stored_cycle
			elif stored_cycle != null:
				last_cycle = int(stored_cycle)
		if last_cycle != _current_cycle_id:
			_knockback_cycle_by_body[body_id] = _current_cycle_id
			var upward_force: float = -abs(knockback_strength)
			if body is CharacterBody2D:
				var current_velocity: Vector2 = body.velocity
				if current_velocity.y > upward_force:
					body.velocity = Vector2(current_velocity.x, upward_force)
			elif body.has_method("apply_central_impulse"):
				body.apply_central_impulse(Vector2(0.0, upward_force))

	if body.has_method("take_damage"):
		body.take_damage()

func _on_damage_area_body_exited(body: Node) -> void:
	if body == null or not is_instance_valid(body):
		return
	var body_id: int = body.get_instance_id()
	_last_damage_time_by_body.erase(body_id)
	if _knockback_cycle_by_body.has(body_id):
		var stored_cycle_variant: Variant = _knockback_cycle_by_body[body_id]
		var stored_cycle: int = -1
		if stored_cycle_variant is int:
			stored_cycle = stored_cycle_variant
		elif stored_cycle_variant != null:
			stored_cycle = int(stored_cycle_variant)
		if stored_cycle != _current_cycle_id:
			_knockback_cycle_by_body.erase(body_id)

func get_sonar_edges() -> Array:
	var edges: Array[Dictionary] = []

	var half_size: Vector2 = platform_size * 0.5
	var top_y: float = -half_size.y
	var bottom_y: float = half_size.y
	var left_x: float = -half_size.x
	var right_x: float = half_size.x

	var corners: Array[Vector2] = [
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

	if _extend_progress <= 0.0:
		return edges

	var extension: float = abs(extend_distance) * _extend_progress
	var spike_base_y: float = top_y
	var spike_tip_y: float = spike_base_y - spike_height - extension
	var spike_spacing: float = platform_size.x / max(1, spike_count)

	for spike_index in range(spike_count):
		var spike_left: float = left_x + spike_spacing * spike_index
		var spike_right: float = left_x + spike_spacing * (spike_index + 1)
		var spike_tip: Vector2 = Vector2((spike_left + spike_right) * 0.5, spike_tip_y)
		var base_left: Vector2 = Vector2(spike_left, spike_base_y)
		var base_right: Vector2 = Vector2(spike_right, spike_base_y)

		edges.append({
			"start": to_global(base_left),
			"end": to_global(spike_tip)
		})
		edges.append({
			"start": to_global(spike_tip),
			"end": to_global(base_right)
		})

	return edges
