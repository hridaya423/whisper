extends Node2D
var is_glowing = false
var glow_timer = 0.0
var base_glow_duration = 2.0
var glow_duration = 2.0
var glow_color = Color(1.0, 1.0, 1.0, 1.0)
var sonar_position = Vector2.ZERO
var base_sonar_range = 150.0
var sonar_range = 150.0
var sonar_direction = Vector2.RIGHT
var sonar_cone_angle = 35.0
var wave_rings = []
var max_wave_rings = 3
var highlighted_edges = []
var ambient_enabled = false
var ambient_position = Vector2.ZERO
var ambient_range = 0.0
var ambient_glow_color = Color(0.92, 0.97, 1.0, 0.2)
var ambient_intensity_scale = 0.6
var pulse_active = false
var tilemap_layer: TileMapLayer
var tilemap_edges = []
var platform_edges = [] 
var all_edges = []
var rune_system: RuneSystem
var camera: Camera2D
var player: CharacterBody2D
var camera_following_wave = false
var original_camera_position: Vector2
var camera_follow_tween: Tween
const TILE_SIZE = 16
func _ready():
	tilemap_layer = get_node_or_null("../TileMapLayer")
	rune_system = get_node_or_null("../RuneSystem")
	player = get_node_or_null("../Player")
	if player and is_instance_valid(player):
		camera = player.get_node_or_null("Camera2D")
	add_to_group("sonar_system")
	z_index = 1000
	if tilemap_layer and is_instance_valid(tilemap_layer):
		tilemap_layer.visible = false

	_calculate_tilemap_edges()
func _process(delta):
	if is_glowing:
		glow_timer -= delta
		if glow_timer <= 0:
			is_glowing = false
			wave_rings.clear()

	_calculate_platform_edges()

	all_edges = tilemap_edges + platform_edges

	_update_wave_rings(delta)
	queue_redraw()
func _draw():
	if not is_glowing and not ambient_enabled:
		return
	if ambient_enabled:
		_draw_ambient_glow()
	_draw_wave_rings()
	if tilemap_layer and not all_edges.is_empty():
		_draw_platform_highlights()

func _has_property(node: Object, property_name: StringName) -> bool:
	for property_info in node.get_property_list():
		if property_info.get("name") == property_name:
			return true
	return false

func _calculate_tilemap_edges():
	tilemap_edges.clear()
	if not tilemap_layer:
		return

	var used_rect = tilemap_layer.get_used_rect()
	for x in range(used_rect.position.x, used_rect.position.x + used_rect.size.x):
		for y in range(used_rect.position.y, used_rect.position.y + used_rect.size.y):
			var tile_pos = Vector2i(x, y)
			if tilemap_layer.get_cell_source_id(tile_pos) == -1:
				continue

			var world_pos = tilemap_layer.map_to_local(tile_pos)
			var half_tile = TILE_SIZE / 2.0
			var neighbors = [
				Vector2i(x, y - 1),
				Vector2i(x + 1, y),
				Vector2i(x, y + 1),
				Vector2i(x - 1, y)
			]
			var edge_lines = [
				{"start": Vector2(world_pos.x - half_tile, world_pos.y - half_tile),
				 "end": Vector2(world_pos.x + half_tile, world_pos.y - half_tile)},
				{"start": Vector2(world_pos.x + half_tile, world_pos.y - half_tile),
				 "end": Vector2(world_pos.x + half_tile, world_pos.y + half_tile)},
				{"start": Vector2(world_pos.x + half_tile, world_pos.y + half_tile),
				 "end": Vector2(world_pos.x - half_tile, world_pos.y + half_tile)},
				{"start": Vector2(world_pos.x - half_tile, world_pos.y + half_tile),
				 "end": Vector2(world_pos.x - half_tile, world_pos.y - half_tile)}
			]
			for i in range(4):
				var neighbor_pos = neighbors[i]
				var neighbor_has_tile = tilemap_layer.get_cell_source_id(neighbor_pos) != -1
				if not neighbor_has_tile:
					tilemap_edges.append(edge_lines[i])

