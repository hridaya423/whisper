extends Node2D
class_name LightMoth

const _ANIMATION_NAME := "fly"
const _MOTH_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/moth1.png"),
	preload("res://assets/sprites/moth2.png")
]

@export var follow_offset: Vector2 = Vector2(32.0, -28.0)
@export var hover_amplitude: float = 8.0
@export var hover_speed: float = 2.0
@export var follow_lerp_speed: float = 6.0
@export var hover_noise_amplitude: float = 3.0
@export var hover_noise_speed: float = 1.4
@export var lateral_flap_amplitude: float = 5.0
@export var lateral_flap_speed: float = 2.6
@export var body_glow_color: Color = Color(1.0, 0.94, 0.76, 0.4)
@export var animation_speed: float = 7.0
@export var lateral_noise_range: float = 10.0
@export var sprite_scale: Vector2 = Vector2(0.15, 0.15)
@export var enable_ambient_sonar: bool = true
@export var show_ambient_rings: bool = false
@export var dialogue_offset: Vector2 = Vector2(0.0, -28.0)
@export var dialogue_size: Vector2 = Vector2(65.0, 22.0)
@export var dialogue_padding: Vector2 = Vector2(4.0, 2.0)
@export var dialogue_bg_color: Color = Color(0.08, 0.06, 0.12, 0.95)
@export var dialogue_text_color: Color = Color(0.95, 0.9, 1.0, 0.96)
@export var dialogue_font_size: int = 7 t
@export_range(0, 64, 1) var dialogue_corner_radius: int = 3 
@export_range(32.0, 320.0, 1.0) var dialogue_max_width: float = 100.0  
@export_range(24.0, 200.0, 1.0) var dialogue_max_height: float = 40.0
@export var dialogue_truncate_indicator: String = "..."
@export var dialogue_font: Font = preload("res://assets/fonts/October Crow.ttf")
@export var dialogue_use_typewriter: bool = true
@export var dialogue_typewriter_speed: float = 28.0
@export var dialogue_text_prefix: String = "[wave amp=6 freq=3][shake rate=18 level=3]"
@export var dialogue_text_suffix: String = "[/shake][/wave]"

@export var sonar_radius: float = 50.0
@export var corruption_glow_color: Color = Color(0.52, 0.28, 0.72, 0.4)
@export_range(0.0, 1.0, 0.01) var corruption_min_sonar_multiplier: float = 0.45
@export_range(0.0, 1.0, 0.01) var corruption_min_brightness: float = 0.4
@export_range(1, 16, 1) var corruption_damage_ramp_steps: int = 6
var _player: Player
var _hover_time: float = 0.0
var _last_facing_x: float = 1.0
var _noise_time: float = 0.0
var _hover_noise: FastNoiseLite = FastNoiseLite.new()
var _sonar_system: Node = null
var _lateral_phase: float = 0.0
var _sprite: AnimatedSprite2D
var _current_animation_speed: float = -1.0
var _ambient_active: bool = false
var _dialogue_container: Control
var _dialogue_background: Panel
var _dialogue_label: RichTextLabel
var _dialogue_timer: float = 0.0
var _dialogue_stylebox: StyleBoxFlat
var _dialogue_full_text: String = ""
var _dialogue_typewriter_active: bool = false
var _dialogue_visible_chars: float = 0.0

static var _instance: LightMoth
var _base_sonar_radius: float = 0.0
var _base_body_glow_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var _base_sprite_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)
var _current_corruption_level: float = -1.0
var _current_sonar_radius: float = 0.0
var _current_ambient_color: Color = Color(1.0, 1.0, 1.0, 1.0)

func _enter_tree() -> void:
	_instance = self

