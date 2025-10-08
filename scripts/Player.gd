extends CharacterBody2D
class_name Player
const SPEED = 200.0
const JUMP_VELOCITY = -400.0
const SONAR_COOLDOWN = 2.0
const SONAR_RANGE = 150.0
const MIN_LANDING_VELOCITY = 150.0
const ATTACK_COOLDOWN = 0.5
const DASH_SPEED = 600.0
const DASH_DURATION = 0.2
const DASH_COOLDOWN = 4.5
var MAX_HEALTH = 10
var sonar_timer = 0.0
var sonar_cooldown_duration = SONAR_COOLDOWN
var attack_timer = 0.0
var dash_timer = 0.0
var can_sonar = true
var can_attack = true
var can_dash = true
var is_dashing = false
var dash_direction = Vector2.ZERO
var jump_count = 0
var max_jumps = 2
var has_double_jump = true
var crystal_power_active = false
var crystal_power_timer = 0.0
var crystal_sonar_duration_boost = 1.0
var crystal_jump_boost = 1.0
var crystal_dash_boost = 1.0
var power_up_particles_left: CPUParticles2D
var power_up_particles_right: CPUParticles2D
var lightning_particles: CPUParticles2D
var lightning_shader_sprites: Array[Sprite2D] = []
var lightning_animation_timer = 0.0
var spark_appear_intervals: Array[float] = []
var is_charging_attack = false
var charge_time = 0.0
var max_charge_time = 2.0
var min_charge_time = 0.3
var charge_particles: CPUParticles2D
var charge_indicator: Sprite2D
var e_key_was_pressed = false
var health = MAX_HEALTH
var invulnerable = false
var invulnerable_timer = 0.0
var invulnerable_duration = 1.5
var facing_direction = Vector2.RIGHT
var sonar_direction = Vector2.RIGHT
var is_aiming_mode = false
var was_aiming_last_frame = false
var stored_aim_direction = Vector2.RIGHT
var mouse_aim_active: bool = false
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var death_plane_y = 1000
var footstep_timer = 0.0
var base_footstep_interval = 0.4
var was_on_floor = false
var last_velocity_y = 0.0

var animation_frame_counter = 0
var is_walk_step_frame = false
var player_base_texture: Texture2D
var player_step_texture: Texture2D
var player_jump_texture: Texture2D
var health_ui_layer: CanvasLayer
var health_bar_background: ColorRect
var health_bar_fill: ColorRect
var health_label: Label
var rune_ui_container: Control
var rune_slots: Array[TextureRect] = []
var rune_labels: Array[Label] = []
var rune_timers: Array[Label] = []
var sonar_indicator: TextureRect
var medkit_system: Node
var reward_system: Node
var quest_system: Node
var damage_camera_zoom_active: bool = false
var original_camera_zoom: float = 1.0
var camera_breathing_tween: Tween
var critical_health_shake_tween: Tween
var breathing_camera: Camera2D
var shake_camera: Camera2D
var dash_trail_particles: CPUParticles2D
var footstep_particles: CPUParticles2D
var jump_buffer_timer: float = 0.0
var attack_buffer_timer: float = 0.0
var dash_buffer_timer: float = 0.0
const JUMP_BUFFER_TIME: float = 0.1
const ATTACK_BUFFER_TIME: float = 0.2
const DASH_BUFFER_TIME: float = 0.15
var environment_speed_modifiers: Dictionary[int, float] = {}
var environment_speed_multiplier: float = 1.0
@export var light_projectile_scene: PackedScene
@export var corruption_start_time: float = 20.0
@export var corruption_tick_interval: float = 1.0
@export var idle_speed_threshold: float = 6.0
@export var corruption_reset_on_move: bool = true
@export var corruption_color: Color = Color(0.18, 0.00, 0.30)
@export var corruption_color_b: Color = Color(0.30, 0.02, 0.02)
@export var corruption_pulse: bool = true
@export var corruption_pulse_speed: float = 0.6
var corruption_timer: float = 0.0
var corruption_active: bool = false
var corruption_tick_timer: float = 0.0
var corruption_damage: int = 1
var corruption_tween: Tween
@onready var footstep_audio: AudioStreamPlayer2D = $FootstepAudio
@onready var landing_audio: AudioStreamPlayer2D = $LandingAudio
@onready var sonar_audio: AudioStreamPlayer2D = $SonarAudio
@onready var attack_audio: AudioStreamPlayer2D = $AttackAudio
@onready var sprite: Sprite2D = $Sprite2D
signal sonar_pulse_emitted(position: Vector2, range: float, direction: Vector2)
signal player_died
func _ready():
	z_index = 101
	add_to_group("player")
	_load_animation_textures()
	var game_manager = get_node_or_null("../GameManager")
	if game_manager and game_manager.has_method("_on_player_sonar_pulse"):
		sonar_pulse_emitted.connect(Callable(game_manager, "_on_player_sonar_pulse"))
	var rune_system = get_node("../RuneSystem")
	if rune_system:
		rune_system.rune_activated.connect(_on_rune_changed)
		rune_system.rune_deactivated.connect(_on_rune_changed)
		rune_system.rune_inventory_updated.connect(_update_rune_ui)
	_setup_quest_systems()
	_setup_health_ui()
	_setup_sonar_indicator()
	_update_health_ui()
	_update_rune_ui()
func _setup_health_ui():
	health_ui_layer = CanvasLayer.new()
	health_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(health_ui_layer)
	var health_container = Control.new()
	health_container.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	health_container.position = Vector2(20, -60)
	health_container.size = Vector2(200, 40)
	health_ui_layer.add_child(health_container)
	var outer_border = ColorRect.new()
	outer_border.position = Vector2(-4, -2)
	outer_border.size = Vector2(168, 28)
	outer_border.color = Color(0.15, 0.0, 0.0, 0.9)
	health_container.add_child(outer_border)
	health_bar_background = ColorRect.new()
	health_bar_background.position = Vector2(0, 0)
	health_bar_background.size = Vector2(160, 24)
	health_bar_background.color = Color(0.08, 0.0, 0.0, 0.95)
	health_container.add_child(health_bar_background)
	health_bar_fill = ColorRect.new()
	health_bar_fill.position = Vector2(2, 2)
	health_bar_fill.size = Vector2(156, 20)
	health_bar_fill.color = Color(0.6, 0.05, 0.05)
	health_container.add_child(health_bar_fill)
	rune_ui_container = Control.new()
	rune_ui_container.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	rune_ui_container.position = Vector2(-180, -60)
	rune_ui_container.size = Vector2(160, 50)
	health_ui_layer.add_child(rune_ui_container)
	for i in range(3):
		var slot_container = Control.new()
		slot_container.position = Vector2(i * 50, 0)
		slot_container.size = Vector2(45, 45)
		rune_ui_container.add_child(slot_container)
		var slot_bg = ColorRect.new()
		slot_bg.position = Vector2(0, 0)
		slot_bg.size = Vector2(45, 45)
		slot_bg.color = Color(0.1, 0.1, 0.15, 0.8)
		slot_container.add_child(slot_bg)
		var slot_border = ColorRect.new()
		slot_border.position = Vector2(-2, -2)
		slot_border.size = Vector2(49, 49)
		slot_border.color = Color(0.3, 0.3, 0.4, 0.9)
		slot_container.add_child(slot_border)
		slot_container.move_child(slot_border, 0)
		var rune_sprite = TextureRect.new()
		rune_sprite.position = Vector2(2, 2)
		rune_sprite.size = Vector2(41, 41)
		rune_sprite.texture = load("res://assets/sprites/rune_longersonar.png")
		rune_sprite.modulate = Color(1, 1, 1, 0)
		rune_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rune_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rune_sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		slot_container.add_child(rune_sprite)
		rune_slots.append(rune_sprite)
		var key_label = Label.new()
		key_label.text = str(i + 1)
		key_label.position = Vector2(15, 38)
		key_label.size = Vector2(15, 10)
		key_label.add_theme_font_size_override("font_size", 10)
		key_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_container.add_child(key_label)
		rune_labels.append(key_label)
		var timer_label = Label.new()
		timer_label.text = ""
		timer_label.position = Vector2(30, 2)
		timer_label.size = Vector2(12, 8)
		timer_label.add_theme_font_size_override("font_size", 8)
		timer_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 0.8))
		timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_container.add_child(timer_label)
		rune_timers.append(timer_label)
