extends Node
class_name MedkitSystem
const SCARY_FONT = preload("res://assets/fonts/October Crow.ttf")
const COLOR_BACKGROUND = Color(0.04, 0.0, 0.0, 0.92)
const COLOR_BORDER = Color(0.8, 0.1, 0.1, 0.9)
const COLOR_TEXT_PRIMARY = Color(0.9, 0.8, 0.8, 1.0)
const COLOR_TEXT_SECONDARY = Color(0.7, 0.6, 0.6, 0.9)
const COLOR_MEDKIT_AVAILABLE = Color(0.2, 0.8, 0.3, 1.0)
const COLOR_MEDKIT_EMPTY = Color(0.8, 0.3, 0.3, 0.6)
var max_medkits: int = 3
var medkit_heal_amount: int = 2
var current_medkits: int = 0
var player: Node
var reward_system: Node
var medkit_ui_container: Control
var medkit_count_label: Label
var medkit_icons: Array[Control] = []
var medkit_input_action: String = "use_medkit"
var medkit_use_sound: AudioStreamPlayer
var healing_effect_scene: PackedScene
signal medkit_used(amount_healed: int)
signal medkit_added(total_count: int)
signal medkit_count_changed(new_count: int)
signal medkit_inventory_full
func _ready():
	_setup_references()
	_setup_ui()
	_setup_audio()
	_setup_input_handling()
func _setup_references():
	player = get_tree().get_first_node_in_group("player")
	reward_system = _find_node_by_name(get_tree().current_scene, "RewardSystem")
	if reward_system and is_instance_valid(reward_system):
		reward_system.medkit_system = self
func _find_node_by_name(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	for child in node.get_children():
		var result = _find_node_by_name(child, name)
		if result:
			return result
	return null
func _setup_ui():
	if not player or not is_instance_valid(player):
		return
	medkit_ui_container = Control.new()
	medkit_ui_container.name = "MedkitUIContainer"
	medkit_ui_container.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	medkit_ui_container.position = Vector2(20, -140)
	medkit_ui_container.size = Vector2(220, 70)
	medkit_ui_container.visible = false
	var ui_layer = player.get_node_or_null("health_ui_layer")
	if ui_layer and is_instance_valid(ui_layer):
		ui_layer.add_child(medkit_ui_container)
	else:
		var health_ui_layer = CanvasLayer.new()
		health_ui_layer.name = "health_ui_layer"
		health_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		player.add_child(health_ui_layer)
		health_ui_layer.add_child(medkit_ui_container)
	_create_medkit_ui_elements()
	_update_medkit_ui()
func _create_medkit_ui_elements():
	var bg_panel = Panel.new()
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_panel.add_theme_stylebox_override("panel", _create_medkit_panel_style())
	medkit_ui_container.add_child(bg_panel)
	var title_label = Label.new()
	title_label.text = "MEDICAL SUPPLIES"
	title_label.position = Vector2(10, 8)
	title_label.size = Vector2(180, 20)
	title_label.add_theme_font_override("font", SCARY_FONT)
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	title_label.add_theme_constant_override("shadow_offset_x", 2)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	medkit_ui_container.add_child(title_label)
	medkit_count_label = Label.new()
	medkit_count_label.text = "0/3"
	medkit_count_label.position = Vector2(10, 30)
	medkit_count_label.size = Vector2(60, 25)
	medkit_count_label.add_theme_font_override("font", SCARY_FONT)
	medkit_count_label.add_theme_font_size_override("font_size", 16)
	medkit_count_label.add_theme_color_override("font_color", COLOR_MEDKIT_AVAILABLE)
	medkit_count_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	medkit_count_label.add_theme_constant_override("shadow_offset_x", 2)
	medkit_count_label.add_theme_constant_override("shadow_offset_y", 2)
	medkit_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	medkit_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	medkit_ui_container.add_child(medkit_count_label)
	var key_label = Label.new()
	key_label.text = "PRESS [H] TO USE"
	key_label.position = Vector2(80, 30)
	key_label.size = Vector2(130, 25)
	key_label.add_theme_font_override("font", SCARY_FONT)
	key_label.add_theme_font_size_override("font_size", 10)
	key_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	key_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	key_label.add_theme_constant_override("shadow_offset_x", 1)
	key_label.add_theme_constant_override("shadow_offset_y", 1)
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	medkit_ui_container.add_child(key_label)
	for i in range(max_medkits):
		var icon = _create_improved_medkit_icon(i)
		medkit_ui_container.add_child(icon)
		medkit_icons.append(icon)
func _create_medkit_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BACKGROUND
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = COLOR_BORDER
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 4
	style.shadow_offset = Vector2(2, 2)
	return style
func _create_improved_medkit_icon(index: int) -> Control:
	var icon_container = Control.new()
	icon_container.position = Vector2(10 + (index * 65), 55)
	icon_container.size = Vector2(18, 12)
	var icon_bg = ColorRect.new()
	icon_bg.color = Color(0.1, 0.05, 0.05, 0.8)
	icon_bg.size = Vector2(18, 12)
	icon_bg.position = Vector2(0, 0)
	icon_container.add_child(icon_bg)
	var icon_border = ColorRect.new()
	icon_border.color = COLOR_BORDER
	icon_border.size = Vector2(18, 12)
	icon_border.position = Vector2(-1, -1)
	icon_container.add_child(icon_border)
	icon_container.move_child(icon_border, 0)
	var icon = TextureRect.new()
	icon.position = Vector2(1, 1)
	icon.size = Vector2(16, 10)
	icon.texture = _create_enhanced_medkit_texture()
	icon.modulate = Color(1, 1, 1, 0.4)
	icon_container.add_child(icon)
	return icon_container
func _create_enhanced_medkit_texture() -> ImageTexture:
	var image = Image.create(16, 10, false, Image.FORMAT_RGBA8)
	for y in range(10):
		for x in range(16):
			var color = Color.TRANSPARENT
			if x >= 2 and x <= 13 and y >= 1 and y <= 8:
				color = Color(0.95, 0.95, 0.95, 1.0)
			if x >= 6 and x <= 9 and y >= 3 and y <= 6:
				color = Color(0.9, 0.1, 0.1, 1.0)
			if x >= 7 and x <= 8 and y >= 2 and y <= 7:
				color = Color(0.9, 0.1, 0.1, 1.0)
			if x >= 6 and x <= 9 and y == 1:
				color = Color(0.6, 0.6, 0.6, 1.0)
			if ((x == 2 or x == 13) and y >= 1 and y <= 8) or ((y == 1 or y == 8) and x >= 2 and x <= 13):
				color = Color(0.4, 0.4, 0.4, 1.0)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)
