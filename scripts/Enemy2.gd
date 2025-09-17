extends CharacterBody2D
class_name EnemyFollowerGround

const SPEED = 100.0
const ATTACK_RANGE = 80.0
const ATTACK_COOLDOWN = 1.0
const DETECTION_RANGE = 200.0
const SOUND_DETECTION_RANGE = 300.0
const GRAVITY = 980.0
const JUMP_VELOCITY = -300.0

var player: Node2D = null
var attack_timer = 0.0
var can_attack = true
var health = 3
var last_sound_position = Vector2.ZERO
var sound_timer = 0.0
var is_hunting_sound = false

var movement_direction = 1.0
var stuck_timer = 0.0
var last_position = Vector2.ZERO
var jump_cooldown_timer = 0.0
var unreachable_timer = 0.0

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
	if game_manager and game_manager.has_signal("player_sonar_pulse"):
		game_manager.player_sonar_pulse.connect(_on_sonar_detected)
		
	_setup_damage_area()

	z_index = 100
	
	call_deferred("_check_initial_ground")

func _setup_damage_area():
	var area = Area2D.new()
	area.name = "DamageArea"
	add_child(area)

	var area_collision = CollisionShape2D.new()
	var area_shape = RectangleShape2D.new()
	area_shape.size = Vector2(20, 24)
	area_collision.shape = area_shape
	area.add_child(area_collision)

	area.body_entered.connect(_on_player_touch)

func _check_initial_ground():
	var space_state = get_world_2d().direct_space_state
	var from = global_position
	var to = global_position + Vector2(0, 50)

	var query = PhysicsRayQueryParameters2D.create(from, to)
	query.exclude = [self]
	query.collision_mask = 1

	var result = space_state.intersect_ray(query)

func _physics_process(delta):
	if not can_attack:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true

	if sound_timer > 0:
		sound_timer -= delta
	else:
		is_hunting_sound = false

	if jump_cooldown_timer > 0:
		jump_cooldown_timer -= delta

	if unreachable_timer > 0:
		unreachable_timer -= delta

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if player:
		var distance_to_player = global_position.distance_to(player.global_position)
		var effective_attack_range = ATTACK_RANGE * attack_range_multiplier
		
		if distance_to_player <= DETECTION_RANGE or is_hunting_sound:
			_face_target()

			if distance_to_player <= effective_attack_range and can_attack:
				var height_diff = abs(player.global_position.y - global_position.y)
				if height_diff <= 32:
					shoot_at_player()

			_move_toward_target(delta)
		else:
			_patrol(delta)
	else:
		_patrol(delta)

	move_and_slide()

	_check_if_stuck(delta)

func _face_target():
	if not sprite:
		return

	var target_pos = player.global_position
	if is_hunting_sound and sound_timer > 0:
		target_pos = last_sound_position

	var direction = target_pos.x - global_position.x
	if direction > 0:
		sprite.scale.x = abs(sprite.scale.x)
		movement_direction = 1.0
	else:
		sprite.scale.x = -abs(sprite.scale.x)
		movement_direction = -1.0

func _move_toward_target(delta):
	var target_pos = player.global_position
	if is_hunting_sound and sound_timer > 0:
		target_pos = last_sound_position

	var distance_to_target = global_position.distance_to(target_pos)
	var effective_attack_range = ATTACK_RANGE * attack_range_multiplier
	
	if distance_to_target <= effective_attack_range:
		velocity.x = move_toward(velocity.x, 0, SPEED * 3)
		unreachable_timer = 0.0
		return

	var direction = sign(target_pos.x - global_position.x)

	var height_diff = target_pos.y - global_position.y
	var is_target_above = height_diff < -20
	var is_target_below = height_diff > 40
	if (is_target_above or is_target_below) and distance_to_target > effective_attack_range * 1.5:
		unreachable_timer += delta
		if unreachable_timer > 3.0:
			_patrol(delta)
			return

	if _can_move_in_direction(direction):
		velocity.x = direction * SPEED * speed_multiplier
		unreachable_timer = 0.0
	else:
		if is_on_floor() and not is_target_above and not is_target_below and jump_cooldown_timer <= 0 and _should_jump():
			velocity.y = JUMP_VELOCITY
			velocity.x = direction * SPEED * speed_multiplier * 0.7
			jump_cooldown_timer = 1.5
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED * 2)
			unreachable_timer += delta
			if unreachable_timer > 2.0:
				_patrol(delta)
				return

