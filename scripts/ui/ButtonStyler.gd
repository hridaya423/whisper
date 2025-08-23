
extends Node

const BUTTON_FONT_SIZE = 24
const BUTTON_MIN_WIDTH = 300
const BUTTON_MIN_HEIGHT = 55

const COLOR_NORMAL = Color(0.7, 0.7, 0.7, 0.7)
const COLOR_HOVER = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_PRESSED = Color(0.8, 0.1, 0.1, 1.0)

var transitioning = false

func style_button(button: Button):
	style_single_button(button)

func style_all_buttons(node: Node):
	for child in node.get_children():
		if child is Button:
			style_single_button(child)
		if child.get_child_count() > 0:
			style_all_buttons(child)

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
	button.add_theme_stylebox_override("normal", create_normal_stylebox())
	button.add_theme_stylebox_override("hover", create_hover_stylebox())
	button.add_theme_stylebox_override("pressed", create_pressed_stylebox())
	button.add_theme_stylebox_override("focus", create_focus_stylebox())
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.text = button.text.to_upper()
	button.set_meta("original_text", button.text)
	button.set_meta("is_hovering", false)
	setup_button_animations(button)

func create_normal_stylebox() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	
	style.border_width_left = 2
	style.border_color = Color(0.3, 0.3, 0.3, 0.3)
	
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	
	return style

func create_hover_stylebox() -> StyleBoxFlat:
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

func create_pressed_stylebox() -> StyleBoxFlat:
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

func create_focus_stylebox() -> StyleBoxFlat:
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

func _on_button_hover(button: Button):
	if transitioning:
		return
		
	button.set_meta("is_hovering", true)
	
	var tween = button.create_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.2)
	
	start_glitch_effect(button)

func _on_button_unhover(button: Button):
	if transitioning:
		return
		
	button.set_meta("is_hovering", false)
	
	var tween = button.create_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.3)
	
	stop_glitch_effect(button)

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
		if is_instance_valid(timer):
			timer.queue_free()
		if button.has_meta("original_text"):
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
