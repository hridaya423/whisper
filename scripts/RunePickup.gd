extends Sprite2D
class_name RunePickup
@export var rune_type: RuneSystem.RuneType = RuneSystem.RuneType.RANGE_AMPLIFIER
@export var pickup_distance: float = 40.0
var rune_system: RuneSystem
var collected = false
var time_offset: float
var audio_player: AudioStreamPlayer2D
var dialogue_player: AudioStreamPlayer2D
var dialogue_played = false
func _ready():
	var paths_to_try = [
		"../../RuneSystem",
		"../RuneSystem",
		"/root/Main/RuneSystem",
		get_tree().current_scene.get_node("RuneSystem") if get_tree().current_scene.has_node("RuneSystem") else null
	]
	for path in paths_to_try:
		if path and is_instance_valid(path):
			rune_system = path
			break
		elif typeof(path) == TYPE_STRING:
			var node = get_node_or_null(path)
			if node:
				rune_system = node
				break
	if not rune_system:
		rune_system = _find_node_by_name(get_tree().current_scene, "RuneSystem")
	time_offset = randf() * TAU
	setup_visual()
	setup_audio()
	setup_dialogue()
func _find_node_by_name(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	for child in node.get_children():
		var result = _find_node_by_name(child, name)
		if result:
			return result
	return null
func setup_visual():
	texture = load("res://assets/sprites/rune_longersonar.png")
	var rune_colors = {
		RuneSystem.RuneType.RANGE_AMPLIFIER: Color(1.2, 0.6, 0.6),
		RuneSystem.RuneType.DURATION_CRYSTAL: Color(0.6, 1.2, 0.6),
		RuneSystem.RuneType.RAPID_PULSE: Color(0.6, 0.6, 1.2)
	}
	modulate = rune_colors.get(rune_type, Color.WHITE)
	z_index = 100
func setup_audio():
	audio_player = AudioStreamPlayer2D.new()
	add_child(audio_player)
	audio_player.volume_db = -10
	audio_player.pitch_scale = 1.2
func setup_dialogue():
	dialogue_player = AudioStreamPlayer2D.new()
	add_child(dialogue_player)
	dialogue_player.volume_db = -5
func play_rune_dialogue():
	if dialogue_played:
		return
	var audio_path = "res://assets/dialogue/runes.mp3"
	if ResourceLoader.exists(audio_path):
		var audio_stream = load(audio_path)
		dialogue_player.stream = audio_stream
		dialogue_player.play()
		dialogue_played = true
		print("Playing rune dialogue")
var player_nearby = false
var current_player = null
func _process(delta):
	if collected:
		return
	var time = Time.get_time_dict_from_system()["second"] + time_offset
	position.y += sin(time * 2.0) * 0.5 - sin((time - delta) * 2.0) * 0.5
	var base_pulse = 0.7 + sin(time * 4.0) * 0.3
	var pulse_intensity = 5.0 if player_nearby else 4.0
	modulate.a = 0.5 + sin(time * pulse_intensity) * (0.3 if player_nearby else 0.2)
	rotation = sin(time * 1.5) * 0.2
	check_player_proximity()
	if player_nearby and Input.is_action_just_pressed("interact"):
		collect_rune()
func check_player_proximity():
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		player_nearby = false
		current_player = null
		return
	var distance = global_position.distance_to(player.global_position)
	var was_nearby = player_nearby
	player_nearby = distance <= pickup_distance
	if player_nearby and not was_nearby:
		current_player = player
	elif not player_nearby and was_nearby:
		current_player = null
func collect_rune():
	if collected:
		return
	if not rune_system:
		return
	collected = true
	var collection_success = rune_system.collect_rune(rune_type)
	if not collection_success:
		await play_rejection_animation()
		collected = false
		return
	play_pickup_sound()
	play_rune_dialogue()
	await play_pickup_animation()
	await show_rune_info()
	queue_free()
func play_rejection_animation():
	var camera = get_viewport().get_camera_2d()
	if camera:
		_apply_screen_shake(camera, 1.0)
	var canvas_layer = CanvasLayer.new()
	canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene.add_child(canvas_layer)
	var x_container = Control.new()
	x_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	x_container.size = Vector2(400, 400)
	x_container.position = Vector2(-200, -200)
	canvas_layer.add_child(x_container)
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(overlay)
	canvas_layer.move_child(overlay, 0)
	var x_bar1 = ColorRect.new()
	x_bar1.color = Color(1.0, 0.0, 0.0, 1.0)
	x_bar1.size = Vector2(400, 40)
	x_bar1.position = Vector2(0, 180)
	x_bar1.rotation = deg_to_rad(45)
	x_bar1.pivot_offset = Vector2(200, 20)
	x_container.add_child(x_bar1)
	var x_bar2 = ColorRect.new()
	x_bar2.color = Color(1.0, 0.0, 0.0, 1.0)
	x_bar2.size = Vector2(400, 40)
	x_bar2.position = Vector2(0, 180)
	x_bar2.rotation = deg_to_rad(-45)
	x_bar2.pivot_offset = Vector2(200, 20)
	x_container.add_child(x_bar2)
	var text_label = RichTextLabel.new()
	text_label.size = Vector2(400, 80)
	text_label.position = Vector2(0, -120)
	text_label.bbcode_enabled = true
	text_label.fit_content = true
	text_label.scroll_active = false
	var font_path = "res://assets/fonts/Federant-Regular.ttf"
	if ResourceLoader.exists(font_path):
		var custom_font = load(font_path)
		text_label.add_theme_font_override("normal_font", custom_font)
	text_label.add_theme_font_size_override("normal_font_size", 36)
	text_label.add_theme_color_override("default_color", Color(1.0, 0.2, 0.2))
	text_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	text_label.add_theme_constant_override("shadow_offset_x", 3)
	text_label.add_theme_constant_override("shadow_offset_y", 3)
	text_label.text = "[center][shake rate=15 level=10]INVENTORY FULL![/shake][/center]"
	canvas_layer.add_child(text_label)
	x_container.scale = Vector2(0.1, 0.1)
	x_container.modulate.a = 0.0
	overlay.modulate.a = 0.0
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(x_container, "scale", Vector2(1.2, 1.2), 0.15)
	tween.tween_property(x_container, "modulate:a", 1.0, 0.1)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.2)
	await tween.finished
	var settle_tween = create_tween()
	settle_tween.tween_property(x_container, "scale", Vector2(1.0, 1.0), 0.1)
	await settle_tween.finished
	await get_tree().create_timer(1.5).timeout
	var out_tween = create_tween()
	out_tween.set_parallel(true)
	out_tween.tween_property(x_container, "modulate:a", 0.0, 0.3)
	out_tween.tween_property(overlay, "modulate:a", 0.0, 0.3)
	await out_tween.finished
	canvas_layer.queue_free()
