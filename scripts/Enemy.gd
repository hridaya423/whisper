extends CharacterBody2D
class_name EnemyFollower

const SPEED = 120.0
const HOVER_SPEED = 80.0
const ATTACK_RANGE = 120.0
const ATTACK_COOLDOWN = 1.5
const DETECTION_RANGE = 250.0
const SOUND_DETECTION_RANGE = 400.0
const HOVER_HEIGHT = 20.0  
const FLOAT_AMPLITUDE = 5.0  
const FLOAT_FREQUENCY = 1.5   
const SPACING_DISTANCE = 40.0  
const SIDE_DISTANCE = 40.0     

var player: Node2D = null
var attack_timer = 0.0
var can_attack = true
var health = 3
var last_sound_position = Vector2.ZERO
var sound_timer = 0.0
var is_hunting_sound = false
var hover_target_y = 0.0
var float_timer = 0.0
var ground_y = 0.0
var preferred_side = 1  
var side_offset = 0.0   


var speed_multiplier: float = 1.0
var attack_cooldown_multiplier: float = 1.0
var attack_range_multiplier: float = 1.0


@export var dark_projectile_scene: PackedScene

@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_audio: AudioStreamPlayer2D = $AttackAudio
@onready var death_audio: AudioStreamPlayer2D = $DeathAudio

func _ready():
	
	add_to_group("enemies")
	
	
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		for child in get_tree().current_scene.get_children():
			if "Player" in child.name:
				player = child
				break
	
	
	var game_manager = get_node("../GameManager")
	if game_manager:
		if game_manager.has_signal("player_sonar_pulse"):
			game_manager.player_sonar_pulse.connect(_on_sonar_detected)
	
	
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(16, 20)
	collision.shape = shape
	add_child(collision)
	
	
	var area = Area2D.new()
	add_child(area)
	var area_collision = CollisionShape2D.new()
	var area_shape = RectangleShape2D.new()
	area_shape.size = Vector2(20, 24)
	area_collision.shape = area_shape
	area.add_child(area_collision)
	area.body_entered.connect(_on_player_touch)
	
	
	find_ground_level()
	
	
	preferred_side = 1 if randf() > 0.5 else -1
	side_offset = randf_range(0, 30)  
	
	z_index = 100
	
	print("Enemy spawned with multipliers - speed:", speed_multiplier, " cooldown:", attack_cooldown_multiplier, " range:", attack_range_multiplier)

func _physics_process(delta):
	float_timer += delta
	
	
	if !can_attack:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true
			
			
	
	
	if sound_timer > 0:
		sound_timer -= delta
	else:
		is_hunting_sound = false
		
	hover_movement(delta)
	
	
	if player != null:
		var distance_to_player = global_position.distance_to(player.global_position)
		
		
		var effective_attack_range = ATTACK_RANGE * attack_range_multiplier
		
		
		print("ENEMY DEBUG - Distance: ", distance_to_player, " | Attack range: ", effective_attack_range, " | Can attack: ", can_attack, " | Detection range: ", DETECTION_RANGE)
		
		
		if distance_to_player <= DETECTION_RANGE or is_hunting_sound:
			hunt_target(delta)
			print("HUNTING TARGET - moving towards player")
			
			
			if distance_to_player <= effective_attack_range and can_attack:
				print("CONDITIONS MET - ATTACKING NOW!")
				shoot_at_player()
			else:
				print("NOT ATTACKING - Distance:", distance_to_player, " > Range:", effective_attack_range, " OR can_attack:", can_attack)
		else:
			print("NOT HUNTING - Distance:", distance_to_player, " > Detection:", DETECTION_RANGE)
	
	move_and_slide()

func find_ground_level():
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2(0, 500)
	)
	query.exclude = [self]
	query.collision_mask = 1
	
	var result = space_state.intersect_ray(query)
	if not result.is_empty():
		ground_y = result.position.y
		hover_target_y = ground_y - HOVER_HEIGHT
	else:
		ground_y = global_position.y + 100
		hover_target_y = ground_y - HOVER_HEIGHT

