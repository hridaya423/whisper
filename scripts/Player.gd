extends CharacterBody2D
class_name Player
const SPEED = 200.0
const JUMP_VELOCITY = -400.0
const SONAR_COOLDOWN = 2.0
const SONAR_RANGE = 150.0
const MIN_LANDING_VELOCITY = 150.0
const ATTACK_COOLDOWN = 0.5
const MELEE_COOLDOWN = 0.7
const MELEE_CHARGE_TIME = 1.0
const MELEE_WAVE_SPEED = 400.0
const MELEE_WAVE_DAMAGE_MULTIPLIER = 2.0
const MELEE_ATTACK_RESOURCE := preload("res://scripts/MeleeAttack.gd")
const PARRY_CLANG_SOUND := preload("res://assets/sfx/playerattack.mp3")
const PAUSE_MENU_SCENE := preload("res://scenes/ui/PauseMenu.tscn")
const DASH_SPEED = 600.0
const DASH_DURATION = 0.2
const DASH_COOLDOWN = 4.5
const SLIDE_SPEED = 350.0
const SLIDE_DURATION = 0.6
const SLIDE_FRICTION = 0.92
const SLIDE_JUMP_BOOST = 1.5
const MIN_SLIDE_SPEED = 50.0 
var MAX_HEALTH = 10
var sonar_timer = 0.0
var sonar_cooldown_duration = SONAR_COOLDOWN
var attack_timer = 0.0
var melee_attack_timer = 0.0
var melee_charge_time = 0.0
var is_charging_melee = false
var melee_charge_arc: Line2D 
var melee_charge_particles: CPUParticles2D
var dash_timer = 0.0
var can_sonar = true
var can_attack = true
var can_melee_attack = true
var can_dash = true
var is_dashing = false
var is_sliding = false
var slide_timer = 0.0
var slide_particles: CPUParticles2D
var dash_direction = Vector2.ZERO
var dash_speed_override: float = DASH_SPEED
var _external_dash_active: bool = false
var _external_dash_reset_cooldown: bool = false
var _cached_can_dash: bool = true
var _cached_dash_timer: float = 0.0
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
var s_key_was_pressed = false
var x_key_was_pressed = false
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
var synergy_ui: CanvasLayer
var damage_camera_zoom_active: bool = false
var original_camera_zoom: float = 1.0
var camera_breathing_tween: Tween
var critical_health_shake_tween: Tween
var damage_hit_shake_tween: Tween
var dramatic_shake_tween: Tween
var breathing_camera: Camera2D
var shake_camera: Camera2D
var dramatic_camera: Camera2D
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
var camera_breath_offset: Vector2 = Vector2.ZERO
var camera_critical_offset: Vector2 = Vector2.ZERO
var camera_damage_hit_offset: Vector2 = Vector2.ZERO
var camera_dramatic_offset: Vector2 = Vector2.ZERO
var parry_system: ParrySystem
var parry_audio: AudioStreamPlayer2D
var parry_shield_effect: Node2D
var _prev_melee_key_pressed: bool = false
var _prev_parry_key_pressed: bool = false
var damage_effect_layer: CanvasLayer
var chromatic_rect: ColorRect
var chromatic_tween: Tween
var pause_menu: PauseMenu
var is_pause_menu_active: bool = false
var stored_mouse_mode: int = Input.MOUSE_MODE_VISIBLE
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
var _speed_debuff_multiplier: float = 1.0
var _speed_debuff_timer: float = 0.0
@onready var footstep_audio: AudioStreamPlayer2D = $FootstepAudio
@onready var landing_audio: AudioStreamPlayer2D = $LandingAudio
@onready var sonar_audio: AudioStreamPlayer2D = $SonarAudio
@onready var attack_audio: AudioStreamPlayer2D = $AttackAudio
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
signal sonar_pulse_emitted(position: Vector2, range: float, direction: Vector2)
signal player_died
func _ready():
	z_index = 101
	add_to_group("player")
	stored_mouse_mode = Input.get_mouse_mode()
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
	_update_camera_combined_offset()
	_initialize_parry_system()
	_ensure_input_actions()
	_setup_pause_menu()