func _calculate_platform_edges():
	platform_edges.clear()

	for platform in get_tree().get_nodes_in_group("sonar_platforms"):
		if not platform or not is_instance_valid(platform) or not platform is Node2D:
			continue

		if platform.has_method("get_sonar_edges"):
			var extra_edges = platform.get_sonar_edges()
			if typeof(extra_edges) == TYPE_ARRAY:
				for edge in extra_edges:
					if typeof(edge) == TYPE_DICTIONARY and edge.has("start") and edge.has("end"):
						platform_edges.append({
							"start": edge.start,
							"end": edge.end,
							"platform": platform
						})

		var rects: Array = []
		if platform.has_method("get_sonar_rects"):
			rects = platform.get_sonar_rects()
		elif platform.has_method("get_sonar_rect"):
			var rect_result = platform.get_sonar_rect()
			if typeof(rect_result) == TYPE_ARRAY:
				rects = rect_result
			elif rect_result is Rect2:
				rects = [rect_result]
		elif _has_property(platform, "platform_size"):
			rects = [Rect2(platform.global_position - platform.platform_size / 2, platform.platform_size)]

		for rect_value in rects:
			if not rect_value is Rect2:
				continue
			var rect: Rect2 = rect_value
			if rect.size.x <= 0 or rect.size.y <= 0:
				continue

			var corners = [
				rect.position,
				rect.position + Vector2(rect.size.x, 0),
				rect.position + rect.size,
				rect.position + Vector2(0, rect.size.y)
			]
			var edge_lines = [
				{"start": corners[0], "end": corners[1], "platform": platform},
				{"start": corners[1], "end": corners[2], "platform": platform},
				{"start": corners[2], "end": corners[3], "platform": platform},
				{"start": corners[3], "end": corners[0], "platform": platform}
			]
			platform_edges += edge_lines
func _calculate_fast_wave(distance: float, wave_radius: float) -> float:
	var wave_thickness = 50.0
	var distance_to_wave = abs(distance - wave_radius)
	if distance_to_wave < wave_thickness:
		var intensity = 1.0 - (distance_to_wave / wave_thickness)
		return 0.7 + intensity * 0.3
	else:
		return 0.5
func _is_bottom_edge(edge: Dictionary) -> bool:
	var start_pos = edge.start
	var end_pos = edge.end
	return abs(start_pos.y - end_pos.y) < 1.0 and start_pos.y > sonar_position.y + 10
func _update_wave_rings(delta: float):
	var any_active = false
	for ring in wave_rings:
		if ring.delay > 0:
			ring.delay -= delta
			continue
		if not ring.active:
			ring.active = true
		ring.radius += ring.speed * delta
		var progress = ring.radius / ring.max_radius
		ring.alpha = 1.0 - progress
		if ring.radius >= ring.max_radius:
			ring.alpha = 0.0
		if ring.active and ring.alpha > 0.0:
			any_active = true
	pulse_active = any_active
func _draw_wave_rings():
	for ring in wave_rings:
		if not ring.active or ring.alpha <= 0:
			continue
		var color = glow_color
		color.a = ring.alpha * 0.8
		var start_angle = sonar_direction.angle() - deg_to_rad(sonar_cone_angle / 2.0)
		var end_angle = sonar_direction.angle() + deg_to_rad(sonar_cone_angle / 2.0)
		var arc_points = 32
		draw_arc(sonar_position, ring.radius, start_angle, end_angle, arc_points, color, 2.0)
		if ring.radius > 5:
			color.a = ring.alpha * 0.3
			draw_arc(sonar_position, ring.radius - 2, start_angle, end_angle, arc_points, color, 4.0)
func _draw_ambient_glow():
	if ambient_range <= 0.0:
		return
	var outer_color = ambient_glow_color
	outer_color.a *= 0.45
	draw_arc(ambient_position, ambient_range, 0.0, TAU, 64, outer_color, 1.5)
	var mid_color = ambient_glow_color
	mid_color.a *= 0.7
	draw_arc(ambient_position, ambient_range * 0.65, 0.0, TAU, 64, mid_color, 2.2)
func _draw_platform_highlights():
	_update_highlighted_edges()
	for edge_data in highlighted_edges:
		var edge = edge_data.edge
		_draw_highlighted_line(edge.start, edge.end, edge_data.alpha)

