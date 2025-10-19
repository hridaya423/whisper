extends CharacterBody2D
class_name EnemyFollower

const DAMAGE_NUMBER_SCENE := preload("res://scripts/ui/DamageNumber.gd")
static var _kill_hit_stop_active: bool = false
static var _previous_time_scale: float = 1.0
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
const DARK_PROJECTILE_SPEED = 300.0
const CHASE_OFFSET_SAMPLES = [
	Vector2(0, -120),
	Vector2(0, 120),
	Vector2(90, -60),
	Vector2(-90, -60),
	Vector2(140, 0),
	Vector2(-140, 0)
]
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
var stuck_timer: float = 0.0
var lost_sight_timer: float = 0.0
var last_position: Vector2 = Vector2.INF
var speed_multiplier: float = 1.0
signal enemy_died
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
	var game_manager = get_node_or_null("../GameManager")
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
	_update_stuck_state(delta)
	if not player:
		move_and_slide()
		return
	var distance_to_player = global_position.distance_to(player.global_position)
	var effective_attack_range = ATTACK_RANGE * attack_range_multiplier
	if has_line_of_sight_to_player():
		lost_sight_timer = 0.0
	else:
		lost_sight_timer += delta
	if distance_to_player <= DETECTION_RANGE or is_hunting_sound:
		hunt_target(delta)
		if distance_to_player <= effective_attack_range and can_attack and _has_clear_path_to(player.global_position):
			shoot_at_player()
	elif lost_sight_timer > 1.5:
		preferred_side *= -1
		lost_sight_timer = 0.75
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
func _update_stuck_state(delta):
	if last_position != Vector2.INF:
		var travelled = global_position.distance_to(last_position)
		if travelled < 2.0:
			stuck_timer += delta
		else:
			stuck_timer = 0.0
	else:
		stuck_timer = 0.0
	last_position = global_position
	if stuck_timer > 0.8:
		_attempt_escape_from_stuck()
func _attempt_escape_from_stuck():
	stuck_timer = 0.0
	preferred_side *= -1
	hover_target_y = global_position.y - HOVER_HEIGHT
	velocity = Vector2(randf_range(-60.0, 60.0), -HOVER_SPEED)
func hunt_target(delta):
	if not player:
		return
	var chase_target = _choose_chase_target()
	face_player(chase_target)
	var effective_attack_range = ATTACK_RANGE * attack_range_multiplier
	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player <= effective_attack_range * 0.85 and _has_clear_path_to(player.global_position):
		velocity.x = move_toward(velocity.x, 0, SPEED * speed_multiplier)
		return
	var approach_point = calculate_ideal_side_position(chase_target)
	update_hover_target(approach_point)
	var direction_to_approach = approach_point - global_position
	var effective_speed = SPEED * speed_multiplier
	if direction_to_approach.length() > 15.0:
		velocity.x = direction_to_approach.normalized().x * effective_speed
	else:
		velocity.x = move_toward(velocity.x, 0, effective_speed * 2)
	var avoidance = get_simple_avoidance()
	if avoidance.x != 0:
		velocity.x += avoidance.x * 0.3
func face_player(target_position: Variant = null):
	if not sprite:
		return
	var reference: Vector2
	if target_position == null:
		reference = player.global_position if player else global_position
	else:
		reference = target_position
	var player_direction = reference.x - global_position.x
	if player_direction > 0:
		sprite.scale.x = abs(sprite.scale.x)
	else:
		sprite.scale.x = -abs(sprite.scale.x)
func _choose_chase_target() -> Vector2:
	var base_target = player.global_position if player else global_position
	if is_hunting_sound and sound_timer > 0:
		base_target = last_sound_position
	if _has_clear_path_to(base_target):
		return base_target
	for offset in CHASE_OFFSET_SAMPLES:
		var candidate = base_target + Vector2(offset.x * preferred_side, offset.y)
		if _has_clear_path_to(candidate):
			return candidate
	return base_target
func _has_clear_path_to(target_position: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, target_position)
	var exclude: Array = [self]
	if player:
		exclude.append(player)
	query.exclude = exclude
	query.collision_mask = 1
	var result = space_state.intersect_ray(query)
	return result.is_empty()
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
	return _has_clear_path_to(player.global_position)
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
func _predict_player_position(projectile_speed: float) -> Vector2:
	if not player:
		return global_position
	var target_position = player.global_position
	if player is CharacterBody2D:
		var player_velocity: Vector2 = (player as CharacterBody2D).velocity
		var distance = global_position.distance_to(target_position)
		var travel_time = distance / max(projectile_speed, 1.0)
		target_position += player_velocity * travel_time * 0.75
	return target_position