func _setup_health_ui():
	health_ui_layer = CanvasLayer.new()
	health_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(health_ui_layer)

	damage_effect_layer = CanvasLayer.new()
	damage_effect_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	damage_effect_layer.layer = 200
	add_child(damage_effect_layer)

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
			attack_timer = 0.0
	if not can_melee_attack:
		melee_attack_timer -= delta
		if melee_attack_timer <= 0:
			can_melee_attack = true
			melee_attack_timer = 0.0
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

	if _speed_debuff_timer > 0:
		_speed_debuff_timer -= delta
		if _speed_debuff_timer <= 0:
			_speed_debuff_multiplier = 1.0
			_speed_debuff_timer = 0.0
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		jump_count = 0
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	if jump_buffer_timer > 0:
		if is_on_floor():
			var jump_boost = SLIDE_JUMP_BOOST if is_sliding else 1.0
			velocity.y = JUMP_VELOCITY * crystal_jump_boost * jump_boost
			if is_sliding:
				_end_slide()
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
	if Input.is_action_just_pressed("pause_game"
		var quest_ui = get_node_or_null("../QuestUI")
		if quest_ui and quest_ui.is_showing:
			return
		if get_tree().paused:
			_resume_game()
		else:
			_pause_game()
		return
	var e_pressed = Input.is_physical_key_pressed(KEY_E)
	var e_just_pressed = e_pressed and not e_key_was_pressed
	e_key_was_pressed = e_pressed
	if e_just_pressed and can_sonar:
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
	var s_pressed = Input.is_physical_key_pressed(KEY_S)
	var s_just_pressed = s_pressed and not s_key_was_pressed
	s_key_was_pressed = s_pressed
	if s_just_pressed:
		_open_synergy_menu()

	var x_pressed = Input.is_physical_key_pressed(KEY_X)
	var x_just_pressed = x_pressed and not x_key_was_pressed
	x_key_was_pressed = x_pressed
	if x_just_pressed:
		var synergy_system = get_node("../RuneSynergy")
		if synergy_system and synergy_system.has_active_synergy():
			synergy_system.use_synergy()
	var parry_pressed := Input.is_action_just_pressed("parry")
	var parry_key_down := Input.is_physical_key_pressed(KEY_F)
	if parry_key_down and not _prev_parry_key_pressed:
		parry_pressed = true
	_prev_parry_key_pressed = parry_key_down
	if parry_pressed:
		_attempt_parry()
	var melee_key_down := Input.is_physical_key_pressed(KEY_C)
	var melee_just_pressed = melee_key_down and not _prev_melee_key_pressed
	var melee_just_released = not melee_key_down and _prev_melee_key_pressed
	_prev_melee_key_pressed = melee_key_down

	if melee_just_pressed and can_melee_attack:
		_start_melee_charge()
	elif is_charging_melee and melee_key_down:
		_update_melee_charge(delta)
	elif melee_just_released and is_charging_melee:
		_release_melee_charge()
	var direction_input = Input.get_axis("move_left", "move_right")
	var direction = 0
	if direction_input < 0:
		direction = -1
	elif direction_input > 0:
		direction = 1
	var is_moving = direction != 0 and is_on_floor()
	var effective_speed = get_effective_speed()

	_handle_slide_input(delta, direction)

	if is_sliding:
		_check_slide_collision()

	_physics_process_wave_movement(delta)

	if is_dashing:
		var dash_speed := dash_speed_override if dash_speed_override > 0.0 else DASH_SPEED
		velocity.x = dash_direction.x * dash_speed
		if abs(dash_direction.y) > 0.0001:
			velocity.y = dash_direction.y * dash_speed
	elif is_sliding:
		velocity.x *= SLIDE_FRICTION
		if abs(velocity.x) < MIN_SLIDE_SPEED:
			_end_slide()
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

	_apply_wind_forces()

	move_and_slide()
	_handle_corruption(delta)
func _apply_wind_forces() -> void:
	var wind_tunnels = get_tree().get_nodes_in_group("wind_tunnels")
	for tunnel in wind_tunnels:
		if tunnel.has_method("is_body_in_wind") and tunnel.is_body_in_wind(self):
			var wind_force: Vector2 = tunnel.get_wind_force_at_position(self, global_position)

			velocity += wind_force
			var wind_dir: Vector2 = tunnel.wind_direction.normalized()
			var movement_dir: Vector2 = Vector2(
				Input.get_axis("move_left", "move_right"),
				0
			)

			if movement_dir.length() > 0.1:
				var alignment: float = movement_dir.normalized().dot(wind_dir)
				if alignment > 0.7:
					velocity.x *= 1.4
				elif alignment < -0.7:
					velocity.x *= 0.7

func apply_speed_debuff(reduction: float, duration: float) -> void:
	_speed_debuff_multiplier = 1.0 - reduction 
	_speed_debuff_timer = duration

func _is_idle_on_floor() -> bool:
	return is_on_floor() and abs(velocity.x) <= idle_speed_threshold and abs(velocity.y) < 0.01
func _handle_corruption(delta: float) -> void:
	if health <= 0:
		return
	if get_tree().paused:
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
		_update_camera_combined_offset()
		var mouse_pos = get_global_mouse_position()
		var player_pos = global_position
		var direction_to_mouse = (mouse_pos - player_pos).normalized()
		sonar_direction = direction_to_mouse
		stored_aim_direction = sonar_direction
		_update_camera_for_aiming(mouse_pos)
	else:
		mouse_aim_active = false
		is_aiming_mode = false
		_update_camera_combined_offset()
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

func _get_player_camera() -> Camera2D:
	return get_node_or_null("Camera2D")

func _update_camera_combined_offset():
	var camera = _get_player_camera()
	if not camera:
		return
	if is_aiming_mode:
		camera.offset = Vector2.ZERO
		return
	camera.offset = camera_breath_offset + camera_critical_offset + camera_damage_hit_offset + camera_dramatic_offset
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
	camera_breath_offset = Vector2(x_offset, y_offset)
	_update_camera_combined_offset()
func _stop_camera_breathing():
	if camera_breathing_tween and camera_breathing_tween.is_valid():
		camera_breathing_tween.kill()
		camera_breathing_tween = null
	camera_breath_offset = Vector2.ZERO
	_update_camera_combined_offset()
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
	camera_critical_offset = Vector2(shake_x, shake_y)
	_update_camera_combined_offset()
func _stop_critical_health_camera_shake():
	if critical_health_shake_tween and critical_health_shake_tween.is_valid():
		critical_health_shake_tween.kill()
		critical_health_shake_tween = null
	camera_critical_offset = Vector2.ZERO
	_update_camera_combined_offset()

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
	if rune_system:
		enhanced_duration *= rune_system.get_duration_multiplier()
	sonar_pulse_emitted.emit(global_position, sonar_range, sonar_direction)
	var sonar_system = get_node("../SonarSystem")
	if sonar_system:
		sonar_system.glow_duration = enhanced_duration
		sonar_system.glow_timer = enhanced_duration
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

func _perform_melee_attack():
	if not can_melee_attack:
		return

	can_melee_attack = false
	melee_attack_timer = MELEE_COOLDOWN

	var melee_direction := _get_melee_direction()
	if melee_direction == Vector2.ZERO:
		melee_direction = Vector2.RIGHT

	var melee_attack: MeleeAttack = MELEE_ATTACK_RESOURCE.new()
	add_child(melee_attack)
	melee_attack.setup(self, melee_direction, get_effective_attack_damage())

	if abs(melee_direction.x) > 0.01:
		facing_direction = Vector2.RIGHT if melee_direction.x > 0 else Vector2.LEFT
		update_sprite_direction()

	_play_melee_feedback()

func _get_melee_direction() -> Vector2:
	var direction := Vector2.ZERO
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		direction = (get_global_mouse_position() - global_position).normalized()
	elif stored_aim_direction.length_squared() > 0.0001:
		direction = stored_aim_direction.normalized()
	elif facing_direction.length_squared() > 0.0001:
		direction = facing_direction.normalized()

	if direction.length_squared() == 0:
		return Vector2.RIGHT
	return direction

func _play_melee_feedback():
	if sprite:
		var melee_tween = create_tween()
		melee_tween.tween_property(sprite, "modulate", Color(1.0, 0.85, 0.6), 0.06)
		melee_tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	if attack_audio:
		attack_audio.pitch_scale = randf_range(0.9, 1.05)
		attack_audio.play()
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
	if projectile.has_method("set_damage_multiplier"):
		var damage_mult = get_effective_attack_damage()
		projectile.set_damage_multiplier(damage_mult)
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
func take_damage(amount: int = 1) -> void:
	amount = int(amount)
	if amount <= 0:
		return
	if invulnerable:
		return
	health = max(health - amount, 0)
	_update_health_ui()
	_on_health_changed()
	_create_damage_screen_effect()
	var camera = _get_player_camera()
	if camera:
		_apply_damage_hit_camera_shake(camera)
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
	_spawn_damage_flash_overlay()

func _spawn_damage_flash_overlay():
	var damage_flash = ColorRect.new()
	damage_effect_layer.add_child(damage_flash)
	damage_flash.color = Color(0.7, 0.0, 0.0, 0.45)
	damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween = damage_flash.create_tween()
	tween.tween_property(damage_flash, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func():
		if is_instance_valid(damage_flash):
			damage_flash.queue_free()
	)

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

func _apply_damage_hit_camera_shake(_camera: Camera2D):
	if damage_hit_shake_tween and damage_hit_shake_tween.is_valid():
		damage_hit_shake_tween.kill()
	damage_hit_shake_tween = null
	camera_damage_hit_offset = Vector2.ZERO
	_update_camera_combined_offset()

	var effective_max_health = max(1, MAX_HEALTH)
	var health_ratio = clamp(float(max(health, 0)) / float(effective_max_health), 0.0, 1.0)
	var iterations = clampi(int(round(lerp(12.0, 8.0, health_ratio))), 8, 12)
	var duration = 0.3
	var segment_duration = duration / float(iterations)
	var base_intensity = 4.0
	var max_intensity = 12.0
	var intensity = lerp(base_intensity, max_intensity, 1.0 - health_ratio)

	damage_hit_shake_tween = create_tween()
	damage_hit_shake_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	damage_hit_shake_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	for i in range(iterations):
		var offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity * 0.6, intensity * 0.6)
		)
		damage_hit_shake_tween.tween_callback(Callable(self, "_set_camera_damage_hit_offset").bind(offset))
		damage_hit_shake_tween.tween_interval(segment_duration * 0.5)
		damage_hit_shake_tween.tween_callback(Callable(self, "_set_camera_damage_hit_offset").bind(Vector2.ZERO))
		damage_hit_shake_tween.tween_interval(segment_duration * 0.5)

	damage_hit_shake_tween.tween_callback(Callable(self, "_set_camera_damage_hit_offset").bind(Vector2.ZERO))
	damage_hit_shake_tween.tween_callback(Callable(self, "_clear_damage_hit_shake"))
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
	dramatic_camera = camera
	if dramatic_shake_tween and dramatic_shake_tween.is_valid():
		dramatic_shake_tween.kill()
		camera_dramatic_offset = Vector2.ZERO
		_update_camera_combined_offset()
	var shake_intensity = 20.0
	var iterations = 8
	var total_duration = 0.8
	var segment_duration = total_duration / float(iterations)
	dramatic_shake_tween = create_tween()
	dramatic_shake_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for i in range(iterations):
		var offset = Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity))
		dramatic_shake_tween.tween_callback(Callable(self, "_set_camera_dramatic_offset").bind(offset))
		dramatic_shake_tween.tween_interval(segment_duration * 0.5)
		dramatic_shake_tween.tween_callback(Callable(self, "_set_camera_dramatic_offset").bind(Vector2.ZERO))
		dramatic_shake_tween.tween_interval(segment_duration * 0.5)
	dramatic_shake_tween.tween_callback(Callable(self, "_set_camera_dramatic_offset").bind(Vector2.ZERO))
	dramatic_shake_tween.tween_callback(Callable(self, "_clear_dramatic_shake"))