func hover_movement(delta):
	
	var float_offset = sin(float_timer * FLOAT_FREQUENCY) * FLOAT_AMPLITUDE
	var target_y = hover_target_y + float_offset
	
	
	var effective_hover_speed = HOVER_SPEED * speed_multiplier
	var y_diff = target_y - global_position.y
	velocity.y = y_diff * effective_hover_speed * delta * 10.0
	
	
	velocity.y = clamp(velocity.y, -200.0, 200.0)

func hunt_target(delta):
	var target_position = player.global_position
	if is_hunting_sound and sound_timer > 0:
		target_position = last_sound_position
	
	
	face_player()
	
	
	var distance_to_player = global_position.distance_to(player.global_position)
	var effective_attack_range = ATTACK_RANGE * attack_range_multiplier
	
	
	if distance_to_player <= effective_attack_range:
		print("IN ATTACK RANGE - stopping movement to attack")
		velocity.x = move_toward(velocity.x, 0, SPEED * speed_multiplier)  
		return  
	
	
	var ideal_side_position = calculate_ideal_side_position(target_position)
	
	
	update_hover_target(ideal_side_position)
	
	var distance_to_ideal = global_position.distance_to(ideal_side_position)
	var direction_to_ideal = (ideal_side_position - global_position).normalized()
	
	
	var effective_speed = SPEED * speed_multiplier
	
	
	if distance_to_ideal > 20:  
		velocity.x = direction_to_ideal.x * effective_speed
		print("Moving to side position, distance to ideal:", distance_to_ideal)
	else:
		
		velocity.x = move_toward(velocity.x, 0, effective_speed * 2)
		print("At ideal side position")
	
	
	var avoidance = get_simple_avoidance()
	velocity.x += avoidance.x * 0.3

func face_player():
	if not player or not sprite:
		return
	
	
	var player_direction = player.global_position.x - global_position.x
	
	
	if player_direction > 0:
		sprite.scale.x = abs(sprite.scale.x)  
	else:
		sprite.scale.x = -abs(sprite.scale.x)  

func calculate_ideal_side_position(target_pos: Vector2) -> Vector2:
	
	var base_side_distance = SIDE_DISTANCE + side_offset
	
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	var same_side_enemies = 0
	
	for enemy in enemies:
		if enemy == self or not enemy:
			continue
		
		
		var enemy_relative_x = enemy.global_position.x - target_pos.x
		var my_relative_x = preferred_side * base_side_distance
		
		if sign(enemy_relative_x) == sign(my_relative_x):
			same_side_enemies += 1
	
	
	var adjusted_distance = base_side_distance + (same_side_enemies * 25)
	
	
	return Vector2(
		target_pos.x + (preferred_side * adjusted_distance),
		target_pos.y  
	)

func get_simple_avoidance() -> Vector2:
	var avoidance_force = Vector2.ZERO
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies:
		if enemy == self or not enemy:
			continue
			
		var distance = global_position.distance_to(enemy.global_position)
		if distance < 30 and distance > 0:  
			var push_direction = (global_position - enemy.global_position).normalized()
			avoidance_force += push_direction * 50  
	
	return avoidance_force

func has_line_of_sight_to_player() -> bool:
	if not player:
		return false
		
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		player.global_position
	)
	query.exclude = [self]
	query.collision_mask = 1  
	
	var result = space_state.intersect_ray(query)
	return result.is_empty()  

func update_hover_target(target_pos: Vector2):
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		Vector2(target_pos.x, target_pos.y - 50),
		Vector2(target_pos.x, target_pos.y + 100)
	)
	query.exclude = [self]
	query.collision_mask = 1
	
	var result = space_state.intersect_ray(query)
	if not result.is_empty():
		var new_ground_y = result.position.y
		var new_hover_y = new_ground_y - HOVER_HEIGHT
		
		
		hover_target_y = lerp(hover_target_y, new_hover_y, 0.05)