func _ready():
	_hover_noise.seed = randi()
	_hover_noise.frequency = 0.8
	_hover_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_hover_noise.fractal_octaves = 3

	_setup_sprite()
	_setup_dialogue_ui()

	if _player == null:
		_player = get_parent() as Player
		if _player == null:
			_player = get_tree().get_first_node_in_group("player") as Player
	_resolve_sonar_system()

	if _player:
		global_position = _player.global_position + follow_offset
	_base_sonar_radius = sonar_radius
	_base_body_glow_color = body_glow_color
	if _sprite:
		_base_sprite_modulate = _sprite.modulate
	_current_sonar_radius = _base_sonar_radius
	_current_ambient_color = _base_body_glow_color

func set_player(player: Player) -> void:
	_player = player
	_resolve_sonar_system()
	if _player:
		global_position = _player.global_position + follow_offset

func _process(delta: float) -> void:
	if _player == null:
		return

	_hover_time += delta * hover_speed
	_noise_time += delta * hover_noise_speed
	_lateral_phase += delta * lateral_flap_speed

	var hover_offset: Vector2 = Vector2.ZERO
	hover_offset.y = sin(_hover_time) * hover_amplitude
	var noise_sample: float = _hover_noise.get_noise_1d(_noise_time)
	hover_offset.y += noise_sample * hover_noise_amplitude
	hover_offset.x += noise_sample * (hover_noise_amplitude * 0.6)
	hover_offset.x += cos(_lateral_phase) * lateral_flap_amplitude
	if _sprite and animation_speed != _current_animation_speed:
		var frames := _sprite.sprite_frames
		if frames:
			frames.set_animation_speed(_ANIMATION_NAME, animation_speed)
		_current_animation_speed = animation_speed

	if _player.facing_direction.length_squared() > 0.01:
		var facing_x: float = sign(_player.facing_direction.x)
		if facing_x != 0.0:
			_last_facing_x = facing_x

	var base_offset: Vector2 = follow_offset
	base_offset.x = abs(follow_offset.x) * _last_facing_x
	base_offset.x += _hover_noise.get_noise_1d(_noise_time + 97.0) * lateral_noise_range
	var target_position: Vector2 = _player.global_position + base_offset + hover_offset

	var lerp_factor: float = clamp(delta * follow_lerp_speed, 0.0, 1.0)
	global_position = global_position.lerp(target_position, lerp_factor)

	if _sprite and _sprite.scale != sprite_scale:
		_sprite.scale = sprite_scale

	_update_corruption_state()

	if enable_ambient_sonar:
		_update_sonar_system()
	else:
		_clear_ambient_sonar()

	if _dialogue_typewriter_active and _dialogue_label:
		_dialogue_visible_chars += dialogue_typewriter_speed * delta
		_dialogue_label.visible_characters = int(_dialogue_visible_chars)
		if _dialogue_label.visible_characters >= _dialogue_label.get_total_character_count():
			_dialogue_label.visible_characters = -1
			_dialogue_typewriter_active = false

	if _dialogue_timer > 0.0:
		_dialogue_timer -= delta
		if _dialogue_timer <= 0.0:
			_hide_dialogue()

	_update_dialogue_position()

func _exit_tree() -> void:
	_clear_ambient_sonar(true)
	if _instance == self:
		_instance = null

func _resolve_sonar_system() -> void:
	if _player:
		_sonar_system = _player.get_node_or_null("../SonarSystem")
	if _sonar_system == null:
		_sonar_system = get_tree().get_first_node_in_group("sonar_system")

func _update_sonar_system() -> void:
	if not enable_ambient_sonar:
		return
	if sonar_radius <= 0.0:
		return
	if _sonar_system == null or not is_instance_valid(_sonar_system):
		_resolve_sonar_system()
	if _sonar_system and _sonar_system.has_method("set_ambient_sonar"):
		var ambient_color := _current_ambient_color
		if not show_ambient_rings:
			ambient_color.a = 0.0
		_sonar_system.call("set_ambient_sonar", global_position, _current_sonar_radius, ambient_color)
		_ambient_active = true