func _set_camera_dramatic_offset(offset: Vector2):
	camera_dramatic_offset = offset
	_update_camera_combined_offset()

func _clear_dramatic_shake():
	dramatic_shake_tween = null
	camera_dramatic_offset = Vector2.ZERO
	_update_camera_combined_offset()
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

func _set_camera_damage_hit_offset(offset: Vector2):
	camera_damage_hit_offset = offset
	_update_camera_combined_offset()

func _clear_damage_hit_shake():
	damage_hit_shake_tween = null
	camera_damage_hit_offset = Vector2.ZERO
	_update_camera_combined_offset()
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
func _open_synergy_menu():
	if synergy_ui:
		if synergy_ui.has_method("show_synergy_menu"):
			synergy_ui.show_synergy_menu()

func _initialize_parry_system():
	if parry_system:
		return

	parry_system = ParrySystem.new()
	parry_system.parry_window_duration = 0.3
	parry_system.failure_cooldown = 0.5
	parry_system.parry_started.connect(_on_parry_window_started)
	parry_system.parry_failed.connect(_on_parry_failed)
	parry_system.parry_window_ended.connect(_on_parry_window_ended)
	add_child(parry_system)

	parry_audio = AudioStreamPlayer2D.new()
	parry_audio.stream = PARRY_CLANG_SOUND
	parry_audio.volume_db = -1.5
	parry_audio.bus = "Master"
	add_child(parry_audio)