func _setup_sonar_indicator():
	sonar_indicator = TextureRect.new()
	sonar_indicator.texture = load("res://assets/sprites/wave.png")
	sonar_indicator.position = Vector2(20, 60)
	sonar_indicator.size = Vector2(32, 32)
	sonar_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_ui_layer.add_child(sonar_indicator)
	_update_sonar_indicator()
func _update_sonar_indicator():
	if not sonar_indicator:
		return
	if can_sonar:
		sonar_indicator.modulate = Color.WHITE
	else:
		var progress = 1.0 - (sonar_timer / sonar_cooldown_duration)
		var alpha = lerp(0.3, 1.0, progress)
		sonar_indicator.modulate = Color(alpha, alpha, alpha, 1.0)
func _update_health_ui():
	if not health_bar_fill:
		return
	var health_percentage = float(health) / float(MAX_HEALTH)
	var max_width = 156.0
	var current_width = max_width * health_percentage
	health_bar_fill.size.x = current_width
	if corruption_active:
		if not corruption_pulse:
			health_bar_fill.color = corruption_color
		return
	if health_percentage > 0.7:
		health_bar_fill.color = Color(0.6, 0.05, 0.05)
	elif health_percentage > 0.4:
		health_bar_fill.color = Color(0.7, 0.1, 0.0)
	elif health_percentage > 0.2:
		health_bar_fill.color = Color(0.8, 0.0, 0.0)
	else:
		health_bar_fill.color = Color(0.9, 0.05, 0.05)
	if health_percentage <= 0.3 and not corruption_active:
		_create_critical_health_effect()
func _create_critical_health_effect():
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(health_bar_fill, "color", Color(1.0, 0.2, 0.2), 0.6)
	tween.tween_property(health_bar_fill, "color", Color(0.4, 0.0, 0.0), 0.6)
	_create_critical_health_border()
func _physics_process(delta):
	if !can_sonar:
		sonar_timer -= delta
		if sonar_timer <= 0:
			can_sonar = true
			sonar_timer = 0.0
	if !can_attack:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true
	if !can_dash:
		dash_timer -= delta
		if dash_timer <= 0:
			can_dash = true
			is_dashing = false
	if crystal_power_active:
		crystal_power_timer -= delta
		if crystal_power_timer <= 0:
			_end_crystal_power_up()
	_update_rune_ui()
	_update_sonar_indicator()
	_update_camera_micro_effects()
	_update_player_animation(delta)
	_update_input_buffers(delta)
	if invulnerable:
		invulnerable_timer -= delta
		if invulnerable_timer <= 0:
			invulnerable = false
			modulate = Color.WHITE
		else:
			var flash = sin(invulnerable_timer * 20.0)
			modulate.a = 0.5 + abs(flash) * 0.5
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		jump_count = 0
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	if jump_buffer_timer > 0:
		if is_on_floor():
			velocity.y = JUMP_VELOCITY * crystal_jump_boost
			jump_count = 1
			jump_buffer_timer = 0.0
		elif has_double_jump and jump_count < max_jumps:
			var jump_power = JUMP_VELOCITY * 0.85 * crystal_jump_boost
			velocity.y = jump_power
			jump_count += 1
			jump_buffer_timer = 0.0
	var right_click_released = was_aiming_last_frame and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if right_click_released:
		stored_aim_direction = sonar_direction
	_update_sonar_direction()
	if right_click_released and can_sonar:
		var temp_direction = sonar_direction
		sonar_direction = stored_aim_direction
		emit_sonar_pulse()
		sonar_direction = temp_direction
	var e_pressed = Input.is_physical_key_pressed(KEY_E)
	var e_just_pressed = e_pressed and not e_key_was_pressed
	e_key_was_pressed = e_pressed
	if (Input.is_action_just_pressed("ui_accept") or e_just_pressed) and can_sonar:
		emit_sonar_pulse()
	was_aiming_last_frame = is_aiming_mode
	_handle_charging_attack()
	if Input.is_action_just_pressed("ui_cancel"):
		attack_buffer_timer = ATTACK_BUFFER_TIME
	if attack_buffer_timer > 0 and can_attack:
		shoot_light_projectile_at_mouse(0.0)
		attack_buffer_timer = 0.0
	if Input.is_key_pressed(KEY_SHIFT):
		dash_buffer_timer = DASH_BUFFER_TIME
	if dash_buffer_timer > 0 and can_dash and not is_dashing:
		start_dash()
		dash_buffer_timer = 0.0
	if Input.is_key_pressed(KEY_Q):
		_drop_rune()
	if Input.is_action_just_pressed("slot_1"):
		_activate_rune_slot(0)
	elif Input.is_action_just_pressed("slot_2"):
		_activate_rune_slot(1)
	elif Input.is_action_just_pressed("slot_3"):
		_activate_rune_slot(2)
	var direction_input = Input.get_axis("move_left", "move_right")
	var direction = 0
	if direction_input < 0:
		direction = -1
	elif direction_input > 0:
		direction = 1
	var is_moving = direction != 0 and is_on_floor()
	var effective_speed = get_effective_speed()
	if is_dashing:
		velocity.x = dash_direction.x * DASH_SPEED
	elif direction != 0:
		velocity.x = direction * effective_speed
		facing_direction = Vector2.RIGHT if direction > 0 else Vector2.LEFT
		update_sprite_direction()
	else:
		velocity.x = move_toward(velocity.x, 0, effective_speed * 3)
	var current_speed = abs(velocity.x)
	var step_interval = clamp(0.36 - (current_speed / SPEED) * 0.12, 0.24, 0.36)
	handle_footstep_audio(delta, is_moving, step_interval)
	handle_landing_sound()
	if global_position.y > death_plane_y:
		player_died.emit()
	if not is_inside_tree():
		return
	last_velocity_y = velocity.y
	was_on_floor = is_on_floor()
	move_and_slide()
	_handle_corruption(delta)
func _is_idle_on_floor() -> bool:
	return is_on_floor() and abs(velocity.x) <= idle_speed_threshold and abs(velocity.y) < 0.01
func _handle_corruption(delta: float) -> void:
	if health <= 0:
		return
	if not corruption_active:
		if _is_idle_on_floor():
			corruption_timer += delta
			if corruption_timer >= corruption_start_time:
				_start_corruption()
		else:
			corruption_timer = 0.0
	else:
		if corruption_reset_on_move and not _is_idle_on_floor():
			_clear_corruption()
		else:
			corruption_tick_timer += delta
			if corruption_tick_timer >= corruption_tick_interval:
				corruption_tick_timer = 0.0
				_apply_corruption_damage(corruption_damage)
				corruption_damage += 1
