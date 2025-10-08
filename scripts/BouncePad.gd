extends AnimatableBody2D

@export var platform_size: Vector2 = Vector2(48, 16)
@export var bounce_strength: float = 600.0
@export var bounce_direction: Vector2 = Vector2(0, -1)
@export var compression_amount: float = 4.0

var is_compressed: bool = false
var original_position: Vector2
var bounce_particles: CPUParticles2D
var area: Area2D
var spring_visual: Node2D
var spring_lines: Array = []
var spring_compressed: float = 0.0
var sonar_system: Node
var sonar_visibility: float = 0.0
var sonar_reveal_timer: float = 0.0

const SPRING_REVEAL_DURATION: float = 1.1
const SPRING_VISIBILITY_LERP_SPEED: float = 8.0
const SONAR_RANGE_PADDING: float = 12.0
const SONAR_CONE_PADDING: float = 6.0
const SONAR_WAVE_TOLERANCE: float = 28.0

const SPRING_HEIGHT: float = 20.0
const SPRING_WIDTH: float = 12.0
const SPRING_SEGMENTS: int = 10

func _ready():
	add_to_group("sonar_platforms")
	position = position.snapped(Vector2(16, 16))
	original_position = position

	if $Sprite2D:
		$Sprite2D.visible = false

	if $CollisionShape2D and $CollisionShape2D.shape is RectangleShape2D:
		$CollisionShape2D.shape.size = platform_size

	_create_spring_visual()

	_create_detection_area()

	_create_bounce_particles()

	sonar_system = _find_sonar_system()

func _create_spring_visual():
	spring_visual = Node2D.new()
	spring_visual.name = "SpringVisual"
	add_child(spring_visual)
	spring_visual.z_index = -1
	spring_visual.position = Vector2(0, -8)

	spring_visual.add_to_group("sonar_platforms")


	var spring_height = SPRING_HEIGHT
	var spring_width = SPRING_WIDTH
	var num_coils = 5

	for i in range(num_coils):
		spring_lines.append({
			"y_offset": -spring_height * (float(i) / num_coils),
			"x_alternator": i % 2
		})

	spring_visual.draw.connect(_draw_spring)

func _create_detection_area():
	area = Area2D.new()
	add_child(area)

	var area_shape = CollisionShape2D.new()
	area_shape.shape = RectangleShape2D.new()
	area_shape.shape.size = platform_size + Vector2(4, 4) 
	area.add_child(area_shape)

	area.body_entered.connect(_on_body_entered)

func _create_bounce_particles():
	bounce_particles = CPUParticles2D.new()
	add_child(bounce_particles)

	bounce_particles.emitting = false
	bounce_particles.one_shot = true
	bounce_particles.amount = 30
	bounce_particles.lifetime = 0.8
	bounce_particles.explosiveness = 1.0

	var particle_direction = -bounce_direction.normalized()
	bounce_particles.direction = particle_direction
	bounce_particles.spread = 60.0
	bounce_particles.initial_velocity_min = 100.0
	bounce_particles.initial_velocity_max = 250.0

	bounce_particles.gravity = Vector2(0, 400)

	bounce_particles.scale_amount_min = 2.0
	bounce_particles.scale_amount_max = 5.0

	var strength_factor = clamp(bounce_strength / 1000.0, 0.0, 1.0)
	var color = Color(0.5 + strength_factor * 0.5, 0.7 + strength_factor * 0.3, 1.0 - strength_factor * 0.5, 0.9)
	bounce_particles.color = color

func _on_body_entered(body):
	if body is CharacterBody2D and not is_compressed:
		_bounce_player(body)

func _bounce_player(player: CharacterBody2D):
	var normalized_direction = bounce_direction.normalized()
	player.velocity = normalized_direction * bounce_strength

	_play_bounce_animation()

	bounce_particles.emitting = true
	bounce_particles.restart()