func play_pickup_sound():
	print("Pickup sound plays!")
func play_pickup_animation():
	var camera = get_viewport().get_camera_2d()
	Engine.time_scale = 0.2
	var tween1 = create_tween()
	tween1.set_parallel(true)
	tween1.tween_property(self, "scale", Vector2(3.0, 3.0), 0.4)
	if camera:
		_apply_screen_shake(camera, 0.6)
	await tween1.finished
	var screen_center = camera.global_position
	var tween2 = create_tween()
	tween2.set_parallel(true)
	tween2.tween_property(self, "global_position", screen_center, 0.2)
	tween2.tween_property(self, "scale", Vector2(0.1, 0.1), 0.2)
	tween2.tween_property(self, "modulate:a", 0.0, 0.15)
	await tween2.finished
	Engine.time_scale = 1.0
func _apply_screen_shake(camera: Camera2D, duration: float):
	var original_offset = camera.offset
	var intensity = float(SettingsManager.get_setting(SettingsManager.SECTION_GAMEPLAY, "screen_shake_intensity", 1.0))
	var shake_strength = 15.0 * clamp(intensity, 0.0, 2.0)
	var shake_tween = create_tween()
	shake_tween.set_loops()
	for i in range(int(duration * 60)):
		var shake_offset = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
		shake_tween.tween_property(camera, "offset", original_offset + shake_offset, 0.016)
	var stop_timer = get_tree().create_timer(duration)
	await stop_timer.timeout
	shake_tween.kill()
	camera.offset = original_offset