func _attempt_parry():
	if not parry_system:
		return

	if parry_system.start_parry():
		_play_parry_activation_effect()
	else:
		if parry_system.is_on_cooldown():
			_play_parry_denied_feedback()

func try_parry(projectile: Node) -> bool:
	if not parry_system:
		return false

	if parry_system.try_parry_hit():
		_handle_parry_success(projectile)
		return true
	return false

func _play_parry_activation_effect():
	if sprite:
		var flash_tween = create_tween()
		flash_tween.tween_property(sprite, "modulate", Color(1.2, 1.2, 1.35), 0.05)
		flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.18)

func _play_parry_denied_feedback():
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(1.0, 0.6, 0.6), 0.05)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)

func _handle_parry_success(projectile: Node):
	_clear_parry_shield_effect(true)
	_spawn_parry_success_ripple()
	if sprite:
		var flash_tween = create_tween()
		flash_tween.tween_property(sprite, "modulate", Color(1.4, 1.4, 1.4), 0.06)
		flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.22)
	if parry_audio and parry_audio.stream:
		parry_audio.pitch_scale = randf_range(0.95, 1.05)
		parry_audio.play()
	if projectile and projectile.has_method("deflect_from_player"):
		projectile.deflect_from_player(self)

func _on_parry_window_started():
	_spawn_parry_shield_effect()

func _on_parry_failed():
	_play_parry_denied_feedback()
	_clear_parry_shield_effect()

func _on_parry_window_ended(success: bool):
	if success:
		return
	_clear_parry_shield_effect()

func _spawn_parry_shield_effect():
	_clear_parry_shield_effect(true)
	var shield := Node2D.new()
	parry_shield_effect = shield
	shield.position = Vector2.ZERO
	shield.z_index = z_index + 3
	add_child(shield)

	var ring := Line2D.new()
	ring.points = _make_arc_points(48.0, 40, facing_direction, 180.0)
	ring.width = 12
	ring.default_color = Color(0.85, 0.95, 1.0, 0.9)
	ring.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ring.end_cap_mode = Line2D.LINE_CAP_ROUND
	ring.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(0.9, 0.95, 1.0, 1.0))
	gradient.add_point(1.0, Color(0.4, 0.7, 1.0, 0.1))
	ring.gradient = gradient
	shield.add_child(ring)

	shield.scale = Vector2(0.6, 0.6)
	shield.modulate = Color(1.0, 1.0, 1.0, 0.85)
	var tween := shield.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(shield, "scale", Vector2.ONE, 0.1)

func _clear_parry_shield_effect(immediate: bool = false):
	if not parry_shield_effect or not is_instance_valid(parry_shield_effect):
		parry_shield_effect = null
		return

	var shield := parry_shield_effect
	parry_shield_effect = null
	if immediate:
		shield.queue_free()
		return

	var tween := shield.create_tween()
	tween.tween_property(shield, "modulate:a", 0.0, 0.1)
	tween.tween_callback(func():
		if is_instance_valid(shield):
			shield.queue_free()
	)

func _spawn_parry_success_ripple():
	var ripple := Node2D.new()
	ripple.position = Vector2.ZERO
	ripple.z_index = z_index + 4
	add_child(ripple)

	var ring := Line2D.new()
	ring.points = _make_circle_points(24.0, 36)
	ring.width = 16
	ring.default_color = Color(1.0, 0.95, 0.6, 0.95)
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(1.0, 0.95, 0.6, 1.0))
	gradient.add_point(1.0, Color(1.0, 0.6, 0.2, 0.0))
	ring.gradient = gradient
	ring.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ring.end_cap_mode = Line2D.LINE_CAP_ROUND
	ripple.add_child(ring)

	ripple.scale = Vector2(0.5, 0.5)
	var tween := ripple.create_tween()
	tween.tween_property(ripple, "scale", Vector2(2.0, 2.0), 0.25)
	tween.parallel().tween_property(ripple, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func():
		if is_instance_valid(ripple):
			ripple.queue_free()
	)

func _setup_pause_menu():
	if pause_menu and is_instance_valid(pause_menu):
		pause_menu.queue_free()
	pause_menu = PAUSE_MENU_SCENE.instantiate()
	add_child(pause_menu)
	pause_menu.resume_requested.connect(_on_pause_menu_resume)
	pause_menu.restart_requested.connect(_on_pause_menu_restart)
	pause_menu.quit_requested.connect(_on_pause_menu_quit)
	pause_menu.hide_menu()