func _start_corruption():
	corruption_active = true
	corruption_damage = 1
	corruption_tick_timer = 0.0
	if health_bar_fill:
		if corruption_tween and corruption_tween.is_running():
			corruption_tween.kill()
		if corruption_pulse:
			corruption_tween = create_tween()
			corruption_tween.set_loops()
			corruption_tween.tween_property(health_bar_fill, "color", corruption_color_b, corruption_pulse_speed)
			corruption_tween.tween_property(health_bar_fill, "color", corruption_color, corruption_pulse_speed)
		else:
			health_bar_fill.color = corruption_color
func _clear_corruption():
	corruption_active = false
	corruption_timer = 0.0
	corruption_tick_timer = 0.0
	corruption_damage = 1
	if corruption_tween and corruption_tween.is_running():
		corruption_tween.kill()
	corruption_tween = null
	_update_health_ui()
func _apply_corruption_damage(amount: int) -> void:
	health = max(0, health - amount)
	_update_health_ui()
	if health <= 0:
		player_died.emit()
func _update_sonar_direction():
	var mouse_aim = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if mouse_aim:
		mouse_aim_active = true
		is_aiming_mode = true
		var mouse_pos = get_global_mouse_position()
		var player_pos = global_position
		var direction_to_mouse = (mouse_pos - player_pos).normalized()
		sonar_direction = direction_to_mouse
		stored_aim_direction = sonar_direction
		_update_camera_for_aiming(mouse_pos)
	else:
		mouse_aim_active = false
		is_aiming_mode = false
		sonar_direction = facing_direction
		_reset_camera_follow()
func _update_camera_for_aiming(mouse_pos: Vector2):
	var camera = get_node("Camera2D")
	if not camera:
		return
	var player_pos = global_position
	var mouse_offset = mouse_pos - player_pos
	var sensitivity = clamp(float(SettingsManager.get_setting(SettingsManager.SECTION_GAMEPLAY, "mouse_sensitivity", 1.0)), 0.2, 2.5)
	var max_offset = 100.0 * sensitivity
	mouse_offset *= sensitivity
	mouse_offset = mouse_offset.limit_length(max_offset)
	var target_camera_pos = mouse_offset * 0.5
	camera.position = camera.position.lerp(target_camera_pos, 0.1)
func _reset_camera_follow():
	var camera = get_node("Camera2D")
	if not camera:
		return
	camera.position = camera.position.lerp(Vector2.ZERO, 0.05)
func _update_camera_micro_effects():
	var camera = get_node("Camera2D")
	if not camera or damage_camera_zoom_active:
		return
	var ready_abilities = 0
	if can_sonar:
		ready_abilities += 1
	if can_attack:
		ready_abilities += 1
	if can_dash:
		ready_abilities += 1
	if get_health_percentage() <= 0.3:
		_apply_critical_health_camera_shake(camera)
	else:
		_stop_critical_health_camera_shake()
	if ready_abilities > 0:
		_apply_camera_breathing(camera, ready_abilities)
	else:
		_stop_camera_breathing()
func _apply_camera_breathing(camera: Camera2D, ability_count: int):
	if camera_breathing_tween and camera_breathing_tween.is_valid():
		return
	breathing_camera = camera
	var base_intensity = 1.0
	var intensity = base_intensity + (ability_count - 1) * 0.5
	var breath_offset = intensity * 0.8
	camera_breathing_tween = create_tween()
	camera_breathing_tween.set_loops()
	camera_breathing_tween.tween_method(_set_camera_breath_offset, 0.0, breath_offset, 1.2)
	camera_breathing_tween.tween_method(_set_camera_breath_offset, breath_offset, 0.0, 1.2)
func _set_camera_breath_offset(offset_amount: float):
	if not breathing_camera:
		return
	var time = Time.get_ticks_msec() * 0.001
	var x_offset = sin(time * 0.8) * offset_amount
	var y_offset = cos(time * 0.6) * offset_amount * 0.7
	if not is_aiming_mode:
		breathing_camera.offset = Vector2(x_offset, y_offset)
func _stop_camera_breathing():
	if camera_breathing_tween and camera_breathing_tween.is_valid():
		camera_breathing_tween.kill()
		camera_breathing_tween = null
	var camera = get_node("Camera2D")
	if camera and not is_aiming_mode:
		var reset_tween = create_tween()
		reset_tween.tween_property(camera, "offset", Vector2.ZERO, 0.3)
func _apply_critical_health_camera_shake(camera: Camera2D):
	if critical_health_shake_tween and critical_health_shake_tween.is_valid():
		return
	shake_camera = camera
	critical_health_shake_tween = create_tween()
	critical_health_shake_tween.set_loops()
	var shake_intensity = 2.5
	var sway_duration = 0.8
	critical_health_shake_tween.tween_method(_set_camera_critical_offset, 0.0, shake_intensity, sway_duration)
	critical_health_shake_tween.tween_method(_set_camera_critical_offset, shake_intensity, -shake_intensity, sway_duration)
	critical_health_shake_tween.tween_method(_set_camera_critical_offset, -shake_intensity, 0.0, sway_duration)
func _set_camera_critical_offset(intensity: float):
	if not shake_camera or is_aiming_mode:
		return
	var time = Time.get_ticks_msec() * 0.001
	var shake_x = sin(time * 3.2) * intensity + randf_range(-0.5, 0.5)
	var shake_y = cos(time * 2.8) * intensity * 0.8 + randf_range(-0.3, 0.3)
	shake_camera.offset = Vector2(shake_x, shake_y)
func _stop_critical_health_camera_shake():
	if critical_health_shake_tween and critical_health_shake_tween.is_valid():
		critical_health_shake_tween.kill()
		critical_health_shake_tween = null

func _load_animation_textures():
	player_base_texture = load("res://assets/sprites/player.png")
	player_step_texture = load("res://assets/sprites/playerstep.png")
	player_jump_texture = load("res://assets/sprites/playerjump.png")

	if sprite and player_base_texture:
		sprite.texture = player_base_texture

func _update_player_animation(delta: float):
	if not sprite:
		return

	var is_moving = abs(velocity.x) > 5.0
	var is_airborne = not is_on_floor()

	if is_airborne:
		sprite.texture = player_jump_texture
		is_walk_step_frame = false
		animation_frame_counter = 0
	elif is_moving:
		animation_frame_counter += 1
		var current_speed = abs(velocity.x)
		var speed_multiplier = max(current_speed / SPEED, 0.5)
		var frame_threshold = int(6.0 / speed_multiplier)
		frame_threshold = clamp(frame_threshold, 4, 12)

		if animation_frame_counter >= frame_threshold:
			animation_frame_counter = 0
			is_walk_step_frame = not is_walk_step_frame

		if is_walk_step_frame:
			sprite.texture = player_step_texture
		else:
			sprite.texture = player_base_texture
	else:
		sprite.texture = player_base_texture
		is_walk_step_frame = false
		animation_frame_counter = 0
func update_sprite_direction():
	if sprite:
		if facing_direction == Vector2.LEFT:
			sprite.flip_h = false
		else:
			sprite.flip_h = true
func emit_sonar_pulse():
	if !can_sonar:
		return
	can_sonar = false
	var rune_system = get_node("../RuneSystem")
	var cooldown = get_effective_sonar_cooldown()
	sonar_cooldown_duration = cooldown
	sonar_timer = cooldown
	play_sonar_sound()
	var sonar_range = get_effective_sonar_range()
	if rune_system:
		sonar_range *= rune_system.get_range_multiplier()
	var enhanced_duration = get_effective_sonar_duration()
	sonar_pulse_emitted.emit(global_position, sonar_range, sonar_direction)
	var sonar_system = get_node("../SonarSystem")
	if sonar_system and crystal_power_active:
		sonar_system.apply_duration_boost(crystal_sonar_duration_boost)
	discover_nearby_crystals()
	_update_sonar_indicator()