func show_rune_info():
	var canvas_layer = create_info_panel()
	get_tree().current_scene.add_child(canvas_layer)
	var panel = canvas_layer.get_child(0)
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.05, 0.05)
	panel.position += Vector2(0, -300)
	var camera = get_viewport().get_camera_2d()
	if camera:
		_apply_screen_shake(camera, 0.5)
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(panel, "scale", Vector2(1.4, 1.4), 0.12)
	tween.tween_property(panel, "modulate:a", 1.0, 0.08)
	tween.tween_property(panel, "position:y", panel.position.y + 300, 0.12)
	await tween.finished
	var settle_tween = create_tween()
	settle_tween.set_parallel(true)
	settle_tween.tween_property(panel, "scale", Vector2(0.95, 0.95), 0.08)
	await settle_tween.finished
	var final_tween = create_tween()
	final_tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.05)
	await final_tween.finished
	var start_time = Time.get_time_dict_from_system()
	var timeout_duration = 5.0
	var should_close = false
	while not should_close:
		await get_tree().process_frame
		if Input.is_action_just_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
			should_close = true
			break
		var current_time = Time.get_time_dict_from_system()
		var elapsed = (current_time.hour * 3600 + current_time.minute * 60 + current_time.second) - (start_time.hour * 3600 + start_time.minute * 60 + start_time.second)
		if elapsed >= timeout_duration:
			should_close = true
			break
	var out_tween = create_tween()
	out_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	out_tween.parallel().tween_property(panel, "modulate:a", 0.0, 0.3)
	out_tween.parallel().tween_property(panel, "scale", Vector2(0.8, 0.8), 0.3)
	await out_tween.finished
	canvas_layer.queue_free()
