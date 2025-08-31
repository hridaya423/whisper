extends Node2D
class_name EnemySpawner

@export var enemy_scene: PackedScene
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
	
	if player:
		print("EnemySpawner: Found player at ", player.global_position)
	else:
		print("EnemySpawner: Could not find player!")
	
	
	level_manager = find_level_manager()
	if level_manager:
		if level_manager.has_signal("level_completed"):
			level_manager.level_completed.connect(_on_level_completed)
		print("EnemySpawner: Connected to LevelManager")
	else:
		print("EnemySpawner: Could not find LevelManager!")
	
	
	_update_scaling_values()

func find_level_manager() -> Node:
	
	var paths_to_try = [
		"../LevelManager",
		"../../LevelManager", 
		get_tree().current_scene.get_node("LevelManager") if get_tree().current_scene.has_node("LevelManager") else null
	]
	
	for path in paths_to_try:
		if path and is_instance_valid(path):
			return path
	
	
	return find_node_by_type(get_tree().current_scene, "LevelManager")

func find_node_by_type(node: Node, type_name: String) -> Node:
	
	if node.name == type_name or (node.get_script() and str(node.get_script()).contains(type_name)):
		return node
	
	
	for child in node.get_children():
		var result = find_node_by_type(child, type_name)
		if result:
			return result
	
	return null

func _on_level_completed(level_number: int):
	current_level = level_number + 1  
	print("EnemySpawner: Level ", current_level, " starting - updating enemy scaling")
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
	
	print("=== ENEMY SCALING FOR LEVEL ", current_level, " ===")
	print("Spawn interval: ", cached_spawn_interval, " (was ", spawn_interval, ")")
	print("Max enemies: ", cached_max_enemies, " (was ", max_enemies, ")")
	print("Enemy health multiplier: ", cached_enemy_health_multiplier)
	print("Enemy size multiplier: ", cached_enemy_size_multiplier) 
	print("Enemy speed multiplier: ", cached_enemy_speed_multiplier)

func _spawn_level_completion_enemies():
	
	if current_level >= 3:  
		if current_enemies.size() < cached_max_enemies:
			spawn_enemy()
			print("Spawned bonus enemy for level completion")

func _process(delta):
	
	if level_manager and "current_level" in level_manager:
		var manager_level = level_manager.current_level
		if manager_level != current_level:
			current_level = manager_level
			print("EnemySpawner: Level updated to ", current_level)
			_update_scaling_values()
	
	
	if current_level <= 1:
		return
	
	spawn_timer += delta
	
	
	current_enemies = current_enemies.filter(func(enemy): return is_instance_valid(enemy))
	
	
	if spawn_timer >= cached_spawn_interval and current_enemies.size() < cached_max_enemies and player != null:
		spawn_enemy()
		spawn_timer = 0.0

func spawn_enemy():
	if enemy_scene == null:
		return
	
	print("Spawning level ", current_level, " enemy...")
	var enemy = enemy_scene.instantiate()
	get_parent().add_child(enemy)
	
	
	var spawn_position = get_spawn_position()
	enemy.global_position = spawn_position
	
	
	_enhance_enemy_for_level(enemy)
	
	
	current_enemies.append(enemy)
	
	print("Enhanced enemy spawned at: ", spawn_position, " Total enemies: ", current_enemies.size())

func _enhance_enemy_for_level(enemy: Node):
	if not level_scaling_enabled:
		return
	
	print("=== ENHANCING ENEMY FOR LEVEL ", current_level, " ===")
	
	
	if "health" in enemy:
		var original_health = enemy.health
		
		var base_health_for_level = _get_base_health_for_level()
		enemy.health = int(base_health_for_level * cached_enemy_health_multiplier)
		print("Enemy health set: ", original_health, " -> ", enemy.health, " (base: ", base_health_for_level, ")")
	
	
	if enemy.has_node("Sprite2D"):
		var sprite = enemy.get_node("Sprite2D")
		sprite.scale *= cached_enemy_size_multiplier
		print("Enemy size enhanced by: ", cached_enemy_size_multiplier)
	elif "sprite" in enemy and enemy.sprite:
		enemy.sprite.scale *= cached_enemy_size_multiplier
		print("Enemy size enhanced by: ", cached_enemy_size_multiplier)
	
	
	if enemy.has_method("set_speed_multiplier"):
		enemy.set_speed_multiplier(cached_enemy_speed_multiplier)
	else:
		enemy.set("speed_multiplier", cached_enemy_speed_multiplier)
	print("Enemy speed multiplier set: ", cached_enemy_speed_multiplier)
	
	
	if enemy.has_method("set_attack_range_multiplier"):
		enemy.set_attack_range_multiplier(1.0 + (current_level - 1) * 0.1)  
	else:
		enemy.set("attack_range_multiplier", 1.0 + (current_level - 1) * 0.1)
	print("Enemy attack range multiplier set: ", 1.0 + (current_level - 1) * 0.1)
	
	
	if current_level >= 3:
		_enhance_enemy_attacks(enemy)
	
	
	_add_level_visual_effects(enemy)
	
	print("=== ENEMY ENHANCEMENT COMPLETE ===")

func _get_base_health_for_level() -> int:
	
	match current_level:
		1:
			return 1  
		2:
			return 2  
		3:
			return 2  
		4:
			return 3  
		5:
			return 3  
		_:
			return 3 + (current_level - 5)  

func _enhance_enemy_attacks(enemy: Node):
	
	var cooldown_multiplier = max(0.6, 1.0 - (current_level - 1) * 0.1)  
	if enemy.has_method("set_attack_cooldown_multiplier"):
		enemy.set_attack_cooldown_multiplier(cooldown_multiplier)
	else:
		enemy.set("attack_cooldown_multiplier", cooldown_multiplier)
	print("Enemy attack cooldown multiplier set: ", cooldown_multiplier)
	
	
	if current_level >= 4:
		var range_multiplier = 1.0 + (current_level - 3) * 0.15  
		if enemy.has_method("set_attack_range_multiplier"):
			enemy.set_attack_range_multiplier(range_multiplier)
		else:
			enemy.set("attack_range_multiplier", range_multiplier)
		print("Enemy attack range multiplier set: ", range_multiplier)

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
	
	print("Added particle effects to level ", current_level, " enemy")

func get_spawn_position() -> Vector2:
	if player == null:
		return global_position
	
	var player_pos = player.global_position
	var spawn_pos = Vector2()
	
	
	var level_adjusted_distance = spawn_distance_from_player * (1.0 - (current_level - 1) * 0.05)  
	level_adjusted_distance = max(250.0, level_adjusted_distance)  
	
	var side = 1 if randf() > 0.5 else -1
	spawn_pos.x = player_pos.x + (level_adjusted_distance * side)
	spawn_pos.y = player_pos.y + spawn_height_offset + randf_range(-50, 50)
	
	return spawn_pos

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
	print("Manual level override set to: ", level)
