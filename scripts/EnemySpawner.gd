extends Node2D
class_name EnemySpawner
@export var hover_enemy_scene: PackedScene
@export var ground_enemy_scene: PackedScene
@export var spawn_interval: float = 7.0
@export var max_enemies: int = 2
@export var spawn_distance_from_player: float = 300.0
@export var spawn_height_offset: float = -100.0
@export var level_scaling_enabled: bool = true
@export var spawn_rate_increase_per_level: float = 0.2
@export var max_enemies_increase_per_level: int = 1
@export var enemy_health_multiplier_per_level: float = 0.3
@export var enemy_size_multiplier_per_level: float = 0.15
@export var enemy_speed_multiplier_per_level: float = 0.1
@export var hover_weight: float = 1.0
@export var ground_weight: float = 1.0
@export var ground_collision_mask: int = 1
@export var enemy_clear_width: float = 18.0
@export var enemy_clear_height: float = 22.0
@export var ground_snap_offset: float = 2.0
@export var max_spawn_tries: int = 12
var spawn_timer: float = 0.0
var current_enemies: Array[Node] = []
var player: Node2D = null
var level_manager: Node = null
var current_level: int = 1
var cached_spawn_interval: float
var cached_max_enemies: int
var cached_enemy_health_multiplier: float
var cached_enemy_size_multiplier: float
var cached_enemy_speed_multiplier: float
func _ready():
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		for child in get_tree().current_scene.get_children():
			if "Player" in child.name:
				player = child
				break
	level_manager = find_level_manager()
	if level_manager:
		if level_manager.has_signal("level_completed"):
			level_manager.level_completed.connect(_on_level_completed)
	_update_scaling_values()
func find_level_manager() -> Node:
	var scene := get_tree().current_scene
	if scene and scene.has_node("LevelManager"):
		return scene.get_node("LevelManager")
	return find_node_by_type(get_tree().current_scene, "LevelManager")
func find_node_by_type(node: Node, type_name: String) -> Node:
	if node and (node.name == type_name or (node.get_script() and str(node.get_script()).contains(type_name))):
		return node
	for child in node.get_children():
		var res = find_node_by_type(child, type_name)
		if res:
			return res
	return null
func _on_level_completed(level_number: int):
	current_level = level_number + 1
	_update_scaling_values()
	_spawn_level_completion_enemies()
func _update_scaling_values():
	if not level_scaling_enabled:
		cached_spawn_interval = spawn_interval
		cached_max_enemies = max_enemies
		cached_enemy_health_multiplier = 1.0
		cached_enemy_size_multiplier = 1.0
		cached_enemy_speed_multiplier = 1.0
		return
	var level_bonus = current_level - 1
	cached_spawn_interval = max(8.0, spawn_interval - (level_bonus * spawn_rate_increase_per_level))
	cached_max_enemies = max_enemies + (level_bonus * max_enemies_increase_per_level)
	cached_enemy_health_multiplier = 1.0 + (level_bonus * enemy_health_multiplier_per_level)
	cached_enemy_size_multiplier = 1.0 + (level_bonus * enemy_size_multiplier_per_level)
	cached_enemy_speed_multiplier = 1.0 + (level_bonus * enemy_speed_multiplier_per_level)
func _spawn_level_completion_enemies():
	if current_level >= 3:
		if current_enemies.size() < cached_max_enemies:
			spawn_enemy()
func _process(delta):
	if level_manager and "current_level" in level_manager:
		var manager_level = level_manager.current_level
		if manager_level != current_level:
			current_level = manager_level
			_update_scaling_values()
	if current_level <= 1:
		return
	spawn_timer += delta
	current_enemies = current_enemies.filter(func(e): return is_instance_valid(e))
	if spawn_timer >= cached_spawn_interval and current_enemies.size() < cached_max_enemies and player != null:
		spawn_enemy()
		spawn_timer = 0.0
