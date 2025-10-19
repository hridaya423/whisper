extends CanvasLayer
class_name PauseMenu

signal resume_requested
signal restart_requested
signal quit_requested

@export var resume_button_path: NodePath
@export var restart_button_path: NodePath
@export var quit_button_path: NodePath

var resume_button: Button
var restart_button: Button
var quit_button: Button

const BUTTON_FONT_SIZE = 24
const BUTTON_MIN_WIDTH = 300
const BUTTON_MIN_HEIGHT = 55
const BUTTON_SPACING = 25
const COLOR_NORMAL = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_HOVER = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_PRESSED = Color(0.8, 0.1, 0.1, 1.0)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 210
	set_process_unhandled_input(true)

	if resume_button_path != NodePath():
		resume_button = get_node_or_null(resume_button_path)
	if restart_button_path != NodePath():
		restart_button = get_node_or_null(restart_button_path)
	if quit_button_path != NodePath():
		quit_button = get_node_or_null(quit_button_path)

	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

	var panel = $Panel
	if panel:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.8)
		panel.add_theme_stylebox_override("panel", style)
		panel.modulate = Color.WHITE

		if resume_button:
			style_single_button(resume_button)
		if restart_button:
			style_single_button(restart_button)
		if quit_button:
			style_single_button(quit_button)

	hide()

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
	style.bg_color = Color(0, 0, 0, 0.5)
	style.border_width_left = 2
	style.border_color = Color(0.3, 0.3, 0.3, 0.3)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	return style

func create_hover_stylebox() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
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
	button.set_meta("is_hovering", true)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.2)

func _on_button_unhover(button: Button):
	button.set_meta("is_hovering", false)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.3)

func show_menu():
	show()
	if resume_button:
		resume_button.grab_focus()

func hide_menu():
	hide()
	if resume_button and resume_button.has_focus():
		resume_button.release_focus()

func _on_resume_pressed():
	resume_requested.emit()

func _on_restart_pressed():
	restart_requested.emit()

func _on_quit_pressed():
	quit_requested.emit()

func _unhandled_input(event):
	if not visible:
		return
	if event.is_action_pressed("pause_game"):
		resume_requested.emit()