func _clear_ambient_sonar(force: bool = false) -> void:
	if _ambient_active or force:
		if _sonar_system == null or not is_instance_valid(_sonar_system):
			_resolve_sonar_system()
		if _sonar_system and _sonar_system.has_method("clear_ambient_sonar"):
			_sonar_system.call("clear_ambient_sonar")
		_ambient_active = false

func _setup_sprite() -> void:
	if _sprite:
		return

	_sprite = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.add_animation(_ANIMATION_NAME)
	frames.set_animation_loop(_ANIMATION_NAME, true)
	frames.set_animation_speed(_ANIMATION_NAME, animation_speed)

	for texture in _MOTH_TEXTURES:
		frames.add_frame(_ANIMATION_NAME, texture)

	_sprite.sprite_frames = frames
	_sprite.animation = _ANIMATION_NAME
	_sprite.z_index = 1
	_sprite.scale = sprite_scale
	_sprite.play()
	add_child(_sprite)
	_current_animation_speed = animation_speed

func _setup_dialogue_ui() -> void:
	if _dialogue_container:
		return

	_dialogue_container = Control.new()
	_dialogue_container.name = "DialogueBubble"
	_dialogue_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_container.visible = false
	_dialogue_container.size = dialogue_size
	_dialogue_container.pivot_offset = dialogue_size * 0.5
	add_child(_dialogue_container)

	_dialogue_background = Panel.new()
	_dialogue_background.name = "Background"
	_dialogue_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialogue_stylebox = StyleBoxFlat.new()
	_dialogue_stylebox.bg_color = dialogue_bg_color
	_dialogue_stylebox.corner_radius_top_left = dialogue_corner_radius
	_dialogue_stylebox.corner_radius_top_right = dialogue_corner_radius
	_dialogue_stylebox.corner_radius_bottom_left = dialogue_corner_radius
	_dialogue_stylebox.corner_radius_bottom_right = dialogue_corner_radius
	_dialogue_background.add_theme_stylebox_override("panel", _dialogue_stylebox)
	_dialogue_container.add_child(_dialogue_background)

	_dialogue_label = RichTextLabel.new()
	_dialogue_label.name = "DialogueLabel"
	_dialogue_label.bbcode_enabled = true
	_dialogue_label.fit_content = true
	_dialogue_label.scroll_active = false
	_dialogue_label.scroll_following = false
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dialogue_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialogue_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialogue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_container.add_child(_dialogue_label)

	_update_dialogue_position()

func show_dialogue(text: String = "", duration: float = 4.0) -> void:
	_setup_dialogue_ui()
	if not _dialogue_container or not _dialogue_label:
		return

	var trimmed_text := text.strip_edges()
	if trimmed_text.is_empty():
		trimmed_text = "..."
	_set_dialogue_text(trimmed_text)

	if dialogue_use_typewriter:
		_dialogue_label.visible_characters = 0
		_dialogue_visible_chars = 0.0
		_dialogue_typewriter_active = true
	else:
		_dialogue_label.visible_characters = -1
		_dialogue_typewriter_active = false
	_dialogue_container.size = dialogue_size
	_dialogue_container.visible = true
	_dialogue_timer = max(duration, 0.25)
	_update_dialogue_position()

func _hide_dialogue() -> void:
	if _dialogue_container:
		_dialogue_container.visible = false
	_dialogue_timer = 0.0
	_dialogue_typewriter_active = false
	if _dialogue_label:
		_dialogue_label.visible_characters = -1

func _update_dialogue_position() -> void:
	if not _dialogue_container:
		return
	_adjust_dialogue_size()
	_apply_dialogue_style()
	if _dialogue_label:
		_dialogue_label.position = dialogue_padding
	var offset = _get_dialogue_offset()
	_dialogue_container.position = offset

func _get_dialogue_offset() -> Vector2:
	var offset = dialogue_offset
	if _last_facing_x < 0.0:
		offset.x = -dialogue_offset.x
	return offset

