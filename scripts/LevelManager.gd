extends Node2D


signal level_completed(level_number)
signal show_level_message(message)


var current_level: int = 1
var player_start_position: Vector2
var distance_traveled: float = 0.0
var level_complete: bool = false
var time_frozen: bool = false


var levels = [
	{"number": 1, "distance": 1000, "message": "Well done \"The Fabled One\", you survived the 1st level.... THE NEXT ONE WON'T BE THAT EASY"},
	{"number": 2, "distance": 2500, "message": "The darkness grows stronger... Level 2 complete"},
	{"number": 3, "distance": 3500, "message": "You're still alive? Impressive... Level 3 conquered"},
	{"number": 4, "distance": 5500, "message": "The shadows whisper your name... Level 4 survived"},
	{"number": 5, "distance": 8000, "message": "Final level complete... or is it?"},
]


@onready var player = $"../Player"  
@onready var ui_layer = $"../CanvasLayer"  
@onready var camera = $"../Player/Camera2D"  


var level_message_container: Control
var level_message_label: RichTextLabel
var screen_overlay: ColorRect


var typewriter_speed: float = 0.08  
var character_variation: float = 0.03  
var current_text: String = ""
var text_index: int = 0
var typewriter_timer: Timer


var typewriter_sound: AudioStreamPlayer


var shake_strength: float = 0.0
var shake_fade: float = 5.0
var original_camera_offset: Vector2


var flicker_timer: Timer
var is_flickering: bool = false

func _ready():
	
	if player:
		player_start_position = player.global_position
	
	
	if camera:
		original_camera_offset = camera.offset
	
	
	_setup_ui()
	
	
	_setup_audio()
	
	
	_setup_atmospheric_effects()
	
	
	level_completed.connect(_on_level_completed)
	show_level_message.connect(_display_level_message)

func _process(delta):
	
	if shake_strength > 0 and camera:
		shake_strength = max(shake_strength - shake_fade * delta, 0)
		camera.offset = original_camera_offset + _get_random_shake_offset()
	
	
	if time_frozen:
		return
	
	if not player or level_complete:
		return
	
	
	var current_distance = player.global_position.x - player_start_position.x
	distance_traveled = max(0, current_distance)  
	
	
	_check_level_progress()

func _get_random_shake_offset() -> Vector2:
	return Vector2(
		randf_range(-shake_strength, shake_strength),
		randf_range(-shake_strength, shake_strength)
	)

func _check_level_progress():
	if current_level > levels.size():
		return
	
	var required_distance = levels[current_level - 1]["distance"]
	
	if distance_traveled >= required_distance and not level_complete:
		level_complete = true
		emit_signal("level_completed", current_level)

func _on_level_completed(level_num):
	
	_freeze_time()
	
	
	_apply_screen_shake(30.0)
	
	
	_start_atmospheric_effects()
	
	
	await get_tree().create_timer(0.5).timeout
	
	
	var message = levels[level_num - 1]["message"]
	emit_signal("show_level_message", message)
	
	
	await get_tree().create_timer(len(message) * (typewriter_speed + character_variation) + 3.0).timeout
	
	
	await _fade_out_message()
	_stop_atmospheric_effects()
	
	
	_unfreeze_time()
	
	
	_start_next_level()

func _freeze_time():
	time_frozen = true
	
	
	get_tree().paused = true
	
	
	if ui_layer:
		ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	
	
	if player and player.has_method("set_physics_process"):
		player.set_physics_process(false)
		player.set_process(false)
	
	
	if screen_overlay:
		var tween = create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  
		tween.tween_property(screen_overlay, "color:a", 0.7, 0.3)

func _unfreeze_time():
	time_frozen = false
	get_tree().paused = false
	
	
	if player and player.has_method("set_physics_process"):
		player.set_physics_process(true)
		player.set_process(true)
	
	
	if screen_overlay:
		var tween = create_tween()
		tween.tween_property(screen_overlay, "color:a", 0.0, 0.5)

func _apply_screen_shake(strength: float):
	shake_strength = strength

func _start_next_level():
	current_level += 1
	level_complete = false
	
	print("Started level ", current_level)
	

func _display_level_message(message: String):
	if not level_message_label:
		print("ERROR: level_message_label not found!")
		return
	
	print("Displaying message: ", message)  
	
	
	level_message_container.visible = true
	level_message_container.modulate.a = 0.0
	level_message_label.text = ""
	current_text = message
	text_index = 0
	
	
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  
	tween.tween_property(level_message_container, "modulate:a", 1.0, 1.0)  
	tween.tween_callback(_start_typewriter)

func _start_typewriter():
	if typewriter_timer:
		
		typewriter_timer.start(randf_range(0.1, 0.3))

