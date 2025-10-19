extends Boss
class_name Sentinel

const GROUND_SLAM_RANGE = 200.0
const MINION_SPAWN_DISTANCE = 150.0
const SHIELD_DURATION = 5.0
const PROJECTILE_SPEED = 300.0
const SPIKE_RANGE = 400.0

var shield_active: bool = false
var shield_timer: float = 0.0
var attack_cooldown: float = 0.0
var minion_spawn_cooldown: float = 0.0
var is_attacking: bool = false
var attack_charge_time: float = 0.0
var current_attack_type: String = ""

var ground_slam_particles: CPUParticles2D
var shield_effect: Sprite2D
var minion_scene: PackedScene
var sentinel_idle_texture: Texture2D
var sentinel_pre_attack_texture: Texture2D
var sentinel_attack_texture: Texture2D
var orbiting_stones: Array[Node2D] = []

@onready var slam_area: Area2D = $SlamArea
@onready var slam_collision: CollisionShape2D = $SlamArea/CollisionShape2D
@onready var damage_area: Area2D = $DamageArea

func _ready():
	super._ready()
	boss_name = "THE SENTINEL"
	boss_type = BossType.SENTINEL
	max_health = 40
	current_health = max_health
	movement_speed = 100.0

	_setup_sentinel_components()
	_setup_slam_area()

func _exit_tree():
	for stone in orbiting_stones:
		if is_instance_valid(stone):
			stone.queue_free()
	orbiting_stones.clear()

	for projectile in get_tree().get_nodes_in_group("boss_projectiles"):
		if is_instance_valid(projectile):
			projectile.queue_free()

func _setup_sentinel_components():
	minion_scene = preload("res://scenes/enemy.tscn")

	_load_sentinel_textures()

	ground_slam_particles = CPUParticles2D.new()
	add_child(ground_slam_particles)
	_setup_slam_particles()

	shield_effect = Sprite2D.new()
	add_child(shield_effect)
	_setup_shield_effect()

func _load_sentinel_textures():
	sentinel_idle_texture = load("res://assets/sprites/sentinelidle.png")
	sentinel_pre_attack_texture = load("res://assets/sprites/sentineltoattack.png")
	sentinel_attack_texture = load("res://assets/sprites/sentinelattack.png")

	if sprite and sentinel_idle_texture:
		sprite.texture = sentinel_idle_texture

func _setup_slam_particles():
	ground_slam_particles.emitting = false
	ground_slam_particles.amount = 50
	ground_slam_particles.lifetime = 1.5
	ground_slam_particles.direction = Vector2(0, -1)
	ground_slam_particles.spread = 45.0
	ground_slam_particles.initial_velocity_min = 100.0
	ground_slam_particles.initial_velocity_max = 200.0
	ground_slam_particles.scale_amount_min = 0.5
	ground_slam_particles.scale_amount_max = 1.5
	ground_slam_particles.color = Color(0.6, 0.4, 0.2, 0.8)

func _setup_shield_effect():
	shield_effect.modulate = Color(0.5, 0.5, 1.0, 0.3)
	shield_effect.scale = Vector2(2.0, 2.0)
	shield_effect.visible = false

func _setup_slam_area():
	if slam_area and slam_collision:
		slam_area.body_entered.connect(_on_slam_area_entered)
		slam_area.monitoring = false 
		if slam_collision and slam_collision.shape is CircleShape2D:
			slam_collision.shape.radius = GROUND_SLAM_RANGE
			slam_collision.disabled = true


func _on_contact_damage(body):
	if body is Player and not is_in_cinematic:
		body.take_damage()

func _update_boss_behavior(delta):
	if is_defeated:
		return

	_update_timers(delta)
	_update_shield(delta)
	_update_orbiting_stones(delta)

	if is_attacking:
		_update_attack_charge(delta)
		return

	var distance_to_player = get_distance_to_player()

	match current_phase:
		BossPhase.PHASE_1:
			_phase_1_behavior(distance_to_player)
		BossPhase.PHASE_2:
			_phase_2_behavior(distance_to_player)
		BossPhase.PHASE_3:
			_phase_3_behavior(distance_to_player)
		BossPhase.PHASE_4:
			_phase_4_behavior(distance_to_player)

func _update_timers(delta):
	attack_cooldown -= delta
	minion_spawn_cooldown -= delta

	attack_cooldown = max(0.0, attack_cooldown)
	minion_spawn_cooldown = max(0.0, minion_spawn_cooldown)