func _update_highlighted_edges():
	var new_edges = []
	var reference_position = ambient_position if ambient_enabled else sonar_position
	var pulse_range = sonar_range if pulse_active else 0.0
	var effective_range = max(ambient_range, pulse_range) if ambient_enabled else pulse_range
	if effective_range <= 0.0:
		highlighted_edges = []
		return

	var half_cone_angle = max(sonar_cone_angle * 0.5, 1.0)

	for edge in all_edges:
		var start_pos = edge.start
		var end_pos = edge.end
		var edge_center = (start_pos + end_pos) / 2.0
		var distance_to_center = edge_center.distance_to(reference_position)

		if distance_to_center > effective_range:
			continue

		var direction_to_edge = (edge_center - sonar_position).normalized()
		var angle_to_edge = rad_to_deg(sonar_direction.angle_to(direction_to_edge))
		var within_cone = abs(angle_to_edge) <= half_cone_angle
		var within_ambient = ambient_enabled and distance_to_center <= ambient_range

		if not within_cone and not within_ambient:
			continue

		var highlight_alpha = 0.0

		if pulse_active and within_cone:
			for ring in wave_rings:
				if not ring.active:
					continue
				var distance_to_ring = abs(distance_to_center - ring.radius)
				if distance_to_ring < 25:
					var ring_intensity = 1.0 - (distance_to_ring / 25.0)
					var direction_factor = 1.0 - (abs(angle_to_edge) / half_cone_angle) * 0.3
					var pulse_alpha = ring_intensity * ring.alpha * direction_factor * 0.9
					highlight_alpha = max(highlight_alpha, pulse_alpha)

		if ambient_enabled and within_ambient:
			var ambient_factor = 1.0 - clamp(distance_to_center / max(ambient_range, 0.01), 0.0, 1.0)
			ambient_factor = pow(ambient_factor, 1.4)
			highlight_alpha = max(highlight_alpha, ambient_factor * ambient_intensity_scale)

		if highlight_alpha <= 0.0:
			continue

		new_edges.append({
			"edge": edge,
			"alpha": highlight_alpha,
			"fade_timer": 0.1,
			"fade_duration": 0.1
		})

	highlighted_edges = new_edges

func _draw_highlighted_line(start: Vector2, end: Vector2, alpha: float):
	var color = glow_color
	color.a = alpha
	draw_line(start, end, color, 2.0)
	color.a = alpha * 0.4
	draw_line(start, end, color, 4.0)
func set_ambient_sonar(position: Vector2, range: float, color: Color = Color(0.92, 0.97, 1.0, 0.2)):
	ambient_enabled = true
	ambient_position = position
	ambient_range = max(range, 0.0)
	ambient_glow_color = color
	if not pulse_active:
		sonar_position = ambient_position
	is_glowing = true
	glow_timer = max(glow_timer, 0.1)
	queue_redraw()
func clear_ambient_sonar():
	ambient_enabled = false
	ambient_range = 0.0
	ambient_position = Vector2.ZERO
	if not pulse_active:
		is_glowing = false
		glow_timer = 0.0
	queue_redraw()
func _on_sonar_pulse(position: Vector2, range: float, direction: Vector2):
	sonar_range = range

	if rune_system:
		glow_duration = base_glow_duration * rune_system.get_duration_multiplier()
	else:
		glow_duration = base_glow_duration
	is_glowing = true
	glow_timer = glow_duration
	sonar_position = position
	sonar_direction = direction.normalized()
	pulse_active = true

	var range_ratio = sonar_range / base_sonar_range
	if range_ratio > 1.3 and camera and player:
		print("Camera wave follow activated - range ratio: ", range_ratio)
		_start_camera_wave_follow()
	wave_rings.clear()
	highlighted_edges.clear()
	for i in range(max_wave_rings):
		var ring = {
			"radius": 0.0,
			"max_radius": sonar_range,
			"speed": 300.0,
			"alpha": 1.0,
			"delay": i * 0.15,
			"active": false
		}
		wave_rings.append(ring)
func _start_camera_wave_follow():
	if camera_following_wave:
		return
	camera_following_wave = true
	original_camera_position = camera.global_position
	_follow_wave_expansion()
func _follow_wave_expansion():
	if not camera_following_wave:
		return
	var furthest_ring_radius = 0.0
	for ring in wave_rings:
		if ring.active and ring.radius > furthest_ring_radius:
			furthest_ring_radius = ring.radius
	var wave_front_offset = sonar_direction * furthest_ring_radius * 0.7
	var target_position = sonar_position + wave_front_offset
	if camera_follow_tween:
		camera_follow_tween.kill()
	camera_follow_tween = create_tween()
	camera_follow_tween.tween_property(camera, "global_position", target_position, 0.3)
	if furthest_ring_radius >= sonar_range * 0.95:
		await get_tree().create_timer(1.0).timeout
		_return_camera_to_player()
	else:
		await get_tree().create_timer(0.1).timeout
		_follow_wave_expansion()
func _return_camera_to_player():
	if not camera_following_wave:
		return
	camera_following_wave = false
	if camera_follow_tween:
		camera_follow_tween.kill()
	camera_follow_tween = create_tween()
	camera_follow_tween.tween_property(camera, "global_position", player.global_position, 0.8)
func apply_duration_boost(boost_multiplier: float):
	glow_duration = base_glow_duration * boost_multiplier
	if glow_duration > glow_timer:
		glow_timer = glow_duration