func _handle_charging_attack():
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and can_attack and not is_charging_attack:
		_start_charging_attack()
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and is_charging_attack:
		_update_charging_attack()
	elif not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and is_charging_attack:
		_release_charged_attack()
func _start_charging_attack():
	if !can_attack or !light_projectile_scene:
		return
	is_charging_attack = true
	charge_time = 0.0
	_create_charge_particles()
	_create_charge_indicator()
	print("Started charging attack")
func _update_charging_attack():
	charge_time += get_process_delta_time()
	charge_time = min(charge_time, max_charge_time)
	var charge_intensity = charge_time / max_charge_time
	if charge_particles:
		charge_particles.amount = int(lerp(10, 50, charge_intensity))
		charge_particles.scale_amount_max = lerp(0.5, 1.5, charge_intensity)
		var charge_color = Color.WHITE.lerp(Color(0.3, 0.6, 1.0), charge_intensity)
		charge_particles.color = charge_color
	if charge_indicator:
		var mouse_pos = get_global_mouse_position()
		var aim_direction = (mouse_pos - global_position).normalized()
		charge_indicator.position = aim_direction * 25
		var scale_value = lerp(0.2, 1.2, charge_intensity)
		charge_indicator.scale = Vector2(scale_value, scale_value)
		var pulse = sin(Time.get_ticks_msec() * 0.01) * 0.2 + 0.8
		var charge_color = Color.WHITE.lerp(Color(0.3, 0.8, 1.0), charge_intensity)
		charge_indicator.modulate = Color(charge_color.r * pulse, charge_color.g * pulse, charge_color.b * pulse, charge_intensity * 0.8)
func _release_charged_attack():
	var charge_level = charge_time / max_charge_time
	shoot_light_projectile_at_mouse(charge_level)
	_cleanup_charge()
func _cancel_charge():
	is_charging_attack = false
	charge_time = 0.0
	_cleanup_charge()
func _cleanup_charge():
	is_charging_attack = false
	charge_time = 0.0
	if charge_particles:
		charge_particles.queue_free()
		charge_particles = null
	if charge_indicator:
		charge_indicator.queue_free()
		charge_indicator = null
func _create_charge_particles():
	if charge_particles:
		charge_particles.queue_free()
	charge_particles = CPUParticles2D.new()
	add_child(charge_particles)
	charge_particles.position = Vector2(0, 0)
	charge_particles.emitting = true
	charge_particles.amount = 15
	charge_particles.lifetime = 1.0
	charge_particles.direction = Vector2(0, -1)
	charge_particles.spread = 45.0
	charge_particles.initial_velocity_min = 20.0
	charge_particles.initial_velocity_max = 40.0
	charge_particles.scale_amount_min = 0.3
	charge_particles.scale_amount_max = 0.8
	charge_particles.color = Color.WHITE
func _create_charge_indicator():
	if charge_indicator:
		charge_indicator.queue_free()
	charge_indicator = Sprite2D.new()
	add_child(charge_indicator)
	charge_indicator.z_index = 1
	var size = 48
	var texture = ImageTexture.new()
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size/2, size/2)
	var radius = size/2
	for x in range(size):
		for y in range(size):
			var pos = Vector2(x, y)
			var distance = pos.distance_to(center)
			if distance <= radius:
				var normalized_distance = distance / radius
				var core_alpha = max(0, 1.0 - (normalized_distance * normalized_distance * 2.0))
				var glow_alpha = max(0, 0.9 - normalized_distance)
				var alpha = max(core_alpha, glow_alpha * 0.3)
				var color = Color(1.0, 1.0, 1.0, alpha)
				image.set_pixel(x, y, color)
			else:
				image.set_pixel(x, y, Color.TRANSPARENT)
	texture.set_image(image)
	charge_indicator.texture = texture
	charge_indicator.scale = Vector2(0.2, 0.2)
	charge_indicator.modulate = Color(1, 1, 1, 0)
	charge_indicator.material = CanvasItemMaterial.new()
	charge_indicator.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
func shoot_light_projectile_at_mouse(charge_level: float = 0.0):
	if !can_attack or !light_projectile_scene:
		return
	can_attack = false
	attack_timer = ATTACK_COOLDOWN
	var mouse_pos = get_global_mouse_position()
	var aim_direction = (mouse_pos - global_position).normalized()
	if abs(aim_direction.x) > 0.1:
		facing_direction = Vector2.RIGHT if aim_direction.x > 0 else Vector2.LEFT
		update_sprite_direction()
	var projectile = light_projectile_scene.instantiate()
	get_parent().add_child(projectile)
	var spawn_offset = aim_direction * 30.0
	projectile.global_position = global_position + spawn_offset
	if projectile.has_method("set_direction"):
		projectile.set_direction(aim_direction)
	else:
		projectile.direction = aim_direction
	if projectile is Node2D:
		(projectile as Node2D).rotation = aim_direction.angle()
	if charge_level > 0.0 and projectile.has_method("set_charge_level"):
		projectile.set_charge_level(charge_level)
	play_attack_sound()
func handle_footstep_audio(delta: float, is_moving: bool, step_interval: float):
	if is_moving:
		footstep_timer += delta
		if footstep_timer >= step_interval:
			footstep_timer = 0.0
			play_footstep_sound()
	else:
		footstep_timer = 0.0
func handle_landing_sound():
	if is_on_floor() and !was_on_floor and abs(last_velocity_y) > MIN_LANDING_VELOCITY:
		play_landing_sound()
		_create_landing_dust_particles(abs(last_velocity_y))
func play_footstep_sound():
	if footstep_audio:
		footstep_audio.pitch_scale = randf_range(0.9, 1.1)
		footstep_audio.volume_db = randf_range(-1.5, 0)
		footstep_audio.play()
	_create_footstep_dust()
func play_landing_sound():
	if landing_audio:
		landing_audio.pitch_scale = randf_range(0.9, 1.05)
		landing_audio.volume_db = randf_range(-2, 0)
		landing_audio.play()
func play_sonar_sound():
	if sonar_audio:
		sonar_audio.pitch_scale = randf_range(0.9, 1.1)
		sonar_audio.play()
func play_attack_sound():
	if attack_audio:
		attack_audio.pitch_scale = randf_range(0.95, 1.05)
		attack_audio.play()
func take_damage():
	if invulnerable:
		return
	health -= 1
	_update_health_ui()
	_on_health_changed()
	_create_damage_screen_effect()
	_create_dramatic_damage_effect()
	if health <= 0:
		player_died.emit()
	else:
		invulnerable = true
		invulnerable_timer = invulnerable_duration
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color.RED, 0.1)
		tween.tween_property(self, "modulate", Color.WHITE, 0.1)
func _create_damage_screen_effect():
	var damage_flash = ColorRect.new()
	health_ui_layer.add_child(damage_flash)
	damage_flash.color = Color(0.7, 0.0, 0.0, 0.6)
	damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween = damage_flash.create_tween()
	tween.tween_property(damage_flash, "modulate:a", 0.0, 0.6)
	tween.finished.connect(func(): damage_flash.queue_free())
