extends StaticBody2D
class_name SonarDoor

@export_group("Door Properties")
@export var door_size: Vector2 = Vector2(16, 96)
@export var open_direction: Vector2 = Vector2(0, -1) 
@export var open_distance: float = 100.0
@export var open_duration: float = 1.0
@export var auto_close: bool = false
@export var auto_close_delay: float = 3.0

@export_group("Crush Damage")
@export var crush_damage_percent: float = 0.75
@export var crush_debuff_duration: float = 3.0
@export var crush_speed_reduction: float = 0.5 

@export_group("Visual")
@export var frame_thickness: float = 4.0
@export var show_lock_icon: bool = true

enum DoorState { CLOSED, OPENING, OPEN, CLOSING }

var _state: DoorState = DoorState.CLOSED
var _collision_shape: CollisionShape2D
var _original_position: Vector2
var _target_position: Vector2
var _open_tween: Tween
var _auto_close_timer: float = 0.0
var _pending_close_resume: bool = false

func _ready() -> void:
	add_to_group("sonar_platforms")
	add_to_group("doors")

	var half_height: float = door_size.y * 0.5
	var desired_bottom: float = position.y + half_height
	var snapped_bottom: float = floor(desired_bottom / 16.0) * 16.0
	var snapped_x: float = round(position.x / 16.0) * 16.0

	var tile_gap: float = 20.0
	var bottom_y: float = snapped_bottom - tile_gap
	position = Vector2(snapped_x, bottom_y - half_height)
	_original_position = position

	collision_layer = 1 
	collision_mask = 1 

	_configure_collision()
	set_process(true)

func _configure_collision() -> void:
	_collision_shape = CollisionShape2D.new()
	_collision_shape.name = "CollisionShape2D"
	_collision_shape.disabled = false 
	add_child(_collision_shape)

	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = door_size
	_collision_shape.shape = rect

	_collision_shape.debug_color = Color(1, 0, 0, 0.3) if _state == DoorState.CLOSED else Color(0, 1, 0, 0.3)

func _process(delta: float) -> void:
	if auto_close and _state == DoorState.OPEN:
		_auto_close_timer += delta
		if _auto_close_timer >= auto_close_delay:
			close()

func open() -> void:
	if _state == DoorState.OPEN or _state == DoorState.OPENING:
		return

	_state = DoorState.OPENING
	_auto_close_timer = 0.0
	_pending_close_resume = false

	if _collision_shape:
		_collision_shape.disabled = true

	_target_position = _original_position + (open_direction.normalized() * open_distance)

	if _open_tween and _open_tween.is_valid():
		_open_tween.kill()

	_open_tween = create_tween()
	_open_tween.set_ease(Tween.EASE_IN_OUT)
	_open_tween.set_trans(Tween.TRANS_CUBIC)

	_open_tween.tween_property(self, "position", _target_position, open_duration)

	_open_tween.finished.connect(func():
		_state = DoorState.OPEN
		_auto_close_timer = 0.0
	, CONNECT_ONE_SHOT)

func close() -> void:
	if _state == DoorState.CLOSED or _state == DoorState.CLOSING:
		return

	_state = DoorState.CLOSING
	_pending_close_resume = false

	_check_for_crush()

	_start_close_tween()

func _check_for_crush() -> void:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if not space_state:
		print("No space state!")
		return

	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = door_size
	query.shape = shape
	query.transform = global_transform
	query.collision_mask = 0xFFFFFFFF 
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var results: Array[Dictionary] = space_state.intersect_shape(query, 10)
	print("Door crush check: Found ", results.size(), " bodies at position ", global_position)

	for result in results:
		var body: Node = result.get("collider")
		print("  - Found body: ", body.name if body else "null", " | Is player: ", body.is_in_group("player") if body else false)

		if body and body.is_in_group("player"):
			if body.has_method("take_damage"):
				var damage: int = _calculate_crush_damage(body)
				if damage > 0:
					body.take_damage(damage)

			if body.has_method("apply_speed_debuff"):
				body.apply_speed_debuff(crush_speed_reduction, crush_debuff_duration)
				print("  >>> Applied speed debuff: ", crush_speed_reduction, " for ", crush_debuff_duration, "s")

			_eject_body_from_door(body)
			break

