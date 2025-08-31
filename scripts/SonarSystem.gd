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
var sonar_cone_angle = 90.0

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
	queue_redraw()

func _draw():
	if not is_glowing or not tilemap_layer or platform_edges.is_empty():
		return
	
	var temporal_alpha = glow_timer / glow_duration
	
	var wave_progress = 1.0 - (glow_timer / glow_duration)
	var wave_radius = sonar_range * wave_progress * 2.0 
	
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
		
		var wave_alpha = _calculate_fast_wave(distance_to_sonar, wave_radius)
		var distance_factor = 1.0 - (distance_to_sonar / sonar_range) * 0.5
		var direction_factor = 1.0 - (angle_diff / (sonar_cone_angle / 2.0)) * 0.3
		var final_alpha = temporal_alpha * max(wave_alpha, 0.4) * distance_factor * direction_factor
		final_alpha = clamp(final_alpha, 0.0, 1.0)
		
		if final_alpha > 0.1:
			_draw_slim_line(start_pos, end_pos, final_alpha)

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

func _draw_slim_line(start: Vector2, end: Vector2, alpha: float):
	var color = glow_color
	
	var boosted_alpha = min(alpha * 2.0, 1.0)
	color.a = boosted_alpha
	
	draw_line(start, end, color, 2.0)
	var glow_color_bright = color
	glow_color_bright.a = boosted_alpha * 0.6
	draw_line(start, end, glow_color_bright, 3.5)

func _on_sonar_pulse(position: Vector2, range: float, direction: Vector2):
	if rune_system:
		sonar_range = base_sonar_range * rune_system.get_range_multiplier()
		glow_duration = base_glow_duration * rune_system.get_duration_multiplier()
		print("Sonar with runes - Range: ", sonar_range, ", Duration: ", glow_duration)
	else:
		sonar_range = base_sonar_range
		glow_duration = base_glow_duration
	
	is_glowing = true
	glow_timer = glow_duration
	sonar_position = position
	sonar_direction = direction.normalized()