func _pause_game():
	if get_tree().paused:
		return
	if not pause_menu:
		_setup_pause_menu()
	stored_mouse_mode = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	is_pause_menu_active = true
	pause_menu.show_menu()

func _resume_game():
	if not get_tree().paused and not is_pause_menu_active:
		return
	get_tree().paused = false
	is_pause_menu_active = false
	if pause_menu:
		pause_menu.hide_menu()
	Input.set_mouse_mode(stored_mouse_mode)

func _on_pause_menu_resume():
	_resume_game()

func _on_pause_menu_restart():
	_resume_game()
	get_tree().reload_current_scene()

func _on_pause_menu_quit():
	_resume_game()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _make_circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points: Array[Vector2] = []
	var count: int = max(3, segments)
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	if points.size() > 0:
		points.append(points[0])
	return PackedVector2Array(points)

func _make_arc_points(radius: float, segments: int, direction: Vector2, arc_angle: float) -> PackedVector2Array:
	var points: Array[Vector2] = []
	var count: int = max(2, segments)
	var start_angle = direction.angle() - deg_to_rad(arc_angle / 2.0)
	var end_angle = direction.angle() + deg_to_rad(arc_angle / 2.0)
	var angle_step = (end_angle - start_angle) / float(count - 1)
	for i in range(count):
		var angle = start_angle + angle_step * float(i)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return PackedVector2Array(points)

func _ensure_input_actions():
	if not InputMap.has_action("pause_game"):
		InputMap.add_action("pause_game")
	else:
		InputMap.action_erase_events("pause_game")
	var pause_event := InputEventKey.new()
	pause_event.physical_keycode = KEY_ESCAPE
	pause_event.keycode = KEY_ESCAPE
	InputMap.action_add_event("pause_game", pause_event)

	if not InputMap.has_action("parry"):
		InputMap.add_action("parry")
	else:
		InputMap.action_erase_events("parry")
	var parry_event := InputEventKey.new()
	parry_event.physical_keycode = KEY_F
	parry_event.keycode = KEY_F
	InputMap.action_add_event("parry", parry_event)

	if not InputMap.has_action("melee_attack"):
		InputMap.add_action("melee_attack")
	else:
		InputMap.action_erase_events("melee_attack")
	var melee_event := InputEventKey.new()
	melee_event.physical_keycode = KEY_C
	melee_event.keycode = KEY_C
	InputMap.action_add_event("melee_attack", melee_event)

	if not InputMap.has_action("open_synergy"):
		InputMap.add_action("open_synergy")
	else:
		InputMap.action_erase_events("open_synergy")
	var synergy_event := InputEventKey.new()
	synergy_event.physical_keycode = KEY_S
	synergy_event.keycode = KEY_S
	InputMap.action_add_event("open_synergy", synergy_event)

func _exit_tree():
	if pause_menu and is_instance_valid(pause_menu):
		pause_menu.queue_free()
		pause_menu = null

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
	synergy_ui = _find_node_by_name(get_tree().current_scene, "SynergyUI")
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
	if has_meta("synergy_movement_speed"):
		base_speed *= get_meta("synergy_movement_speed")
	base_speed *= environment_speed_multiplier
	base_speed *= _speed_debuff_multiplier
	return base_speed
func get_effective_attack_damage() -> float:
	var base_damage = 1.0
	if reward_system and reward_system.has_method("get_attack_multiplier"):
		base_damage *= reward_system.get_attack_multiplier()
	if has_meta("synergy_attack_damage"):
		base_damage *= get_meta("synergy_attack_damage")
	if has_meta("corruption_damage_mult"):
		base_damage *= get_meta("corruption_damage_mult")
	return base_damage
func get_effective_sonar_range() -> float:
	var base_range = SONAR_RANGE
	if reward_system and reward_system.has_method("get_sonar_range_multiplier"):
		base_range *= reward_system.get_sonar_range_multiplier()
	if quest_system and quest_system.has_method("has_active_penalty"):
		if quest_system.has_active_penalty(quest_system.PenaltyType.SONAR_RANGE_REDUCTION):
			var penalty = quest_system.get_penalty_multiplier(quest_system.PenaltyType.SONAR_RANGE_REDUCTION)
			base_range *= (1.0 - penalty)
	if has_meta("synergy_sonar_range"):
		var synergy_mult = get_meta("synergy_sonar_range")
		base_range *= synergy_mult
	if has_meta("corruption_range_mult"):
		var corruption_mult = get_meta("corruption_range_mult")
		base_range *= corruption_mult
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
	if has_meta("synergy_cooldown_mult"):
		base_cooldown *= get_meta("synergy_cooldown_mult")
	return base_cooldown
func _on_health_changed():
	if medkit_system and medkit_system.has_method("_on_player_health_changed"):
		medkit_system._on_player_health_changed(health)
func start_dash():
	if _external_dash_active:
		return
	if not can_dash or is_dashing:
		return
	dash_direction = facing_direction
	dash_speed_override = DASH_SPEED
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
	dash_speed_override = DASH_SPEED
	_stop_dash_trail_particles()