func _update_shield(delta):
	if shield_active:
		shield_timer -= delta
		if shield_timer <= 0:
			_deactivate_shield()

func _update_attack_charge(delta):
	attack_charge_time += delta

	const CHARGE_TIME = 0.5
	var charge_intensity = attack_charge_time / CHARGE_TIME

	modulate = Color(1.0 + charge_intensity * 0.5, 1.0 - charge_intensity * 0.5, 1.0 - charge_intensity * 0.5)

	var pulse = sin(attack_charge_time * 20.0) * 0.2 + 1.0
	scale = Vector2(pulse, pulse) * Vector2(1.0, 1.0)

	if attack_charge_time >= CHARGE_TIME:
		scale = Vector2(1.0, 1.0)
		match current_attack_type:
			"stone_projectile":
				_execute_stone_projectile()
			"ground_slam":
				_execute_ground_slam()
			"spike_line":
				_execute_spike_line()
			"stone_orbit":
				_execute_stone_orbit()

func _phase_1_behavior(distance: float):
	if attack_cooldown <= 0:
		if distance > 250:
			_start_attack("stone_projectile", 1.5)
		elif distance <= GROUND_SLAM_RANGE:
			_start_attack("ground_slam", 1.8)
		else:
			_start_attack("stone_projectile", 1.5)
	elif minion_spawn_cooldown <= 0:
		_spawn_minions(1)
		minion_spawn_cooldown = 15.0
	else:
		_move_toward_player()

func _phase_2_behavior(distance: float):
	if attack_cooldown <= 0:
		var attack_choice = randf()
		if attack_choice < 0.4:
			_start_attack("stone_projectile", 1.2)
		elif attack_choice < 0.7:
			_start_attack("spike_line", 1.4)
		else:
			_start_attack("ground_slam", 1.6)
	elif minion_spawn_cooldown <= 0:
		_spawn_minions(2)
		minion_spawn_cooldown = 12.0
	elif not shield_active and randf() < 0.015:
		_activate_shield()
	else:
		_move_toward_player()

func _phase_3_behavior(distance: float):
	if attack_cooldown <= 0:
		var attack_choice = randf()
		if attack_choice < 0.35:
			_start_attack("stone_orbit", 1.2)
		elif attack_choice < 0.65:
			_start_attack("spike_line", 0.9)
		else:
			_start_attack("stone_projectile", 0.8)
	elif minion_spawn_cooldown <= 0:
		_spawn_minions(2)
		minion_spawn_cooldown = 10.0
	else:
		_move_toward_player()

func _phase_4_behavior(distance: float):
	if attack_cooldown <= 0:
		var attack_choice = randf()
		if attack_choice < 0.3:
			_start_attack("ground_slam", 0.7)
		elif attack_choice < 0.65:
			_start_attack("spike_line", 0.5)
		else:
			_start_attack("stone_projectile", 0.5)
	if minion_spawn_cooldown <= 0:
		_spawn_minions(3)
		minion_spawn_cooldown = 8.0
	if not is_attacking:
		_move_toward_player()

func _move_toward_player():
	if player and not is_attacking:
		var direction = get_direction_to_player()
		velocity = direction * movement_speed

		if abs(direction.x) > 0.1:
			sprite.flip_h = direction.x < 0

		if sprite.texture != sentinel_idle_texture:
			sprite.texture = sentinel_idle_texture

func _start_attack(attack_type: String, cooldown: float):
	is_attacking = true
	attack_charge_time = 0.0
	current_attack_type = attack_type
	attack_cooldown = cooldown
	velocity = Vector2.ZERO
	sprite.texture = sentinel_pre_attack_texture
	boss_attack_started.emit(self, attack_type)

	_create_attack_telegraph(attack_type)

func _execute_stone_projectile():
	is_attacking = false
	attack_charge_time = 0.0
	modulate = Color.WHITE
	sprite.texture = sentinel_attack_texture

	var direction_to_player = get_direction_to_player()
	var angles = [-0.3, 0.0, 0.3] if current_phase >= BossPhase.PHASE_3 else [0.0]

	for angle_offset in angles:
		_fire_stone_projectile(direction_to_player.rotated(angle_offset))

	await get_tree().create_timer(0.4).timeout
	if not is_instance_valid(self):
		return
	if sprite:
		sprite.texture = sentinel_idle_texture