func _calculate_crush_damage(body: Node) -> int:
	var max_health_value = _safe_get_property(body, "MAX_HEALTH")
	if typeof(max_health_value) in [TYPE_INT, TYPE_FLOAT]:
		var damage: int = int(round(float(max_health_value) * crush_damage_percent))
		return max(1, damage)
	return 1

func _safe_get_property(target: Object, property_name: StringName) -> Variant:
	if not target:
		return null
	var property_list: Array = target.get_property_list()
	for property in property_list:
		if property.has("name") and property.name == property_name:
			return target.get(property_name)
	return null

func _eject_body_from_door(body: Node) -> void:
	if not (body is CharacterBody2D):
		return

	var character: CharacterBody2D = body
	var door_center: Vector2 = global_position
	var body_position: Vector2 = character.global_position
	var offset: Vector2 = body_position - door_center

	var side_vector: Vector2 = Vector2(-open_direction.y, open_direction.x)
	if side_vector.length_squared() < 0.001:
		side_vector = Vector2.RIGHT
	else:
		side_vector = side_vector.normalized()

	var side_dot: float = offset.dot(side_vector)
	var push_dir: Vector2 = side_vector
	if abs(side_dot) > 0.1:
		push_dir = side_vector * (1 if side_dot >= 0 else -1)

	var horizontal_extent: float = door_size.x * 0.5 + 16.0
	var vertical_extent: float = door_size.y * 0.5 + 16.0
	var new_position: Vector2 = character.global_position

	if abs(push_dir.x) > 0.001:
		new_position.x = door_center.x + push_dir.x * horizontal_extent
	if abs(push_dir.y) > 0.001:
		new_position.y = door_center.y + push_dir.y * vertical_extent

	character.global_position = new_position

	var eject_speed: float = 220.0
	if abs(push_dir.x) > 0.001:
		character.velocity.x = push_dir.x * eject_speed
	if abs(push_dir.y) > 0.001:
		character.velocity.y = push_dir.y * max(eject_speed * 0.5, abs(character.velocity.y))

	_queue_close_resume()

func _start_close_tween(custom_duration: float = -1.0) -> void:
	if _open_tween and _open_tween.is_valid():
		_open_tween.kill()
	_open_tween = null
	_pending_close_resume = false

	var duration: float = custom_duration if custom_duration > 0.0 else open_duration
	duration = max(duration, 0.05)

	_open_tween = create_tween()
	_open_tween.set_ease(Tween.EASE_IN_OUT)
	_open_tween.set_trans(Tween.TRANS_CUBIC)
	_open_tween.tween_property(self, "position", _original_position, duration)
	_open_tween.finished.connect(Callable(self, "_on_close_tween_finished"), CONNECT_ONE_SHOT)

func _queue_close_resume() -> void:
	if _state != DoorState.CLOSING:
		return
	if _pending_close_resume:
		return
	_pending_close_resume = true
	call_deferred("_resume_closing_after_crush")

func _resume_closing_after_crush() -> void:
	_pending_close_resume = false
	if _state != DoorState.CLOSING:
		return

	var remaining_vector: Vector2 = _original_position - global_position
	if remaining_vector.length_squared() <= 0.01:
		global_position = _original_position
		_on_close_tween_finished()
		return
	var total_distance: float = max(open_distance, 0.01)
	var distance_left: float = remaining_vector.length()
	var fraction_left: float = clamp(distance_left / total_distance, 0.0, 1.0)
	var duration: float = max(open_duration * fraction_left, 0.05)
	_start_close_tween(duration)

func _on_close_tween_finished() -> void:
	_open_tween = null
	_pending_close_resume = false
	_state = DoorState.CLOSED
	if _collision_shape:
		_collision_shape.disabled = false
	_check_for_crush()

