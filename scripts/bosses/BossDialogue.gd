extends Control
class_name BossDialogue

const Boss = preload("res://scripts/bosses/Boss.gd")

var boss: Boss
var dialogue_lines: Array[String]
var current_line_index: int = 0
var current_char_index: int = 0
var is_typing: bool = false
var typing_speed: float = 0.05

var dialogue_container: Control
var dialogue_background: ColorRect
var dialogue_text: RichTextLabel
var continue_prompt: Label
var audio_player: AudioStreamPlayer

var typing_timer: float = 0.0
var line_complete: bool = false
var active_typing_tween: Tween
var active_pulse_tween: Tween

signal dialogue_line_completed
signal all_dialogue_completed

const SCARY_FONT = preload("res://assets/fonts/October Crow.ttf")

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func setup_for_boss(target_boss: Boss):
	boss = target_boss
	_create_dialogue_ui()
	_setup_audio_player()

func _create_dialogue_ui():
	dialogue_container = Control.new()
	dialogue_container.name = "DialogueContainer"
	dialogue_container.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dialogue_container.anchor_left = 0.15
	dialogue_container.anchor_right = 0.85
	dialogue_container.anchor_top = 1.0
	dialogue_container.anchor_bottom = 1.0
	dialogue_container.offset_top = -180
	dialogue_container.offset_bottom = -30 
	dialogue_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dialogue_container)

	var border = ColorRect.new()
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.offset_left = -4
	border.offset_top = -4
	border.offset_right = 4
	border.offset_bottom = 4
	border.color = _get_boss_border_color()
	dialogue_container.add_child(border)

	dialogue_background = ColorRect.new()
	dialogue_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialogue_background.color = Color(0.05, 0.05, 0.08, 0.98)
	dialogue_container.add_child(dialogue_background)

	var gradient_overlay = ColorRect.new()
	gradient_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0, 0, 0, 0.3))
	gradient.add_point(1.0, Color(0, 0, 0, 0))
	gradient_overlay.color = Color(0, 0, 0, 0.2)
	dialogue_container.add_child(gradient_overlay)

	dialogue_text = RichTextLabel.new()
	dialogue_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialogue_text.offset_left = 30
	dialogue_text.offset_top = 20
	dialogue_text.offset_right = -30
	dialogue_text.offset_bottom = -40
	dialogue_text.bbcode_enabled = true
	dialogue_text.fit_content = true
	dialogue_text.scroll_active = false
	dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_text.add_theme_font_override("normal_font", SCARY_FONT)
	dialogue_text.add_theme_font_size_override("normal_font_size", 22)
	dialogue_text.add_theme_color_override("default_color", _get_boss_text_color())
	dialogue_text.add_theme_color_override("font_shadow_color", Color.BLACK)
	dialogue_text.add_theme_color_override("font_outline_color", Color.BLACK)
	dialogue_text.add_theme_constant_override("shadow_offset_x", 3)
	dialogue_text.add_theme_constant_override("shadow_offset_y", 3)
	dialogue_text.add_theme_constant_override("outline_size", 2)
	dialogue_container.add_child(dialogue_text)

	continue_prompt = Label.new()
	continue_prompt.visible = false
	dialogue_container.add_child(continue_prompt)

func _get_boss_border_color() -> Color:
	match boss.boss_type:
		Boss.BossType.DREAD:
			return Color(0.6, 0.2, 0.8, 0.8)
		Boss.BossType.WRAITH:
			return Color(0.4, 0.7, 1.0, 0.8)
		Boss.BossType.SENTINEL:
			return Color(0.8, 0.6, 0.2, 0.8)
		Boss.BossType.LORD_OF_DARKNESS:
			return Color(0.9, 0.1, 0.1, 0.8)
		_:
			return Color(0.7, 0.3, 0.3, 0.8)

func _get_boss_text_color() -> Color:
	match boss.boss_type:
		Boss.BossType.DREAD:
			return Color(0.8, 0.6, 1.0)
		Boss.BossType.WRAITH:
			return Color(0.7, 0.9, 1.0)
		Boss.BossType.SENTINEL:
			return Color(1.0, 0.9, 0.6)
		Boss.BossType.LORD_OF_DARKNESS:
			return Color(1.0, 0.3, 0.3)
		_:
			return Color(0.9, 0.7, 0.7)

func start_dialogue(lines: Array[String]):
	dialogue_lines = lines
	current_line_index = 0

	_play_dialogue_audio()

	dialogue_container.modulate.a = 0.0
	visible = true

	var fade_in = create_tween()
	fade_in.tween_property(dialogue_container, "modulate:a", 1.0, 0.5)
	await fade_in.finished

	_start_next_line()

func _start_next_line():
	if current_line_index >= dialogue_lines.size():
		_finish_all_dialogue()
		return

	current_char_index = 0
	line_complete = false
	is_typing = true
	continue_prompt.visible = false

	dialogue_text.text = ""
	_type_current_line()

