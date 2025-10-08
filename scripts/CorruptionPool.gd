@tool
extends Node2D

@export var radius: float = 48.0
@export var vertical_scale: float = 0.35
@export var outline_points: int = 28
@export var distortion_amplitude: float = 16.0
@export var distortion_seed: int = 0
@export var damage_interval: float = 1.5
@export var damage_per_tick: int = 1
@export var slow_multiplier: float = 0.6
@export var sonar_outline_subdivisions: int = 2
@export var overlay_color: Color = Color(0.35, 0.0, 0.45, 0.38)
@export var overlay_fade_time: float = 0.3
@export var overlay_vignette_radius: float = 0.75
@export var overlay_vignette_softness: float = 0.45

var _area: Area2D
var _collision: CollisionShape2D
var _tracked_bodies: Dictionary[int, Dictionary] = {}
var _outline_points_local: PackedVector2Array = []
var _editor_signature: String = ""

const _MIN_INTERVAL: float = 0.2
const _MIN_POINTS: int = 10

static var _overlay_layer: CanvasLayer
static var _overlay_rect: ColorRect
static var _overlay_user_count: int = 0
static var _overlay_tween: Tween
static var _overlay_shader: Shader
static var _overlay_material: ShaderMaterial

func _ready() -> void:
	add_to_group("hazards")
	add_to_group("sonar_platforms")
	visible = Engine.is_editor_hint()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	_clamp_parameters()
	_area = $Area2D
	_collision = $Area2D/CollisionShape2D
	_refresh_outline()
	if _area:
		_area.body_entered.connect(_on_body_entered)
		_area.body_exited.connect(_on_body_exited)
	queue_redraw()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_ensure_editor_outline()
		return
	var now_seconds: float = Time.get_ticks_msec() / 1000.0
	var bodies_to_remove: Array = []
	for body_id in _tracked_bodies.keys():
		var entry := _tracked_bodies[body_id]
		if not entry.has("node"):
			bodies_to_remove.append(body_id)
			continue
		var body: Node = entry["node"]
		if body == null or not is_instance_valid(body):
			bodies_to_remove.append(body_id)
			continue
		var last_time: float = entry.get("last_damage", now_seconds)
		if now_seconds - last_time >= max(_MIN_INTERVAL, damage_interval):
			_apply_damage(body)
			entry["last_damage"] = now_seconds
	for remove_id in bodies_to_remove:
		_cleanup_body(remove_id)

func _ensure_editor_outline() -> void:
	_clamp_parameters()
	var signature := "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		radius, vertical_scale, outline_points, distortion_amplitude,
		distortion_seed, slow_multiplier, sonar_outline_subdivisions,
		overlay_fade_time, overlay_vignette_radius, overlay_vignette_softness
	]
	if signature == _editor_signature:
		return
	_editor_signature = signature
	_refresh_outline()

func _clamp_parameters() -> void:
	radius = max(radius, 8.0)
	vertical_scale = clamp(vertical_scale, 0.1, 1.0)
	outline_points = max(_MIN_POINTS, outline_points)
	distortion_amplitude = max(distortion_amplitude, 0.0)
	damage_interval = max(_MIN_INTERVAL, damage_interval)
	damage_per_tick = max(damage_per_tick, 1)
	slow_multiplier = clamp(slow_multiplier, 0.05, 1.0)
	sonar_outline_subdivisions = clamp(sonar_outline_subdivisions, 1, 6)
	overlay_fade_time = max(overlay_fade_time, 0.01)
	overlay_vignette_radius = clamp(overlay_vignette_radius, 0.2, 1.3)
	overlay_vignette_softness = clamp(overlay_vignette_softness, 0.05, 1.0)

func _refresh_outline() -> void:
	_generate_outline_points()
	if _collision and is_instance_valid(_collision):
		_configure_collision()
	queue_redraw()

func _configure_collision() -> void:
	if not _collision or not is_instance_valid(_collision):
		return
	if _outline_points_local.is_empty():
		_generate_outline_points()
	var polygon_shape: ConvexPolygonShape2D
	if _collision.shape and _collision.shape is ConvexPolygonShape2D:
		polygon_shape = _collision.shape
	else:
		polygon_shape = ConvexPolygonShape2D.new()
		_collision.shape = polygon_shape
	polygon_shape.points = _outline_points_local