func _patrol(delta):
	var can_move = _can_move_in_direction(movement_direction)
	var edge_ahead = _is_edge_ahead(movement_direction)

	if can_move and not edge_ahead:
		velocity.x = movement_direction * SPEED * speed_multiplier * 0.5
	else:
		movement_direction *= -1
		velocity.x = move_toward(velocity.x, 0, SPEED * 2)
		
		if sprite:
			sprite.scale.x = movement_direction * abs(sprite.scale.x)

func _is_edge_ahead(dir: float) -> bool:
	var space_state = get_world_2d().direct_space_state
	var check_distance = 20

	var from = global_position + Vector2(dir * check_distance, 10) 
	var to = from + Vector2(0, 30)

	var query = PhysicsRayQueryParameters2D.create(from, to)
	query.exclude = [self]
	query.collision_mask = 1

	var result = space_state.intersect_ray(query)
	return result.is_empty()

func _can_move_in_direction(dir: float) -> bool:
	if dir == 0:
		return true

	var space_state = get_world_2d().direct_space_state
	var from = global_position
	var to = global_position + Vector2(dir * 24, 0)

	var query = PhysicsRayQueryParameters2D.create(from, to)
	query.exclude = [self]
	query.collision_mask = 1

	var result = space_state.intersect_ray(query)
	return result.is_empty()

func _should_jump() -> bool:
	var space_state = get_world_2d().direct_space_state
	var check_distance = 25

	var wall_check = PhysicsRayQueryParameters2D.create(
		global_position + Vector2(0, -5),
		global_position + Vector2(movement_direction * check_distance, -5)
	)
	wall_check.exclude = [self]
	wall_check.collision_mask = 1
	var wall_hit = space_state.intersect_ray(wall_check)
	
	if not wall_hit.is_empty():
		var wall_height = global_position.y - wall_hit.position.y
		if wall_height > 0 and wall_height <= 20:
			return true

	return false

func _check_if_stuck(delta):
	stuck_timer += delta

	if stuck_timer >= 1.0:
		var distance_moved = last_position.distance_to(global_position)

		if distance_moved < 5.0:
			if is_on_floor():
				velocity.y = JUMP_VELOCITY * 0.8
			movement_direction *= -1
			if sprite:
				sprite.scale.x = movement_direction * abs(sprite.scale.x)

		last_position = global_position
		stuck_timer = 0.0

func has_line_of_sight_to_player() -> bool:
	if not player:
		return false

	var distance = global_position.distance_to(player.global_position)
	var height_diff = abs(player.global_position.y - global_position.y)
	return distance <= ATTACK_RANGE * attack_range_multiplier and height_diff <= 40

func shoot_at_player():
	if not can_attack or not player or not dark_projectile_scene:
		return


	can_attack = false
	attack_timer = ATTACK_COOLDOWN * attack_cooldown_multiplier

	var projectile = dark_projectile_scene.instantiate()
	if not projectile:
		return

	var parent = get_parent()
	if not parent:
		projectile.queue_free()
		return

	parent.add_child(projectile)
	
	var direction_to_player = (player.global_position - global_position).normalized()
	var spawn_offset = direction_to_player * 20
	projectile.global_position = global_position + spawn_offset

	if projectile.has_method("set_direction"):
		projectile.set_direction(direction_to_player)
	elif "direction" in projectile:
		projectile.direction = direction_to_player
	elif "velocity" in projectile:
		projectile.velocity = direction_to_player * 250.0

	if "speed" in projectile:
		projectile.speed = 250.0

	play_attack_sound()

func _on_sonar_detected(position: Vector2, range: float, direction: Vector2):
	var distance_to_sound = global_position.distance_to(position)
	if distance_to_sound <= SOUND_DETECTION_RANGE:
		last_sound_position = position
		sound_timer = 5.0
		is_hunting_sound = true

func _on_player_touch(body):
	if body.name == "Player" and body.has_method("take_damage"):
		body.take_damage()

func take_damage():
	health -= 1
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.RED, 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	if health <= 0:
		die()

func die():
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

func play_death_sound():
	if death_audio and death_audio.stream:
		death_audio.pitch_scale = randf_range(0.7, 1.0)
		death_audio.play()

func set_speed_multiplier(multiplier: float):
	speed_multiplier = multiplier

func set_attack_cooldown_multiplier(multiplier: float):
	attack_cooldown_multiplier = multiplier

func set_attack_range_multiplier(multiplier: float):
	attack_range_multiplier = multiplier