func _type_current_line():
	if active_typing_tween and active_typing_tween.is_valid():
		active_typing_tween.kill()

	var current_line = dialogue_lines[current_line_index]
	var typing_speed_adjusted = _get_typing_speed_for_boss()

	active_typing_tween = create_tween()

	for i in range(current_line.length()):
		active_typing_tween.tween_callback(_add_next_character)
		active_typing_tween.tween_interval(typing_speed_adjusted)

	active_typing_tween.tween_callback(_on_line_typing_finished)

func _add_next_character():
	if current_line_index >= dialogue_lines.size():
		return

	if current_char_index < dialogue_lines[current_line_index].length():
		var current_line = dialogue_lines[current_line_index]
		var char_to_add = current_line[current_char_index]
		dialogue_text.text += char_to_add
		current_char_index += 1

		_play_typing_sound(char_to_add)

func _get_typing_speed_for_boss() -> float:
	match boss.boss_type:
		Boss.BossType.DREAD:
			return 0.04
		Boss.BossType.WRAITH:
			return randf_range(0.02, 0.06)
		Boss.BossType.SENTINEL:
			return 0.03  
		Boss.BossType.LORD_OF_DARKNESS:
			return 0.02
		_:
			return 0.03

func _play_typing_sound(character: String):
	pass

func _on_line_typing_finished():
	is_typing = false
	line_complete = true
	continue_prompt.visible = false

	dialogue_line_completed.emit()

	await get_tree().create_timer(0.1).timeout
	if line_complete and current_line_index < dialogue_lines.size():
		_advance_to_next_line()

func _input(event):
	if not visible:
		return

	if event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
		if is_typing:
			_skip_current_line_typing()

func _skip_current_line_typing():
	if current_line_index < dialogue_lines.size():
		if active_typing_tween and active_typing_tween.is_valid():
			active_typing_tween.kill()

		dialogue_text.text = dialogue_lines[current_line_index]
		current_char_index = dialogue_lines[current_line_index].length()
		_on_line_typing_finished()

func _advance_to_next_line():
	if active_pulse_tween and active_pulse_tween.is_valid():
		active_pulse_tween.kill()

	current_line_index += 1
	_start_next_line()

func _finish_all_dialogue():
	if active_typing_tween and active_typing_tween.is_valid():
		active_typing_tween.kill()
	if active_pulse_tween and active_pulse_tween.is_valid():
		active_pulse_tween.kill()

	var fade_out = create_tween()
	fade_out.tween_property(dialogue_container, "modulate:a", 0.0, 0.4)
	await fade_out.finished

	visible = false
	all_dialogue_completed.emit()

func create_boss_specific_effects():
	match boss.boss_type:
		Boss.BossType.DREAD:
			_create_shadow_effects()
		Boss.BossType.WRAITH:
			_create_ethereal_effects()
		Boss.BossType.SENTINEL:
			_create_stone_effects()
		Boss.BossType.LORD_OF_DARKNESS:
			_create_darkness_effects()

func _create_shadow_effects():
	var shadow_particles = CPUParticles2D.new()
	dialogue_container.add_child(shadow_particles)
	shadow_particles.position = Vector2(400, 75)
	shadow_particles.emitting = true
	shadow_particles.amount = 20
	shadow_particles.lifetime = 2.0
	shadow_particles.color = Color(0.2, 0.1, 0.4, 0.6)

func _create_ethereal_effects():
	var ethereal_particles = CPUParticles2D.new()
	dialogue_container.add_child(ethereal_particles)
	ethereal_particles.position = Vector2(400, 75)
	ethereal_particles.emitting = true
	ethereal_particles.amount = 15
	ethereal_particles.lifetime = 3.0
	ethereal_particles.color = Color(0.6, 0.8, 1.0, 0.4)

func _create_stone_effects():
	var dust_particles = CPUParticles2D.new()
	dialogue_container.add_child(dust_particles)
	dust_particles.position = Vector2(400, 75)
	dust_particles.emitting = true
	dust_particles.amount = 10
	dust_particles.lifetime = 1.5
	dust_particles.color = Color(0.6, 0.5, 0.3, 0.7)

func _create_darkness_effects():
	var darkness_particles = CPUParticles2D.new()
	dialogue_container.add_child(darkness_particles)
	darkness_particles.position = Vector2(400, 75)
	darkness_particles.emitting = true
	darkness_particles.amount = 30
	darkness_particles.lifetime = 2.5
	darkness_particles.color = Color(0.8, 0.1, 0.1, 0.8)

func _setup_audio_player():
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	audio_player.volume_db = 0.0
	audio_player.bus = "Master"

func _play_dialogue_audio():
	if not boss:
		return

	if boss.has_method("get_dialogue_audio_path"):
		var audio_path = boss.get_dialogue_audio_path()
		if audio_path and ResourceLoader.exists(audio_path):
			var audio_stream = load(audio_path)
			if audio_stream:
				audio_player.stream = audio_stream
				audio_player.play()