func spawn_enemy():
	var scene_to_spawn: PackedScene = _pick_enemy_scene()
	if scene_to_spawn == null:
		print("EnemySpawner: No scene to spawn")
		return
	var is_hover := scene_to_spawn == hover_enemy_scene
	var enemy = scene_to_spawn.instantiate()
	get_parent().add_child(enemy)
	var pos_ok := false
	var spawn_pos := global_position
	for i in range(max_spawn_tries):
		var side = 1 if randf() > 0.5 else -1
		var base = player.global_position + Vector2(spawn_distance_from_player * (1.0 - (current_level - 1) * 0.05), 0) * side
		if is_hover:
			var p = _find_hover_spawn(base)
			if p != null:
				spawn_pos = p
				pos_ok = true
				break
		else:
			var p2 = _find_ground_spawn(base)
			if p2 != null:
				spawn_pos = p2
				pos_ok = true
				break
	if not pos_ok:
		print("EnemySpawner: Failed to find valid spawn position, removing enemy")
		enemy.queue_free()
		return
	print("EnemySpawner: Enemy spawned at position: ", spawn_pos)
	enemy.global_position = spawn_pos
	_enhance_enemy_for_level(enemy)
	_connect_enemy_to_quest_system(enemy)
	current_enemies.append(enemy)
func _pick_enemy_scene() -> PackedScene:
	var a = max(0.001, hover_weight)
	var b = max(0.001, ground_weight)
	var total = a + b
	var r = randf() * total
	if r < a:
		return hover_enemy_scene
	return ground_enemy_scene
func _find_hover_spawn(base: Vector2):
	var space = get_world_2d().direct_space_state
	var ox = randf_range(-120.0, 120.0)
	var start = base + Vector2(ox, spawn_height_offset + randf_range(-80.0, 40.0))
	var rq = PhysicsRayQueryParameters2D.create(start, start + Vector2(0, 600))
	rq.exclude = [self]
	rq.collision_mask = ground_collision_mask
	var hit = space.intersect_ray(rq)
	if hit.is_empty():
		return null
	var ground_y = hit.position.y
	var target = Vector2(start.x, ground_y - absf(spawn_height_offset))
	if _has_clearance_box(target, enemy_clear_width, enemy_clear_height):
		return target
	return null
func _find_ground_spawn(base: Vector2):
	var space = get_world_2d().direct_space_state
	for j in range(8):
		var ox = randf_range(-100.0, 100.0)
		var start = base + Vector2(ox, -100)
		var end = start + Vector2(0, 400)
		var rq = PhysicsRayQueryParameters2D.create(start, end)
		rq.exclude = [self]
		rq.collision_mask = 1
		var hit = space.intersect_ray(rq)
		if hit.is_empty():
			continue
		var floor_y = hit.position.y - 20
		var pos = Vector2(hit.position.x, floor_y)
		var clearance_start = pos + Vector2(0, -30)
		var clearance_end = pos + Vector2(0, -10)
		var clearance_check = PhysicsRayQueryParameters2D.create(clearance_start, clearance_end)
		clearance_check.exclude = [self]
		clearance_check.collision_mask = 1
		var clearance_hit = space.intersect_ray(clearance_check)
		if clearance_hit.is_empty():
			return pos
	return null
func _has_clearance_box(center: Vector2, w: float, h: float) -> bool:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, h)
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.transform = Transform2D(0.0, center)
	q.collide_with_areas = true
	q.collide_with_bodies = true
	q.collision_mask = ground_collision_mask
	var space = get_world_2d().direct_space_state
	var res = space.intersect_shape(q, 8)
	return res.is_empty()
func _has_floor_edge_margin(pos: Vector2, margin: float) -> bool:
	var space = get_world_2d().direct_space_state
	var left = PhysicsRayQueryParameters2D.create(pos + Vector2(-margin, -4), pos + Vector2(-margin, 24))
	left.collision_mask = ground_collision_mask
	left.exclude = [self]
	var right = PhysicsRayQueryParameters2D.create(pos + Vector2(margin, -4), pos + Vector2(margin, 24))
	right.collision_mask = ground_collision_mask
	right.exclude = [self]
	var l = space.intersect_ray(left)
	var r = space.intersect_ray(right)
	return not l.is_empty() and not r.is_empty()