func _on_body_entered(body: Node) -> void:
	if body == null or not is_instance_valid(body):
		return
	var body_id: int = body.get_instance_id()
	var entry: Dictionary = {
		"node": body,
		"last_damage": Time.get_ticks_msec() / 1000.0
	}
	_tracked_bodies[body_id] = entry
	_apply_slow_effect(body, true)
	if body.is_in_group("player"):
		_register_overlay_user()


func _on_body_exited(body: Node) -> void:
	if body == null or not is_instance_valid(body):
		return
	var body_id: int = body.get_instance_id()
	_cleanup_body(body_id)

func _cleanup_body(body_id: int) -> void:
	if not _tracked_bodies.has(body_id):
		return
	var entry := _tracked_bodies[body_id]
	var body: Node = entry.get("node", null)
	if body and is_instance_valid(body):
		_apply_slow_effect(body, false)
		if body.is_in_group("player"):
			_unregister_overlay_user()
	_tracked_bodies.erase(body_id)

func _apply_slow_effect(body: Node, apply: bool) -> void:
	var source_id: int = get_instance_id()
	if not body.is_in_group("player"):
		return
	if body.has_method("add_environment_speed_modifier") and apply:
		body.add_environment_speed_modifier(source_id, slow_multiplier)
	elif body.has_method("remove_environment_speed_modifier") and not apply:
		body.remove_environment_speed_modifier(source_id)

func _apply_damage(body: Node) -> void:
	if body.has_method("take_damage"):
		if damage_per_tick <= 1:
			body.take_damage()
		else:
			for i in range(damage_per_tick):
				body.take_damage()
	if body is CharacterBody2D:
		var current_velocity: Vector2 = body.velocity
		if current_velocity.y < 40.0:
			body.velocity = Vector2(current_velocity.x, 40.0)

func get_sonar_edges() -> Array:
	var edges: Array = []
	if _outline_points_local.size() < 2:
		return edges
	var subdiv: int = sonar_outline_subdivisions
	for i in range(_outline_points_local.size()):
		var start_local: Vector2 = _outline_points_local[i]
		var end_local: Vector2 = _outline_points_local[(i + 1) % _outline_points_local.size()]
		if subdiv <= 1:
			edges.append({
				"start": to_global(start_local),
				"end": to_global(end_local)
			})
		else:
			for s in range(subdiv):
				var t0: float = float(s) / subdiv
				var t1: float = float(s + 1) / subdiv
				var point_a: Vector2 = start_local.lerp(end_local, t0)
				var point_b: Vector2 = start_local.lerp(end_local, t1)
				edges.append({
					"start": to_global(point_a),
					"end": to_global(point_b)
				})
	return edges

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	if _outline_points_local.size() >= 3:
		var fill_color: Color = Color(0.2, 0.0, 0.25, 0.55)
		var border_color: Color = Color(0.6, 0.15, 0.75, 0.9)
		draw_colored_polygon(_outline_points_local, fill_color)
		for i in range(_outline_points_local.size()):
			var start_point: Vector2 = _outline_points_local[i]
			var end_point: Vector2 = _outline_points_local[(i + 1) % _outline_points_local.size()]
			draw_line(start_point, end_point, border_color, 2.0)

func _generate_outline_points() -> void:
	var rng := RandomNumberGenerator.new()
	if distortion_seed != 0:
		rng.seed = int(distortion_seed)
	else:
		var seed_value := int(round(global_position.x * 1000.0)) * 928371 + int(round(global_position.y * 1000.0)) * 527083 + int(radius * 131)
		rng.seed = seed_value
	var total_points: int = max(_MIN_POINTS, outline_points)
	var points: Array = []
	var min_y: float = INF
	for i in range(total_points):
		var angle: float = TAU * float(i) / total_points
		var base_radius_x: float = radius + rng.randf_range(-distortion_amplitude, distortion_amplitude)
		var base_radius_y: float = (radius * vertical_scale) + rng.randf_range(-distortion_amplitude * 0.35, distortion_amplitude * 0.35)
		var direction := Vector2(cos(angle), sin(angle))
		var point := Vector2(direction.x * base_radius_x, direction.y * base_radius_y)
		if point.y < 0.0:
			point.y *= 0.25
		else:
			point.y *= rng.randf_range(0.85, 1.25)
		points.append(point)
		min_y = min(min_y, point.y)
	if min_y == INF:
		_outline_points_local = PackedVector2Array()
		return
	var shift := -min_y
	for i in range(points.size()):
		points[i].y += shift
		if points[i].y < 6.0:
			points[i].y = clamp(points[i].y + rng.randf_range(-2.0, 2.0), 0.0, points[i].y + 4.0)
	_outline_points_local = PackedVector2Array(points)

