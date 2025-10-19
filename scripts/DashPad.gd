extends AnimatableBody2D

@export var platform_size: Vector2 = Vector2(48, 16)
@export var dash_strength: float = 600.0
@export var dash_direction: Vector2 = Vector2.RIGHT
@export var compression_amount: float = 4.0
@export var sonar_echo_range: float = 50.0
@export var activation_cooldown: float = 0.35
@export var dash_duration: float = 0.25
@export var hide_base_sprite: bool = false

const MIN_COOLDOWN: float = 0.05
const MIN_DIRECTION_LENGTH: float = 0.001

const SONAR_RANGE_PADDING: float = 12.0
const SONAR_CONE_PADDING: float = 6.0
const SONAR_WAVE_TOLERANCE: float = 24.0
const SONAR_VISIBILITY_LERP_SPEED: float = 8.0
const SONAR_VISIBILITY_THRESHOLD: float = 0.05

var is_compressed: bool = false
var original_position: Vector2
var dash_particles: CPUParticles2D
var detection_area: Area2D
var _last_activation_time_by_body: Dictionary = {}
var sonar_system: Node
var sonar_visibility: float = 0.0
var _requires_sonar_reveal: bool = false

func _ready() -> void:
	add_to_group("sonar_platforms")
	position = position.snapped(Vector2(16, 16))
	original_position = position
	_requires_sonar_reveal = hide_base_sprite

	_configure_base_sprite()
	_configure_collision_shape()
	_create_detection_area()
	_create_dash_particles()
	sonar_system = _find_sonar_system()
	_apply_sonar_visibility()

func _configure_base_sprite() -> void:
	var sprite: Sprite2D = $Sprite2D
	if sprite:
		if hide_base_sprite and not Engine.is_editor_hint():
			sprite.visible = false
			var color: Color = sprite.modulate
			color.a = 0.0
			sprite.modulate = color
		else:
			sprite.visible = true

func _configure_collision_shape() -> void:
	var collision: CollisionShape2D = $CollisionShape2D
	if not collision:
		return
	var rect_shape: RectangleShape2D
	if collision.shape and collision.shape is RectangleShape2D:
		rect_shape = collision.shape as RectangleShape2D
	else:
		rect_shape = RectangleShape2D.new()
		collision.shape = rect_shape
	rect_shape.size = platform_size

func _create_detection_area() -> void:
	detection_area = Area2D.new()
	detection_area.name = "DetectionArea"
	add_child(detection_area)

	detection_area.monitoring = true
	detection_area.monitorable = true
	detection_area.collision_layer = 0
	detection_area.collision_mask = 1

	var area_shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = platform_size + Vector2(4, 4)
	area_shape.shape = rectangle
	detection_area.add_child(area_shape)

	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)

func _create_dash_particles() -> void:
	dash_particles = CPUParticles2D.new()
	dash_particles.name = "DashParticles"
	add_child(dash_particles)

	dash_particles.emitting = false
	dash_particles.one_shot = true
	dash_particles.amount = 30
	dash_particles.lifetime = 0.8
	dash_particles.explosiveness = 1.0
	dash_particles.direction = -_get_dash_direction()
	dash_particles.spread = 60.0
	dash_particles.initial_velocity_min = 100.0
	dash_particles.initial_velocity_max = 250.0
	dash_particles.gravity = Vector2(0, 400)
	dash_particles.scale_amount_min = 2.0
	dash_particles.scale_amount_max = 5.0

	var strength_factor: float = clamp(dash_strength / 1000.0, 0.0, 1.0)
	var color: Color = Color(0.5 + strength_factor * 0.5, 0.7 + strength_factor * 0.3, 1.0 - strength_factor * 0.5, 0.9)
	dash_particles.color = color

func _on_body_entered(body: Node) -> void:
	if not body is CharacterBody2D:
		return

	var now_seconds: float = Time.get_ticks_msec() / 1000.0
	var cooldown: float = max(MIN_COOLDOWN, activation_cooldown)
	var body_id: int = body.get_instance_id()
	var last_time: float = -cooldown
	if _last_activation_time_by_body.has(body_id):
		var stored: Variant = _last_activation_time_by_body[body_id]
		if stored is float:
			last_time = stored
		elif stored != null:
			last_time = float(stored)
	if now_seconds - last_time < cooldown:
		return

	_last_activation_time_by_body[body_id] = now_seconds
	_dash_character(body as CharacterBody2D)

func _on_body_exited(body: Node) -> void:
	if body == null or not is_instance_valid(body):
		return
	_last_activation_time_by_body.erase(body.get_instance_id())

func _dash_character(character: CharacterBody2D) -> void:
	var direction: Vector2 = _get_dash_direction()
	var player: Player = character as Player
	if player:
		var facing_direction: Vector2 = player.facing_direction
		if facing_direction.length_squared() > 0.0:
			direction = facing_direction.normalized()
	character.velocity = direction * dash_strength

	if player:
		_apply_player_dash_state(player, direction)

	_play_dash_animation()
	_trigger_particles(direction)
	_emit_sonar_ping(direction)

func _apply_player_dash_state(player: Player, direction: Vector2) -> void:
	if not is_instance_valid(player):
		return

	if player.has_method("force_dash"):
		player.force_dash(direction, dash_strength, dash_duration, true)
	else:
		player.velocity = direction * dash_strength