func _create_dramatic_damage_effect():
	var level_manager = get_node("../LevelManager")
	var current_level = 1
	if level_manager and level_manager.has_method("get_current_level"):
		current_level = level_manager.get_current_level()

	var base_chance = 0.15
	var level_bonus = (current_level - 1) * 0.05
	var dramatic_chance = base_chance + level_bonus
	dramatic_chance = clamp(dramatic_chance, 0.15, 0.35)

	if randf() > dramatic_chance:
		return
	_start_slow_motion_effect()
	var camera = get_node("Camera2D")
	if camera:
		_apply_dramatic_camera_shake(camera)
	_create_damage_burst_particles()
	_apply_damage_audio_effects()
func _start_slow_motion_effect():
	Engine.time_scale = 0.3
	damage_camera_zoom_active = true
	var camera = get_node("Camera2D")
	if camera:
		original_camera_zoom = camera.zoom.x
		var zoom_tween = create_tween()
		zoom_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		zoom_tween.tween_property(camera, "zoom", Vector2(original_camera_zoom * 1.3, original_camera_zoom * 1.3), 0.2)
	var timer = get_tree().create_timer(1.0, true, false, true)
	timer.timeout.connect(_end_slow_motion_effect)
func _end_slow_motion_effect():
	Engine.time_scale = 1.0
	damage_camera_zoom_active = false
	var camera = get_node("Camera2D")
	if camera and original_camera_zoom > 0:
		var zoom_tween = create_tween()
		zoom_tween.tween_property(camera, "zoom", Vector2(original_camera_zoom, original_camera_zoom), 0.3)
func _apply_dramatic_camera_shake(camera: Camera2D):
	var shake_intensity = 20.0
	var shake_duration = 0.8
	for i in range(8):
		var shake_tween = create_tween()
		shake_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		var offset = Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity))
		shake_tween.tween_property(camera, "offset", offset, 0.1)
		shake_tween.tween_property(camera, "offset", Vector2.ZERO, 0.1)
		await get_tree().create_timer(0.1, true, false, true).timeout
func _create_damage_burst_particles():
	var burst_particles = CPUParticles2D.new()
	add_child(burst_particles)
	burst_particles.position = Vector2(0, 0)
	burst_particles.emitting = true
	burst_particles.amount = 25
	burst_particles.lifetime = 1.2
	burst_particles.one_shot = true
	burst_particles.color = Color(1.0, 0.2, 0.2, 0.8)
	burst_particles.direction = Vector2(0, -1)
	burst_particles.spread = 360.0
	burst_particles.initial_velocity_min = 60.0
	burst_particles.initial_velocity_max = 120.0
	burst_particles.scale_amount_min = 0.3
	burst_particles.scale_amount_max = 0.8
	burst_particles.gravity = Vector2(0, 200)
	var cleanup_timer = get_tree().create_timer(2.0)
	cleanup_timer.timeout.connect(func(): burst_particles.queue_free())
func _apply_damage_audio_effects():
	if attack_audio:
		attack_audio.pitch_scale = 0.6
	if footstep_audio:
		footstep_audio.pitch_scale = 0.6
	var audio_timer = get_tree().create_timer(1.0, true, false, true)
	audio_timer.timeout.connect(_restore_audio_pitch)
func _restore_audio_pitch():
	if attack_audio:
		attack_audio.pitch_scale = 1.0
	if footstep_audio:
		footstep_audio.pitch_scale = 1.0
func heal(amount: int):
	var old_health = health
	health = min(health + amount, MAX_HEALTH)
	_update_health_ui()
	_on_health_changed()
	if health > old_health:
		_create_healing_effect()
func set_max_health(new_max: int):
	var old_percentage = float(health) / float(MAX_HEALTH)
	MAX_HEALTH = new_max
	health = int(old_percentage * MAX_HEALTH)
	_update_health_ui()
func get_health_percentage() -> float:
	"""Get current health as a percentage (0.0 to 1.0)"""
	return float(health) / float(MAX_HEALTH)
func _activate_rune_slot(slot_index: int):
	var rune_system = get_node("../RuneSystem")
	if not rune_system:
		return
	var active_runes = rune_system.get_active_runes()
	var inventory = rune_system.get_inventory()
	var cooldowns = rune_system.get_rune_cooldowns()
	if slot_index < active_runes.size() and active_runes[slot_index] != null:
		var result = rune_system.deactivate_rune(slot_index)
		return
	var rune_type_to_activate = _find_best_rune_for_slot(slot_index, inventory, cooldowns)
	if rune_type_to_activate == null:
		return
	var result = rune_system.activate_rune(slot_index, rune_type_to_activate)
	var updated_active_runes = rune_system.get_active_runes()
func _find_best_rune_for_slot(slot_index: int, inventory: Dictionary, cooldowns: Dictionary):
	var all_types = [RuneSystem.RuneType.RANGE_AMPLIFIER, RuneSystem.RuneType.DURATION_CRYSTAL, RuneSystem.RuneType.RAPID_PULSE]
	for rune_type in all_types:
		if inventory.has(rune_type) and inventory[rune_type] > 0:
			if not cooldowns.has(rune_type):
				return rune_type
	return null
func _drop_rune():
	var rune_system = get_node("../RuneSystem")
	if rune_system:
		var success = rune_system.drop_rune()
func _update_rune_ui():
	var rune_system = get_node("../RuneSystem")
	if not rune_system or rune_slots.size() != 3:
		return
	var active_runes = rune_system.get_active_runes()
	var inventory = rune_system.get_inventory()
	var cooldowns = rune_system.get_rune_cooldowns()
	var timers = rune_system.get_active_rune_timers()
	var has_any_runes = (inventory.size() > 0) or (active_runes.filter(func(r): return r != null).size() > 0) or (cooldowns.size() > 0)
	rune_ui_container.visible = has_any_runes
	var base_rune_colors = {
		RuneSystem.RuneType.RANGE_AMPLIFIER: Color(1.2, 0.6, 0.6),
		RuneSystem.RuneType.DURATION_CRYSTAL: Color(0.6, 1.2, 0.6),
		RuneSystem.RuneType.RAPID_PULSE: Color(0.6, 0.6, 1.2)
	}
	var slot_assignments = _calculate_slot_assignments(active_runes, inventory, cooldowns)
	for i in range(3):
		var slot_container = rune_slots[i].get_parent()
		slot_container.visible = has_any_runes
		if not has_any_runes:
			continue
		var slot_data = slot_assignments[i]
		var display_type = slot_data.type
		var rune_type = slot_data.rune_type
		var count = slot_data.count
		match display_type:
			"active":
				var base_color = base_rune_colors.get(rune_type, Color.WHITE)
				var time_remaining = timers[i] if i < timers.size() else 0.0
				if time_remaining > 0:
					var time_percentage = time_remaining / 30.0
					var fade_color = base_color.lerp(Color(0.5, 0.5, 0.5), 1.0 - time_percentage)
					rune_slots[i].modulate = fade_color
					rune_labels[i].text = str(int(time_remaining) + 1) + "s"
					if time_remaining < 5:
						rune_labels[i].add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
					elif time_remaining < 10:
						rune_labels[i].add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
					else:
						rune_labels[i].add_theme_color_override("font_color", Color.WHITE)
				else:
					rune_slots[i].modulate = base_color
					rune_labels[i].text = "ON"
					rune_labels[i].add_theme_color_override("font_color", Color.WHITE)
			"available":
				var base_color = base_rune_colors.get(rune_type, Color.WHITE)
				rune_slots[i].modulate = base_color * 0.4
				rune_labels[i].text = str(i + 1)
				rune_labels[i].add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
			"cooldown":
				rune_slots[i].modulate = Color(0.8, 0.4, 0.4, 0.6)
				var cd_time = cooldowns.get(rune_type, 0.0)
				rune_labels[i].text = str(int(cd_time) + 1) + "s"
				rune_labels[i].add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
			"empty":
				rune_slots[i].modulate = Color(1, 1, 1, 0)
				rune_labels[i].text = str(i + 1)
				rune_labels[i].add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