func shoot_at_player():
	if !can_attack or player == null:
		return
	
	print("=== ENEMY ATTACKING ===")
	
	if !dark_projectile_scene:
		print("ERROR: No dark projectile scene assigned!")
		return
	
	
	face_player()
	
	
	can_attack = false
	attack_timer = ATTACK_COOLDOWN * attack_cooldown_multiplier
	print("Attack cooldown set to:", attack_timer, " (base:", ATTACK_COOLDOWN, " * multiplier:", attack_cooldown_multiplier, ")")
	
	
	var projectile = dark_projectile_scene.instantiate()
	if !projectile:
		print("ERROR: Failed to instantiate projectile!")
		return
	
	
	var parent = get_parent()
	if !parent:
		print("ERROR: No parent to add projectile to!")
		projectile.queue_free()
		return
		
	parent.add_child(projectile)
	
	
	var direction_to_player = (player.global_position - global_position).normalized()
	var spawn_offset = direction_to_player * 35  
	projectile.global_position = global_position + spawn_offset
	
	
	if projectile.has_method("set_direction"):
		projectile.set_direction(direction_to_player)
	elif "direction" in projectile:
		projectile.direction = direction_to_player
	elif projectile.has_method("setup"):
		projectile.setup(direction_to_player)
	else:
		
		if "velocity" in projectile:
			var projectile_speed = 300.0
			projectile.velocity = direction_to_player * projectile_speed
	
	
	if "speed" in projectile:
		projectile.speed = 300.0
	
	
	if "target" in projectile:
		projectile.target = player.global_position
	
	print("Projectile fired towards player")
	play_attack_sound()

func _on_sonar_detected(position: Vector2, range: float, direction: Vector2):
	var distance_to_sound = global_position.distance_to(position)
	
	if distance_to_sound <= SOUND_DETECTION_RANGE:
		last_sound_position = position
		sound_timer = 5.0 
		is_hunting_sound = true
		print("Enemy heard sonar at: ", position)

func _on_player_touch(body):
	if body.name == "Player" and body.has_method("take_damage"):
		body.take_damage()
		print("Enemy touched player - dealing damage!")

func take_damage():
	health -= 1
	print("Enemy took damage, health now: ", health)
	
	
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.RED, 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	
	if health <= 0:
		die()

func die():
	print("Enemy dying!")
	
	
	play_death_sound()
	
	
	set_collision_layer(0)
	set_collision_mask(0)
	
	
	if sprite:
		var tween = create_tween()
		tween.parallel().tween_property(sprite, "scale", Vector2(0.1, 0.1), 1.0)  
		tween.parallel().tween_property(sprite, "modulate", Color(0.2, 0.0, 0.4, 0.0), 1.0)
		tween.parallel().tween_property(self, "position:y", position.y - 50, 0.6)
		
		
		await tween.finished
		await get_tree().create_timer(0.5).timeout  
		queue_free()
	else:
		
		await get_tree().create_timer(2.0).timeout
		queue_free()

func play_attack_sound():
	if attack_audio and attack_audio.stream:
		attack_audio.pitch_scale = randf_range(0.6, 0.9)  
		attack_audio.play()
	else:
		print("No attack audio found or no stream assigned")

func play_death_sound():
	if death_audio and death_audio.stream:
		death_audio.pitch_scale = randf_range(0.7, 1.0)
		death_audio.play()
	else:
		print("No death audio found or no stream assigned")


func set_speed_multiplier(multiplier: float):
	speed_multiplier = multiplier
	print("Enemy speed multiplier set to:", multiplier)

func set_attack_cooldown_multiplier(multiplier: float):
	attack_cooldown_multiplier = multiplier
	print("Enemy attack cooldown multiplier set to:", multiplier)

func set_attack_range_multiplier(multiplier: float):
	attack_range_multiplier = multiplier
	print("Enemy attack range multiplier set to:", multiplier)