func toggle() -> void:
	if _state == DoorState.CLOSED or _state == DoorState.CLOSING:
		open()
	else:
		close()

func is_open() -> bool:
	return _state == DoorState.OPEN

func is_closed() -> bool:
	return _state == DoorState.CLOSED

func get_sonar_edges() -> Array:
	var edges: Array = []
	var half_size: Vector2 = door_size * 0.5

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

	var frame_extend: float = frame_thickness
	var frame_corners: Array[Vector2] = [
		Vector2(-half_size.x - frame_extend, -half_size.y - frame_extend),
		Vector2(half_size.x + frame_extend, -half_size.y - frame_extend),
		Vector2(half_size.x + frame_extend, half_size.y + frame_extend),
		Vector2(-half_size.x - frame_extend, half_size.y + frame_extend)
	]

	for i in range(frame_corners.size()):
		var start: Vector2 = to_global(frame_corners[i])
		var end: Vector2 = to_global(frame_corners[(i + 1) % frame_corners.size()])
		edges.append({"start": start, "end": end})

	if show_lock_icon and (_state == DoorState.CLOSED or _state == DoorState.CLOSING):
		var lock_size: float = min(door_size.x, door_size.y) * 0.3
		var lock_offset: Vector2 = Vector2(0, lock_size * 0.2)

		var shackle_width: float = lock_size * 0.5
		var shackle_height: float = lock_size * 0.4
		edges.append({
			"start": to_global(lock_offset + Vector2(-shackle_width, 0)),
			"end": to_global(lock_offset + Vector2(-shackle_width, -shackle_height))
		})
		edges.append({
			"start": to_global(lock_offset + Vector2(-shackle_width, -shackle_height)),
			"end": to_global(lock_offset + Vector2(shackle_width, -shackle_height))
		})
		edges.append({
			"start": to_global(lock_offset + Vector2(shackle_width, -shackle_height)),
			"end": to_global(lock_offset + Vector2(shackle_width, 0))
		})

		var body_half: Vector2 = Vector2(lock_size * 0.6, lock_size * 0.4) * 0.5
		var body_corners: Array[Vector2] = [
			lock_offset + Vector2(-body_half.x, 0),
			lock_offset + Vector2(body_half.x, 0),
			lock_offset + Vector2(body_half.x, body_half.y * 2),
			lock_offset + Vector2(-body_half.x, body_half.y * 2)
		]

		for i in range(body_corners.size()):
			var start: Vector2 = to_global(body_corners[i])
			var end: Vector2 = to_global(body_corners[(i + 1) % body_corners.size()])
			edges.append({"start": start, "end": end})

		var keyhole_pos: Vector2 = lock_offset + Vector2(0, body_half.y * 0.8)
		var keyhole_size: float = lock_size * 0.15
		edges.append({
			"start": to_global(keyhole_pos + Vector2(0, -keyhole_size)),
			"end": to_global(keyhole_pos + Vector2(0, keyhole_size))
		})

	if _state == DoorState.OPENING or _state == DoorState.OPEN:
		var arrow_size: float = 8.0
		var arrow_pos: Vector2 = Vector2.ZERO
		var dir: Vector2 = open_direction.normalized()

		for i in range(2):
			var offset: Vector2 = dir * (i * 12.0 - 6.0)
			var arrow_tip: Vector2 = offset + (dir * arrow_size)
			var arrow_left: Vector2 = offset + (dir.rotated(2.5) * -arrow_size * 0.6)
			var arrow_right: Vector2 = offset + (dir.rotated(-2.5) * -arrow_size * 0.6)

			edges.append({
				"start": to_global(arrow_pos + offset),
				"end": to_global(arrow_pos + arrow_tip)
			})
			edges.append({
				"start": to_global(arrow_pos + arrow_tip),
				"end": to_global(arrow_pos + arrow_left)
			})
			edges.append({
				"start": to_global(arrow_pos + arrow_tip),
				"end": to_global(arrow_pos + arrow_right)
			})

	return edges