func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		while _tracked_bodies.size() > 0:
			var keys_array := _tracked_bodies.keys()
			if keys_array.is_empty():
				break
			var first_key: int = int(keys_array[0])
			_cleanup_body(first_key)

func _ensure_overlay_initialized() -> void:
	if _overlay_layer and is_instance_valid(_overlay_layer) and _overlay_rect and is_instance_valid(_overlay_rect) and _overlay_material:
		return
	var layer := CanvasLayer.new()
	layer.layer = 100
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(0, 0, 0, 0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var material := _create_overlay_material(Color(overlay_color.r, overlay_color.g, overlay_color.b, 0.0))
	rect.material = material
	layer.add_child(rect)
	get_tree().root.add_child(layer)
	_overlay_layer = layer
	_overlay_rect = rect
	_overlay_material = material

func _create_overlay_material(base_color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _get_overlay_shader()
	material.set_shader_parameter("vignette_color", base_color)
	material.set_shader_parameter("radius", overlay_vignette_radius)
	material.set_shader_parameter("softness", overlay_vignette_softness)
	return material

func _get_overlay_material() -> ShaderMaterial:
	if _overlay_material:
		return _overlay_material
	if _overlay_rect and is_instance_valid(_overlay_rect) and _overlay_rect.material is ShaderMaterial:
		_overlay_material = _overlay_rect.material
		return _overlay_material
	return null

static func _get_overlay_shader() -> Shader:
	if _overlay_shader:
		return _overlay_shader
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec4 vignette_color : source_color;
uniform float radius = 0.75;
uniform float softness = 0.45;
void fragment() {
	vec2 uv = SCREEN_UV * 2.0 - 1.0;
	float aspect = SCREEN_PIXEL_SIZE.y / max(SCREEN_PIXEL_SIZE.x, 0.0001);
	uv.x *= aspect;
	float dist = length(uv);
	float edge0 = radius;
	float edge1 = radius + softness;
	float alpha = smoothstep(edge0, edge1, dist);
	COLOR = vec4(vignette_color.rgb, vignette_color.a * clamp(alpha, 0.0, 1.0));
}
"""
	_overlay_shader = shader
	return _overlay_shader

func _register_overlay_user() -> void:
	if overlay_fade_time <= 0.0:
		overlay_fade_time = 0.05
	_overlay_user_count += 1
	_ensure_overlay_initialized()
	var mat := _get_overlay_material()
	if not mat:
		return
	mat.set_shader_parameter("radius", overlay_vignette_radius)
	mat.set_shader_parameter("softness", overlay_vignette_softness)
	var current_color: Color = mat.get_shader_parameter("vignette_color")
	current_color = Color(overlay_color.r, overlay_color.g, overlay_color.b, current_color.a)
	mat.set_shader_parameter("vignette_color", current_color)
	if _overlay_tween and is_instance_valid(_overlay_tween):
		_overlay_tween.kill()
	if _overlay_layer and is_instance_valid(_overlay_layer):
		_overlay_tween = _overlay_layer.create_tween()
		var target_color := Color(overlay_color.r, overlay_color.g, overlay_color.b, overlay_color.a)
		_overlay_tween.tween_property(mat, "shader_parameter/vignette_color", target_color, overlay_fade_time)

func _unregister_overlay_user() -> void:
	if _overlay_user_count > 0:
		_overlay_user_count -= 1
	if _overlay_user_count > 0:
		return
	var mat := _get_overlay_material()
	if _overlay_layer and is_instance_valid(_overlay_layer) and _overlay_rect and is_instance_valid(_overlay_rect) and mat:
		if _overlay_tween and is_instance_valid(_overlay_tween):
			_overlay_tween.kill()
		_overlay_tween = _overlay_layer.create_tween()
		var current_color: Color = mat.get_shader_parameter("vignette_color")
		var target_color := Color(current_color.r, current_color.g, current_color.b, 0.0)
		_overlay_tween.tween_property(mat, "shader_parameter/vignette_color", target_color, overlay_fade_time)
		_overlay_tween.finished.connect(func():
			if _overlay_user_count > 0:
				return
			if _overlay_layer and is_instance_valid(_overlay_layer):
				_overlay_layer.queue_free()
			_overlay_layer = null
			_overlay_rect = null
			_overlay_tween = null
			_overlay_material = null)