func _fire_stone_projectile(direction: Vector2):
	var projectile = Area2D.new()
	projectile.add_to_group("boss_projectiles")
	get_parent().add_child(projectile)
	projectile.global_position = global_position + direction * 40

	var stone_sprite = Sprite2D.new()
	projectile.add_child(stone_sprite)
	var stone_texture = _create_stone_texture()
	stone_sprite.texture = stone_texture

	var collision = CollisionShape2D.new()
	collision.shape = CircleShape2D.new()
	collision.shape.radius = 12
	projectile.add_child(collision)

	var trail = CPUParticles2D.new()
	projectile.add_child(trail)
	trail.emitting = true
	trail.amount = 10
	trail.lifetime = 0.5
	trail.color = Color(0.6, 0.4, 0.2, 0.7)
	trail.direction = -direction
	trail.spread = 30
	trail.initial_velocity_min = 20
	trail.initial_velocity_max = 40

	projectile.set_script(preload("res://scripts/bosses/BossProjectile.gd"))
	projectile.direction = direction
	projectile.speed = PROJECTILE_SPEED
	projectile.damage = 1

func _execute_ground_slam():
	is_attacking = false
	attack_charge_time = 0.0
	modulate = Color.WHITE

	sprite.texture = sentinel_attack_texture

	ground_slam_particles.global_position = global_position
	ground_slam_particles.emitting = true
	ground_slam_particles.restart()

	var camera = get_tree().get_first_node_in_group("camera")
	if camera:
		_create_slam_camera_shake(camera)

	if slam_area and slam_collision:
		slam_area.monitoring = true
		slam_collision.disabled = false

	await get_tree().create_timer(0.3).timeout

	if slam_area and slam_collision:
		slam_area.monitoring = false
		slam_collision.disabled = true

	await get_tree().create_timer(0.2).timeout
	if not is_instance_valid(self):
		return
	if sprite:
		sprite.texture = sentinel_idle_texture

func _execute_spike_line():
	is_attacking = false
	attack_charge_time = 0.0
	modulate = Color.WHITE
	sprite.texture = sentinel_attack_texture

	var direction_to_player = get_direction_to_player()
	var num_spikes = 8
	var spike_spacing = 50.0

	for i in range(num_spikes):
		var spike_pos = global_position + direction_to_player * spike_spacing * (i + 1)
		_create_ground_spike(spike_pos, i * 0.1)

	await get_tree().create_timer(0.4).timeout
	if not is_instance_valid(self):
		return
	if sprite:
		sprite.texture = sentinel_idle_texture

func _create_ground_spike(pos: Vector2, delay: float):
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(self):
		return

	var spike = Area2D.new()
	spike.add_to_group("boss_projectiles")
	get_parent().add_child(spike)
	spike.global_position = pos

	var spike_sprite = Sprite2D.new()
	spike.add_child(spike_sprite)
	spike_sprite.texture = _create_spike_texture()
	spike_sprite.modulate = Color(0.6, 0.4, 0.2)

	var collision = CollisionShape2D.new()
	collision.shape = CircleShape2D.new()
	collision.shape.radius = 20
	spike.add_child(collision)

	spike_sprite.scale = Vector2(0.1, 0.1)
	var appear_tween = spike.create_tween()
	appear_tween.tween_property(spike_sprite, "scale", Vector2(1.0, 1.5), 0.2)

	spike.body_entered.connect(func(body):
		if body is Player:
			body.take_damage()
	)

	await get_tree().create_timer(1.5).timeout
	if not is_instance_valid(self):
		if is_instance_valid(spike):
			spike.queue_free()
		return
	if is_instance_valid(spike):
		var fade_tween = spike.create_tween()
		fade_tween.tween_property(spike_sprite, "modulate:a", 0.0, 0.3)
		fade_tween.tween_callback(func(): spike.queue_free())