func create_info_panel() -> CanvasLayer:
	var canvas_layer = CanvasLayer.new()
	canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.size = Vector2(800, 400)
	panel.position = Vector2(-400, -200)
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.95)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(overlay)
	var content_bg = ColorRect.new()
	content_bg.color = Color(0.02, 0.0, 0.05, 0.98)
	content_bg.position = Vector2(50, 50)
	content_bg.size = Vector2(700, 300)
	panel.add_child(content_bg)
	var border = ColorRect.new()
	border.position = Vector2(45, 45)
	border.size = Vector2(710, 310)
	border.color = Color(0.8, 0.0, 0.0, 1.0)
	panel.add_child(border)
	panel.move_child(border, 1)
	var inner_glow = ColorRect.new()
	inner_glow.position = Vector2(47, 47)
	inner_glow.size = Vector2(706, 306)
	inner_glow.color = Color(0.4, 0.0, 0.0, 0.5)
	panel.add_child(inner_glow)
	panel.move_child(inner_glow, 2)
	var title = RichTextLabel.new()
	title.size = Vector2(700, 80)
	title.position = Vector2(50, 80)
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	var font_path = "res://assets/fonts/October Crow.ttf"
	if ResourceLoader.exists(font_path):
		var custom_font = load(font_path)
		title.add_theme_font_override("normal_font", custom_font)
		title.add_theme_font_override("bold_font", custom_font)
	title.add_theme_font_size_override("normal_font_size", 48)
	title.add_theme_color_override("default_color", Color(1.0, 0.0, 0.0))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.add_theme_constant_override("shadow_outline_size", 6)
	title.add_theme_color_override("font_outline_color", Color(0.5, 0, 0))
	title.add_theme_constant_override("outline_size", 2)
	title.text = "[center][wave amp=30 freq=2][shake rate=20 level=5]" + get_rune_name() + " ACQUIRED[/shake][/wave][/center]"
	panel.add_child(title)
	var desc = RichTextLabel.new()
	desc.size = Vector2(680, 120)
	desc.position = Vector2(60, 170)
	desc.bbcode_enabled = true
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.fit_content = true
	desc.scroll_active = false
	var readable_font_path = "res://assets/fonts/Federant-Regular.ttf"
	if ResourceLoader.exists(readable_font_path):
		var custom_font = load(readable_font_path)
		desc.add_theme_font_override("normal_font", custom_font)
	desc.add_theme_font_size_override("normal_font_size", 20)
	desc.add_theme_color_override("default_color", Color(0.9, 0.9, 1.0))
	desc.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	desc.add_theme_constant_override("shadow_offset_x", 2)
	desc.add_theme_constant_override("shadow_offset_y", 2)
	desc.text = "[center][wave amp=10 freq=1]" + get_rune_description() + "[/wave][/center]"
	panel.add_child(desc)
	var effect = RichTextLabel.new()
	effect.size = Vector2(680, 60)
	effect.position = Vector2(60, 300)
	effect.bbcode_enabled = true
	effect.fit_content = true
	effect.scroll_active = false
	if ResourceLoader.exists(readable_font_path):
		var custom_font = load(readable_font_path)
		effect.add_theme_font_override("normal_font", custom_font)
	effect.add_theme_font_size_override("normal_font_size", 18)
	effect.add_theme_color_override("default_color", Color(0.8, 1.0, 0.8))
	effect.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	effect.add_theme_constant_override("shadow_offset_x", 2)
	effect.add_theme_constant_override("shadow_offset_y", 2)
	effect.text = "[center][shake rate=10 level=15][wave amp=15 freq=3]" + get_rune_effect() + "[/wave][/shake][/center]"
	panel.add_child(effect)
	canvas_layer.add_child(panel)
	return canvas_layer
func get_rune_name() -> String:
	match rune_type:
		RuneSystem.RuneType.RANGE_AMPLIFIER:
			return "Range Amplifier"
		RuneSystem.RuneType.DURATION_CRYSTAL:
			return "Duration Crystal"
		RuneSystem.RuneType.RAPID_PULSE:
			return "Rapid Pulse"
		_:
			return "Unknown Rune"
func get_rune_description() -> String:
	match rune_type:
		RuneSystem.RuneType.RANGE_AMPLIFIER:
			return "An ancient crystal infused with resonant energy. When activated, it amplifies the range of your sonar pulses, allowing you to detect distant threats and passages through the darkness."
		RuneSystem.RuneType.DURATION_CRYSTAL:
			return "A shimmering gemstone that bends time itself. This mysterious artifact extends the duration of your sonar's illuminating effect, giving you more time to navigate treacherous terrain."
		RuneSystem.RuneType.RAPID_PULSE:
			return "A volatile energy core that pulses with unstable power. When harnessed, it dramatically reduces the cooldown between sonar pulses, allowing for rapid exploration of unknown areas."
		_:
			return "A mysterious artifact of unknown origin."
func get_rune_effect() -> String:
	match rune_type:
		RuneSystem.RuneType.RANGE_AMPLIFIER:
			return "Effect: +50% Sonar Range • Duration: 30s • Cooldown: 60s"
		RuneSystem.RuneType.DURATION_CRYSTAL:
			return "Effect: +100% Platform Highlight Duration • Duration: 30s • Cooldown: 60s"
		RuneSystem.RuneType.RAPID_PULSE:
			return "Effect: -30% Sonar Cooldown • Duration: 30s • Cooldown: 60s"
		_:
			return "Effect: Unknown"