func _create_medkit_icon(index: int) -> TextureRect:
	var icon = TextureRect.new()
	icon.position = Vector2(140 + (index * 15), 2)
	icon.size = Vector2(12, 16)
	var image = Image.create(12, 16, false, Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(12):
			if (x >= 4 and x <= 7) or (y >= 6 and y <= 9):
				image.set_pixel(x, y, Color.WHITE)
			elif (x >= 3 and x <= 8 and y >= 5 and y <= 10):
				image.set_pixel(x, y, Color(0.8, 0.2, 0.2))
			else:
				image.set_pixel(x, y, Color.TRANSPARENT)
	var texture = ImageTexture.create_from_image(image)
	icon.texture = texture
	icon.modulate = Color(1, 1, 1, 0.3)
	return icon
func _setup_audio():
	medkit_use_sound = AudioStreamPlayer.new()
	medkit_use_sound.name = "MedkitUseSound"
	add_child(medkit_use_sound)
func _setup_input_handling():
	if not InputMap.has_action("use_medkit"):
		InputMap.add_action("use_medkit")
		var key_event = InputEventKey.new()
		key_event.keycode = KEY_H
		InputMap.action_add_event("use_medkit", key_event)
func _input(event):
	if event.is_action_pressed("use_medkit"):
		use_medkit()
func add_medkits(amount: int) -> bool:
	var previous_count = current_medkits
	current_medkits = min(current_medkits + amount, max_medkits)
	var actual_added = current_medkits - previous_count
	if actual_added > 0:
		if previous_count == 0 and current_medkits > 0:
			_animate_ui_appearance()
		medkit_added.emit(current_medkits)
		medkit_count_changed.emit(current_medkits)
		_update_medkit_ui()
		_show_medkit_notification(actual_added)
		if current_medkits >= max_medkits:
			medkit_inventory_full.emit()
		return true
	return false
func _animate_ui_appearance():
	if not medkit_ui_container:
		return
	medkit_ui_container.visible = true
	medkit_ui_container.modulate = Color(1, 1, 1, 0)
	medkit_ui_container.scale = Vector2(0.8, 0.8)
	var tween = medkit_ui_container.create_tween()
	tween.set_parallel(true)
	tween.tween_property(medkit_ui_container, "modulate:a", 1.0, 0.5)
	tween.tween_property(medkit_ui_container, "scale", Vector2(1.0, 1.0), 0.4)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
func use_medkit() -> bool:
	if current_medkits <= 0:
		_show_no_medkits_message()
		return false
	if not player:
		return false
	var player_health = player.get("health")
	var max_health = player.get("MAX_HEALTH")
	if player_health >= max_health:
		_show_full_health_message()
		return false
	current_medkits -= 1
	var amount_healed = min(medkit_heal_amount, max_health - player_health)
	if player.has_method("heal"):
		player.heal(amount_healed)
	_play_medkit_use_effects()
	_update_medkit_ui()
	medkit_used.emit(amount_healed)
	medkit_count_changed.emit(current_medkits)
	return true
func _play_medkit_use_effects():
	if medkit_use_sound and medkit_use_sound.stream:
		medkit_use_sound.play()
	_create_healing_visual_effect()
func _create_healing_visual_effect():
	if not player:
		return
	var particles = CPUParticles2D.new()
	player.add_child(particles)
	particles.emitting = true
	particles.amount = 20
	particles.lifetime = 1.0
	particles.one_shot = true
	particles.direction = Vector2(0, -1)
	particles.spread = 45.0
	particles.initial_velocity_min = 20.0
	particles.initial_velocity_max = 40.0
	particles.gravity = Vector2(0, -50)
	particles.scale_amount_min = 0.3
	particles.scale_amount_max = 0.8
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.2, 1.0, 0.2, 0.8))
	gradient.add_point(1.0, Color(0.0, 0.8, 0.0, 0.0))
	particles.color_ramp = gradient
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
		timer.queue_free()
	)
	add_child(timer)
	timer.start()