func _play_dash_animation() -> void:
	if is_compressed:
		return

	is_compressed = true
	var compress_tween: Tween = create_tween()
	compress_tween.set_parallel(true)
	compress_tween.tween_property(self, "position", position + Vector2(0, compression_amount), 0.1)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if $Sprite2D:
		compress_tween.tween_property($Sprite2D, "scale", Vector2(1.2, 0.8), 0.1)

	compress_tween.chain().set_parallel(true)
	compress_tween.tween_property(self, "position", original_position, 0.15)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	if $Sprite2D:
		compress_tween.tween_property($Sprite2D, "scale", Vector2.ONE, 0.15)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	compress_tween.chain().tween_callback(func():
		is_compressed = false
	)

func _trigger_particles(direction: Vector2) -> void:
	if not dash_particles:
		return
	dash_particles.direction = -direction
	dash_particles.emitting = true
	dash_particles.restart()

func _emit_sonar_ping(direction: Vector2) -> void:
	var sonar_system: Node = get_tree().root.find_child("SonarSystem", true, false)
	if sonar_system and sonar_system.has_method("_on_sonar_pulse"):
		sonar_system._on_sonar_pulse(global_position, sonar_echo_range, direction)

func _get_dash_direction() -> Vector2:
	var direction: Vector2 = dash_direction
	if direction.length_squared() < MIN_DIRECTION_LENGTH:
		direction = Vector2.RIGHT
	return direction.normalized()

func _process(_delta: float) -> void:
	if dash_particles:
		dash_particles.direction = -_get_dash_direction()
	if Engine.is_editor_hint():
		queue_redraw()
		return

	_update_sonar_visibility(_delta)
	_apply_sonar_visibility()

func _draw() -> void:
	if Engine.is_editor_hint():
		return

func get_sonar_edges() -> Array[Dictionary]:
	var half_size: Vector2 = platform_size * 0.5
	var corners: Array[Vector2] = [
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y)
	]

	var edges: Array[Dictionary] = []
	for i in range(corners.size()):
		var start: Vector2 = to_global(corners[i])
		var end: Vector2 = to_global(corners[(i + 1) % corners.size()])
		edges.append({
			"start": start,
			"end": end,
			"platform": self
		})
	return edges

func get_sonar_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var half_size: Vector2 = platform_size * 0.5
	var top_left: Vector2 = global_position - half_size
	rects.append(Rect2(top_left, platform_size))
	return rects

func _find_sonar_system() -> Node:
	var root: Window = get_tree().root
	if root == null:
		return null
	return root.find_child("SonarSystem", true, false)

func _update_sonar_visibility(delta: float) -> void:
	var target_visibility: float = 1.0 if _is_sonar_wave_revealing() else 0.0
	sonar_visibility = lerp(sonar_visibility, target_visibility, delta * SONAR_VISIBILITY_LERP_SPEED)

func _apply_sonar_visibility() -> void:
	var clamped: float = clamp(sonar_visibility, 0.0, 1.0)
	var sprite: Sprite2D = $Sprite2D
	if sprite:
		if _requires_sonar_reveal and not Engine.is_editor_hint():
			var sprite_color: Color = sprite.modulate
			sprite_color.a = clamped
			sprite.modulate = sprite_color
			sprite.visible = clamped > SONAR_VISIBILITY_THRESHOLD
		else:
			sprite.visible = true

func _is_sonar_wave_revealing() -> bool:
	if Engine.is_editor_hint():
		return true
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

	if not (sonar_position_variant is Vector2 and sonar_direction_variant is Vector2):
		return false
	if not (sonar_range_variant is float or sonar_range_variant is int):
		return false
	if not (sonar_cone_angle_variant is float or sonar_cone_angle_variant is int):
		return false

	var sonar_position: Vector2 = sonar_position_variant as Vector2
	var sonar_direction: Vector2 = sonar_direction_variant as Vector2
	var sonar_range: float = float(sonar_range_variant)
	var sonar_cone_angle: float = float(sonar_cone_angle_variant)

	if sonar_direction == Vector2.ZERO:
		sonar_direction = Vector2.RIGHT

	var wave_rings: Array = []
	if wave_rings_variant is Array:
		wave_rings = wave_rings_variant as Array

	var distance_to_sonar: float = global_position.distance_to(sonar_position)
	if distance_to_sonar > sonar_range + SONAR_RANGE_PADDING:
		return false

	if sonar_direction != Vector2.ZERO:
		var direction_to_pad: Vector2 = (global_position - sonar_position).normalized()
		var angle_to_pad: float = abs(rad_to_deg(sonar_direction.angle_to(direction_to_pad)))
		if angle_to_pad > (sonar_cone_angle * 0.5) + SONAR_CONE_PADDING:
			return false

	for ring_variant in wave_rings:
		if not (ring_variant is Dictionary):
			continue
		var ring: Dictionary = ring_variant as Dictionary
		if not ring.has("active") or not bool(ring["active"]):
			continue
		var ring_radius: float = 0.0
		if ring.has("radius"):
			var radius_variant: Variant = ring["radius"]
			if radius_variant is float:
				ring_radius = radius_variant
			elif radius_variant is int:
				ring_radius = float(radius_variant)
			elif radius_variant != null:
				ring_radius = float(radius_variant)
		if abs(distance_to_sonar - ring_radius) <= SONAR_WAVE_TOLERANCE:
			return true

	return false
