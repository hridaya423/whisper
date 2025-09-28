extends Node
class_name RuneSystem
enum RuneType {
	RANGE_AMPLIFIER,
	DURATION_CRYSTAL,
	RAPID_PULSE
}
var rune_inventory = {}
var active_rune_slots = [null, null, null]
var rune_spawning_enabled = false
var distance_traveled = 0.0
var last_spawn_distance = 0.0
var spawn_interval = 350.0
var rune_duration = 30.0
var rune_cooldown = 60.0
var active_rune_timers = [0.0, 0.0, 0.0]
var rune_cooldowns = {}
var rune_multipliers = {
	"range": 1.0,
	"duration": 1.0,
	"cooldown": 1.0
}
var rune_configs = {
	RuneType.RANGE_AMPLIFIER: {
		"name": "Range Amplifier",
		"description": "Sonar range +50%",
		"range_multiplier": 1.5, "stackable": true
	},
	RuneType.DURATION_CRYSTAL: {
		"name": "Duration Crystal",
		"description": "Sonar duration +100%",
		"duration_multiplier": 2.0, "stackable": true
	},
	RuneType.RAPID_PULSE: {
		"name": "Rapid Pulse",
		"description": "Sonar cooldown -30%",
		"cooldown_multiplier": 0.7, "stackable": true
	}
}
var level_manager: Node
var player: Node
var tilemap_layer: TileMapLayer
signal rune_collected(rune_type: RuneType)
signal rune_activated(slot: int, rune_type: RuneType)
signal rune_deactivated(slot: int, rune_type: RuneType)
signal rune_inventory_updated
signal rune_spawned(position: Vector2, rune_type: RuneType)
func _ready():
	level_manager = _find_level_manager()
	player = _find_player()
	tilemap_layer = _find_tilemap()
	if level_manager and level_manager.has_signal("level_completed"):
		level_manager.level_completed.connect(_on_level_completed)
func _find_level_manager() -> Node:
	var paths_to_try = [
		"../LevelManager",
		"../../LevelManager",
		get_tree().current_scene.get_node("LevelManager") if get_tree().current_scene.has_node("LevelManager") else null
	]
	for path in paths_to_try:
		if path and is_instance_valid(path):
			return path
	return _find_node_by_name(get_tree().current_scene, "LevelManager")
func _find_player() -> Node:
	return get_tree().get_first_node_in_group("player")
func _find_tilemap() -> TileMapLayer:
	return _find_node_by_name(get_tree().current_scene, "TileMapLayer")