func _update_medkit_ui():
	if medkit_ui_container:
		medkit_ui_container.visible = current_medkits > 0
	if medkit_count_label:
		medkit_count_label.text = str(current_medkits) + "/" + str(max_medkits)
		if current_medkits == 0:
			medkit_count_label.add_theme_color_override("font_color", COLOR_MEDKIT_EMPTY)
		elif current_medkits < max_medkits:
			medkit_count_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3, 1.0))
		else:
			medkit_count_label.add_theme_color_override("font_color", COLOR_MEDKIT_AVAILABLE)
	for i in range(medkit_icons.size()):
		if i < current_medkits:
			var icon_texture = medkit_icons[i].get_child(2) as TextureRect
			if icon_texture:
				icon_texture.modulate = Color(1.0, 1.0, 1.0, 1.0)
				var bg = medkit_icons[i].get_child(0) as ColorRect
				if bg:
					bg.color = Color(0.15, 0.1, 0.05, 0.9)
		else:
			var icon_texture = medkit_icons[i].get_child(2) as TextureRect
			if icon_texture:
				icon_texture.modulate = Color(0.4, 0.4, 0.4, 0.5)
				var bg = medkit_icons[i].get_child(0) as ColorRect
				if bg:
					bg.color = Color(0.05, 0.05, 0.05, 0.6)
func _show_medkit_notification(amount: int):
	if not player:
		return
	var notification = _create_notification("+" + str(amount) + " MEDKIT" + ("S" if amount > 1 else ""), Color(0.6, 0.8, 0.6))
	var ui_layer = player.get_node_or_null("health_ui_layer")
	if ui_layer:
		ui_layer.add_child(notification)
		_animate_notification(notification)
func _show_no_medkits_message():
	if not player:
		return
	var notification = _create_notification("NO MEDKITS AVAILABLE", Color(0.8, 0.3, 0.3))
	var ui_layer = player.get_node_or_null("health_ui_layer")
	if ui_layer:
		ui_layer.add_child(notification)
		_animate_notification(notification)
func _show_full_health_message():
	if not player:
		return
	var notification = _create_notification("HEALTH ALREADY FULL", Color(0.8, 0.8, 0.3))
	var ui_layer = player.get_node_or_null("health_ui_layer")
	if ui_layer:
		ui_layer.add_child(notification)
		_animate_notification(notification)
func _create_notification(text: String, color: Color) -> Control:
	var notification = Control.new()
	notification.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	notification.position = Vector2(-100, -50)
	notification.size = Vector2(200, 40)
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.15, 0.9)
	bg.size = notification.size
	notification.add_child(bg)
	var label = Label.new()
	label.text = text
	label.size = notification.size
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notification.add_child(label)
	return notification
func _animate_notification(notification: Control):
	notification.modulate = Color(1, 1, 1, 0)
	notification.position.y -= 20
	var tween = notification.create_tween()
	tween.set_parallel(true)
	tween.tween_property(notification, "modulate:a", 1.0, 0.2)
	tween.tween_property(notification, "position:y", notification.position.y + 20, 0.2)
	tween.tween_interval(1.5)
	tween.tween_property(notification, "modulate:a", 0.0, 0.3)
	tween.tween_property(notification, "position:y", notification.position.y - 10, 0.3)
	await tween.finished
	notification.queue_free()
func get_medkit_count() -> int:
	return current_medkits
func get_max_medkits() -> int:
	return max_medkits
func is_inventory_full() -> bool:
	return current_medkits >= max_medkits
func can_use_medkit() -> bool:
	if current_medkits <= 0:
		return false
	if not player:
		return false
	var player_health = player.get("health")
	var max_health = player.get("MAX_HEALTH")
	return player_health < max_health
func check_critical_health():
	if not player:
		return
	var player_health = player.get("health")
	var max_health = player.get("MAX_HEALTH")
	if player_health <= 3 and current_medkits > 0 and player_health < max_health:
		_show_critical_health_suggestion()
func _show_critical_health_suggestion():
	var notification = _create_notification("PRESS [H] TO USE MEDKIT", Color(1.0, 0.8, 0.3))
	var ui_layer = player.get_node_or_null("health_ui_layer")
	if ui_layer:
		ui_layer.add_child(notification)
		_animate_notification(notification)
func get_medkit_save_data() -> Dictionary:
	return {
		"current_medkits": current_medkits,
		"max_medkits": max_medkits
	}
func load_medkit_save_data(data: Dictionary):
	if data.has("current_medkits"):
		current_medkits = data.current_medkits
	if data.has("max_medkits"):
		max_medkits = data.max_medkits
	_update_medkit_ui()
func _on_player_health_changed(new_health: int):
	if new_health <= 3:
		check_critical_health()