func _set_dialogue_text(raw_text: String) -> void:
	if not _dialogue_label:
		return
	_apply_dialogue_style()
	var prepared_text := _truncate_text_to_fit(raw_text)
	_dialogue_full_text = prepared_text
	_dialogue_label.bbcode_text = _compose_display_text(prepared_text)
	_adjust_dialogue_size()

static func show_global_dialogue(text: String = "", duration: float = 4.0) -> void:
	if _instance:
		_instance.show_dialogue(text, duration)

static func has_instance() -> bool:
	return _instance != null

func _apply_dialogue_style() -> void:
	if _dialogue_stylebox:
		_dialogue_stylebox.bg_color = dialogue_bg_color
		_dialogue_stylebox.corner_radius_top_left = dialogue_corner_radius
		_dialogue_stylebox.corner_radius_top_right = dialogue_corner_radius
		_dialogue_stylebox.corner_radius_bottom_left = dialogue_corner_radius
		_dialogue_stylebox.corner_radius_bottom_right = dialogue_corner_radius
	if _dialogue_label:
		_dialogue_label.add_theme_color_override("default_color", dialogue_text_color)
		_dialogue_label.add_theme_color_override("font_shadow_color", Color(0.1, 0.0, 0.15, 0.9))
		_dialogue_label.add_theme_constant_override("shadow_offset_x", 2)
		_dialogue_label.add_theme_constant_override("shadow_offset_y", 2)
		_dialogue_label.add_theme_constant_override("shadow_outline_size", 2)
		if dialogue_font:
			_dialogue_label.add_theme_font_override("normal_font", dialogue_font)
		_dialogue_label.add_theme_font_size_override("normal_font_size", dialogue_font_size)
		_dialogue_label.fit_content = false
		_dialogue_label.scroll_active = false
		_dialogue_label.scroll_following = false
		_dialogue_label.size_flags_horizontal = Control.SIZE_FILL
		_dialogue_label.size_flags_vertical = Control.SIZE_FILL

func _adjust_dialogue_size() -> void:
	if not _dialogue_container or not _dialogue_label:
		return
	var padding: Vector2 = dialogue_padding * 2.0
	var char_width: float = _approx_char_width()
	var line_height: float = _approx_line_height()
	var available_width: float = max(32.0, dialogue_max_width - padding.x)
	var max_chars_per_line: int = max(4, int(available_width / max(char_width, 1.0)))
	var words: Array = _dialogue_full_text.split(" ", false)
	if words.is_empty():
		words = [_dialogue_full_text]
	var line_lengths: Array = _approximate_lines(words, max_chars_per_line)
	var widest_chars: int = 0
	for length_value in line_lengths:
		var line_chars: int = int(length_value)
		if line_chars > widest_chars:
			widest_chars = line_chars
	if widest_chars <= 0:
		widest_chars = max(1, _dialogue_full_text.length())
	var target_width: float = clamp(padding.x + widest_chars * char_width, dialogue_size.x, dialogue_max_width)
	var target_height: float = clamp(dialogue_padding.y * 2.0 + float(line_lengths.size()) * line_height, dialogue_size.y, dialogue_max_height)
	var final_size := Vector2(target_width, target_height)
	_dialogue_container.size = final_size
	_dialogue_container.pivot_offset = final_size * 0.5
	var label_size := final_size - dialogue_padding * 2.0
	label_size.x = max(8.0, label_size.x)
	label_size.y = max(8.0, label_size.y)
	_dialogue_label.custom_minimum_size = label_size
	_dialogue_label.size = label_size