func shoot_at_player():
	if !can_attack or player == null:
		return
	if !dark_projectile_scene:
		return
	face_player(player.global_position)
	can_attack = false
	attack_timer = ATTACK_COOLDOWN * attack_cooldown_multiplier
	var projectile = dark_projectile_scene.instantiate()
	if !projectile:
		return
	var parent = get_parent()
	if !parent:
		projectile.queue_free()
		return
	parent.add_child(projectile)
	var aim_target = _predict_player_position(DARK_PROJECTILE_SPEED)
	var direction_to_player = aim_target - global_position
	if direction_to_player.length_squared() == 0:
		direction_to_player = Vector2.RIGHT if preferred_side >= 0 else Vector2.LEFT
	else:
		direction_to_player = direction_to_player.normalized()
	var spawn_offset = direction_to_player * 35
	projectile.global_position = global_position + spawn_offset
	if projectile.has_method("set_direction"):
		projectile.set_direction(direction_to_player)
	elif "direction" in projectile:
		projectile.direction = direction_to_player
	elif projectile.has_method("setup"):
		projectile.setup(direction_to_player)
	elif "velocity" in projectile:
		projectile.velocity = direction_to_player * DARK_PROJECTILE_SPEED
	if "speed" in projectile:
		projectile.speed = DARK_PROJECTILE_SPEED
	if "target" in projectile:
		projectile.target = aim_target
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
func take_damage(amount: int = 1, hit_position: Vector2 = Vector2.INF, config: Dictionary = {}):
	amount = int(amount)
	if amount <= 0:
		return

	if hit_position == Vector2.INF:
		hit_position = global_position

	health -= amount
	print("Enemy took damage:", amount, "remaining health:", health)
	_spawn_damage_number(amount, hit_position, config)
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.RED, 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	if health <= 0:
		die(hit_position, config)

func _spawn_damage_number(amount: float, hit_position: Vector2, config: Dictionary):
	if DAMAGE_NUMBER_SCENE == null:
		return

	var scene_root = get_tree().current_scene
	if scene_root == null:
		return

	var damage_number: DamageNumber = DAMAGE_NUMBER_SCENE.new()
	damage_number.z_index = 900
	scene_root.add_child(damage_number)

	var options := config.duplicate(true) if config and config is Dictionary else {}
	if not options.has("is_boss"):
		options["is_boss"] = false

	damage_number.show_damage(amount, hit_position, options)
func die(hit_position: Vector2 = Vector2.INF, kill_config: Dictionary = {}):
	var world_position := hit_position if hit_position != Vector2.INF else global_position
	var is_player_kill: bool = bool(kill_config.get("is_player_attack", false))

	if is_player_kill:
		await _trigger_player_kill_feedback(world_position, kill_config)

	print("Enemy dying!")
	enemy_died.emit()
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
		if not is_instance_valid(self):
			return
		queue_free()
	else:
		await get_tree().create_timer(2.0).timeout
		if not is_instance_valid(self):
			return
		queue_free()

func _trigger_player_kill_feedback(world_position: Vector2, kill_config: Dictionary):
	await _apply_kill_hit_stop()
	_spawn_kill_burst_particles(world_position, kill_config)
	_trigger_kill_screen_flash(kill_config)

func _apply_kill_hit_stop(duration: float = 0.08, freeze_scale: float = 0.05):
	if _kill_hit_stop_active:
		return

	_kill_hit_stop_active = true
	_previous_time_scale = Engine.time_scale
	Engine.time_scale = min(freeze_scale, Engine.time_scale)

	await get_tree().create_timer(duration, true, true, true).timeout
	if not is_instance_valid(self):
		return

	if Engine.time_scale <= freeze_scale + 0.001:
		Engine.time_scale = _previous_time_scale

	_kill_hit_stop_active = false

func _spawn_kill_burst_particles(world_position: Vector2, kill_config: Dictionary):
	var scene_root = get_tree().current_scene
	if scene_root == null:
		return

	var burst = CPUParticles2D.new()
	scene_root.add_child(burst)
	burst.global_position = world_position
	burst.z_index = 950
	burst.one_shot = true
	burst.emitting = false
	burst.amount = 45
	burst.lifetime = 0.6
	burst.explosiveness = 1.0
	burst.direction = Vector2(0, -1)
	burst.spread = 280.0
	burst.initial_velocity_min = 180.0
	burst.initial_velocity_max = 320.0
	burst.scale_amount_min = 0.6
	burst.scale_amount_max = 1.4
	burst.color = Color(1.0, 0.75, 0.3, 0.9)
	burst.gravity = Vector2(0, 400)
	burst.emitting = true

	await get_tree().create_timer(burst.lifetime + 0.2).timeout
	if is_instance_valid(burst):
		burst.queue_free()

func _trigger_kill_screen_flash(kill_config: Dictionary):
	var flash_color: Color = Color(1.0, 0.95, 0.7, 0.35)

	var canvas := CanvasLayer.new()
	canvas.layer = 120
	get_tree().root.add_child(canvas)

	var flash := ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = flash_color
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(flash)

	var flash_tween := create_tween()
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.2)
	flash_tween.tween_callback(func():
		canvas.queue_free()
	)
func play_attack_sound():
	if attack_audio and is_instance_valid(attack_audio) and attack_audio.stream:
		attack_audio.pitch_scale = randf_range(0.6, 0.9)
		attack_audio.play()
	else:
		print("No attack audio found or no stream assigned")
func play_death_sound():
	if death_audio and is_instance_valid(death_audio) and death_audio.stream:
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