func force_dash(direction: Vector2, speed: float, duration: float, reset_cooldown: bool = false) -> void:
	if direction.length_squared() < 0.0001:
		return
	if _external_dash_active:
		_finish_external_dash()
	elif is_dashing:
		_end_dash()
	var dash_dir: Vector2 = direction.normalized()
	var dash_speed: float = speed if speed > 0.0 else DASH_SPEED
	_cached_can_dash = can_dash
	_cached_dash_timer = dash_timer
	_external_dash_reset_cooldown = reset_cooldown
	dash_direction = dash_dir
	dash_speed_override = dash_speed
	if dash_direction.x < -0.001:
		facing_direction = Vector2.LEFT
	elif dash_direction.x > 0.001:
		facing_direction = Vector2.RIGHT
	update_sprite_direction()
	velocity = dash_direction * dash_speed_override
	is_dashing = true
	_external_dash_active = true
	if reset_cooldown:
		can_dash = true
		dash_timer = 0.0
	dash_buffer_timer = 0.0
	var dash_duration: float = max(duration, 0.05)
	var dash_duration_timer: SceneTreeTimer = get_tree().create_timer(dash_duration)
	dash_duration_timer.timeout.connect(_finish_external_dash)
	_create_dash_trail_particles()
	var dash_tween: Tween = create_tween()
	dash_tween.tween_property(self, "modulate:a", 0.7, 0.05)
	dash_tween.tween_property(self, "modulate:a", 1.0, 0.1)
func _finish_external_dash() -> void:
	if not _external_dash_active:
		return
	_end_dash()
	if _external_dash_reset_cooldown:
		can_dash = true
		dash_timer = 0.0
	else:
		can_dash = _cached_can_dash
		dash_timer = _cached_dash_timer
	_external_dash_active = false
	_external_dash_reset_cooldown = false

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
	
	if has_meta("synergy_sonar_duration"):
		base_duration *= get_meta("synergy_sonar_duration")
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

func _handle_slide_input(delta: float, direction: int):
	if is_sliding:
		slide_timer -= delta
		if slide_timer <= 0 or not is_on_floor():
			_end_slide()

	var is_ctrl_pressed = Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_SHIFT)
	var is_moving_fast = abs(velocity.x) > MIN_SLIDE_SPEED

	if is_ctrl_pressed and is_on_floor():
		print("[SLIDE DEBUG] CTRL pressed. Speed:", abs(velocity.x), " MinSpeed:", MIN_SLIDE_SPEED, " Fast enough:", is_moving_fast)

	if is_ctrl_pressed and is_on_floor() and is_moving_fast and not is_sliding and not is_dashing:
		_start_slide(direction)

func _start_slide(direction: int):
	is_sliding = true
	slide_timer = SLIDE_DURATION

	var slide_direction = sign(velocity.x) if velocity.x != 0 else facing_direction.x
	velocity.x = slide_direction * SLIDE_SPEED

	_create_slide_particles()

	if collision_shape:
		var original_shape = collision_shape.shape
		if original_shape is RectangleShape2D:
			var rect = original_shape as RectangleShape2D
			collision_shape.position.y = 4
			var new_shape = RectangleShape2D.new()
			new_shape.size = Vector2(rect.size.x, rect.size.y * 0.6)
			collision_shape.shape = new_shape

	print("[SLIDE] Started sliding at speed:", velocity.x)

func _end_slide():
	"""End slide and restore collision"""
	if not is_sliding:
		return

	is_sliding = false
	slide_timer = 0.0

	_clear_slide_hit_metadata()

	if slide_particles and is_instance_valid(slide_particles):
		slide_particles.emitting = false
		var cleanup_timer = get_tree().create_timer(slide_particles.lifetime + 0.1)
		cleanup_timer.timeout.connect(func():
			if slide_particles and is_instance_valid(slide_particles):
				slide_particles.queue_free()
				slide_particles = null
		)

	if collision_shape:
		collision_shape.position.y = 0
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = Vector2(16, 20)
		collision_shape.shape = rect_shape

	print("[SLIDE] Ended slide")

func _clear_slide_hit_metadata():
	var meta_list = get_meta_list()
	for meta_name in meta_list:
		if meta_name.begins_with("slide_hit_"):
			remove_meta(meta_name)

func _create_slide_particles():
	if slide_particles and is_instance_valid(slide_particles):
		slide_particles.queue_free()

	slide_particles = CPUParticles2D.new()
	add_child(slide_particles)
	slide_particles.position = Vector2(0, 10)
	slide_particles.emitting = true
	slide_particles.amount = 25
	slide_particles.lifetime = 0.7
	slide_particles.color = Color(0.7, 0.6, 0.5, 0.8)

	var slide_dir = -sign(velocity.x) if velocity.x != 0 else -facing_direction.x
	slide_particles.direction = Vector2(slide_dir, -0.3)
	slide_particles.spread = 35.0
	slide_particles.initial_velocity_min = 40.0
	slide_particles.initial_velocity_max = 80.0
	slide_particles.scale_amount_min = 0.3
	slide_particles.scale_amount_max = 0.8
	slide_particles.gravity = Vector2(0, 80)

func _check_slide_collision():
	var enemies = get_tree().get_nodes_in_group("enemies")
	var slide_damage_range = 40.0

	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue

		var distance = global_position.distance_to(enemy.global_position)
		if distance < slide_damage_range:
			if not has_meta("slide_hit_" + str(enemy.get_instance_id())):
				_hit_enemy_with_slide(enemy)
				set_meta("slide_hit_" + str(enemy.get_instance_id()), true)

func _hit_enemy_with_slide(enemy: Node):
	if enemy.has_method("take_damage"):
		enemy.take_damage()

	if enemy is CharacterBody2D:
		var knockback_direction = (enemy.global_position - global_position).normalized()
		var knockback_force = 300.0
		enemy.velocity = knockback_direction * knockback_force

	var impact_particles = CPUParticles2D.new()
	get_parent().add_child(impact_particles)
	impact_particles.global_position = enemy.global_position
	impact_particles.emitting = true
	impact_particles.one_shot = true
	impact_particles.amount = 15
	impact_particles.lifetime = 0.4
	impact_particles.color = Color(1.0, 0.7, 0.3, 0.9)
	impact_particles.direction = Vector2(0, -1)
	impact_particles.spread = 180.0
	impact_particles.initial_velocity_min = 50.0
	impact_particles.initial_velocity_max = 120.0
	impact_particles.scale_amount_min = 0.4
	impact_particles.scale_amount_max = 0.9
	impact_particles.gravity = Vector2(0, 200)

	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(impact_particles):
		impact_particles.queue_free()