func _calculate_slot_assignments(active_runes: Array, inventory: Dictionary, cooldowns: Dictionary) -> Array:
	var assignments = []
	var assigned_runes = {}
	for i in range(3):
		var slot_data = {"type": "empty", "rune_type": null, "count": 0}
		if i < active_runes.size() and active_runes[i] != null:
			slot_data.type = "active"
			slot_data.rune_type = active_runes[i]
			assigned_runes[active_runes[i]] = true
		assignments.append(slot_data)
	var all_rune_types = []
	for rune_type in inventory.keys():
		if inventory[rune_type] > 0:
			all_rune_types.append(rune_type)
	for rune_type in cooldowns.keys():
		if not inventory.has(rune_type) or inventory[rune_type] == 0:
			all_rune_types.append(rune_type)
	var key_index = 0
	for i in range(3):
		if assignments[i].type == "empty":
			while key_index < all_rune_types.size():
				var rune_type = all_rune_types[key_index]
				key_index += 1
				if not assigned_runes.has(rune_type):
					assigned_runes[rune_type] = true
					if cooldowns.has(rune_type):
						assignments[i].type = "cooldown"
						assignments[i].rune_type = rune_type
					else:
						assignments[i].type = "available"
						assignments[i].rune_type = rune_type
						assignments[i].count = inventory.get(rune_type, 0)
					break
	return assignments
func _on_rune_changed(slot: int, rune_type):
	_update_rune_ui()
func _setup_quest_systems():
	quest_system = _find_node_by_name(get_tree().current_scene, "QuestSystem")
	medkit_system = _find_node_by_name(get_tree().current_scene, "MedkitSystem")
	if not medkit_system:
		medkit_system = preload("res://scripts/MedkitSystem.gd").new()
		medkit_system.name = "MedkitSystem"
		get_tree().current_scene.add_child.call_deferred(medkit_system)
	reward_system = _find_node_by_name(get_tree().current_scene, "RewardSystem")
	if not reward_system:
		reward_system = preload("res://scripts/RewardSystem.gd").new()
		reward_system.name = "RewardSystem"
		get_tree().current_scene.add_child.call_deferred(reward_system)
	if medkit_system and medkit_system.has_method("_on_player_health_changed"):
		pass