func _typewriter_tick():
	if text_index < current_text.length():
		
		level_message_label.text = current_text.substr(0, text_index + 1)
		text_index += 1
		
		
		if typewriter_sound:
			typewriter_sound.pitch_scale = randf_range(0.9, 1.1)
			typewriter_sound.volume_db = randf_range(-12, -10)  
			typewriter_sound.play()
		
		
		typewriter_timer.start(typewriter_speed + randf_range(-character_variation, character_variation))
	else:
		
		typewriter_timer.stop()
		
		
		if typewriter_sound:
			typewriter_sound.pitch_scale = 0.8
			typewriter_sound.volume_db = -8
			typewriter_sound.play()

func _fade_out_message() -> void:
	if level_message_container:
		var tween = create_tween()
		tween.tween_property(level_message_container, "modulate:a", 0.0, 1.5)  
		await tween.finished
		level_message_container.visible = false

func _setup_ui():
	if not ui_layer:
		ui_layer = CanvasLayer.new()
		ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS  
		get_parent().add_child(ui_layer)
	
	
	screen_overlay = ColorRect.new()
	screen_overlay.color = Color(0, 0, 0, 0)
	screen_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(screen_overlay)
	
	
	level_message_container = Control.new()
	level_message_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	level_message_container.visible = false
	ui_layer.add_child(level_message_container)
	
	
	level_message_label = RichTextLabel.new()
	level_message_label.size = Vector2(800, 200)
	level_message_label.position = Vector2(-400, -100)  
	level_message_label.bbcode_enabled = true
	level_message_label.fit_content = true
	level_message_label.scroll_active = false
	level_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	
	var font_path = "res://assets/fonts/October Crow.ttf"  
	if ResourceLoader.exists(font_path):
		var custom_font = load(font_path)
		level_message_label.add_theme_font_override("normal_font", custom_font)
		level_message_label.add_theme_font_override("bold_font", custom_font)
	
	
	level_message_label.add_theme_font_size_override("normal_font_size", 48)
	level_message_label.add_theme_font_size_override("bold_font_size", 48)
	level_message_label.add_theme_color_override("default_color", Color(0.9, 0.1, 0.1))  
	level_message_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	level_message_label.add_theme_constant_override("shadow_offset_x", 3)
	level_message_label.add_theme_constant_override("shadow_offset_y", 3)
	level_message_label.add_theme_constant_override("shadow_outline_size", 5)
	
	
	level_message_label.add_theme_color_override("font_outline_color", Color(0.3, 0, 0))
	level_message_label.add_theme_constant_override("outline_size", 2)
	
	level_message_container.add_child(level_message_label)
	
	
	typewriter_timer = Timer.new()
	typewriter_timer.one_shot = true  
	typewriter_timer.timeout.connect(_typewriter_tick)
	typewriter_timer.process_mode = Node.PROCESS_MODE_ALWAYS  
	add_child(typewriter_timer)
	
	
	if ResourceLoader.exists(font_path):
		var custom_font = load(font_path)
	
	
	if ResourceLoader.exists(font_path):
		var custom_font = load(font_path)

func _setup_audio():
	
	typewriter_sound = AudioStreamPlayer.new()
	typewriter_sound.stream = load("res://assets/sfx/typewriter.mp3")  
	typewriter_sound.volume_db = -12
	typewriter_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(typewriter_sound)

func _setup_atmospheric_effects():
	
	flicker_timer = Timer.new()
	flicker_timer.wait_time = 0.15
	flicker_timer.timeout.connect(_screen_flicker)
	flicker_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(flicker_timer)

func _start_atmospheric_effects():
	
	is_flickering = true
	flicker_timer.start()

func _stop_atmospheric_effects():
	
	is_flickering = false
	flicker_timer.stop()
	
	
	if screen_overlay:
		var tween = create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(screen_overlay, "color:a", 0.7, 0.5)

func _screen_flicker():
	if not is_flickering or not screen_overlay:
		return
	
	
	var target_alpha = randf_range(0.5, 0.9)
	var flicker_duration = randf_range(0.05, 0.15)
	
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(screen_overlay, "color:a", target_alpha, flicker_duration)

func _game_completed():
	
	_freeze_time()
	_apply_screen_shake(50.0)
	
	
	_start_atmospheric_effects()
	
	var completion_message = "[center][wave amp=50 freq=2]You survived all levels...[/wave]\n[shake rate=10 level=20]but the nightmare never ends...[/shake][/center]"
	
	
	level_message_label.bbcode_enabled = true
	emit_signal("show_level_message", completion_message)
	
	await get_tree().create_timer(6.0).timeout
	
	
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(screen_overlay, "color:a", 1.0, 2.0)
	
	await tween.finished