func _enhance_enemy_for_level(enemy: Node):
	if not level_scaling_enabled:
		return
	if "health" in enemy:
		var base_health_for_level = _get_base_health_for_level()
		enemy.health = int(base_health_for_level * cached_enemy_health_multiplier)
	if enemy.has_node("Sprite2D"):
		var sprite = enemy.get_node("Sprite2D")
		sprite.scale *= cached_enemy_size_multiplier
	elif "sprite" in enemy and enemy.sprite:
		enemy.sprite.scale *= cached_enemy_size_multiplier
	if enemy.has_method("set_speed_multiplier"):
		enemy.set_speed_multiplier(cached_enemy_speed_multiplier)
	else:
		enemy.set("speed_multiplier", cached_enemy_speed_multiplier)
	if enemy.has_method("set_attack_range_multiplier"):
		enemy.set_attack_range_multiplier(1.0 + (current_level - 1) * 0.1)
	else:
		enemy.set("attack_range_multiplier", 1.0 + (current_level - 1) * 0.1)
	if current_level >= 3:
		_enhance_enemy_attacks(enemy)
	_add_level_visual_effects(enemy)
func _get_base_health_for_level() -> int:
	match current_level:
		1: return 1
		2: return 2
		3: return 2
		4: return 3
		5: return 3
		_: return 3 + (current_level - 5)
func _enhance_enemy_attacks(enemy: Node):
	var cooldown_multiplier = max(0.6, 1.0 - (current_level - 1) * 0.1)
	if enemy.has_method("set_attack_cooldown_multiplier"):
		enemy.set_attack_cooldown_multiplier(cooldown_multiplier)
	else:
		enemy.set("attack_cooldown_multiplier", cooldown_multiplier)
	if current_level >= 4:
		var range_multiplier = 1.0 + (current_level - 3) * 0.15
		if enemy.has_method("set_attack_range_multiplier"):
			enemy.set_attack_range_multiplier(range_multiplier)
		else:
			enemy.set("attack_range_multiplier", range_multiplier)
func _add_level_visual_effects(enemy: Node):
	if current_level <= 1:
		return
	var sprite = null
	if enemy.has_node("Sprite2D"):
		sprite = enemy.get_node("Sprite2D")
	elif "sprite" in enemy and enemy.sprite:
		sprite = enemy.sprite
	if not sprite:
		return
	var level_colors = [
		Color.WHITE,
		Color(1.1, 0.9, 0.9),
		Color(1.2, 0.8, 0.8),
		Color(1.4, 0.6, 0.6),
		Color(1.6, 0.4, 0.4),
	]
	var color_index = min(current_level - 1, level_colors.size() - 1)
	sprite.modulate = level_colors[color_index]
	if current_level >= 4:
		var tween = enemy.create_tween()
		tween.set_loops()
		tween.tween_property(sprite, "modulate:a", 0.8, 1.2)
		tween.tween_property(sprite, "modulate:a", 1.0, 1.2)
	if current_level >= 5:
		_add_particle_effects(enemy)
func _add_particle_effects(enemy: Node):
	var particles = CPUParticles2D.new()
	enemy.add_child(particles)
	particles.emitting = true
	particles.amount = 10
	particles.lifetime = 1.5
	particles.texture = null
	particles.direction = Vector2(0, -1)
	particles.spread = 30.0
	particles.initial_velocity_min = 5.0
	particles.initial_velocity_max = 15.0
	particles.gravity = Vector2(0, -30)
	particles.scale_amount_min = 0.3
	particles.scale_amount_max = 0.8
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.3, 0.0, 0.5, 0.6))
	gradient.add_point(1.0, Color(0.0, 0.0, 0.0, 0.0))
	particles.color_ramp = gradient
func get_spawn_position() -> Vector2:
	return player.global_position + Vector2(spawn_distance_from_player, spawn_height_offset) if player != null else global_position
func spawn_enemy_now():
	spawn_enemy()
func clear_all_enemies():
	for enemy in current_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	current_enemies.clear()
func get_scaling_info() -> Dictionary:
	return {
		"current_level": current_level,
		"spawn_interval": cached_spawn_interval,
		"max_enemies": cached_max_enemies,
		"health_multiplier": cached_enemy_health_multiplier,
		"size_multiplier": cached_enemy_size_multiplier,
		"speed_multiplier": cached_enemy_speed_multiplier,
		"base_health": _get_base_health_for_level()
	}
func set_level_override(level: int):
	current_level = level
	_update_scaling_values()
func _connect_enemy_to_quest_system(enemy: Node):
	var quest_system = _find_node_by_name(get_tree().current_scene, "QuestSystem")
	if quest_system and quest_system.has_method("register_enemy"):
		quest_system.register_enemy(enemy)
func _find_node_by_name(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	for child in node.get_children():
		var result = _find_node_by_name(child, name)
		if result:
			return result
	return null