func _find_node_by_name(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	for child in node.get_children():
		var result = _find_node_by_name(child, name)
		if result:
			return result
	return null
func _process(delta):
	_update_distance_tracking()
	_handle_rune_spawning()
	_handle_rune_timing(delta)
func _update_distance_tracking():
	if not player:
		return
	var current_distance = player.global_position.length()
	if current_distance > distance_traveled:
		distance_traveled = current_distance
func _handle_rune_spawning():
	if not rune_spawning_enabled or not player or not tilemap_layer:
		return
	var distance_since_last_spawn = distance_traveled - last_spawn_distance
	if distance_since_last_spawn >= spawn_interval:
		_spawn_random_rune()
		last_spawn_distance = distance_traveled
func _handle_rune_timing(delta: float):
	var types_to_remove = []
	for rune_type in rune_cooldowns.keys():
		rune_cooldowns[rune_type] -= delta
		if rune_cooldowns[rune_type] <= 0:
			types_to_remove.append(rune_type)
	for rune_type in types_to_remove:
		rune_cooldowns.erase(rune_type)
		if not rune_inventory.has(rune_type):
			rune_inventory[rune_type] = 0
		rune_inventory[rune_type] += 1
		rune_inventory_updated.emit()
	for i in range(active_rune_slots.size()):
		if active_rune_slots[i] != null:
			active_rune_timers[i] -= delta
			if active_rune_timers[i] <= 0:
				var expired_rune_type = active_rune_slots[i]
				rune_cooldowns[expired_rune_type] = rune_cooldown
				active_rune_slots[i] = null
				active_rune_timers[i] = 0.0
				_update_multipliers()
				rune_deactivated.emit(i, expired_rune_type)
				rune_inventory_updated.emit()
func _on_level_completed(level_number: int):
	if level_number >= 3:
		rune_spawning_enabled = true
func _spawn_random_rune():
	var spawn_position = _find_valid_spawn_position()
	if spawn_position == Vector2.ZERO:
		return
	var rune_type = _generate_random_rune_type()
	_create_rune_pickup(spawn_position, rune_type)
	rune_spawned.emit(spawn_position, rune_type)
func _find_valid_spawn_position() -> Vector2:
	if not player or not tilemap_layer:
		return Vector2.ZERO
	var player_pos = player.global_position
	var attempts = 20
	for i in range(attempts):
		var angle = randf() * TAU
		var distance = randf_range(100, 300)
		var potential_pos = player_pos + Vector2(cos(angle), sin(angle)) * distance
		if _is_valid_spawn_position(potential_pos):
			return potential_pos
	return Vector2.ZERO
func _is_valid_spawn_position(pos: Vector2) -> bool:
	if not tilemap_layer:
		return false
	var tile_pos = tilemap_layer.local_to_map(pos)
	var below_tile = Vector2i(tile_pos.x, tile_pos.y + 1)
	var has_ground = tilemap_layer.get_cell_source_id(below_tile) != -1
	var spawn_tile = tilemap_layer.get_cell_source_id(tile_pos)
	var is_empty = spawn_tile == -1
	return has_ground and is_empty
func _generate_random_rune_type() -> RuneType:
	var rune_types = [RuneType.RANGE_AMPLIFIER, RuneType.DURATION_CRYSTAL, RuneType.RAPID_PULSE]
	return rune_types[randi() % rune_types.size()]
func _create_rune_pickup(position: Vector2, rune_type: RuneType):
	var pickup = preload("res://scripts/RunePickup.gd").new()
	pickup.rune_type = rune_type
	pickup.global_position = position
	get_tree().current_scene.add_child(pickup)
func activate_rune(slot_index: int, rune_type: RuneType = RuneType.RANGE_AMPLIFIER) -> bool:
	if slot_index < 0 or slot_index >= active_rune_slots.size():
		return false
	if active_rune_slots[slot_index] == null:
		if rune_type in rune_cooldowns:
			var remaining = int(rune_cooldowns[rune_type])
			return false
		if rune_type in rune_inventory and rune_inventory[rune_type] > 0:
			active_rune_slots[slot_index] = rune_type
			active_rune_timers[slot_index] = rune_duration
			rune_inventory[rune_type] -= 1
			if rune_inventory[rune_type] <= 0:
				rune_inventory.erase(rune_type)
			_update_multipliers()
			rune_activated.emit(slot_index, rune_type)
			rune_inventory_updated.emit()
			return true
		else:
			return false
	else:
		return deactivate_rune(slot_index)
	return false
func deactivate_rune(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= active_rune_slots.size():
		return false
	var rune_type = active_rune_slots[slot_index]
	if rune_type == null:
		return false
	var remaining_time = active_rune_timers[slot_index]
	var time_used = rune_duration - remaining_time
	if time_used >= 5.0:
		var cooldown_ratio = time_used / rune_duration
		var reduced_cooldown = rune_cooldown * cooldown_ratio * 0.5
		rune_cooldowns[rune_type] = reduced_cooldown
	else:
		rune_cooldowns[rune_type] = rune_cooldown
	active_rune_slots[slot_index] = null
	active_rune_timers[slot_index] = 0.0
	_update_multipliers()
	rune_deactivated.emit(slot_index, rune_type)
	rune_inventory_updated.emit()
	return true
func collect_rune(rune_type: RuneType) -> bool:
	var total_inventory = get_total_inventory_count()
	var total_active = get_total_active_count()
	var total_runes = total_inventory + total_active
	if total_runes >= 3:
		return false
	if not rune_inventory.has(rune_type):
		rune_inventory[rune_type] = 0
	rune_inventory[rune_type] += 1
	rune_collected.emit(rune_type)
	rune_inventory_updated.emit()
	return true
func get_total_inventory_count() -> int:
	var total = 0
	for rune_type in rune_inventory.keys():
		total += rune_inventory[rune_type]
	return total
func get_total_active_count() -> int:
	var total = 0
	for rune_type in active_rune_slots:
		if rune_type != null:
			total += 1
	return total
func drop_rune() -> bool:
	for rune_type in rune_inventory.keys():
		if rune_inventory[rune_type] > 0:
			rune_inventory[rune_type] -= 1
			if rune_inventory[rune_type] <= 0:
				rune_inventory.erase(rune_type)
			rune_inventory_updated.emit()
			return true
	return false
func _update_multipliers():
	rune_multipliers.range = 1.0
	rune_multipliers.duration = 1.0
	rune_multipliers.cooldown = 1.0
	var rune_counts = {}
	for rune_type in active_rune_slots:
		if rune_type != null:
			if not rune_counts.has(rune_type):
				rune_counts[rune_type] = 0
			rune_counts[rune_type] += 1
	for rune_type in rune_counts:
		var config = rune_configs[rune_type]
		var count = rune_counts[rune_type]
		if config.has("range_multiplier"):
			if config.stackable:
				rune_multipliers.range *= pow(config.range_multiplier, count)
			else:
				rune_multipliers.range *= config.range_multiplier
		if config.has("duration_multiplier"):
			if config.stackable:
				rune_multipliers.duration *= pow(config.duration_multiplier, count)
			else:
				rune_multipliers.duration *= config.duration_multiplier
		if config.has("cooldown_multiplier"):
			if config.stackable:
				rune_multipliers.cooldown *= pow(config.cooldown_multiplier, count)
			else:
				rune_multipliers.cooldown *= config.cooldown_multiplier
func get_range_multiplier() -> float:
	return rune_multipliers.range
func get_duration_multiplier() -> float:
	return rune_multipliers.duration
func get_cooldown_multiplier() -> float:
	return rune_multipliers.cooldown
func get_active_runes() -> Array:
	return active_rune_slots.duplicate()
func get_inventory() -> Dictionary:
	return rune_inventory.duplicate()
func get_rune_info(rune_type: RuneType) -> Dictionary:
	return rune_configs[rune_type].duplicate()
func get_active_rune_timers() -> Array:
	return active_rune_timers.duplicate()
func get_rune_cooldowns() -> Dictionary:
	return rune_cooldowns.duplicate()
func is_rune_on_cooldown(rune_type: RuneType) -> bool:
	return rune_type in rune_cooldowns
func get_rune_cooldown_time(rune_type: RuneType) -> float:
	return rune_cooldowns.get(rune_type, 0.0)