func _start_melee_charge():
	is_charging_melee = true
	melee_charge_time = 0.0

	var melee_direction = facing_direction
	if melee_direction == Vector2.ZERO:
		melee_direction = Vector2.RIGHT

	melee_charge_arc = Line2D.new()
	add_child(melee_charge_arc)
	melee_charge_arc.z_index = z_index + 1
	melee_charge_arc.default_color = Color(1.0, 0.95, 0.6, 0.0)
	melee_charge_arc.width = 5.0 
	melee_charge_arc.end_cap_mode = Line2D.LINE_CAP_ROUND
	melee_charge_arc.begin_cap_mode = Line2D.LINE_CAP_ROUND
	melee_charge_arc.antialiased = true
	melee_charge_arc.joint_mode = Line2D.LINE_JOINT_ROUND

	melee_charge_arc.position = melee_direction * 25

func _update_melee_charge(delta: float):
	melee_charge_time += delta
	melee_charge_time = min(melee_charge_time, MELEE_CHARGE_TIME)

	if melee_charge_arc and is_instance_valid(melee_charge_arc):
		var charge_percent = melee_charge_time / MELEE_CHARGE_TIME

		var melee_direction = facing_direction
		if melee_direction == Vector2.ZERO:
			melee_direction = Vector2.RIGHT

		melee_charge_arc.position = melee_direction * 25

		var arc_degrees = 80.0
		var arc_radius = 45.0

		var aim_angle = melee_direction.angle()
		var start_angle = aim_angle - deg_to_rad(arc_degrees / 2.0)
		var end_angle = aim_angle + deg_to_rad(arc_degrees / 2.0)

		var current_end_angle = lerp(start_angle, end_angle, charge_percent)

		melee_charge_arc.clear_points()
		var point_count = 16
		for i in range(point_count):
			var t = float(i) / float(point_count - 1)
			var angle = lerp(start_angle, current_end_angle, t)
			var point = Vector2(cos(angle), sin(angle)) * arc_radius
			melee_charge_arc.add_point(point)

		var alpha = lerp(0.3, 0.95, charge_percent)
		melee_charge_arc.default_color.a = alpha

		if charge_percent >= 1.0 and (not melee_charge_particles or not is_instance_valid(melee_charge_particles)):
			_create_charge_ready_particles()

func _create_charge_ready_particles():
	melee_charge_particles = CPUParticles2D.new()
	add_child(melee_charge_particles)
	melee_charge_particles.position = Vector2(0, 0)
	melee_charge_particles.emitting = true
	melee_charge_particles.amount = 20
	melee_charge_particles.lifetime = 0.5
	melee_charge_particles.color = Color(1.0, 0.7, 0.3, 0.9)
	melee_charge_particles.direction = Vector2(0, 0)
	melee_charge_particles.spread = 360
	melee_charge_particles.initial_velocity_min = 40
	melee_charge_particles.initial_velocity_max = 80
	melee_charge_particles.scale_amount_min = 0.3
	melee_charge_particles.scale_amount_max = 0.7
	melee_charge_particles.gravity = Vector2(0, -50)
	print("[MELEE] FULLY CHARGED! Particles bursting!")

func _release_melee_charge():
	is_charging_melee = false
	var charge_percent = melee_charge_time / MELEE_CHARGE_TIME

	if melee_charge_arc and is_instance_valid(melee_charge_arc):
		melee_charge_arc.queue_free()
		melee_charge_arc = null
	if melee_charge_particles and is_instance_valid(melee_charge_particles):
		melee_charge_particles.emitting = false
		melee_charge_particles.queue_free()
		melee_charge_particles = null

	can_melee_attack = false
	melee_attack_timer = MELEE_COOLDOWN

	var melee_direction = facing_direction
	if melee_direction == Vector2.ZERO:
		melee_direction = Vector2.RIGHT

	if melee_charge_time < 0.3:
		_perform_instant_melee(melee_direction)
	else:
		_fire_melee_wave(melee_direction, charge_percent)

func _perform_instant_melee(melee_direction: Vector2):
	var melee_attack: MeleeAttack = MELEE_ATTACK_RESOURCE.new()
	add_child(melee_attack)
	melee_attack.setup(self, melee_direction, get_effective_attack_damage())
	if abs(melee_direction.x) > 0.01:
		facing_direction = Vector2.RIGHT if melee_direction.x > 0 else Vector2.LEFT
		update_sprite_direction()
	_play_melee_feedback()
	print("[MELEE] Quick swing")