func _truncate_text_to_fit(raw_text: String) -> String:
	var clean_text := raw_text.strip_edges()
	if clean_text.is_empty():
		return clean_text
	var words: Array = clean_text.split(" ", false)
	if words.is_empty():
		words = [clean_text]
	var padding: Vector2 = dialogue_padding * 2.0
	var char_width: float = _approx_char_width()
	var line_height: float = _approx_line_height()
	var max_chars_per_line: int = max(4, int((dialogue_max_width - padding.x) / max(char_width, 1.0)))
	var max_lines: int = max(1, int((dialogue_max_height - padding.y) / max(line_height, 1.0)))
	var indicator := dialogue_truncate_indicator.strip_edges()
	var start_index := 0
	while start_index < words.size():
		var candidate_words: Array = words.slice(start_index, words.size())
		if start_index > 0 and indicator != "":
			candidate_words.insert(0, indicator)
		if not _needs_truncation_with_words(candidate_words, max_chars_per_line, max_lines):
			return " ".join(candidate_words).strip_edges()
		start_index += 1
	if indicator != "":
		return indicator
	return words.back()

func _needs_truncation_with_words(words: Array, max_chars_per_line: int, max_lines: int) -> bool:
	if words.is_empty():
		return false
	var line_lengths: Array = _approximate_lines(words, max_chars_per_line)
	return line_lengths.size() > max_lines

func _approximate_lines(words: Array, max_chars_per_line: int) -> Array:
	var lines: Array = []
	var current_length: int = 0
	for raw_word in words:
		var word: String = String(raw_word)
		if word.is_empty():
			continue
		var word_len: int = word.length()
		if word_len >= max_chars_per_line:
			if current_length > 0:
				lines.append(current_length)
				current_length = 0
			lines.append(max_chars_per_line)
			continue
		var required: int = word_len
		if current_length > 0:
			required += 1
		if current_length > 0 and current_length + required > max_chars_per_line:
			lines.append(current_length)
			current_length = word_len
		else:
			current_length += required
	if current_length > 0 or lines.is_empty():
		lines.append(max(1, current_length))
	return lines

func _approx_char_width() -> float:
	return max(4.0, float(dialogue_font_size)) * 0.58

func _approx_line_height() -> float:
	return max(8.0, float(dialogue_font_size)) * 1.35

func _compose_display_text(core_text: String) -> String:
	var composed := core_text
	if dialogue_text_prefix != "":
		composed = dialogue_text_prefix + composed
	if dialogue_text_suffix != "":
		composed += dialogue_text_suffix
	return composed

func _update_corruption_state() -> void:
	var target_level: float = _calculate_corruption_level()
	if abs(target_level - _current_corruption_level) < 0.001:
		return
	_current_corruption_level = target_level
	_apply_corruption_visuals()

func _calculate_corruption_level() -> float:
	if _player == null:
		return 0.0
	var corruption_level: float = 0.0
	if _player.corruption_active:
		var ramp_steps: int = maxi(1, corruption_damage_ramp_steps)
		var damage_step: int = maxi(0, _player.corruption_damage - 1)
		var damage_ratio: float = clampf(float(damage_step) / float(ramp_steps), 0.0, 1.0)
		corruption_level = 0.5 + damage_ratio * 0.5
	else:
		var start_time: float = maxf(_player.corruption_start_time, 0.001)
		var timer_ratio: float = clampf(_player.corruption_timer / start_time, 0.0, 1.0)
		corruption_level = timer_ratio * 0.5
	return clampf(corruption_level, 0.0, 1.0)

func _apply_corruption_visuals() -> void:
	var sonar_multiplier: float = lerpf(1.0, corruption_min_sonar_multiplier, _current_corruption_level)
	_current_sonar_radius = _base_sonar_radius * sonar_multiplier
	var brightness: float = lerpf(1.0, corruption_min_brightness, _current_corruption_level)
	var ambient_target: Color = _base_body_glow_color.lerp(corruption_glow_color, _current_corruption_level)
	ambient_target.a = _base_body_glow_color.a * brightness
	_current_ambient_color = ambient_target
	body_glow_color = ambient_target
	if _sprite:
		var corruption_tint: Color = Color(corruption_glow_color.r, corruption_glow_color.g, corruption_glow_color.b, 1.0)
		var sprite_color: Color = _base_sprite_modulate.lerp(corruption_tint, _current_corruption_level)
		sprite_color.a = brightness
		_sprite.modulate = sprite_color
