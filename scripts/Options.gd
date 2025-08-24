extends Control

const BUTTON_FONT_SIZE = 24
const BUTTON_MIN_WIDTH = 300
const BUTTON_MIN_HEIGHT = 55
const SLIDER_MIN_WIDTH = 400
const SLIDER_MIN_HEIGHT = 30

const COLOR_NORMAL = Color(0.7, 0.7, 0.7, 0.7)
const COLOR_HOVER = Color(0.8, 0.1, 0.1, 1.0)
const COLOR_PRESSED = Color(0.8, 0.1, 0.1, 1.0)

const MAIN_MENU_SCENE = "res://scenes/ui/MainMenu.tscn"

var transitioning = false
var volume_slider: HSlider
var volume_label: Label

func _ready():
	style_all_buttons(self)
	style_all_sliders(self)
	setup_volume_controls()
	connect_button_logic()

func setup_volume_controls():
	volume_slider = find_child("VolumeSlider") as HSlider
	volume_label = find_child("VolumeLabel") as Label
	
	if volume_slider:
		volume_slider.min_value = 0.0
		volume_slider.max_value = 100.0
		volume_slider.step = 1.0
		volume_slider.value = 50.0
		
		volume_slider.value_changed.connect(_on_volume_changed)
		volume_slider.drag_started.connect(_on_slider_drag_started)
		volume_slider.drag_ended.connect(_on_slider_drag_ended.bind(false))
		
		_on_volume_changed(volume_slider.value)

func _on_volume_changed(value: float):
	var db_value = linear_to_db(value / 100.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db_value)
	
	if volume_label:
		volume_label.text = "VOLUME: " + str(int(value)) + "%"

func _on_slider_drag_started():
	if volume_slider:
		var tween = create_tween()
		tween.tween_property(volume_slider, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.1)

func _on_slider_drag_ended(value_changed: bool):
	if volume_slider:
		var tween = create_tween()
		tween.tween_property(volume_slider, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)

func style_all_buttons(node: Node):
	for child in node.get_children():
		if child is Button:
			style_single_button(child)
		if child.get_child_count() > 0:
			style_all_buttons(child)

func style_all_sliders(node: Node):
	for child in node.get_children():
		if child is HSlider:
			style_single_slider(child)
		if child.get_child_count() > 0:
			style_all_sliders(child)

func style_single_button(button: Button):
	button.custom_minimum_size = Vector2(BUTTON_MIN_WIDTH, BUTTON_MIN_HEIGHT)
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	button.add_theme_color_override("font_color", COLOR_NORMAL)
	button.add_theme_color_override("font_hover_color", COLOR_HOVER)
	button.add_theme_color_override("font_pressed_color", COLOR_PRESSED)
	button.add_theme_color_override("font_focus_color", Color(0.9, 0.9, 0.9, 0.9))
	button.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	button.add_theme_constant_override("shadow_offset_x", 2)
	button.add_theme_constant_override("shadow_offset_y", 2)
	button.add_theme_stylebox_override("normal", create_button_normal_stylebox())
	button.add_theme_stylebox_override("hover", create_button_hover_stylebox())
	button.add_theme_stylebox_override("pressed", create_button_pressed_stylebox())
	button.add_theme_stylebox_override("focus", create_button_focus_stylebox())
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.text = button.text.to_upper()
	button.set_meta("original_text", button.text)
	button.set_meta("is_hovering", false)
	setup_button_animations(button)

func style_single_slider(slider: HSlider):
	slider.custom_minimum_size = Vector2(SLIDER_MIN_WIDTH, SLIDER_MIN_HEIGHT)
	slider.add_theme_stylebox_override("slider", create_slider_track_stylebox())
	slider.add_theme_stylebox_override("grabber", create_slider_grabber_stylebox())
	slider.add_theme_stylebox_override("grabber_highlight", create_slider_grabber_highlight_stylebox())
	slider.add_theme_stylebox_override("grabber_area", create_slider_fill_stylebox())
	slider.add_theme_stylebox_override("grabber_area_highlight", create_slider_fill_highlight_stylebox())
	
	setup_slider_animations(slider)

func create_slider_track_stylebox() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.3, 0.3, 0.5)
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	
	return style

func create_slider_fill_stylebox() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.1, 0.1, 0.7)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.8, 0.2, 0.2, 0.6)
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	
	return style

func create_slider_fill_highlight_stylebox() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.6, 0.15, 0.15, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.3, 0.3, 0.8)
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	style.shadow_color = Color(0.8, 0.2, 0.2, 0.3)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 0)
	
	return style

func create_slider_grabber_stylebox() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.9)
	
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.5, 0.5, 0.5, 0.7)
	
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	
	return style

func create_slider_grabber_highlight_stylebox() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	
	style.bg_color = Color(0.4, 0.4, 0.4, 1.0)
	
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 1.0, 1.0, 0.8)
	
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	
	style.shadow_color = Color(1.0, 1.0, 1.0, 0.3)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 0)
	
	return style

func create_button_normal_stylebox() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	
	style.border_width_left = 2
	style.border_color = Color(0.3, 0.3, 0.3, 0.3)
	
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	
	return style