func _execute_stone_orbit():
	is_attacking = false
	attack_charge_time = 0.0
	modulate = Color.WHITE

	for stone in orbiting_stones:
		if is_instance_valid(stone):
			stone.queue_free()
	orbiting_stones.clear()

	var num_stones = 4
	for i in range(num_stones):
		var stone = Node2D.new()
		add_child(stone)
		orbiting_stones.append(stone)

		var sprite_node = Sprite2D.new()
		stone.add_child(sprite_node)
		sprite_node.texture = _create_stone_texture()
		sprite_node.scale = Vector2(0.8, 0.8)

		var area = Area2D.new()
		stone.add_child(area)
		var collision = CollisionShape2D.new()
		collision.shape = CircleShape2D.new()
		collision.shape.radius = 10
		area.add_child(collision)
		area.add_to_group("boss_projectiles")

		area.body_entered.connect(func(body):
			if body is Player:
				body.take_damage()
		)

		stone.set_meta("orbit_offset", (TAU / num_stones) * i)
		stone.set_meta("orbit_radius", 80.0)
		stone.set_meta("creation_time", Time.get_ticks_msec() / 1000.0)

	await get_tree().create_timer(0.3).timeout
	if not is_instance_valid(self):
		return
	if sprite:
		sprite.texture = sentinel_idle_texture

func _update_orbiting_stones(delta: float):
	var current_time = Time.get_ticks_msec() / 1000.0

	for stone in orbiting_stones:
		if not is_instance_valid(stone):
			continue

		var offset = stone.get_meta("orbit_offset", 0.0)
		var radius = stone.get_meta("orbit_radius", 80.0)
		var creation_time = stone.get_meta("creation_time", current_time)

		var elapsed = current_time - creation_time
		var expanded_radius = radius + (elapsed * 30.0)

		var angle = offset + (current_time * 3.0)
		stone.position = Vector2(cos(angle), sin(angle)) * expanded_radius

		if expanded_radius > 200 or elapsed > 6.0:
			var sprite_node = stone.get_child(0)
			if sprite_node:
				var fade_tween = create_tween()
				fade_tween.tween_property(sprite_node, "modulate:a", 0.0, 0.3)
				fade_tween.tween_callback(func(): stone.queue_free())
			else:
				stone.queue_free()
			orbiting_stones.erase(stone)

func _on_slam_area_entered(body):
	if body is Player:
		body.take_damage()

func _create_slam_camera_shake(camera: Camera2D):
	_apply_camera_trauma(camera, 0.8) 

	_create_screen_flash(Color(1.0, 0.8, 0.6, 0.3))

func _apply_camera_trauma(camera: Camera2D, trauma_amount: float):
	var shake_duration = 0.5
	var shake_frequency = 30.0
	var max_angle = 0.1 * trauma_amount

	for i in range(int(shake_duration * shake_frequency)):
		var shake_tween = create_tween()
		var angle = randf_range(-max_angle, max_angle) * (1.0 - float(i) / (shake_duration * shake_frequency))
		shake_tween.tween_property(camera, "rotation", angle, 1.0 / shake_frequency)
		await get_tree().create_timer(1.0 / shake_frequency).timeout
		if not is_instance_valid(self):
			return

	var reset_tween = create_tween()
	reset_tween.tween_property(camera, "rotation", 0.0, 0.1)

func _create_screen_flash(color: Color):
	var flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = color
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var canvas = CanvasLayer.new()
	canvas.layer = 100
	get_tree().root.add_child(canvas)
	canvas.add_child(flash)

	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	flash_tween.tween_callback(func():
		canvas.queue_free()
	)

func _activate_shield():
	shield_active = true
	shield_timer = SHIELD_DURATION
	shield_effect.visible = true
	is_vulnerable = false

	var shield_tween = create_tween()
	shield_tween.set_loops()
	shield_tween.tween_property(shield_effect, "modulate:a", 0.6, 0.5)
	shield_tween.tween_property(shield_effect, "modulate:a", 0.2, 0.5)

func _deactivate_shield():
	shield_active = false
	shield_effect.visible = false
	is_vulnerable = true

func _spawn_minions(count: int):
	for i in range(count):
		_spawn_single_minion()

func _spawn_single_minion():
	if not minion_scene:
		return

	var minion = minion_scene.instantiate()
	get_parent().add_child(minion)

	var spawn_angle = randf() * TAU
	var spawn_offset = Vector2(cos(spawn_angle), sin(spawn_angle)) * MINION_SPAWN_DISTANCE
	minion.global_position = global_position + spawn_offset

func _on_phase_changed(new_phase: BossPhase):
	match new_phase:
		BossPhase.PHASE_2:
			movement_speed = 120.0
		BossPhase.PHASE_3:
			movement_speed = 80.0
			_deactivate_shield()
		BossPhase.PHASE_4:
			movement_speed = 150.0

func take_damage(amount: int, hit_position: Vector2 = Vector2.INF, config: Dictionary = {}):
	if shield_active:
		amount = int(amount * 0.5)

	super.take_damage(amount, hit_position, config)

