extends CharacterBody2D
class_name Player

const SPEED = 200.0
const JUMP_VELOCITY = -400.0
const SONAR_COOLDOWN = 2.0
const SONAR_RANGE = 150.0
const MIN_LANDING_VELOCITY = 150.0
const ATTACK_COOLDOWN = 0.5

var MAX_HEALTH = 10
var sonar_timer = 0.0
var attack_timer = 0.0
var can_sonar = true
var can_attack = true
var health = MAX_HEALTH
var invulnerable = false
var invulnerable_timer = 0.0
var invulnerable_duration = 1.5
var facing_direction = Vector2.RIGHT
var sonar_direction = Vector2.RIGHT
var is_aiming_mode = false
var was_aiming_last_frame = false
var stored_aim_direction = Vector2.RIGHT
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var death_plane_y = 1000
var footstep_timer = 0.0
var base_footstep_interval = 0.4
var was_on_floor = false
var last_velocity_y = 0.0

var health_ui_layer: CanvasLayer
var health_bar_background: ColorRect
var health_bar_fill: ColorRect
var health_label: Label

var rune_ui_container: Control
var rune_slots: Array[TextureRect] = []
var rune_labels: Array[Label] = []
var rune_timers: Array[Label] = []

var cooldown_ui_layer: CanvasLayer
var sonar_cooldown_indicator: TextureProgressBar

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
	var game_manager = get_node_or_null("../GameManager")
	if game_manager and game_manager.has_method("_on_player_sonar_pulse"):
		sonar_pulse_emitted.connect(Callable(game_manager, "_on_player_sonar_pulse"))

	var rune_system = get_node("../RuneSystem")
	if rune_system:
		rune_system.rune_activated.connect(_on_rune_changed)
		rune_system.rune_deactivated.connect(_on_rune_changed)
		rune_system.rune_inventory_updated.connect(_update_rune_ui)

	_setup_health_ui()
	_setup_cooldown_ui()
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

func _setup_cooldown_ui():

	cooldown_ui_layer = CanvasLayer.new()
	cooldown_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(cooldown_ui_layer)


	var cooldown_container = VBoxContainer.new()
	cooldown_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	cooldown_container.position = Vector2(5, 5)
	cooldown_container.size = Vector2(60, 60)
	cooldown_ui_layer.add_child(cooldown_container)


	sonar_cooldown_indicator = TextureProgressBar.new()
	sonar_cooldown_indicator.custom_minimum_size = Vector2(60, 60)
	sonar_cooldown_indicator.size = Vector2(60, 60)
	sonar_cooldown_indicator.min_value = 0.0
	sonar_cooldown_indicator.max_value = 1.0
	sonar_cooldown_indicator.value = 1.0
	sonar_cooldown_indicator.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	sonar_cooldown_indicator.radial_initial_angle = -PI * 0.5
	sonar_cooldown_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var wave_texture = load("res://assets/sprites/wave.png")
	var scaled_wave_texture = _create_scaled_wave_texture(wave_texture, 60)


	sonar_cooldown_indicator.texture_under = scaled_wave_texture
	sonar_cooldown_indicator.texture_progress = scaled_wave_texture

	cooldown_container.add_child(sonar_cooldown_indicator)

func _create_scaled_wave_texture(original_texture: Texture2D, target_size: int) -> Texture2D:
	var original_image = original_texture.get_image()
	var scaled_image = Image.create(target_size, target_size, false, Image.FORMAT_RGBA8)
	scaled_image.blit_rect_mask(original_image, original_image, Rect2i(0, 0, original_image.get_width(), original_image.get_height()), Vector2i(0, 0))
	scaled_image.resize(target_size, target_size, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(scaled_image)


func _update_cooldown_ui():
	if not sonar_cooldown_indicator:
		return

	if can_sonar:

		sonar_cooldown_indicator.value = 1.0
		sonar_cooldown_indicator.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:

		var progress = 1.0 - (sonar_timer / SONAR_COOLDOWN)
		sonar_cooldown_indicator.value = progress
		sonar_cooldown_indicator.modulate = Color(0.5, 0.5, 0.5, 1.0)

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

func _physics_process(delta):
	if !can_sonar:
		sonar_timer -= delta
		if sonar_timer <= 0:
			can_sonar = true
	if !can_attack:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true


	_update_rune_ui()
	_update_cooldown_ui()
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
	if Input.is_action_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var right_click_released = was_aiming_last_frame and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if right_click_released:
		stored_aim_direction = sonar_direction

	_update_sonar_direction()
	var sonar_input = Input.is_action_pressed("sonar")
	var use_stored_direction = false
	if right_click_released:
		sonar_input = true
		use_stored_direction = true

	if sonar_input and can_sonar:
		if use_stored_direction:
			var temp_direction = sonar_direction
			sonar_direction = stored_aim_direction
			emit_sonar_pulse()
			sonar_direction = temp_direction
		else:
			emit_sonar_pulse()

	was_aiming_last_frame = is_aiming_mode
	if Input.is_action_pressed("attack") and can_attack:
		shoot_light_projectile()


	if Input.is_action_just_pressed("ui_accept"):
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
	if direction != 0:
		velocity.x = direction * SPEED
		facing_direction = Vector2.RIGHT if direction > 0 else Vector2.LEFT
		update_sprite_direction()
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * 3)
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
	is_aiming_mode = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

	if is_aiming_mode:
		var mouse_pos = get_global_mouse_position()
		var player_pos = global_position
		var direction_to_mouse = (mouse_pos - player_pos).normalized()
		sonar_direction = direction_to_mouse
		_update_camera_for_aiming(mouse_pos)
	else:
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
	var cooldown = SONAR_COOLDOWN
	if rune_system:
		cooldown *= rune_system.get_cooldown_multiplier()

	sonar_timer = cooldown
	play_sonar_sound()


	var sonar_range = SONAR_RANGE
	if rune_system:
		sonar_range *= rune_system.get_range_multiplier()

	sonar_pulse_emitted.emit(global_position, sonar_range, sonar_direction)

func shoot_light_projectile():
	if !can_attack or !light_projectile_scene:
		return
	can_attack = false
	attack_timer = ATTACK_COOLDOWN
	var projectile = light_projectile_scene.instantiate()
	get_parent().add_child(projectile)
	projectile.global_position = global_position + facing_direction * 30
	projectile.direction = facing_direction
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

func play_footstep_sound():
	if footstep_audio:
		footstep_audio.pitch_scale = randf_range(0.9, 1.1)
		footstep_audio.volume_db = randf_range(-1.5, 0)
		footstep_audio.play()

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
	_create_damage_screen_effect()
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
	damage_flash.color = Color(0.7, 0.0, 0.0, 0.4)
	damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween = damage_flash.create_tween()
	tween.tween_property(damage_flash, "modulate:a", 0.0, 0.4)
	tween.finished.connect(func(): damage_flash.queue_free())

func heal(amount: int):
	health = min(health + amount, MAX_HEALTH)
	_update_health_ui()

func set_max_health(new_max: int):
	var old_percentage = float(health) / float(MAX_HEALTH)
	MAX_HEALTH = new_max
	health = int(old_percentage * MAX_HEALTH)
	_update_health_ui()

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