func _play_bounce_animation():
	if is_compressed:
		return

	is_compressed = true

	var compress_tween = create_tween()
	compress_tween.set_parallel(true)
	compress_tween.tween_property(self, "position", position + Vector2(0, compression_amount), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	compress_tween.tween_property(self, "spring_compressed", 1.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if $Sprite2D:
		compress_tween.tween_property($Sprite2D, "scale", Vector2(1.2, 0.8), 0.1)

	compress_tween.chain().set_parallel(true)
	compress_tween.tween_property(self, "position", original_position, 0.15).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	compress_tween.tween_property(self, "spring_compressed", 0.0, 0.15).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	if $Sprite2D:
		compress_tween.tween_property($Sprite2D, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	compress_tween.chain().tween_callback(func(): is_compressed = false)

func _draw_spring():
	if not spring_visual:
		return

	var spring_height = SPRING_HEIGHT * (1.0 - spring_compressed * 0.6)
	var spring_width = SPRING_WIDTH
	var num_segments = SPRING_SEGMENTS

	var spring_color = Color(0.6, 0.6, 0.7, 0.8)

	for i in range(num_segments):
		var t = float(i) / num_segments
		var next_t = float(i + 1) / num_segments

		var y1 = -spring_height * t
		var y2 = -spring_height * next_t

		var x1 = spring_width * (0.5 if i % 2 == 0 else -0.5)
		var x2 = spring_width * (0.5 if (i + 1) % 2 == 0 else -0.5)

		var start_pos = Vector2(x1, y1)
		var end_pos = Vector2(x2, y2)

		spring_visual.draw_line(start_pos, end_pos, spring_color, 2.0)

	spring_visual.draw_line(Vector2(-spring_width * 0.5, 0), Vector2(spring_width * 0.5, 0), spring_color, 2.5)
	spring_visual.draw_line(Vector2(-spring_width * 0.5, -spring_height), Vector2(spring_width * 0.5, -spring_height), spring_color, 2.5)

func _process(_delta):
	if spring_visual:
		spring_visual.queue_redraw()

	if Engine.is_editor_hint():
		queue_redraw()

func get_sonar_edges() -> Array:
	if not spring_visual:
		return []

	var edges: Array = []
	var spring_height = SPRING_HEIGHT * (1.0 - spring_compressed * 0.6)
	var half_width = SPRING_WIDTH * 0.5
	var num_segments = SPRING_SEGMENTS

	for i in range(num_segments):
		var t = float(i) / num_segments
		var next_t = float(i + 1) / num_segments

		var y1 = -spring_height * t
		var y2 = -spring_height * next_t

		var x1 = half_width if i % 2 == 0 else -half_width
		var x2 = half_width if (i + 1) % 2 == 0 else -half_width

		var start_local = Vector2(x1, y1)
		var end_local = Vector2(x2, y2)

		var start_global = spring_visual.to_global(start_local)
		var end_global = spring_visual.to_global(end_local)

		edges.append({"start": start_global, "end": end_global})

	var bottom_left = spring_visual.to_global(Vector2(-half_width, 0))
	var bottom_right = spring_visual.to_global(Vector2(half_width, 0))
	var top_left = spring_visual.to_global(Vector2(-half_width, -spring_height))
	var top_right = spring_visual.to_global(Vector2(half_width, -spring_height))

	edges.append({"start": bottom_left, "end": bottom_right})
	edges.append({"start": top_left, "end": top_right})

	return edges

func _draw():
	if Engine.is_editor_hint():
		var arrow_start = Vector2.ZERO
		var arrow_end = bounce_direction.normalized() * 30
		draw_line(arrow_start, arrow_end, Color.YELLOW, 2.0)

		var arrow_left = arrow_end + (bounce_direction.normalized().rotated(2.5) * -8)
		var arrow_right = arrow_end + (bounce_direction.normalized().rotated(-2.5) * -8)
		draw_line(arrow_end, arrow_left, Color.YELLOW, 2.0)
		draw_line(arrow_end, arrow_right, Color.YELLOW, 2.0)

func _find_sonar_system() -> Node:
	var root = get_tree().root
	if not root:
		return null
	return root.find_child("SonarSystem", true, false)

func _is_sonar_wave_revealing() -> bool:
	if not sonar_system or not is_instance_valid(sonar_system):
		return false
	var is_glowing = sonar_system.get("is_glowing")
	if not is_glowing:
		return false

	var sonar_position: Vector2 = sonar_system.get("sonar_position")
	var sonar_direction: Vector2 = sonar_system.get("sonar_direction")
	var sonar_range: float = sonar_system.get("sonar_range")
	var sonar_cone_angle: float = sonar_system.get("sonar_cone_angle")
	var wave_rings: Array = sonar_system.get("wave_rings")

	var distance_to_sonar = global_position.distance_to(sonar_position)
	if distance_to_sonar > sonar_range + SONAR_RANGE_PADDING:
		return false

	if sonar_direction != Vector2.ZERO:
		var direction_to_pad = (global_position - sonar_position).normalized()
		var angle_to_pad = abs(rad_to_deg(sonar_direction.angle_to(direction_to_pad)))
		if angle_to_pad > (sonar_cone_angle * 0.5) + SONAR_CONE_PADDING:
			return false

	for ring in wave_rings:
		if ring.get("active", false):
			var ring_radius = ring.get("radius", 0.0)
			if abs(distance_to_sonar - ring_radius) <= SONAR_WAVE_TOLERANCE:
				return true

	return false

func _update_spring_visual_modulate():
	if not spring_visual:
		return

	sonar_visibility = clamp(sonar_visibility, 0.0, 1.0)
	var color = spring_visual.modulate
	color.a = 1.0 if Engine.is_editor_hint() else sonar_visibility
	spring_visual.modulate = color
	spring_visual.visible = Engine.is_editor_hint() or sonar_visibility > 0.01