func create_button_hover_stylebox() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	
	style.bg_color = Color(0.15, 0.15, 0.15, 0.3)
	
	style.border_width_left = 3
	style.border_width_right = 1
	style.border_color = Color(1.0, 1.0, 1.0, 0.4)
	
	style.corner_radius_top_left = 2
	style.corner_radius_bottom_left = 2
	
	style.shadow_color = Color(1.0, 1.0, 1.0, 0.15)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 0)
	
	style.content_margin_left = 35
	style.content_margin_right = 30
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	
	return style

func create_button_pressed_stylebox() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	
	style.bg_color = Color(0.2, 0.05, 0.05, 0.4)
	
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.border_color = Color(0.8, 0.2, 0.2, 0.8)
	
	style.content_margin_left = 32
	style.content_margin_right = 28
	style.content_margin_top = 17
	style.content_margin_bottom = 13
	
	return style

func create_button_focus_stylebox() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	
	style.border_width_left = 2
	style.border_color = Color(0.5, 0.5, 0.5, 0.2)
	
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	
	return style

func setup_button_animations(button: Button):
	if not button.mouse_entered.is_connected(_on_button_hover):
		button.mouse_entered.connect(_on_button_hover.bind(button))
	if not button.mouse_exited.is_connected(_on_button_unhover):
		button.mouse_exited.connect(_on_button_unhover.bind(button))

func setup_slider_animations(slider: HSlider):
	if not slider.mouse_entered.is_connected(_on_slider_hover):
		slider.mouse_entered.connect(_on_slider_hover.bind(slider))
	if not slider.mouse_exited.is_connected(_on_slider_unhover):
		slider.mouse_exited.connect(_on_slider_unhover.bind(slider))

func _on_button_hover(button: Button):
	if transitioning:
		return
		
	button.set_meta("is_hovering", true)
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.2)
	
	start_glitch_effect(button)

func _on_button_unhover(button: Button):
	if transitioning:
		return
		
	button.set_meta("is_hovering", false)
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.3)
	
	stop_glitch_effect(button)

func _on_slider_hover(slider: HSlider):
	if transitioning:
		return
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_loops()
	tween.tween_property(slider, "modulate", Color(1.1, 1.1, 1.1, 1.0), 0.8)
	tween.tween_property(slider, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.8)
	slider.set_meta("hover_tween", tween)

func _on_slider_unhover(slider: HSlider):
	if transitioning:
		return
	
	if slider.has_meta("hover_tween"):
		var tween = slider.get_meta("hover_tween")
		if tween:
			tween.kill()
	
	var tween = create_tween()
	tween.tween_property(slider, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)

func start_glitch_effect(button: Button):
	if transitioning:
		return
		
	var timer = Timer.new()
	timer.wait_time = 0.1
	timer.timeout.connect(_glitch_text.bind(button, timer))
	button.add_child(timer)
	timer.start()
	button.set_meta("glitch_timer_node", timer)

func stop_glitch_effect(button: Button):
	if button.has_meta("glitch_timer_node"):
		var timer = button.get_meta("glitch_timer_node")
		if timer and is_instance_valid(timer):
			timer.queue_free()
	
	if button.has_meta("original_text"):
		button.text = button.get_meta("original_text")

func _glitch_text(button: Button, timer: Timer):
	if transitioning or not button.get_meta("is_hovering"):
		timer.queue_free()
		button.text = button.get_meta("original_text")
		return
	
	var original = button.get_meta("original_text")
	var glitched = ""
	
	for i in range(original.length()):
		if randf() < 0.05:
			glitched += char(randi_range(65, 90))
		else:
			glitched += original[i]
	
	button.text = glitched

func connect_button_logic():
	var back_button = find_button_by_text("GO BACK")
	
	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed.bind(back_button))

func _on_back_pressed(button: Button):
	if transitioning:
		return
	
	transitioning = true
	play_click_animation_and_transition(button, MAIN_MENU_SCENE)

func play_click_animation_and_transition(button: Button, scene_path: String):
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC)
	
	var original_pos = button.position
	
	for i in range(5):
		tween.tween_property(button, "position", original_pos + Vector2(randf_range(-8, 8), randf_range(-3, 3)), 0.05)
	
	tween.tween_property(button, "position", original_pos, 0.05)
	
	tween.parallel().tween_property(button, "modulate", Color(2, 0.5, 0.5, 1), 0.1)
	tween.tween_property(button, "modulate", Color(1, 1, 1, 1), 0.4)
	
	tween.parallel().tween_property(button, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.4)
	
	await get_tree().create_timer(0.15).timeout
	
	var fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.size = get_viewport().size
	fade.mouse_filter = Control.MOUSE_FILTER_STOP 
	add_child(fade)
	move_child(fade, get_child_count() - 1)
	
	var fade_tween = create_tween()
	fade_tween.tween_property(fade, "color", Color(0, 0, 0, 1), 0.3)
	await fade_tween.finished
	get_tree().change_scene_to_file(scene_path)

func find_button_by_text(text: String) -> Button:
	return find_button_recursive(self, text.to_upper())

func find_button_recursive(node: Node, text: String) -> Button:
	for child in node.get_children():
		if child is Button and child.text.to_upper() == text:
			return child
		var result = find_button_recursive(child, text)
		if result:
			return result
	return null