func _find_node_by_name(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	for child in node.get_children():
		var result = _find_node_by_name(child, name)
		if result:
			return result
	return null
func add_environment_speed_modifier(source_id: int, multiplier: float) -> void:
	environment_speed_modifiers[source_id] = clamp(multiplier, 0.05, 1.0)
	_recalculate_environment_speed_multiplier()
func remove_environment_speed_modifier(source_id: int) -> void:
	environment_speed_modifiers.erase(source_id)
	_recalculate_environment_speed_multiplier()
func _recalculate_environment_speed_multiplier() -> void:
	var combined: float = 1.0
	for value in environment_speed_modifiers.values():
		if value is float or value is int:
			combined *= float(value)
	environment_speed_multiplier = clamp(combined, 0.1, 1.0)
func get_effective_speed() -> float:
	var base_speed = SPEED
	if reward_system and reward_system.has_method("get_speed_multiplier"):
		base_speed *= reward_system.get_speed_multiplier()
	if quest_system and quest_system.has_method("has_active_penalty"):
		if quest_system.has_active_penalty(quest_system.PenaltyType.MOVEMENT_SPEED_REDUCTION):
			var penalty = quest_system.get_penalty_multiplier(quest_system.PenaltyType.MOVEMENT_SPEED_REDUCTION)
			base_speed *= (1.0 - penalty)
	base_speed *= environment_speed_multiplier
	return base_speed
func get_effective_attack_damage() -> float:
	var base_damage = 1.0
	if reward_system and reward_system.has_method("get_attack_multiplier"):
		base_damage *= reward_system.get_attack_multiplier()
	return base_damage
func get_effective_sonar_range() -> float:
	var base_range = SONAR_RANGE
	if reward_system and reward_system.has_method("get_sonar_range_multiplier"):
		base_range *= reward_system.get_sonar_range_multiplier()
	if quest_system and quest_system.has_method("has_active_penalty"):
		if quest_system.has_active_penalty(quest_system.PenaltyType.SONAR_RANGE_REDUCTION):
			var penalty = quest_system.get_penalty_multiplier(quest_system.PenaltyType.SONAR_RANGE_REDUCTION)
			base_range *= (1.0 - penalty)
	return base_range
func get_effective_sonar_cooldown() -> float:
	var base_cooldown = SONAR_COOLDOWN
	var rune_system = get_node("../RuneSystem")
	if rune_system:
		base_cooldown *= rune_system.get_cooldown_multiplier()
	if quest_system and quest_system.has_method("has_active_penalty"):
		if quest_system.has_active_penalty(quest_system.PenaltyType.SONAR_COOLDOWN_INCREASE):
			var penalty = quest_system.get_penalty_multiplier(quest_system.PenaltyType.SONAR_COOLDOWN_INCREASE)
			base_cooldown *= (1.0 + penalty)
	return base_cooldown
func _on_health_changed():
	if medkit_system and medkit_system.has_method("_on_player_health_changed"):
		medkit_system._on_player_health_changed(health)
func start_dash():
	if not can_dash or is_dashing:
		return
	dash_direction = facing_direction
	is_dashing = true
	can_dash = false
	var effective_dash_cooldown = DASH_COOLDOWN
	if crystal_power_active:
		effective_dash_cooldown *= crystal_dash_boost
	dash_timer = effective_dash_cooldown
	var dash_duration_timer = get_tree().create_timer(DASH_DURATION)
	dash_duration_timer.timeout.connect(_end_dash)
	_create_dash_trail_particles()
	var dash_tween = create_tween()
	dash_tween.tween_property(self, "modulate:a", 0.7, 0.1)
	dash_tween.tween_property(self, "modulate:a", 1.0, 0.1)
func _end_dash():
	is_dashing = false
	_stop_dash_trail_particles()
func discover_nearby_crystals():
	var crystals = get_tree().get_nodes_in_group("light_crystals")
	for crystal in crystals:
		if crystal.has_method("_check_for_discovery"):
			var distance = global_position.distance_to(crystal.global_position)
			if distance <= get_effective_sonar_range():
				crystal._check_for_discovery()
func _apply_crystal_power_up(sonar_duration_boost: float, jump_boost: float, dash_boost: float, duration: float):
	if crystal_power_active:
		crystal_power_timer = max(crystal_power_timer, duration)
		return
	crystal_power_active = true
	crystal_power_timer = duration
	crystal_sonar_duration_boost = sonar_duration_boost
	crystal_jump_boost = jump_boost
	crystal_dash_boost = dash_boost
	_create_power_up_visual_effect()
func _end_crystal_power_up():
	crystal_power_active = false
	crystal_power_timer = 0.0
	crystal_sonar_duration_boost = 1.0
	crystal_jump_boost = 1.0
	crystal_dash_boost = 1.0
	if power_up_particles_left:
		power_up_particles_left.emitting = false
		var fade_timer_left = get_tree().create_timer(power_up_particles_left.lifetime)
		fade_timer_left.timeout.connect(func():
			if power_up_particles_left and is_instance_valid(power_up_particles_left):
				power_up_particles_left.queue_free()
		)
	if power_up_particles_right:
		power_up_particles_right.emitting = false
		var fade_timer_right = get_tree().create_timer(power_up_particles_right.lifetime)
		fade_timer_right.timeout.connect(func():
			if power_up_particles_right and is_instance_valid(power_up_particles_right):
				power_up_particles_right.queue_free()
		)
	if lightning_particles:
		lightning_particles.emitting = false
		var fade_timer_lightning = get_tree().create_timer(lightning_particles.lifetime)
		fade_timer_lightning.timeout.connect(func():
			if lightning_particles and is_instance_valid(lightning_particles):
				lightning_particles.queue_free()
		)
	for i in range(lightning_shader_sprites.size()):
		var sprite = lightning_shader_sprites[i]
		if sprite:
			var fade_tween = create_tween()
			fade_tween.tween_interval(i * 0.1)
			fade_tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
			fade_tween.finished.connect(func():
				if sprite and is_instance_valid(sprite):
					sprite.queue_free()
			)
	lightning_shader_sprites.clear()
	if sprite:
		sprite.modulate = Color.WHITE
func _create_power_up_visual_effect():
	if power_up_particles_left:
		power_up_particles_left.queue_free()
	if power_up_particles_right:
		power_up_particles_right.queue_free()
	if lightning_particles:
		lightning_particles.queue_free()
	for sprite in lightning_shader_sprites:
		if sprite:
			sprite.queue_free()
	lightning_shader_sprites.clear()
	power_up_particles_left = CPUParticles2D.new()
	add_child(power_up_particles_left)
	_setup_foot_particles(power_up_particles_left, Vector2(-8, 12))
	power_up_particles_right = CPUParticles2D.new()
	add_child(power_up_particles_right)
	_setup_foot_particles(power_up_particles_right, Vector2(8, 12))
	lightning_particles = CPUParticles2D.new()
	add_child(lightning_particles)
	_setup_lightning_particles()
	_setup_lightning_sparks()
	if sprite:
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(sprite, "modulate", Color(0.8, 0.9, 1.2, 1.0), 1.5)
		tween.tween_property(sprite, "modulate", Color(0.9, 0.95, 1.1, 1.0), 1.5)
		
func _setup_foot_particles(particles: CPUParticles2D, foot_offset: Vector2):
	particles.position = foot_offset
	particles.z_index = -1
	particles.emitting = true
	particles.amount = 40
	particles.lifetime = 1.8
	particles.color = Color(0.1, 0.5, 1.0, 0.8)
	particles.direction = Vector2(-facing_direction.x * 0.8, 0.3)
	particles.spread = 15.0
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 60.0
	particles.scale_amount_min = 0.2
	particles.scale_amount_max = 0.5
	particles.gravity = Vector2(0, 20)
	
func _setup_lightning_particles():
	lightning_particles.position = Vector2(0, 0)
	lightning_particles.z_index = 1
	lightning_particles.emitting = true
	lightning_particles.amount = 15
	lightning_particles.lifetime = 0.8
	lightning_particles.color = Color(0.8, 0.9, 1.0, 0.9)
	lightning_particles.direction = Vector2(1, 0)
	lightning_particles.spread = 360.0
	lightning_particles.initial_velocity_min = 40.0
	lightning_particles.initial_velocity_max = 80.0
	lightning_particles.scale_amount_min = 0.1
	lightning_particles.scale_amount_max = 0.3
	lightning_particles.gravity = Vector2(0, 0)
	
func _setup_lightning_sparks():
	lightning_animation_timer = 0.0
	spark_appear_intervals.clear()
	var num_sparks = randi_range(2, 6)
	for i in range(num_sparks):
		var spark_sprite = Sprite2D.new()
		add_child(spark_sprite)
		lightning_shader_sprites.append(spark_sprite)
		spark_sprite.modulate.a = 0.0
		spark_sprite.z_index = 0
		var texture = ImageTexture.new()
		var image = Image.create(18, 18, false, Image.FORMAT_RGBA8)
		image.fill(Color(1, 1, 1, 1))
		texture.set_image(image)
		spark_sprite.texture = texture
		_randomize_spark_position(spark_sprite)
		spark_sprite.rotation = randf() * PI * 2
		var shader_material = ShaderMaterial.new()
		var lightning_shader = Shader.new()
		lightning_shader.code = """
shader_type canvas_item;
uniform vec3 effect_color: source_color = vec3(0.2, 0.6, 1.0);
uniform int octave_count: hint_range(1, 20) = 6;
uniform float amp_start = 0.3;
uniform float amp_coeff = 0.7;
uniform float freq_coeff = 3.0;
uniform float speed = 2.0;t
uniform float spark_offset: hint_range(0.0, 10.0) = 0.0;
float hash12(vec2 x) {
	return fract(cos(mod(dot(x, vec2(13.9898, 8.141)), 3.14)) * 43758.5453);
}
vec2 hash22(vec2 uv) {
	uv = vec2(dot(uv, vec2(127.1,311.7)),
			  dot(uv, vec2(269.5,183.3)));
	return 2.0 * fract(sin(uv) * 43758.5453123) - 1.0;
}
float noise(vec2 uv) {
	vec2 iuv = floor(uv);
	vec2 fuv = fract(uv);
	vec2 blur = smoothstep(0.0, 1.0, fuv);
	return mix(mix(dot(hash22(iuv + vec2(0.0,0.0)), fuv - vec2(0.0,0.0)),
				   dot(hash22(iuv + vec2(1.0,0.0)), fuv - vec2(1.0,0.0)), blur.x),
			   mix(dot(hash22(iuv + vec2(0.0,1.0)), fuv - vec2(0.0,1.0)),
				   dot(hash22(iuv + vec2(1.0,1.0)), fuv - vec2(1.0,1.0)), blur.x), blur.y) + 0.5;
}
float fbm(vec2 uv, int octaves) {
	float value = 0.0;
	float amplitude = amp_start;
	for (int i = 0; i < octaves; i++) {
		value += amplitude * noise(uv);
		uv *= freq_coeff;
		amplitude *= amp_coeff;
	}
	return value;
}
void fragment() {
	vec2 uv = 2.0 * UV - 1.0;
	uv += 2.0 * fbm(uv + (TIME + spark_offset) * speed, octave_count) - 1.0;
	float dist = abs(uv.x);
	float crackle = mix(0.0, 0.15, hash12(vec2(TIME + spark_offset)));d
	float lightning_intensity = crackle / (dist + 0.02);
	lightning_intensity *= step(dist, 0.3) * step(0.02, crackle);
	vec3 color = effect_color * lightning_intensity;
	float alpha = lightning_intensity * 0.8;
	COLOR = vec4(color, alpha);
}
"""
		shader_material.shader = lightning_shader
		shader_material.set_shader_parameter("spark_offset", i * 2.0)
		spark_sprite.material = shader_material
		var random_scale = randf_range(0.15, 0.3)
		spark_sprite.scale = Vector2(random_scale, random_scale)
		spark_appear_intervals.append(randf_range(0.2, 1.5))
	_animate_lightning_sparks()
func _randomize_spark_position(spark_sprite: Sprite2D):
	var body_areas = [
		Vector2(-15, -10),
		Vector2(15, -10),
		Vector2(-10, 0),
		Vector2(10, 0),
		Vector2(0, -15),
		Vector2(-8, 8),
		Vector2(8, 8),
		Vector2(0, 5)
	]
	var base_pos = body_areas[randi() % body_areas.size()]
	var random_offset = Vector2(randf_range(-5, 5), randf_range(-5, 5))
	spark_sprite.position = base_pos + random_offset
func _animate_lightning_sparks():
	for i in range(lightning_shader_sprites.size()):
		var spark = lightning_shader_sprites[i]
		var interval = spark_appear_intervals[i]
		_animate_single_spark(spark, interval, i)
func _animate_single_spark(spark: Sprite2D, interval: float, spark_index: int):
	if not spark or not is_instance_valid(spark):
		return
	var tween = create_tween()
	tween.tween_interval(interval)
	tween.tween_property(spark, "modulate:a", 1.0, 0.1)
	tween.tween_interval(randf_range(0.1, 0.4))
	tween.tween_property(spark, "modulate:a", 0.0, 0.05)
	tween.finished.connect(func():
		if spark and is_instance_valid(spark) and crystal_power_active:
			_randomize_spark_position(spark)
			spark.rotation = randf() * PI * 2
			var new_interval = randf_range(0.2, 1.5)
			spark_appear_intervals[spark_index] = new_interval
			_animate_single_spark(spark, new_interval, spark_index)
	)
func get_effective_sonar_duration() -> float:
	var base_duration = 2.0
	if crystal_power_active:
		base_duration *= crystal_sonar_duration_boost
	return base_duration
func _create_landing_dust_particles(impact_velocity: float):
	var landing_particles = CPUParticles2D.new()
	add_child(landing_particles)
	landing_particles.position = Vector2(0, 10)
	landing_particles.emitting = true
	landing_particles.amount = int(lerp(5, 20, impact_velocity / 600.0))
	landing_particles.lifetime = 0.8
	landing_particles.one_shot = true
	landing_particles.color = Color(0.7, 0.6, 0.5, 0.6)
	landing_particles.direction = Vector2(0, -1)
	landing_particles.spread = 90.0
	landing_particles.initial_velocity_min = 20.0
	landing_particles.initial_velocity_max = 60.0
	landing_particles.scale_amount_min = 0.2
	landing_particles.scale_amount_max = 0.6
	landing_particles.gravity = Vector2(0, 100)
	var cleanup_timer = get_tree().create_timer(1.5)
	cleanup_timer.timeout.connect(func(): landing_particles.queue_free())
func _create_footstep_dust():
	if randf() > 0.3:
		return
	var footstep_dust = CPUParticles2D.new()
	add_child(footstep_dust)
	var foot_pos = Vector2(-facing_direction.x * 5, 12)
	footstep_dust.position = foot_pos
	footstep_dust.emitting = true
	footstep_dust.amount = 3
	footstep_dust.lifetime = 0.5
	footstep_dust.one_shot = true
	footstep_dust.color = Color(0.6, 0.5, 0.4, 0.4)
	footstep_dust.direction = Vector2(-facing_direction.x, -0.5)
	footstep_dust.spread = 30.0
	footstep_dust.initial_velocity_min = 10.0
	footstep_dust.initial_velocity_max = 25.0
	footstep_dust.scale_amount_min = 0.1
	footstep_dust.scale_amount_max = 0.3
	footstep_dust.gravity = Vector2(0, 50)
	var cleanup_timer = get_tree().create_timer(1.0)
	cleanup_timer.timeout.connect(func(): footstep_dust.queue_free())
func _create_dash_trail_particles():
	if dash_trail_particles:
		dash_trail_particles.queue_free()
	dash_trail_particles = CPUParticles2D.new()	
	add_child(dash_trail_particles)
	dash_trail_particles.position = Vector2(0, 0)
	dash_trail_particles.emitting = true
	dash_trail_particles.amount = 15
	dash_trail_particles.lifetime = 0.4
	if crystal_power_active:
		dash_trail_particles.color = Color(0.3, 0.7, 1.0, 0.8)
	else:
		dash_trail_particles.color = Color(0.8, 0.8, 0.9, 0.6)
	dash_trail_particles.direction = Vector2(-dash_direction.x, 0)
	dash_trail_particles.spread = 15.0
	dash_trail_particles.initial_velocity_min = 30.0
	dash_trail_particles.initial_velocity_max = 60.0
	dash_trail_particles.scale_amount_min = 0.2
	dash_trail_particles.scale_amount_max = 0.5
	dash_trail_particles.gravity = Vector2(0, 20)
func _stop_dash_trail_particles():
	if dash_trail_particles:
		dash_trail_particles.emitting = false
		var cleanup_timer = get_tree().create_timer(dash_trail_particles.lifetime + 0.1)
		cleanup_timer.timeout.connect(func():
			if dash_trail_particles and is_instance_valid(dash_trail_particles):
				dash_trail_particles.queue_free()
		)
func _update_input_buffers(delta: float):
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
		if jump_buffer_timer < 0:
			jump_buffer_timer = 0
	if attack_buffer_timer > 0:
		attack_buffer_timer -= delta
		if attack_buffer_timer < 0:
			attack_buffer_timer = 0
	if dash_buffer_timer > 0:
		dash_buffer_timer -= delta
		if dash_buffer_timer < 0:
			dash_buffer_timer = 0
func _create_healing_effect():
	var heal_flash = ColorRect.new()
	health_ui_layer.add_child(heal_flash)
	heal_flash.color = Color(0.2, 0.8, 0.3, 0.4)
	heal_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	heal_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween = heal_flash.create_tween()
	tween.tween_property(heal_flash, "modulate:a", 0.8, 0.2)
	tween.tween_property(heal_flash, "modulate:a", 0.0, 0.5)
	tween.finished.connect(func(): heal_flash.queue_free())
	if health_bar_fill:
		var glow_tween = create_tween()
		var original_color = health_bar_fill.color
		glow_tween.tween_property(health_bar_fill, "color", Color(0.4, 0.9, 0.4), 0.3)
		glow_tween.tween_property(health_bar_fill, "color", original_color, 0.4)
func _create_critical_health_border():
	var existing_border = health_ui_layer.get_node_or_null("CriticalBorder")
	if existing_border:
		return
	var border_container = Control.new()
	border_container.name = "CriticalBorder"
	border_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_ui_layer.add_child(border_container)
	var top_border = ColorRect.new()
	top_border.color = Color(0.8, 0.1, 0.1, 0.6)
	top_border.position = Vector2(0, 0)
	top_border.size = Vector2(1920, 10)
	border_container.add_child(top_border)
	var bottom_border = ColorRect.new()
	bottom_border.color = Color(0.8, 0.1, 0.1, 0.6)
	bottom_border.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_border.size = Vector2(1920, 10)
	border_container.add_child(bottom_border)
	var left_border = ColorRect.new()
	left_border.color = Color(0.8, 0.1, 0.1, 0.6)
	left_border.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	left_border.size = Vector2(10, 1080)
	border_container.add_child(left_border)
	var right_border = ColorRect.new()
	right_border.color = Color(0.8, 0.1, 0.1, 0.6)
	right_border.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	right_border.size = Vector2(10, 1080)
	border_container.add_child(right_border)
	var border_tween = create_tween()
	border_tween.set_loops()
	border_tween.tween_property(border_container, "modulate:a", 1.0, 0.8)
	border_tween.tween_property(border_container, "modulate:a", 0.3, 0.8)
	var health_check_timer = Timer.new()
	health_check_timer.wait_time = 0.5
	health_check_timer.timeout.connect(func():
		if get_health_percentage() > 0.3:
			border_container.queue_free()
			health_check_timer.queue_free()
	)
	add_child(health_check_timer)
	health_check_timer.start()