func _fire_melee_wave(direction: Vector2, charge_percent: float):
	var wave = Area2D.new()
	wave.add_to_group("player_projectiles")
	get_parent().add_child(wave)
	wave.global_position = global_position + direction * 30

	wave.collision_layer = 0
	wave.collision_mask = 2

	var wave_arc = Line2D.new()
	wave.add_child(wave_arc)
	wave_arc.width = 5.0 
	wave_arc.default_color = Color(1.0, 0.95, 0.6, 0.95)
	wave_arc.end_cap_mode = Line2D.LINE_CAP_ROUND
	wave_arc.begin_cap_mode = Line2D.LINE_CAP_ROUND
	wave_arc.antialiased = true
	wave_arc.joint_mode = Line2D.LINE_JOINT_ROUND

	var arc_degrees = 80.0
	var arc_radius = 45.0
	var aim_angle = direction.angle()
	var start_angle = aim_angle - deg_to_rad(arc_degrees / 2.0)
	var end_angle = aim_angle + deg_to_rad(arc_degrees / 2.0)

	var point_count = 16
	for i in range(point_count):
		var t = float(i) / float(point_count - 1)
		var angle = lerp(start_angle, end_angle, t)
		var point = Vector2(cos(angle), sin(angle)) * arc_radius
		wave_arc.add_point(point)

	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 25 * (1.0 + charge_percent * 0.3)
	collision.shape = shape
	wave.add_child(collision)

	wave.set_meta("direction", direction)
	wave.set_meta("speed", MELEE_WAVE_SPEED)
	wave.set_meta("damage", get_effective_attack_damage() * MELEE_WAVE_DAMAGE_MULTIPLIER * (1.0 + charge_percent))
	wave.set_meta("lifetime", 1.5)
	wave.set_meta("birth_time", Time.get_ticks_msec() / 1000.0)
	wave.body_entered.connect(_on_wave_hit.bind(wave))
	wave.area_entered.connect(_on_wave_hit_area.bind(wave))

	var camera = get_node("Camera2D")
	if camera:
		_create_quick_camera_shake(camera, 3.0)
	_play_melee_feedback()

func _physics_process_wave_movement(delta: float):
	var waves = get_tree().get_nodes_in_group("player_projectiles")
	for wave in waves:
		if not wave.has_meta("direction"):
			continue
		var direction = wave.get_meta("direction")
		var speed = wave.get_meta("speed", MELEE_WAVE_SPEED)
		wave.global_position += direction * speed * delta
		var birth_time = wave.get_meta("birth_time", 0.0)
		var current_time = Time.get_ticks_msec() / 1000.0
		var lifetime = wave.get_meta("lifetime", 2.0)
		if current_time - birth_time > lifetime:
			_destroy_wave(wave)

func _on_wave_hit(body: Node, wave: Area2D):
	if body.has_method("take_damage"):
		var damage = wave.get_meta("damage", 1)
		for i in range(int(damage)):
			body.take_damage()
		print("[WAVE] Hit enemy for ", damage, " damage!")
		_destroy_wave(wave)

func _on_wave_hit_area(area: Area2D, wave: Area2D):
	var parent = area.get_parent()
	if parent and parent.has_method("take_damage"):
		var damage = wave.get_meta("damage", 1)
		for i in range(int(damage)):
			parent.take_damage()
		_destroy_wave(wave)

func _destroy_wave(wave: Area2D):
	if not is_instance_valid(wave):
		return
	var explosion = CPUParticles2D.new()
	get_parent().add_child(explosion)
	explosion.global_position = wave.global_position
	explosion.emitting = true
	explosion.one_shot = true
	explosion.amount = 20
	explosion.lifetime = 0.4
	explosion.color = Color(1.0, 0.8, 0.4, 0.9)
	explosion.direction = Vector2(0, -1)
	explosion.spread = 360
	explosion.initial_velocity_min = 60
	explosion.initial_velocity_max = 120
	explosion.scale_amount_min = 0.4
	explosion.scale_amount_max = 0.9
	explosion.gravity = Vector2(0, 100)
	wave.queue_free()
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(explosion):
		explosion.queue_free()

func _create_wave_sprite(charge_percent: float) -> Sprite2D:
	var sprite_node = Sprite2D.new()
	var size = 64
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size / 2, size / 2)
	for x in range(size):
		for y in range(size):
			var pos = Vector2(x, y)
			var offset = pos - center
			var angle = offset.angle()
			var dist = offset.length()
			if abs(angle) < PI * 0.5:
				var inner_radius = 12.0
				var outer_radius = 28.0
				if dist > inner_radius and dist < outer_radius:
					var alpha = 1.0 - (dist - inner_radius) / (outer_radius - inner_radius)
					alpha *= (1.0 - abs(angle) / (PI * 0.5))
					var brightness = lerp(0.8, 1.0, charge_percent)
					image.set_pixel(x, y, Color(1.0 * brightness, 0.95 * brightness, 0.6 * brightness, alpha * 0.95))
	sprite_node.texture = ImageTexture.create_from_image(image)
	sprite_node.material = CanvasItemMaterial.new()
	sprite_node.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return sprite_node

func _create_wave_texture_simple() -> ImageTexture:
	var size = 128
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size / 2, size / 2)

	for x in range(size):
		for y in range(size):
			var pos = Vector2(x, y)
			var offset = pos - center
			var angle = offset.angle()
			var dist = offset.length()

			if abs(angle) < PI * 0.5:
				var inner_radius = 25.0
				var outer_radius = 52.0
				if dist > inner_radius and dist < outer_radius:
					var alpha = 1.0 - (dist - inner_radius) / (outer_radius - inner_radius)
					alpha *= (1.0 - abs(angle) / (PI * 0.5))
					alpha = pow(alpha, 0.7)
					image.set_pixel(x, y, Color(1.0, 0.95, 0.6, alpha * 0.9))

	return ImageTexture.create_from_image(image)

func _create_quick_camera_shake(camera: Camera2D, intensity: float):
	var shake_tween = create_tween()
	for i in range(4):
		var offset_val = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		shake_tween.tween_property(camera, "offset", offset_val, 0.05)
	shake_tween.tween_property(camera, "offset", Vector2.ZERO, 0.1)
