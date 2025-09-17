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

var tilemap_layer: TileMapLayer
var platform_edges = []
var rune_system: RuneSystem

const TILE_SIZE = 16

func _ready():
	tilemap_layer = get_node("../TileMapLayer")
	rune_system = get_node("../RuneSystem")
	z_index = 1000
	
	if tilemap_layer:
		tilemap_layer.visible = false
		
	_calculate_platform_edges()

func _process(delta):
	if is_glowing:
		glow_timer -= delta
		if glow_timer <= 0:
			is_glowing = false
			wave_rings.clear()

	_update_wave_rings(delta)

	queue_redraw()

func _draw():
	if not is_glowing:
		return

	_draw_wave_rings()
	if tilemap_layer and not platform_edges.is_empty():
		_draw_platform_highlights()

func _calculate_platform_edges():
	platform_edges.clear()
	
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
					platform_edges.append(edge_lines[i])

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

func _draw_platform_highlights():
	_update_highlighted_edges()

	for edge_data in highlighted_edges:
		var edge = edge_data.edge
		var highlight_alpha = edge_data.alpha

		edge_data.fade_timer -= get_process_delta_time()
		if edge_data.fade_timer > 0:
			var fade_progress = edge_data.fade_timer / edge_data.fade_duration
			highlight_alpha *= fade_progress
			_draw_highlighted_line(edge.start, edge.end, highlight_alpha)

	highlighted_edges = highlighted_edges.filter(func(edge_data): return edge_data.fade_timer > 0)

func _update_highlighted_edges():
	for edge in platform_edges:
		var start_pos = edge.start
		var end_pos = edge.end
		var edge_center = (start_pos + end_pos) / 2.0
		var distance_to_sonar = edge_center.distance_to(sonar_position)

		if distance_to_sonar > sonar_range:
			continue

		var direction_to_edge = (edge_center - sonar_position).normalized()
		var angle_to_edge = rad_to_deg(sonar_direction.angle_to(direction_to_edge))
		var angle_diff = abs(angle_to_edge)

		if angle_diff > sonar_cone_angle / 2.0:
			continue

		var should_highlight = false
		var max_intensity = 0.0

		for ring in wave_rings:
			if not ring.active:
				continue

			var distance_to_ring = abs(distance_to_sonar - ring.radius)
			if distance_to_ring < 25:
				var ring_intensity = 1.0 - (distance_to_ring / 25.0)
				max_intensity = max(max_intensity, ring_intensity * ring.alpha)
				should_highlight = true

		if should_highlight:
			var existing_edge = null
			for edge_data in highlighted_edges:
				if edge_data.edge == edge:
					existing_edge = edge_data
					break

			var direction_factor = 1.0 - (angle_diff / (sonar_cone_angle / 2.0)) * 0.3
			var final_alpha = max_intensity * direction_factor * 0.9

			if existing_edge:
				existing_edge.alpha = max(existing_edge.alpha, final_alpha)
				existing_edge.fade_timer = existing_edge.fade_duration
			else:
				highlighted_edges.append({
					"edge": edge,
					"alpha": final_alpha,
					"fade_timer": 3.0,
					"fade_duration": 3.0
				})

func _draw_highlighted_line(start: Vector2, end: Vector2, alpha: float):
	var color = glow_color
	color.a = alpha
	draw_line(start, end, color, 2.0)
	color.a = alpha * 0.4
	draw_line(start, end, color, 4.0)

func _on_sonar_pulse(position: Vector2, range: float, direction: Vector2):
	if rune_system:
		sonar_range = base_sonar_range * rune_system.get_range_multiplier()
		glow_duration = base_glow_duration * rune_system.get_duration_multiplier()
	else:
		sonar_range = base_sonar_range
		glow_duration = base_glow_duration

	is_glowing = true
	glow_timer = glow_duration
	sonar_position = position
	sonar_direction = direction.normalized()

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