func get_boss_dialogue() -> Array[String]:
	return [
		"For eons I have guarded this realm...",
		"None shall pass while i still stand."
	]

func get_dialogue_audio_path() -> String:
	return "res://assets/dialogue/sentinelentry.mp3"

func _create_stone_texture() -> ImageTexture:
	var size = 24
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size/2, size/2)

	for x in range(size):
		for y in range(size):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			if dist < size/2:
				var brightness = 0.3 + randf() * 0.3
				image.set_pixel(x, y, Color(brightness, brightness * 0.7, brightness * 0.5, 1.0))

	return ImageTexture.create_from_image(image)

func _create_spike_texture() -> ImageTexture:
	var image = Image.create(32, 48, false, Image.FORMAT_RGBA8)

	for x in range(32):
		for y in range(48):
			var normalized_x = float(x - 16) / 16.0
			var normalized_y = float(y) / 48.0

			if abs(normalized_x) < (1.0 - normalized_y):
				var brightness = 0.4 + randf() * 0.2
				image.set_pixel(x, y, Color(brightness, brightness * 0.7, brightness * 0.5, 1.0))

	return ImageTexture.create_from_image(image)

func _create_attack_telegraph(attack_type: String):
	match attack_type:
		"ground_slam":
			_telegraph_ground_slam()
		"spike_line":
			_telegraph_spike_line()
		"stone_projectile":
			_telegraph_stone_projectile()

func _telegraph_ground_slam():
	var warning_circle = Node2D.new()
	add_child(warning_circle)

	for i in range(64):
		var angle = (TAU / 64) * i
		var pos1 = Vector2(cos(angle), sin(angle)) * GROUND_SLAM_RANGE
		var pos2 = Vector2(cos(angle + TAU/64), sin(angle + TAU/64)) * GROUND_SLAM_RANGE

		var line = Line2D.new()
		line.add_point(pos1)
		line.add_point(pos2)
		line.width = 3
		line.default_color = Color(1.0, 0.3, 0.3, 0.0)
		warning_circle.add_child(line)

	var fade_tween = create_tween()
	for child in warning_circle.get_children():
		fade_tween.parallel().tween_property(child, "default_color:a", 0.8, 0.4)

	await get_tree().create_timer(0.6).timeout
	if not is_instance_valid(self):
		if is_instance_valid(warning_circle):
			warning_circle.queue_free()
		return
	if is_instance_valid(warning_circle):
		warning_circle.queue_free()

func _telegraph_spike_line():
	var direction_to_player = get_direction_to_player()
	var num_spikes = 8
	var spike_spacing = 50.0

	for i in range(num_spikes):
		var spike_pos = global_position + direction_to_player * spike_spacing * (i + 1)
		_create_danger_marker(spike_pos, 0.05 * i)

func _telegraph_stone_projectile():
	var direction = get_direction_to_player()
	var warning_line = Line2D.new()
	get_parent().add_child(warning_line)

	warning_line.add_point(global_position)
	warning_line.add_point(global_position + direction * 600)
	warning_line.width = 2
	warning_line.default_color = Color(1.0, 0.5, 0.3, 0.0)
	warning_line.z_index = 50

	var fade_tween = create_tween()
	fade_tween.tween_property(warning_line, "default_color:a", 0.6, 0.3)
	fade_tween.tween_property(warning_line, "default_color:a", 0.0, 0.2)
	fade_tween.tween_callback(func(): warning_line.queue_free())

func _create_danger_marker(pos: Vector2, delay: float):
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(self):
		return

	var marker = Node2D.new()
	get_parent().add_child(marker)
	marker.global_position = pos

	var circle_points = PackedVector2Array()
	for i in range(32):
		var angle = (TAU / 32) * i
		circle_points.append(Vector2(cos(angle), sin(angle)) * 20)
	circle_points.append(circle_points[0])

	var circle = Line2D.new()
	circle.points = circle_points
	circle.width = 2
	circle.default_color = Color(1.0, 0.2, 0.2, 0.0)
	marker.add_child(circle)

	var pulse_tween = create_tween()
	pulse_tween.set_loops(3)
	pulse_tween.tween_property(circle, "default_color:a", 0.8, 0.15)
	pulse_tween.tween_property(circle, "default_color:a", 0.3, 0.15)

	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(self):
		if is_instance_valid(marker):
			marker.queue_free()
		return
	if is_instance_valid(marker):
		marker.queue_free()
